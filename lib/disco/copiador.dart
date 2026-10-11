import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import '../errores.dart';
import 'red.dart';
import 'unidades_windows.dart';

// Copiar una película a un disco o pendrive del PC donde se está (el del
// administrador o uno de la red de casa). La película solo se lee: nunca se
// escribe nada en su disco.
//
// La copia va en otro hilo, a trozos (se lee el siguiente mientras se
// escribe el anterior), con un nombre provisional («Joy (2015).mp4.parcial»):
// solo cuando está entera y comprobada pasa a llamarse como la película. Así,
// si se cancela, se quita el pendrive o se apaga el PC de las películas a
// mitad, no queda un .mp4 roto.
//
// No usa nada de Flutter.

/// Carpeta donde se guardan las copias, en la raíz de cada unidad.
const carpetaCopias = 'Películas';

/// Final del nombre provisional mientras se copia.
const finalParcial = '.parcial';

/// Espacio que se deja libre de más: un disco lleno del todo da problemas.
const margenLibre = 16 * 1024 * 1024;

// ── Unidades ─────────────────────────────────────────────────────────────

/// Cómo va conectada una unidad.
enum Conexion {
  interna,
  usb,

  /// Tarjeta de memoria en un lector del PC.
  tarjeta,

  /// Extraíble, pero Windows no dice por dónde va conectada.
  extraible,
}

/// Lo que se sabe del disco donde está una carpeta.
class Volumen {
  const Volumen({
    required this.sistema,
    required this.libre,
    required this.total,
    this.soloLectura = false,
  });

  /// Formato: `NTFS`, `exFAT`, `FAT32`…
  final String sistema;
  final int libre;
  final int total;
  final bool soloLectura;
}

/// Un disco, pendrive o tarjeta de este PC.
class Unidad extends Volumen {
  const Unidad({
    required this.letra,
    this.etiqueta = '',
    required this.conexion,
    this.extraible = false,
    required super.sistema,
    required super.libre,
    required super.total,
    super.soloLectura,
    this.existente,
  });

  /// `E:`
  final String letra;

  /// Nombre que se le ha puesto (`KINGSTON`); puede ir vacío.
  final String etiqueta;
  final Conexion conexion;

  /// Windows la trata como extraíble (los pendrives; los discos USB, no).
  final bool extraible;

  /// Si la película ya está en su carpeta de copias, lo que ocupa.
  final int? existente;

  /// Donde se guardan las copias: `E:\Películas`.
  String get carpeta => '$letra\\$carpetaCopias';

  /// «KINGSTON (E:)», «Pendrive (E:)», «Disco local (C:)».
  String get nombre {
    final base = etiqueta.isNotEmpty
        ? etiqueta
        : switch (conexion) {
            Conexion.usb when extraible => 'Pendrive',
            Conexion.usb => 'Disco USB',
            Conexion.tarjeta => 'Tarjeta de memoria',
            Conexion.extraible => 'Unidad extraíble',
            Conexion.interna => 'Disco local',
          };
    return '$base ($letra)';
  }

  /// «Pendrive USB», «Disco interno»…
  String get tipo => switch (conexion) {
    Conexion.usb when extraible => 'Pendrive USB',
    Conexion.usb => 'Disco USB',
    Conexion.tarjeta => 'Tarjeta de memoria',
    Conexion.extraible => 'Extraíble',
    Conexion.interna => 'Disco interno',
  };

  /// Los pendrives, discos USB y tarjetas van primero.
  bool get deQuitarYPoner => conexion != Conexion.interna;
}

