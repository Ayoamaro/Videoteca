import 'dart:async';
import 'dart:convert';

import '../datos/buscador.dart' show limpiarParaBuscar;
import 'conexion.dart';
import 'tmdb.dart';

// Sagas completas según TMDB: qué películas tiene cada saga de la colección
// (solo las ya estrenadas) para saber cuáles faltan. Se guarda en
// `%LOCALAPPDATA%\Videoteca\sagas.json` y se vuelve a comprobar cuando se
// pide desde Estadísticas.
//
// No usa nada de Flutter.

/// Una película de una saga según TMDB.
typedef ParteSaga = ({String titulo, int anio});

/// Una saga de TMDB con sus películas ya estrenadas, por orden de estreno.
class InfoSaga {
  const InfoSaga({
    required this.id,
    required this.nombre,
    required this.partes,
  });

  final int id;
  final String nombre;
  final List<ParteSaga> partes;

  Map<String, Object> aJson() => {
    'id': id,
    'nombre': nombre,
    'partes': [
      for (final p in partes) {'t': p.titulo, 'a': p.anio},
    ],
  };

  factory InfoSaga.deJson(Map<String, dynamic> j) => InfoSaga(
    id: j['id'] as int,
    nombre: j['nombre'] as String,
    partes: [
      for (final p in j['partes'] as List)
        (titulo: p['t'] as String, anio: p['a'] as int),
    ],
  );
}

/// Lo comprobado en TMDB: cada saga (por su nombre limpio, ver
/// [claveSaga]) con su información, o `null` si TMDB no la conoce.
class SagasTmdb {
  const SagasTmdb({required this.fecha, required this.sagas});

  final DateTime fecha;
  final Map<String, InfoSaga?> sagas;

  static final vacio = SagasTmdb(fecha: DateTime(2000), sagas: const {});

  String aJson() => jsonEncode({
    'fecha': fecha.toIso8601String(),
    'sagas': {for (final e in sagas.entries) e.key: e.value?.aJson()},
  });

  factory SagasTmdb.deJson(String texto) {
    final j = jsonDecode(texto) as Map<String, dynamic>;
    return SagasTmdb(
      fecha: DateTime.parse(j['fecha'] as String),
      sagas: {
        for (final e in (j['sagas'] as Map<String, dynamic>).entries)
          e.key: e.value == null
              ? null
              : InfoSaga.deJson(e.value as Map<String, dynamic>),
      },
    );
  }
}

/// Nombre de saga para comparar: «Harry Potter - Colección» y «harry potter»
/// dan lo mismo.
String claveSaga(String nombre) => limpiarParaBuscar(limpiarNombreSaga(nombre));

/// Busca en TMDB cada saga de [sagas] (nombre → años de las películas que
/// tienes de ella). Hace [aLaVez] consultas a la vez y avisa del avance con
/// [alAvanzar] (hechas, total). Si TMDB falla del todo (sin internet, clave
/// mala) lanza la `FuenteException`.
Future<SagasTmdb> comprobarSagas(
  Tmdb tmdb,
  Map<String, Set<int>> sagas, {
  int aLaVez = 4,
  void Function(int hechas, int total)? alAvanzar,
  DateTime? hoy,
}) async {
  final pendientes = sagas.entries.toList();
  final resultado = <String, InfoSaga?>{};
  var hechas = 0;
  Future<void> trabajador() async {
    while (pendientes.isNotEmpty) {
      final MapEntry(key: nombre, value: anios) = pendientes.removeLast();
      try {
        resultado[claveSaga(nombre)] = await buscarSaga(
          tmdb,
          nombre,
          anios,
          hoy: hoy,
        );
      } on FuenteException catch (e) {
        // Sin internet o sin clave no sigue; un fallo de una sola saga, sí.
        if (e.claveMala || e.sinInternet) rethrow;
        resultado[claveSaga(nombre)] = null;
      }
      alAvanzar?.call(++hechas, sagas.length);
    }
  }

  await Future.wait([for (var i = 0; i < aLaVez; i++) trabajador()]);
  return SagasTmdb(fecha: hoy ?? DateTime.now(), sagas: resultado);
}

/// La saga [nombre] en TMDB, o `null` si no aparece con ese mismo nombre o
/// ninguna de sus películas es del año de alguna de las tuyas ([anios]): así
/// no se confunde con otra saga que se llame igual.
Future<InfoSaga?> buscarSaga(
  Tmdb tmdb,
  String nombre,
  Set<int> anios, {
  DateTime? hoy,
}) async {
  final clave = claveSaga(nombre);
  for (final (id, nombreTmdb) in await tmdb.buscarSagas(nombre)) {
    if (claveSaga(nombreTmdb) != clave) continue;
    final partes = await tmdb.partesSaga(id, hoy: hoy);
    final cuadra = partes.any((p) => anios.any((a) => (a - p.anio).abs() <= 1));
    if (cuadra) {
      return InfoSaga(
        id: id,
        nombre: limpiarNombreSaga(nombreTmdb),
        partes: partes,
      );
    }
  }
  return null;
}
