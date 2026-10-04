import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:ffi/ffi.dart';
import 'package:image/image.dart' as img;

import '../datos/base_datos.dart';
import '../datos/carpetas_app.dart';
import 'lector_archivo.dart';

// El escáner recorre la carpeta raíz, lee cada `.mp4` (datos y carátula) y lo
// guarda en la base de datos. **Solo lee** los archivos de películas.
//
// Para ir rápido, varios "trabajadores" (isolates: como pequeños programas
// en paralelo) leen películas a la vez mientras la pantalla sigue fluida.
// Si se vuelve a escanear, solo se leen los archivos nuevos o cambiados.
//
// No usa nada de Flutter: también se puede lanzar desde la terminal con
// `dart run tool/escanear.dart`.

/// Un `.mp4` encontrado en el disco.
typedef ArchivoEncontrado = ({
  String ruta,
  int tamano,
  DateTime modificado,
  DateTime creado,
});

/// Busca todos los `.mp4` (y `.m4v`, que es el mismo formato) dentro de
/// [raiz], en cualquier nivel de carpetas.
/// Se salta las carpetas ocultas y de sistema (papelera, `$RECYCLE.BIN`…).
List<ArchivoEncontrado> buscarMp4(String raiz) {
  final encontrados = <ArchivoEncontrado>[];
  void recorrer(Directory carpeta) {
    final List<FileSystemEntity> contenido;
    try {
      contenido = carpeta.listSync(followLinks: false);
    } on FileSystemException {
      return; // Carpeta sin permiso de lectura: se ignora.
    }
    for (final e in contenido) {
      if (e is Directory) {
        if (!_esOcultaODeSistema(e.path)) recorrer(e);
      } else if (e is File && _esVideo(e.path)) {
        final datos = e.statSync();
        encontrados.add((
          ruta: e.path,
          tamano: datos.size,
          modificado: datos.modified,
          // En Windows, `changed` es la fecha de creación del archivo.
          creado: datos.changed,
        ));
      }
    }
  }

  recorrer(Directory(raiz));
  encontrados.sort((a, b) => a.ruta.compareTo(b.ruta));
  return encontrados;
}

/// Como [buscarMp4], pero sin frenar la pantalla.
Future<List<ArchivoEncontrado>> buscarMp4EnSegundoPlano(String raiz) =>
    Isolate.run(() => buscarMp4(raiz));

/// Grupo (carpeta de primer nivel) y género (carpeta donde está el archivo).
///
/// `D:\Comedias\Comedia\Joy (2015).mp4` → ("Comedias", "Comedia").
/// Si la película está directamente en una carpeta de primer nivel, esa
/// carpeta es el género y no hay grupo.
({String grupo, String genero}) ubicacionEnColeccion(String raiz, String ruta) {
  final sep = Platform.pathSeparator;
  var relativa = ruta.startsWith(raiz) ? ruta.substring(raiz.length) : ruta;
  while (relativa.startsWith(sep)) {
    relativa = relativa.substring(1);
  }
  final carpetas = relativa.split(sep)..removeLast();
  return (
    grupo: carpetas.length >= 2 ? carpetas.first : '',
    genero: carpetas.isEmpty ? '' : carpetas.last,
  );
}

/// Resumen de lo encontrado, para el asistente de primer arranque.
class EstructuraColeccion {
  EstructuraColeccion(this.raiz, this.archivos) {
    for (final a in archivos) {
      final u = ubicacionEnColeccion(raiz, a.ruta);
      if (u.grupo.isNotEmpty) {
        (porGrupo[u.grupo] ??= {}).add(u.genero);
      }
      if (u.genero.isNotEmpty) {
        porGenero[u.genero] = (porGenero[u.genero] ?? 0) + 1;
      }
    }
  }

  final String raiz;
  final List<ArchivoEncontrado> archivos;

  /// Género → número de películas.
  final porGenero = <String, int>{};

  /// Grupo → sus géneros.
  final porGrupo = <String, Set<String>>{};

  int get total => archivos.length;

  /// Géneros ordenados de más a menos películas.
  List<(String, int)> get generos =>
      [for (final MapEntry(:key, :value) in porGenero.entries) (key, value)]
        ..sort((a, b) => b.$2.compareTo(a.$2));
}

/// Analiza [raiz] sin frenar la pantalla.
Future<EstructuraColeccion> analizarCarpeta(String raiz) =>
    Isolate.run(() => EstructuraColeccion(raiz, buscarMp4(raiz)));

// ── El escaneo ───────────────────────────────────────────────────────────

enum FaseEscaneo { buscando, leyendo, terminado, cancelado, error }