/// Los discos, pendrives y tarjetas de este PC en los que se puede guardar
/// algo, por orden: primero los que se conectan y desconectan (pendrives,
/// discos USB, tarjetas), después los internos. No salen las unidades de red,
/// los lectores de CD ni los lectores de tarjetas vacíos. Con [archivo]
/// (`Joy (2015).mp4`), cada unidad dice si ya lo tiene en su carpeta de
/// copias.
List<Unidad> unidadesDeEstePc({String? archivo}) => sinVentanasDeWindows(() {
  final unidades = <Unidad>[];
  for (final letra in letrasDeUnidades()) {
    final tipo = tipoDeUnidad(letra);
    if (tipo != TipoUnidad.fija && tipo != TipoUnidad.extraible) continue;
    final datos = datosDeVolumen('$letra\\');
    final espacio = espacioDe('$letra\\');
    // Sin nada dentro (un lector de tarjetas vacío).
    if (datos == null || espacio == null || espacio.total == 0) continue;
    final bus = busDeUnidad(letra);
    int? existente;
    if (archivo != null) {
      final f = File('$letra\\$carpetaCopias\\$archivo');
      try {
        if (f.existsSync()) existente = f.lengthSync();
      } on FileSystemException {
        // No se puede mirar: como si no estuviera.
      }
    }
    unidades.add(
      Unidad(
        letra: letra,
        etiqueta: datos.etiqueta,
        conexion: switch (bus) {
          _busUsb => Conexion.usb,
          _busSd || _busMmc => Conexion.tarjeta,
          _ when tipo == TipoUnidad.extraible => Conexion.extraible,
          _ => Conexion.interna,
        },
        extraible: tipo == TipoUnidad.extraible,
        sistema: datos.sistema,
        soloLectura: datos.soloLectura,
        libre: espacio.libre,
        total: espacio.total,
        existente: existente,
      ),
    );
  }
  return unidades..sort(
    (a, b) => a.deQuitarYPoner != b.deQuitarYPoner
        ? (a.deQuitarYPoner ? -1 : 1)
        : a.letra.compareTo(b.letra),
  );
});

// `STORAGE_BUS_TYPE` de Windows.
const _busUsb = 7;
const _busSd = 12;
const _busMmc = 13;

/// Formato, espacio libre y total del disco donde está [carpeta] (también
/// una carpeta de red). `null` si no se puede saber.
Volumen? volumenDe(String carpeta) => sinVentanasDeWindows(() {
  final espacio = espacioDe(carpeta);
  if (espacio == null) return null;
  final raiz = raizDeVolumen(carpeta);
  final datos = raiz == null ? null : datosDeVolumen(raiz);
  return Volumen(
    sistema: datos?.sistema ?? '',
    soloLectura: datos?.soloLectura ?? false,
    libre: espacio.libre,
    total: espacio.total,
  );
});

// ── Antes de empezar ─────────────────────────────────────────────────────

/// Por qué no se puede guardar una película en un disco.
enum Impedimento {
  /// El disco es de solo lectura (o está protegido contra escritura).
  soloLectura,

  /// Su formato (FAT32) no admite archivos tan grandes.
  formato,

  /// No hay espacio.
  noCabe,
}

/// Lo más grande que admite un archivo en el formato [sistema], o `null` si
/// no hay límite que importe. FAT32: 4 GB menos un byte.
int? maximoArchivo(String sistema) => switch (sistema.toUpperCase()) {
  'FAT32' => 0xFFFFFFFF,
  'FAT' || 'FAT16' || 'FAT12' => 0x7FFFFFFF,
  _ => null,
};

/// Si una película de [tamano] bytes se puede guardar en [v]. [existente]
/// es lo que ocupa la que ya hay con el mismo nombre (si se va a
/// reemplazar, su sitio también vale).
Impedimento? impedimentoCopia(Volumen v, int tamano, {int existente = 0}) {
  if (v.soloLectura) return Impedimento.soloLectura;
  final maximo = maximoArchivo(v.sistema);
  if (maximo != null && tamano > maximo) return Impedimento.formato;
  if (v.libre + existente < tamano + margenLibre) return Impedimento.noCabe;
  return null;
}

