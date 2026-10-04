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
    this.nuevas = 0,
    this.actualizadas = 0,
    this.movidas = 0,
    this.desaparecidas = 0,
    this.recuperadas = 0,
    this.enUso = 0,
    this.idsNuevos = const [],
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

  /// Películas que no estaban en el catálogo.
  final int nuevas;

  /// Películas que ya estaban y se han vuelto a leer porque el archivo ha
  /// cambiado.
  final int actualizadas;

  /// Películas que estaban en otra carpeta o con otro nombre (se reconocen
  /// por el tamaño y la fecha del archivo y conservan su ficha).
  final int movidas;

  /// Películas que estaban en el catálogo y ya no están en el disco.
  final int desaparecidas;

  /// Películas desaparecidas que han vuelto a su sitio.
  final int recuperadas;

  /// Archivos que todavía se están copiando: se leerán más tarde.
  final int enUso;

  /// Números de las películas nuevas guardadas (para avisar).
  final List<int> idsNuevos;

  /// Nombre del último archivo leído.
  final String actual;
  final Duration transcurrido;

  /// Explicación si algo ha ido mal.
  final String mensaje;

  /// Ha cambiado algo en el catálogo.
  bool get hayCambios =>
      nuevas + actualizadas + movidas + desaparecidas + recuperadas > 0;

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
    int? nuevas,
    int? actualizadas,
    int? movidas,
    int? desaparecidas,
    int? recuperadas,
    int? enUso,
    List<int>? idsNuevos,
    String? actual,
    Duration? transcurrido,
    String? mensaje,
  }) => ProgresoEscaneo(
    fase: fase ?? this.fase,
    encontradas: encontradas ?? this.encontradas,
    porLeer: porLeer ?? this.porLeer,
    leidas: leidas ?? this.leidas,
    errores: errores ?? this.errores,
    nuevas: nuevas ?? this.nuevas,
    actualizadas: actualizadas ?? this.actualizadas,
    movidas: movidas ?? this.movidas,
    desaparecidas: desaparecidas ?? this.desaparecidas,
    recuperadas: recuperadas ?? this.recuperadas,
    enUso: enUso ?? this.enUso,
    idsNuevos: idsNuevos ?? this.idsNuevos,
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
    this.marcarNuevas = false,
  });

  final BaseDatos bd;
  final String raiz;
  final CarpetasApp carpetas;

  /// Películas que se leen a la vez. En un disco duro mecánico, 4 va algo
  /// más rápido que 1 sin saturarlo.
  final int trabajadores;

  /// Las películas que no estaban en el catálogo van a la bandeja de
  /// Películas nuevas. En el primer escaneo no (serían todas).
  final bool marcarNuevas;

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

      // 2. Archivos que ya no están donde estaban y archivos que no se
      //    conocían. Si coinciden en tamaño y fecha, es la misma película
      //    movida o renombrada: conserva su ficha (y su número).
      final rutasEnDisco = {for (final a in enDisco) a.ruta};
      final faltan = {
        for (final MapEntry(:key, :value) in conocidos.entries)
          if (!rutasEnDisco.contains(key)) key: value,
      };
      final desconocidos = [
        for (final a in enDisco)
          if (!conocidos.containsKey(a.ruta)) a,
      ];
      final movidas = emparejarMovidas(faltan, desconocidos);
      final releer = <String>{};
      for (final (desde, hacia) in movidas) {
        final u = ubicacionEnColeccion(raiz, hacia.ruta);
        await bd.moverPelicula(
          faltan[desde]!.id,
          ruta: hacia.ruta,
          grupo: u.grupo,
          generoCarpeta: u.genero,
        );
        // Con otro nombre de archivo, se vuelve a leer por si acaso.
        if (_nombre(desde) != _nombre(hacia.ruta)) releer.add(hacia.ruta);
        final antes = faltan.remove(desde)!;
        conocidos[hacia.ruta] = (
          id: antes.id,
          tamano: antes.tamano,
          modificado: antes.modificado,
          conError: antes.conError,
          desaparecida: false,
        );
      }

      // 3. Lo que sigue sin aparecer se marca como desaparecido (no se borra:
      //    se ve en Pendientes). Lo que había desaparecido y ha vuelto, se
      //    desmarca.
      final nuevasDesaparecidas = [
        for (final c in faltan.values)
          if (!c.desaparecida) c.id,
      ];
      await bd.marcarDesaparecidas(nuevasDesaparecidas, DateTime.now());
      final recuperadas = [
        for (final a in enDisco)
          if (conocidos[a.ruta] case final c? when c.desaparecida) c.id,
      ];
      await bd.marcarDesaparecidas(recuperadas, null);

      // 4. Qué hay que leer: lo nuevo, lo cambiado y lo que dio error. Lo que
      //    se está copiando todavía se deja para luego.
      var enUso = 0, actualizadas = 0;
      final porLeer = <ArchivoEncontrado>[];
      final nuevasRutas = <String>{};
      for (final a in enDisco) {
        final conocido = conocidos[a.ruta];
        if (conocido == null) {
          if (archivoEnUso(a.ruta)) {
            enUso++;
          } else {
            porLeer.add(a);
            nuevasRutas.add(a.ruta);
          }
        } else if (_haCambiado(a, conocido)) {
          porLeer.add(a);
          actualizadas++;
        } else if (completo || conocido.conError || releer.contains(a.ruta)) {
          // Se vuelve a leer, pero no cuenta como cambio.
          porLeer.add(a);
        }
      }
      _rutasNuevas = marcarNuevas ? nuevasRutas : const {};

      progreso = progreso.copiar(
        fase: FaseEscaneo.leyendo,
        encontradas: enDisco.length,
        porLeer: porLeer.length,
        nuevas: nuevasRutas.length,
        actualizadas: actualizadas,
        movidas: movidas.length,
        desaparecidas: nuevasDesaparecidas.length,
        recuperadas: recuperadas.length,
        enUso: enUso,
      );
      avisar(siempre: true);

      // 5. Leer los archivos con varios trabajadores.
      if (porLeer.isNotEmpty) {
        final puerto = _puerto = ReceivePort();
        final cola = porLeer.reversed.toList();
        final buzones = <SendPort>[];
        var ocupados = 0;
        final lote = <LecturaCatalogo>[];
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
          } else if (mensaje is (SendPort, LecturaCatalogo)) {
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
        idsNuevos: List.unmodifiable(_idsNuevos),
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

  /// ¿Ha cambiado el archivo desde que se leyó (tamaño o fecha)?
  bool _haCambiado(ArchivoEncontrado a, ArchivoConocido conocido) {
    // La base de datos guarda las fechas con precisión de segundos.
    final segundos = a.modificado.millisecondsSinceEpoch ~/ 1000;
    return conocido.tamano != a.tamano ||
        conocido.modificado.millisecondsSinceEpoch ~/ 1000 != segundos;
  }

  /// Archivos que no estaban en el catálogo (para marcarlos como nuevos).
  Set<String> _rutasNuevas = const {};
  final _idsNuevos = <int>[];

  /// Guarda un lote de películas leídas, con sus miniaturas.
  Future<void> _guardar(List<LecturaCatalogo> lote) async {
    if (lote.isEmpty) return;
    await bd.transaction(() async {
      for (final l in lote) {
        final nueva = _rutasNuevas.contains(l.fila.ruta.value);
        final id = await bd.guardarPelicula(
          l.fila.copyWith(nueva: Value(nueva)),
        );
        if (nueva) _idsNuevos.add(id);
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
class LecturaCatalogo {
  LecturaCatalogo(this.fila, this.miniatura, this.error);
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
    respuestas.send((buzon.sendPort, leerParaCatalogo(raiz, archivo)));
  });
}

/// Lee un archivo y prepara su fila de la base de datos y su miniatura.
LecturaCatalogo leerParaCatalogo(String raiz, ArchivoEncontrado archivo) {
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
  return LecturaCatalogo(
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
      desaparecida: const Value(null),
    ),
    miniatura,
    error,
  );
}

/// Empareja archivos que ya no están ([faltan], ruta → lo que se sabía) con
/// archivos desconocidos ([nuevos]) que tienen el mismo tamaño y la misma
/// fecha de modificación: son la misma película movida o renombrada.
///
/// Si hay varios candidatos (p. ej. dos copias idénticas de una película
/// movidas a la vez), se emparejan por el nombre del archivo; si aun así hay
/// dudas, no se empareja nada (más vale una «nueva» que una ficha cambiada).
List<(String, ArchivoEncontrado)> emparejarMovidas(
  Map<String, ArchivoConocido> faltan,
  List<ArchivoEncontrado> nuevos,
) {
  String huella(int tamano, DateTime fecha) =>
      '$tamano·${fecha.millisecondsSinceEpoch ~/ 1000}';
  final porHuella = <String, List<String>>{};
  for (final MapEntry(:key, :value) in faltan.entries) {
    (porHuella[huella(value.tamano, value.modificado)] ??= []).add(key);
  }
  final nuevosPorHuella = <String, List<ArchivoEncontrado>>{};
  for (final a in nuevos) {
    final h = huella(a.tamano, a.modificado);
    if (porHuella.containsKey(h)) (nuevosPorHuella[h] ??= []).add(a);
  }
  final parejas = <(String, ArchivoEncontrado)>[];
  for (final MapEntry(key: h, value: candidatos) in nuevosPorHuella.entries) {
    final antiguos = [...porHuella[h]!];
    final restantes = <ArchivoEncontrado>[];
    for (final a in candidatos) {
      final mismoNombre = [
        for (final r in antiguos)
          if (_nombre(r) == _nombre(a.ruta)) r,
      ];
      if (mismoNombre.length == 1) {
        parejas.add((mismoNombre.single, a));
        antiguos.remove(mismoNombre.single);
      } else {
        restantes.add(a);
      }
    }
    if (restantes.length == 1 && antiguos.length == 1) {
      parejas.add((antiguos.single, restantes.single));
    }
  }
  return parejas;
}

/// Nombre del archivo, sin la carpeta, en minúsculas.
String _nombre(String ruta) =>
    ruta.substring(ruta.lastIndexOf(Platform.pathSeparator) + 1).toLowerCase();

/// ¿Hay otro programa escribiendo en el archivo? (P. ej. el Explorador
/// mientras lo copia.) Se intenta abrir sin dejar que nadie escriba a la vez:
/// si Windows no deja, es que alguien lo tiene abierto para escribir.
bool archivoEnUso(String ruta) {
  if (!Platform.isWindows) return false;
  final texto = ruta.toNativeUtf16();
  try {
    final manija = _createFile(
      texto,
      _GENERIC_READ,
      _FILE_SHARE_READ,
      nullptr,
      _OPEN_EXISTING,
      0,
      nullptr,
    );
    if (manija.address == _INVALID_HANDLE_VALUE) return true;
    _closeHandle(manija);
    return false;
  } finally {
    calloc.free(texto);
  }
}

// ignore: constant_identifier_names
const _GENERIC_READ = 0x80000000;
// ignore: constant_identifier_names
const _FILE_SHARE_READ = 0x1;
// ignore: constant_identifier_names
const _OPEN_EXISTING = 3;
// ignore: constant_identifier_names
const _INVALID_HANDLE_VALUE = -1;

final _createFile = DynamicLibrary.open('kernel32.dll')
    .lookupFunction<
      Pointer<Void> Function(
        Pointer<Utf16>,
        Uint32,
        Uint32,
        Pointer<Void>,
        Uint32,
        Uint32,
        Pointer<Void>,
      ),
      Pointer<Void> Function(
        Pointer<Utf16>,
        int,
        int,
        Pointer<Void>,
        int,
        int,
        Pointer<Void>,
      )
    >('CreateFileW');

final _closeHandle = DynamicLibrary.open('kernel32.dll')
    .lookupFunction<Int32 Function(Pointer<Void>), int Function(Pointer<Void>)>(
      'CloseHandle',
    );

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