/// Cómo va el escaneo (lo que se muestra en la barra de progreso).
class ProgresoEscaneo {
  const ProgresoEscaneo({
    required this.fase,
    this.encontradas = 0,
    this.porLeer = 0,
    this.leidas = 0,
    this.errores = 0,
    this.borradas = 0,
    this.actual = '',
    this.transcurrido = Duration.zero,
    this.mensaje = '',
  });

  final FaseEscaneo fase;

  /// `.mp4` que hay en el disco.
  final int encontradas;

  /// Cuántos hay que leer (los nuevos o cambiados) y cuántos van leídos.
  final int porLeer;
  final int leidas;

  /// Archivos que Windows no pudo leer.
  final int errores;

  /// Películas que estaban en el catálogo y ya no están en el disco.
  final int borradas;

  /// Nombre del último archivo leído.
  final String actual;
  final Duration transcurrido;

  /// Explicación si algo ha ido mal.
  final String mensaje;

  bool get enMarcha =>
      fase == FaseEscaneo.buscando || fase == FaseEscaneo.leyendo;

  /// De 0 a 1 (o `null` mientras se buscan los archivos).
  double? get fraccion => fase == FaseEscaneo.buscando
      ? null
      : porLeer == 0
      ? 1
      : leidas / porLeer;

  /// Tiempo que falta, calculado con lo que se lleva hecho.
  Duration? get restante {
    if (fase != FaseEscaneo.leyendo || leidas < 12) return null;
    final porArchivo = transcurrido.inMilliseconds / leidas;
    return Duration(milliseconds: (porArchivo * (porLeer - leidas)).round());
  }

  ProgresoEscaneo copiar({
    FaseEscaneo? fase,
    int? encontradas,
    int? porLeer,
    int? leidas,
    int? errores,
    int? borradas,
    String? actual,
    Duration? transcurrido,
    String? mensaje,
  }) => ProgresoEscaneo(
    fase: fase ?? this.fase,
    encontradas: encontradas ?? this.encontradas,
    porLeer: porLeer ?? this.porLeer,
    leidas: leidas ?? this.leidas,
    errores: errores ?? this.errores,
    borradas: borradas ?? this.borradas,
    actual: actual ?? this.actual,
    transcurrido: transcurrido ?? this.transcurrido,
    mensaje: mensaje ?? this.mensaje,
  );
}

/// Escanea la colección y la guarda en [bd].
class Escaner {
  Escaner({
    required this.bd,
    required this.raiz,
    required this.carpetas,
    this.trabajadores = 4,
  });

  final BaseDatos bd;
  final String raiz;
  final CarpetasApp carpetas;

  /// Películas que se leen a la vez. En un disco duro mecánico, 4 va algo
  /// más rápido que 1 sin saturarlo.
  final int trabajadores;

  final _reloj = Stopwatch();
  ReceivePort? _puerto;
  bool _cancelado = false;

  /// Detiene el escaneo. Lo ya leído queda guardado y la próxima vez se
  /// sigue por donde se quedó.
  void cancelar() {
    _cancelado = true;
    _puerto?.close();
  }

  /// Lanza el escaneo y va informando del progreso.
  /// Con [completo], vuelve a leer todos los archivos aunque no hayan cambiado.
  Stream<ProgresoEscaneo> ejecutar({bool completo = false}) {
    final salida = StreamController<ProgresoEscaneo>();
    _escanear(salida, completo).whenComplete(salida.close);
    return salida.stream;
  }