/// ¿Está [carpeta] en el mismo disco (o la misma carpeta compartida de la
/// red) que [otra]? `E:\Pelis` y `e:\Otra` sí; `\\PC\Multimedia\Películas` y
/// `\\pc\multimedia\Copias` también.
bool mismoDisco(String carpeta, String otra) {
  String? base(String ruta) {
    final r = ruta.replaceAll('/', r'\').toLowerCase();
    if (r.startsWith(r'\\')) {
      final partes = r.substring(2).split(r'\').where((p) => p.isNotEmpty);
      return partes.length < 2 ? null : '\\\\${partes.take(2).join(r'\')}';
    }
    return RegExp(r'^[a-z]:').hasMatch(r) ? r.substring(0, 2) : null;
  }

  final a = base(carpeta);
  return a != null && a == base(otra);
}

/// Al reemplazar una película que ya está: si la nueva no cabe con la vieja
/// todavía ahí, hay que borrar la vieja antes de empezar.
bool hayQueBorrarAntes(Volumen v, int tamano, {required int existente}) =>
    existente > 0 && v.libre < tamano + margenLibre;

// ── Copiar ───────────────────────────────────────────────────────────────

/// Cómo va una copia.
class AvanceCopia {
  const AvanceCopia(this.copiados, this.total, {this.comprobando = false});

  final int copiados;
  final int total;

  /// Ya está todo copiado y se está comprobando.
  final bool comprobando;
}

enum FinCopia {
  hecha,
  cancelada,

  /// Ya había un archivo con ese nombre y no se ha pedido reemplazarlo.
  yaExiste,
  fallo,
}

/// Por qué ha fallado una copia.
enum FalloCopia {
  /// No se llega a la película: el PC de las películas se ha apagado o
  /// desconectado de la red, o (en el PC del administrador) el disco se ha
  /// desconectado.
  origenSinConexion,

  /// La película ya no está en esa ruta.
  origenNoEsta,

  /// No se ha podido leer la película (otro motivo).
  origenIlegible,

  /// El disco de destino ha desaparecido: se ha quitado el pendrive.
  destinoQuitado,
  sinEspacio,
  sinPermiso,

  /// El pendrive o la tarjeta están protegidos contra escritura.
  protegido,

  /// El formato del disco (FAT32) no admite archivos tan grandes.
  formato,

  /// La copia no ha salido igual que la original.
  distinta,
  otro,
}

class ResultadoCopia {
  const ResultadoCopia(this.fin, {this.fallo, this.detalle, this.restos});

  final FinCopia fin;
  final FalloCopia? fallo;

  /// Explicación del fallo, si no es uno de los conocidos.
  final String? detalle;

  /// El trozo a medias que no se ha podido borrar (p. ej. porque se ha
  /// quitado el pendrive), si lo hay.
  final String? restos;
}

/// Trozo que se lee y se escribe cada vez.
const _trozo = 8 * 1024 * 1024;

/// Cada cuánto se obliga a Windows a escribir de verdad lo copiado (si no,
/// en algunos discos USB se queda en memoria y la barra llegaría al final
/// mucho antes de que la copia esté hecha).
const _cadaCuantoGuardar = 128 * 1024 * 1024;

/// Lo más que se espera a un trozo. Si se apaga el PC de las películas o se
/// quita el pendrive, Windows puede tardar en rendirse.
const limiteTrozo = Duration(seconds: 45);

/// Copia [origen] en [destino] (la ruta completa del archivo nuevo; su
/// carpeta se crea si no existe). Si [destino] ya existe, solo se sustituye
/// con [reemplazar] (al final, cuando la copia está bien; o antes, con
/// [borrarAntes], si no caben las dos). [cancelada] se mira después de cada
/// trozo. [origen] solo se lee.
Future<ResultadoCopia> copiarArchivo(
  String origen,
  String destino, {
  bool reemplazar = false,
  bool borrarAntes = false,
  bool Function()? cancelada,
  void Function(AvanceCopia avance)? alAvanzar,
  Duration limite = limiteTrozo,
}) async {
  final parcial = '$destino$finalParcial';
  final carpeta = File(destino).parent;
  bool cancelar() => cancelada?.call() ?? false;

  // La película.
  RandomAccessFile? abierto;
  final int total;
  final DateTime modificada;
  try {
    abierto = await File(origen).open().timeout(limite);
    total = await abierto.length().timeout(limite);
    modificada = await File(origen).lastModified().timeout(limite);
  } on Object catch (e) {
    if (abierto != null) await _cerrar(abierto);
    return _falloOrigen(origen, e);
  }
  final leer = abierto;

  // Dónde va.
  final RandomAccessFile escribir;
  try {
    await carpeta.create(recursive: true).timeout(limite);
    if (await File(destino).exists()) {
      if (!reemplazar) {
        await _cerrar(leer);
        return const ResultadoCopia(FinCopia.yaExiste);
      }
      if (borrarAntes) await File(destino).delete();
    }
    await _borrarRestos(carpeta);
    escribir = await File(parcial).open(mode: FileMode.write).timeout(limite);
  } on Object catch (e) {
    await _cerrar(leer);
    return _falloDestino(carpeta.path, e);
  }
  var leerCerrado = false;
  var escribirCerrado = false;

  /// Deja las cosas como estaban: sin el trozo a medias.
  Future<ResultadoCopia> deshacer(
    ResultadoCopia r, {
    Future<void>? pendiente,
  }) async {
    if (!escribirCerrado) await _cerrar(escribir);
    if (!leerCerrado) await _cerrar(leer, pendiente: pendiente);
    final borrado = await _borrar(parcial);
    return ResultadoCopia(
      r.fin,
      fallo: r.fallo,
      detalle: r.detalle,
      restos: borrado ? null : parcial,
    );
  }

  final memorias = [Uint8List(_trozo), Uint8List(_trozo)];
  var cual = 0;
  var copiados = 0;
  var sinGuardar = 0;
  alAvanzar?.call(AvanceCopia(0, total));
  Future<int> lectura = leer.readInto(memorias[0]);
  while (true) {
    final int leidos;
    try {
      leidos = await lectura.timeout(limite);
    } on Object catch (e) {
      final r = await _falloOrigen(origen, e);
      return deshacer(r, pendiente: lectura);
    }
    if (leidos <= 0) break;
    final actual = memorias[cual];
    cual = 1 - cual;
    // El siguiente trozo se lee mientras se escribe este.
    lectura = copiados + leidos >= total
        ? Future.value(0)
        : leer.readInto(memorias[cual]);
    try {
      await escribir.writeFrom(actual, 0, leidos).timeout(limite);
      sinGuardar += leidos;
      if (sinGuardar >= _cadaCuantoGuardar) {
        await escribir.flush().timeout(limite);
        sinGuardar = 0;
      }
    } on Object catch (e) {
      lectura.ignore();
      final r = await _falloDestino(carpeta.path, e);
      return deshacer(r, pendiente: lectura);
    }
    copiados += leidos;
    alAvanzar?.call(AvanceCopia(copiados, total));
    if (cancelar()) {
      return deshacer(
        const ResultadoCopia(FinCopia.cancelada),
        pendiente: lectura,
      );
    }
  }

  // Comprobar que está entera y que es igual que la original.
  alAvanzar?.call(AvanceCopia(copiados, total, comprobando: true));
  try {
    await escribir.flush().timeout(limite * 4);
    await escribir.close().timeout(limite);
    escribirCerrado = true;
  } on Object catch (e) {
    return deshacer(await _falloDestino(carpeta.path, e));
  }
  await _cerrar(leer);
  leerCerrado = true;
  var igual = copiados == total;
  try {
    igual = igual && await File(parcial).length().timeout(limite) == total;
  } on Object catch (e) {
    return deshacer(await _falloDestino(carpeta.path, e));
  }
  try {
    igual = igual && await _mismasMuestras(origen, parcial, total, limite);
  } on _FalloAlComparar catch (f) {
    return deshacer(
      f.enDestino
          ? await _falloDestino(carpeta.path, f.error)
          : await _falloOrigen(origen, f.error),
    );
  }
  if (!igual) {
    return deshacer(
      const ResultadoCopia(FinCopia.fallo, fallo: FalloCopia.distinta),
    );
  }
  if (cancelar()) return deshacer(const ResultadoCopia(FinCopia.cancelada));

  // Ya puede llamarse como la película (con su fecha, como la original).
  try {
    try {
      await File(parcial).setLastModified(modificada);
    } on FileSystemException {
      // La fecha no es imprescindible.
    }
    if (await File(destino).exists()) await File(destino).delete();
    await File(parcial).rename(destino);
  } on Object catch (e) {
    return deshacer(await _falloDestino(carpeta.path, e));
  }
  return const ResultadoCopia(FinCopia.hecha);
}

/// Al comparar la copia con la original ha fallado la lectura de una de las
/// dos.
class _FalloAlComparar {
  const _FalloAlComparar(this.error, {required this.enDestino});

  final Object error;
  final bool enDestino;
}

/// Compara unos trozos de [original] y [copia] (el principio, el final y
/// dos de en medio).
Future<bool> _mismasMuestras(
  String original,
  String copia,
  int total,
  Duration limite,
) async {
  const muestra = 64 * 1024;
  final posiciones = {0, total ~/ 3, total * 2 ~/ 3, max(0, total - muestra)};

  /// Los trozos de [ruta] (si falla, se dice de cuál de las dos era).
  Future<List<List<int>>> trozos(String ruta, {required bool enDestino}) async {
    RandomAccessFile? f;
    try {
      f = await File(ruta).open().timeout(limite);
      return [
        for (final p in posiciones)
          await (await f.setPosition(p)).read(muestra).timeout(limite),
      ];
    } on Object catch (e) {
      throw _FalloAlComparar(e, enDestino: enDestino);
    } finally {
      if (f != null) await _cerrar(f);
    }
  }

  final a = await trozos(original, enDestino: false);
  final b = await trozos(copia, enDestino: true);
  for (var i = 0; i < a.length; i++) {
    if (a[i].length != b[i].length) return false;
    for (var j = 0; j < a[i].length; j++) {
      if (a[i][j] != b[i][j]) return false;
    }
  }
  return true;
}

/// Qué ha pasado al leer la película: se mira si se sigue llegando a ella.
Future<ResultadoCopia> _falloOrigen(String origen, Object error) async {
  const sinConexion = ResultadoCopia(
    FinCopia.fallo,
    fallo: FalloCopia.origenSinConexion,
  );
  final esta = await archivoEsta(origen);
  if (esta == null) return sinConexion;
  if (!esta) {
    // En el PC del administrador: ¿se ha desconectado el disco?
    final raiz = _raiz(origen);
    if (raiz != null && !await _existe(Directory(raiz))) return sinConexion;
    return const ResultadoCopia(FinCopia.fallo, fallo: FalloCopia.origenNoEsta);
  }
  // Se llega, pero algo ha ido mal (o ha tardado demasiado en contestar).
  if (error is TimeoutException) return sinConexion;
  return ResultadoCopia(
    FinCopia.fallo,
    fallo: FalloCopia.origenIlegible,
    detalle: explicarError(error),
  );
}

/// Qué ha pasado al escribir en [carpeta].
Future<ResultadoCopia> _falloDestino(String carpeta, Object error) async {
  final codigo = error is FileSystemException ? error.osError?.errorCode : null;
  final fallo = switch (codigo) {
    39 || 112 => FalloCopia.sinEspacio,
    19 => FalloCopia.protegido,
    5 => FalloCopia.sinPermiso,
    223 => FalloCopia.formato,
    _ => null,
  };
  if (fallo != null) return ResultadoCopia(FinCopia.fallo, fallo: fallo);
  if (!await _existe(Directory(carpeta))) {
    return const ResultadoCopia(
      FinCopia.fallo,
      fallo: FalloCopia.destinoQuitado,
    );
  }
  return ResultadoCopia(
    FinCopia.fallo,
    fallo: FalloCopia.otro,
    detalle: explicarError(error),
  );
}

/// Unidad de [ruta] (`D:\`) si es de este PC; `null` si es de red.
String? _raiz(String ruta) =>
    RegExp(r'^[A-Za-z]:').hasMatch(ruta) && equipoDeRuta(ruta) == null
    ? '${ruta.substring(0, 2)}\\'
    : null;

Future<bool> _existe(FileSystemEntity e) async {
  try {
    return await e.exists().timeout(const Duration(seconds: 8));
  } on Object {
    return false;
  }
}

/// Cierra [f] sin quejarse (si [pendiente] no ha acabado, se espera un poco:
/// Dart no deja cerrar un archivo que se está leyendo).
Future<void> _cerrar(RandomAccessFile f, {Future<void>? pendiente}) async {
  try {
    if (pendiente != null) {
      await pendiente.timeout(const Duration(seconds: 5));
    }
  } on Object {
    // Da igual cómo acabe.
  }
  try {
    await f.close().timeout(const Duration(seconds: 5));
  } on Object {
    // Ya cerrado o el disco ya no está.
  }
}

/// Borra [ruta] si existe. `false` si no se ha podido o no se sabe (p. ej.
/// se ha quitado el pendrive: el trozo seguirá en él al volver a ponerlo).
Future<bool> _borrar(String ruta) async {
  const limite = Duration(seconds: 8);
  try {
    final f = File(ruta);
    if (await f.exists().timeout(limite)) {
      await f.delete().timeout(limite);
      return true;
    }
    // No está… o no se llega a su carpeta.
    return await f.parent.exists().timeout(limite);
  } on Object {
    return false;
  }
}

/// Borra los trozos a medias que hayan quedado en [carpeta] de copias
/// anteriores (la app se cerró de golpe, se quitó el pendrive…).
Future<void> _borrarRestos(Directory carpeta) async {
  try {
    await for (final e in carpeta.list(followLinks: false)) {
      final nombre = e.path.toLowerCase();
      if (e is File &&
          (nombre.endsWith('.mp4$finalParcial') ||
              nombre.endsWith('.m4v$finalParcial'))) {
        await _borrar(e.path);
      }
    }
  } on Object {
    // Si no se puede mirar, se deja como está.
  }
}

// ── En otro hilo ─────────────────────────────────────────────────────────

/// Una copia en marcha (en otro hilo).
class TrabajoCopia {
  TrabajoCopia({
    required this.avance,
    required this.resultado,
    required this.cancelar,
  });

  final Stream<AvanceCopia> avance;
  final Future<ResultadoCopia> resultado;

  /// Para la copia y borra lo copiado (en cuanto acaba el trozo en curso).
  final void Function() cancelar;
}

/// Como [copiarArchivo], pero en otro hilo: la app sigue funcionando
/// mientras tanto.
TrabajoCopia copiarAparte(
  String origen,
  String destino, {
  bool reemplazar = false,
  bool borrarAntes = false,
}) {
  final entrada = ReceivePort();
  final avance = StreamController<AvanceCopia>.broadcast();
  SendPort? ordenes;
  var cancelar = false;
  entrada.listen((mensaje) {
    switch (mensaje) {
      case SendPort puerto:
        ordenes = puerto;
        if (cancelar) puerto.send(true);
      case AvanceCopia a:
        avance.add(a);
    }
  });
  final resultado =
      _copiarEnOtroHilo(
            entrada.sendPort,
            origen,
            destino,
            reemplazar,
            borrarAntes,
          )
          .catchError(
            (Object e) => ResultadoCopia(
              FinCopia.fallo,
              fallo: FalloCopia.otro,
              detalle: explicarError(e),
            ),
          )
          .whenComplete(() {
            entrada.close();
            avance.close();
          });
  return TrabajoCopia(
    avance: avance.stream,
    resultado: resultado,
    cancelar: () {
      cancelar = true;
      ordenes?.send(true);
    },
  );
}

// En una función suelta: lo que se manda al otro hilo no puede llevar nada
// de la pantalla (ver `edicion.dart`).
Future<ResultadoCopia> _copiarEnOtroHilo(
  SendPort salida,
  String origen,
  String destino,
  bool reemplazar,
  bool borrarAntes,
) => Isolate.run(() async {
  final ordenes = ReceivePort();
  var cancelada = false;
  ordenes.listen((_) => cancelada = true);
  salida.send(ordenes.sendPort);
  final reloj = Stopwatch()..start();
  var ultimo = -1000;
  try {
    return await copiarArchivo(
      origen,
      destino,
      reemplazar: reemplazar,
      borrarAntes: borrarAntes,
      cancelada: () => cancelada,
      alAvanzar: (a) {
        // Como mucho 5 veces por segundo (y siempre el principio y el final).
        final ahora = reloj.elapsedMilliseconds;
        if (a.comprobando ||
            a.copiados == 0 ||
            a.copiados == a.total ||
            ahora - ultimo >= 200) {
          ultimo = ahora;
          salida.send(a);
        }
      },
    );
  } finally {
    ordenes.close();
  }
});

// ── Textos ───────────────────────────────────────────────────────────────

/// 1288490188 → «1,2 GB»; 650000000 → «620 MB».
String textoBytes(int bytes) {
  const kb = 1024;
  const mb = kb * 1024;
  const gb = mb * 1024;
  const tb = gb * 1024;
  String numero(double v, {bool decimal = true}) =>
      v.toStringAsFixed(decimal && v < 100 ? 1 : 0).replaceAll('.', ',');
  if (bytes >= tb) return '${numero(bytes / tb)} TB';
  if (bytes >= gb) return '${numero(bytes / gb)} GB';
  if (bytes >= mb) return '${numero(bytes / mb, decimal: false)} MB';
  if (bytes >= kb) return '${numero(bytes / kb, decimal: false)} KB';
  return '$bytes bytes';
}

/// Lo que falta para terminar: «unos segundos», «unos 40 s», «unos 3 min».
String textoRestante(Duration d) {
  final s = d.inSeconds;
  if (s < 10) return 'unos segundos';
  if (s < 60) return 'unos ${(s / 5).round() * 5} s';
  final minutos = (s / 60).round();
  if (minutos < 60) return 'unos $minutos min';
  return '${minutos ~/ 60} h ${minutos % 60} min';
}
