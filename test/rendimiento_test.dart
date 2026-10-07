// Mide cuánto tardan los cálculos del catálogo con una colección real.
//
// Solo se ejecuta si se le da una copia de la base de datos:
//   flutter test test/rendimiento_test.dart --dart-define=BASE=<ruta.sqlite>
// (nunca la base que está usando la app: una copia).
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:videoteca/datos/base_datos.dart';
import 'package:videoteca/datos/buscador.dart';
import 'package:videoteca/datos/carpetas_app.dart';
import 'package:videoteca/datos/catalogo.dart';
import 'package:videoteca/datos/estadisticas.dart';
import 'package:videoteca/datos/filtros.dart';
import 'package:videoteca/datos/pendientes.dart';

const _base = String.fromEnvironment('BASE');

void main() {
  test(
    'Rendimiento con la colección completa',
    () async {
      final tiempos = <String, double>{};
      T medir<T>(String que, T Function() hacer, {int veces = 5}) {
        late T r;
        final reloj = Stopwatch()..start();
        for (var i = 0; i < veces; i++) {
          r = hacer();
        }
        tiempos[que] = reloj.elapsedMicroseconds / veces / 1000;
        return r;
      }

      final base = BaseDatos(NativeDatabase(File(_base)));
      final reloj = Stopwatch()..start();
      final filas = await base.todasLasPeliculas();
      tiempos['leer la base'] = reloj.elapsedMicroseconds / 1000;
      final carpetas = CarpetasApp(Directory.systemTemp.path);
      final todas = medir(
        'convertir filas',
        () => [for (final f in filas) peliculaDesdeFila(f, carpetas)],
      );

      final buscador = medir(
        'preparar el buscador',
        () => Buscador([
          for (final p in todas)
            (
              id: p.id,
              titulo: p.titulo,
              tituloOriginal: p.tituloOriginal,
              anio: p.anio,
              direccion: p.direccion,
              reparto: p.reparto,
            ),
        ]),
      );
      for (final q in ['s', 'spi', 'spiderman', 'tom hanks', 'el señor de']) {
        medir('buscar «$q»', () => buscador.buscar(q), veces: 20);
      }
      medir('sugerencias «tom»', () => buscador.personas('tom'), veces: 20);

      // La primera vez se preparan los textos (se guardan con Expando).
      medir(
        'facetas (1.ª vez)',
        () => Facetas(todas, Filtros.ninguno),
        veces: 1,
      );
      medir('facetas', () => Facetas(todas, Filtros.ninguno), veces: 20);
      final drama = Filtros(generos: {'Drama'});
      medir('aplicar filtros', () => drama.aplicar(todas), veces: 20);
      medir('facetas con filtro', () => Facetas(todas, drama), veces: 20);
      medir('ordenar por título', () {
        final t = {for (final p in todas) p.id: limpiarParaBuscar(p.titulo)};
        return [...todas]..sort((a, b) => t[a.id]!.compareTo(t[b.id]!));
      }, veces: 20);
      medir(
        'directores',
        () => contarNombres(todas, (p) => separarNombres(p.direccion)),
      );
      medir(
        'actores',
        () => contarNombres(todas, (p) => separarNombres(p.reparto)),
      );
      medir('pendientes', () => buscarPendientes(todas));
      medir('estadísticas', () => Estadisticas.de(todas));
      await base.close();

      // ignore: avoid_print
      print('${todas.length} películas');
      for (final MapEntry(:key, :value) in tiempos.entries) {
        // ignore: avoid_print
        print('${value.toStringAsFixed(1).padLeft(8)} ms  $key');
      }
    },
    skip: _base.isEmpty ? 'Falta --dart-define=BASE=<copia.sqlite>' : false,
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
