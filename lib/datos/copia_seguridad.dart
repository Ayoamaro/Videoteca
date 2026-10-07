import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive_io.dart';
import 'package:sqlite3/sqlite3.dart';

import 'carpetas_app.dart';

// Copia de seguridad del catálogo: un `.zip` con la base de datos de la app
// (las fichas, el registro de cambios, lo hecho en «Completar mi colección»
// y los ajustes), las carátulas de antes y después de cada cambio (para
// poder deshacerlos) y las miniaturas. Las claves (TMDB, OMDb, GitHub y la
// del tablón) **nunca** van en la copia.
//
// Restaurar cambia todo eso por lo de la copia, pero se queda con las claves
// y la conexión con el tablón de este PC. La base de datos de antes se guarda
// como `videoteca-antes-de-restaurar.sqlite`, por si acaso.
//
// No usa nada de Flutter.

/// Ajustes que nunca salen del PC.
const ajustesSecretos = {
  'claveTmdb',
  'claveOmdb',
  'llaveGithub',
  'llaveTablon',
};

/// Ajustes de este PC que se conservan al restaurar (si los tiene): las
/// claves y la conexión con el tablón, que puede haber avanzado desde la
/// copia.
const ajustesDelEquipo = {
  ...ajustesSecretos,
  'repoTablon',
  'parametrosTablon',
  'versionTablon',
  'fechaTablon',
};

const _info = 'videoteca-copia.json';
const _base = 'videoteca.sqlite';

/// Lo que dice una copia de sí misma.
class InfoCopia {
  const InfoCopia({
    required this.fecha,
    required this.peliculas,
    required this.versionBase,
  });

  final DateTime fecha;
  final int peliculas;

  /// Versión de la base de datos (la de `BaseDatos.schemaVersion`).
  final int versionBase;

  String aJson() => jsonEncode({
    'fecha': fecha.toIso8601String(),
    'peliculas': peliculas,
    'versionBase': versionBase,
  });

  factory InfoCopia.deJson(String texto) {
    final j = jsonDecode(texto) as Map<String, dynamic>;
    return InfoCopia(
      fecha: DateTime.parse(j['fecha'] as String),
      peliculas: j['peliculas'] as int,
      versionBase: j['versionBase'] as int,
    );
  }
}

/// La copia no se puede usar; [mensaje] se puede enseñar tal cual.
class CopiaException implements Exception {
  CopiaException(this.mensaje);
  final String mensaje;
  @override
  String toString() => mensaje;
}

/// Nombre propuesto para una copia: `Videoteca-copia-2026-10-07.zip`.
String nombreCopia(DateTime fecha) =>
    'Videoteca-copia-${fecha.toIso8601String().substring(0, 10)}.zip';

/// Hace la copia en [destino] (un `.zip`). [copiarBase] tiene que dejar en la
/// ruta que recibe una copia exacta de la base de datos abierta (con
/// `VACUUM INTO`, ver `BaseDatos.copiarA`). Devuelve lo que dice la copia.
Future<InfoCopia> crearCopia({
  required CarpetasApp carpetas,
  required String destino,
  required Future<void> Function(String ruta) copiarBase,
}) async {
  final temporal =
      '${carpetas.raiz}${Platform.pathSeparator}copia-temporal.sqlite';
  _borrar(temporal);
  await copiarBase(temporal);
  try {
    final raiz = carpetas.raiz;
    return await Isolate.run(() => _empaquetar(temporal, destino, raiz));
  } finally {
    _borrar(temporal);
  }
}

/// Mete en el `.zip` [destino] la base de datos [base] (sin las claves) y
/// las carpetas de imágenes de [raiz]. Funciona en otro hilo (isolate).
Future<InfoCopia> _empaquetar(String base, String destino, String raiz) async {
  final info = _quitarSecretos(base);
  final zip = ZipFileEncoder()..create(destino);
  try {
    await zip.addFile(File(base), _base);
    // Las imágenes ya están comprimidas: se guardan tal cual (más rápido).
    for (final carpeta in ['miniaturas', 'copias']) {
      final dir = Directory('$raiz${Platform.pathSeparator}$carpeta');
      if (!dir.existsSync()) continue;
      for (final f in dir.listSync().whereType<File>()) {
        final nombre = f.uri.pathSegments.last;
        await zip.addFile(f, '$carpeta/$nombre', ZipFileEncoder.store);
      }
    }
    zip.addArchiveFile(ArchiveFile.string(_info, info.aJson()));
  } finally {
    await zip.close();
  }
  return info;
}