  Future<void> _escanear(
    StreamController<ProgresoEscaneo> salida,
    bool completo,
  ) async {
    _reloj.start();
    var progreso = const ProgresoEscaneo(fase: FaseEscaneo.buscando);
    salida.add(progreso);
    var ultimoAviso = 0;
    void avisar({bool siempre = false}) {
      // Como mucho unas 12 veces por segundo, para no saturar la pantalla.
      final ahora = _reloj.elapsedMilliseconds;
      if (!siempre && ahora - ultimoAviso < 80) return;
      ultimoAviso = ahora;
      progreso = progreso.copiar(transcurrido: _reloj.elapsed);
      salida.add(progreso);
    }

    final isolates = <Isolate>[];
    try {
      // 1. Qué hay en el disco.
      if (!Directory(raiz).existsSync()) {
        throw _ErrorEscaneo(
          'No se encuentra la carpeta $raiz. ¿Está el disco conectado?',
        );
      }
      final enDisco = await buscarMp4EnSegundoPlano(raiz);
      final conocidos = await bd.archivosConocidos();
      if (enDisco.isEmpty && conocidos.isNotEmpty) {
        // Por seguridad no se vacía el catálogo: lo normal es que algo falle.
        throw _ErrorEscaneo(
          'No hay ningún .mp4 en $raiz. No se ha cambiado nada del catálogo.',
        );
      }

      // 2. Qué hay que leer: lo nuevo, lo cambiado y lo que dio error.
      final porLeer = [
        for (final a in enDisco)
          if (completo || _hayQueLeer(a, conocidos[a.ruta])) a,
      ];

      // 3. Lo que ya no está en el disco sale del catálogo.
      final rutasEnDisco = {for (final a in enDisco) a.ruta};
      final desaparecidas = conocidos.keys.where(
        (r) => !rutasEnDisco.contains(r),
      );
      final borradas = await bd.borrarRutas(desaparecidas.toList());
      for (final id in borradas) {
        _borrarMiniatura(id);
      }

      progreso = progreso.copiar(
        fase: FaseEscaneo.leyendo,
        encontradas: enDisco.length,
        porLeer: porLeer.length,
        borradas: borradas.length,
      );
      avisar(siempre: true);

      // 4. Leer los archivos con varios trabajadores.
      if (porLeer.isNotEmpty) {
        final puerto = _puerto = ReceivePort();
        final cola = porLeer.reversed.toList();
        final buzones = <SendPort>[];
        var ocupados = 0;
        final lote = <_Lectura>[];
        var guardando = Future<void>.value();

        void repartir(SendPort buzon) {
          if (_cancelado || cola.isEmpty) return;
          buzon.send(cola.removeLast());
          ocupados++;
        }

        final cuantos = trabajadores.clamp(1, porLeer.length);
        for (var i = 0; i < cuantos; i++) {
          isolates.add(
            await Isolate.spawn(_trabajador, (puerto.sendPort, raiz)),
          );
        }

        await for (final mensaje in puerto) {
          if (mensaje is SendPort) {
            buzones.add(mensaje);
            repartir(mensaje);
          } else if (mensaje is (SendPort, _Lectura)) {
            final (buzon, lectura) = mensaje;
            ocupados--;
            lote.add(lectura);
            progreso = progreso.copiar(
              leidas: progreso.leidas + 1,
              errores: progreso.errores + (lectura.error == null ? 0 : 1),
              actual: lectura.fila.titulo.value,
            );
            avisar();
            if (lote.length >= 25) {
              final guardar = [...lote];
              lote.clear();
              guardando = guardando.then((_) => _guardar(guardar));
            }
            repartir(buzon);
          }
          if (ocupados == 0 && (cola.isEmpty || _cancelado)) break;
        }
        puerto.close();
        await guardando;
        await _guardar(lote);
      }

      progreso = progreso.copiar(
        fase: _cancelado ? FaseEscaneo.cancelado : FaseEscaneo.terminado,
      );
    } on _ErrorEscaneo catch (e) {
      progreso = progreso.copiar(fase: FaseEscaneo.error, mensaje: e.mensaje);
    } catch (e) {
      progreso = progreso.copiar(
        fase: FaseEscaneo.error,
        mensaje: 'Error inesperado: $e',
      );
    } finally {
      for (final i in isolates) {
        i.kill();
      }
      _reloj.stop();
      avisar(siempre: true);
    }
  }

  bool _hayQueLeer(ArchivoEncontrado a, ArchivoConocido? conocido) {
    if (conocido == null || conocido.conError) return true;
    // La base de datos guarda las fechas con precisión de segundos.
    final segundos = a.modificado.millisecondsSinceEpoch ~/ 1000;
    return conocido.tamano != a.tamano ||
        conocido.modificado.millisecondsSinceEpoch ~/ 1000 != segundos;
  }

  /// Guarda un lote de películas leídas, con sus miniaturas.
  Future<void> _guardar(List<_Lectura> lote) async {
    if (lote.isEmpty) return;
    await bd.transaction(() async {
      for (final l in lote) {
        final id = await bd.guardarPelicula(l.fila);
        if (l.miniatura != null) {
          await File(carpetas.miniatura(id)).writeAsBytes(l.miniatura!);
        } else {
          _borrarMiniatura(id);
        }
      }
    });
  }

  void _borrarMiniatura(int id) {
    final archivo = File(carpetas.miniatura(id));
    if (archivo.existsSync()) archivo.deleteSync();
  }
}

class _ErrorEscaneo implements Exception {
  _ErrorEscaneo(this.mensaje);
  final String mensaje;
}

/// Lo que un trabajador devuelve de cada archivo.
class _Lectura {
  _Lectura(this.fila, this.miniatura, this.error);
  final PeliculasCompanion fila;
  final Uint8List? miniatura;
  final String? error;
}

/// Programa de cada trabajador: recibe archivos y devuelve lo leído.
void _trabajador((SendPort, String) inicio) {
  final (respuestas, raiz) = inicio;
  final buzon = ReceivePort();
  respuestas.send(buzon.sendPort);
  buzon.listen((archivo) {
    respuestas.send((buzon.sendPort, _leerParaCatalogo(raiz, archivo)));
  });
}

