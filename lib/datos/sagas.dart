import 'dart:io';
import 'dart:isolate';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../fuentes/conexion.dart';
import '../fuentes/sagas.dart';
import '../fuentes/tmdb.dart';
import '../modelos/pelicula.dart';
import 'catalogo.dart';
import 'estadisticas.dart';
import 'fuentes.dart';

// Estadísticas de la colección y la comprobación de las sagas en TMDB (desde
// la pantalla de Estadísticas; solo en el PC del administrador, que tiene la
// clave de TMDB).

/// Las estadísticas, calculadas de nuevo cada vez que cambia el catálogo o
/// lo comprobado en TMDB. `null` mientras se carga el catálogo.
final estadisticasProvider = FutureProvider<Estadisticas?>((ref) async {
  final lista = ref.watch(catalogoProvider).value;
  if (lista == null) return null;
  final tmdb = ref.watch(sagasTmdbProvider.select((e) => e.datos));
  // Con las 5.541 tarda unas décimas: se calcula en otro hilo para no
  // frenar la pantalla. Con pocas (las pruebas) no merece la pena.
  if (lista.length < 500) return Estadisticas.de(lista, tmdb: tmdb);
  return _calcular(lista, tmdb);
});

Future<Estadisticas> _calcular(List<Pelicula> lista, SagasTmdb? tmdb) =>
    Isolate.run(() => Estadisticas.de(lista, tmdb: tmdb));

class EstadoSagas {
  const EstadoSagas({
    this.datos,
    this.comprobando = false,
    this.hechas = 0,
    this.total = 0,
    this.error,
  });

  /// Lo último comprobado (se guarda en `sagas.json`).
  final SagasTmdb? datos;
  final bool comprobando;
  final int hechas;
  final int total;
  final String? error;
}

final sagasTmdbProvider = NotifierProvider<ComprobacionSagas, EstadoSagas>(
  ComprobacionSagas.new,
);

class ComprobacionSagas extends Notifier<EstadoSagas> {
  File get _archivo => File(ref.read(carpetasAppProvider).sagas);

  @override
  EstadoSagas build() {
    try {
      if (_archivo.existsSync()) {
        return EstadoSagas(
          datos: SagasTmdb.deJson(_archivo.readAsStringSync()),
        );
      }
    } catch (_) {
      // Archivo estropeado: como si no se hubiera comprobado nunca.
    }
    return const EstadoSagas();
  }

  /// Busca en TMDB todas las sagas de la colección.
  Future<void> comprobar() async {
    if (state.comprobando) return;
    final clave = ref.read(clavesProvider)[Servicio.tmdb] ?? '';
    final sagas = Estadisticas.sagasDe(
      ref.read(catalogoProvider).value ?? const [],
    );
    state = EstadoSagas(
      datos: state.datos,
      comprobando: true,
      total: sagas.length,
    );
    try {
      final datos = await comprobarSagas(
        Tmdb(clave),
        sagas,
        alAvanzar: (hechas, total) => state = EstadoSagas(
          datos: state.datos,
          comprobando: true,
          hechas: hechas,
          total: total,
        ),
      );
      await _archivo.writeAsString(datos.aJson());
      state = EstadoSagas(datos: datos);
    } on FuenteException catch (e) {
      state = EstadoSagas(datos: state.datos, error: e.mensaje);
    }
  }
}