/// Quita las claves de la base de datos copiada y cuenta sus películas.
InfoCopia _quitarSecretos(String ruta) {
  final bd = sqlite3.open(ruta);
  try {
    bd.execute(
      'DELETE FROM ajustes WHERE clave IN '
      '(${ajustesSecretos.map((c) => "'$c'").join(', ')})',
    );
    final peliculas =
        bd
                .select(
                  'SELECT COUNT(*) AS n FROM peliculas WHERE desaparecida IS NULL',
                )
                .first['n']
            as int;
    return InfoCopia(
      fecha: DateTime.now(),
      peliculas: peliculas,
      versionBase: bd.userVersion,
    );
  } finally {
    bd.close();
  }
}

/// Lee qué hay en la copia [zip]. Lanza [CopiaException] si no es una copia
/// de Videoteca o es de una versión más nueva de la app ([versionBase] =
/// la versión de la base de datos de esta app).
Future<InfoCopia> leerCopia(String zip, {required int versionBase}) =>
    Isolate.run(() {
      final InfoCopia info;
      final entrada = InputFileStream(zip);
      try {
        final archivo = ZipDecoder().decodeStream(entrada);
        final datos = archivo.findFile(_info);
        if (datos == null || archivo.findFile(_base) == null) {
          throw CopiaException('Este archivo no es una copia de Videoteca.');
        }
        info = InfoCopia.deJson(utf8.decode(datos.readBytes()!));
      } on CopiaException {
        rethrow;
      } catch (_) {
        throw CopiaException('Este archivo no es una copia de Videoteca.');
      } finally {
        entrada.closeSync();
      }
      if (info.versionBase > versionBase) {
        throw CopiaException(
          'La copia es de una versión más nueva de Videoteca: actualiza la '
          'app antes de restaurarla.',
        );
      }
      return info;
    });

/// Cambia los datos de la app por los de la copia [zip]. La base de datos
/// tiene que estar **cerrada**. Se quedan los [conservar] (los
/// [ajustesDelEquipo] que tiene este PC).
Future<void> restaurarCopia(
  String zip,
  CarpetasApp carpetas, {
  required Map<String, String> conservar,
}) async {
  final raiz = carpetas.raiz;
  final base = carpetas.baseDatos;
  await Isolate.run(() => _restaurar(zip, raiz, base, conservar));
}

Future<void> _restaurar(
  String zip,
  String raiz,
  String baseDatos,
  Map<String, String> conservar,
) async {
  final sep = Platform.pathSeparator;
  final temporal = Directory('$raiz${sep}restaurando');
  if (temporal.existsSync()) temporal.deleteSync(recursive: true);
  await extractFileToDisk(zip, temporal.path);
  try {
    // Primero se comprueba que la base de datos de la copia se abre y se le
    // ponen las claves de este PC; luego se cambian los archivos.
    final nueva = '${temporal.path}$sep$_base';
    final bd = sqlite3.open(nueva);
    try {
      bd.select('SELECT COUNT(*) FROM peliculas');
      final poner = bd.prepare(
        'INSERT OR REPLACE INTO ajustes (clave, valor) VALUES (?, ?)',
      );
      for (final MapEntry(:key, :value) in conservar.entries) {
        poner.execute([key, value]);
      }
      poner.close();
    } on SqliteException {
      throw CopiaException('La base de datos de la copia está estropeada.');
    } finally {
      bd.close();
    }

    final actual = File(baseDatos);
    if (actual.existsSync()) {
      actual.copySync('$raiz${sep}videoteca-antes-de-restaurar.sqlite');
    }
    for (final extra in ['-wal', '-shm', '-journal']) {
      _borrar('$baseDatos$extra');
    }
    File(nueva).copySync(baseDatos);
    for (final carpeta in ['miniaturas', 'copias']) {
      final destino = Directory('$raiz$sep$carpeta');
      if (destino.existsSync()) destino.deleteSync(recursive: true);
      final origen = Directory('${temporal.path}$sep$carpeta');
      if (origen.existsSync()) {
        origen.renameSync(destino.path);
      } else {
        destino.createSync();
      }
    }
  } finally {
    if (temporal.existsSync()) temporal.deleteSync(recursive: true);
  }
}

void _borrar(String ruta) {
  final f = File(ruta);
  if (f.existsSync()) f.deleteSync();
}