/// Lee un archivo y prepara su fila de la base de datos y su miniatura.
_Lectura _leerParaCatalogo(String raiz, ArchivoEncontrado archivo) {
  DatosArchivo datos;
  String? error;
  try {
    datos = leerArchivo(archivo.ruta);
  } catch (e) {
    // Se guarda igualmente con el título y el año del nombre del archivo.
    error = '$e';
    datos = DatosArchivo(
      ruta: archivo.ruta,
      propiedades: const {},
      caratula: null,
      tamanoBytes: archivo.tamano,
    );
  }
  Uint8List? miniatura;
  if (datos.caratula != null) {
    try {
      miniatura = crearMiniatura(datos.caratula!);
    } catch (_) {
      // Imagen dañada o en un formato raro: se queda sin miniatura.
    }
  }
  final u = ubicacionEnColeccion(raiz, archivo.ruta);
  return _Lectura(
    PeliculasCompanion.insert(
      ruta: archivo.ruta,
      grupo: Value(u.grupo),
      generoCarpeta: Value(u.genero),
      titulo: datos.titulo,
      tituloOriginal: Value(datos.texto('System.Media.SubTitle')),
      anio: Value(datos.anio),
      generos: Value(datos.generos.join('. ')),
      temas: Value(datos.lista('System.Keywords').join('; ')),
      sinopsis: Value(datos.texto('System.Comment')),
      direccion: Value(datos.texto('System.Video.Director')),
      guion: Value(datos.texto('System.Media.Writer')),
      reparto: Value(datos.texto('System.Music.Artist')),
      musica: Value(datos.texto('System.Music.Composer')),
      fotografia: Value(datos.texto('System.Music.Conductor')),
      productora: Value(datos.texto('System.Media.Producer')),
      pais: Value(datos.texto('System.Media.Publisher')),
      premios: Value(datos.texto('System.Music.Period')),
      clasificacion: Value(datos.texto('System.ParentalRating')),
      estrellas: Value(datos.estrellas),
      saga: Value(datos.texto('System.Music.AlbumTitle')),
      numeroSaga: Value(datos.numero('System.Music.TrackNumber')),
      enlaceFilmaffinity: Value(datos.texto('System.Media.AuthorUrl')),
      enlaceImdb: Value(datos.texto('System.Media.PromotionUrl')),
      duracionMin: Value(datos.duracionMin),
      resolucion: Value(datos.resolucion),
      tamanoBytes: Value(archivo.tamano),
      tieneCaratula: Value(datos.caratula != null),
      tieneMiniatura: Value(miniatura != null),
      anadida: archivo.creado,
      modificado: archivo.modificado,
      escaneada: DateTime.now(),
      errorLectura: Value(error),
    ),
    miniatura,
    error,
  );
}

/// Ancho de las miniaturas: suficiente para la cuadrícula del catálogo y
/// pesa unas 8 veces menos que la carátula original.
const anchoMiniatura = 240;

/// Reduce una carátula (JPEG o PNG) a una miniatura JPEG.
Uint8List? crearMiniatura(Uint8List caratula) {
  final imagen = img.decodeImage(caratula);
  if (imagen == null) return null;
  final pequena = imagen.width > anchoMiniatura
      ? img.copyResize(
          imagen,
          width: anchoMiniatura,
          interpolation: img.Interpolation.average,
        )
      : imagen;
  return img.encodeJpg(pequena, quality: 82, chroma: img.JpegChroma.yuv420);
}

/// Carpetas ocultas o de sistema de Windows (papelera, "System Volume
/// Information"…). En otros sistemas, las que empiezan por punto.
bool _esOcultaODeSistema(String ruta) {
  final nombre = ruta.split(Platform.pathSeparator).last;
  if (!Platform.isWindows) return nombre.startsWith('.');
  final texto = ruta.toNativeUtf16();
  try {
    final atributos = _getFileAttributes(texto);
    if (atributos == 0xFFFFFFFF) return false; // No se pudo saber.
    return atributos & (_FILE_ATTRIBUTE_HIDDEN | _FILE_ATTRIBUTE_SYSTEM) != 0;
  } finally {
    calloc.free(texto);
  }
}

// ignore: constant_identifier_names
const _FILE_ATTRIBUTE_HIDDEN = 0x2;
// ignore: constant_identifier_names
const _FILE_ATTRIBUTE_SYSTEM = 0x4;

final _getFileAttributes = DynamicLibrary.open('kernel32.dll')
    .lookupFunction<
      Uint32 Function(Pointer<Utf16>),
      int Function(Pointer<Utf16>)
    >('GetFileAttributesW');

/// Vídeos MP4: `.mp4` y `.m4v` (el mismo formato con otra extensión).
bool _esVideo(String ruta) {
  final r = ruta.toLowerCase();
  return r.endsWith('.mp4') || r.endsWith('.m4v');
}
