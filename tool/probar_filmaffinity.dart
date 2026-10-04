// Prueba la lectura de FilmAffinity con películas de tu catálogo: abre la
// ventana de Edge de la app, va a la ficha de cada película (el enlace se
// saca de TMDB → IMDb → Wikidata), la lee y la compara con tus datos.
// Solo lee: no escribe nada en los archivos ni en la base de datos.
//
// Uso:  dart run tool/probar_filmaffinity.dart [n | nombre] [semilla=N]
//
//   n        cuántas películas al azar (10 si no se dice)
//   nombre   las películas cuyo título contiene ese texto
//
// Va despacio a propósito (una ficha cada pocos segundos), como quien
// navega a mano. Si FilmAffinity pide algo en la ventana (cookies,
// comprobación), hazlo tú allí: la prueba espera.

// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:math';

import 'package:videoteca/datos/base_datos.dart';
import 'package:videoteca/datos/carpetas_app.dart';
import 'package:videoteca/disco/escritor.dart' show Campo;
import 'package:videoteca/fuentes/datos_automaticos.dart';
import 'package:videoteca/fuentes/filmaffinity.dart';
import 'package:videoteca/fuentes/navegador.dart';

Future<void> main(List<String> argumentos) async {
  final carpetas = CarpetasApp(carpetaDatosApp());
  final bd = BaseDatos.abrir(carpetas.baseDatos);
  final ajustes = await bd.todosLosAjustes();
  final claveTmdb =
      Platform.environment['TMDB_CLAVE'] ?? ajustes['claveTmdb'] ?? '';
  final semilla =
      int.tryParse(
        argumentos
            .firstWhere((a) => a.startsWith('semilla='), orElse: () => '')
            .replaceFirst('semilla=', ''),
      ) ??
      11;
  final libres = argumentos.where((a) => !a.startsWith('semilla=')).toList();
  final todas = await bd.todasLasPeliculas();
  await bd.close();
  final n = libres.isEmpty ? 10 : int.tryParse(libres.first);
  final List<FilaPelicula> elegidas;
  if (n != null) {
    elegidas = ([...todas]..shuffle(Random(semilla))).take(n).toList();
  } else {
    final texto = libres.join(' ').toLowerCase();
    elegidas = todas
        .where((p) => p.titulo.toLowerCase().contains(texto))
        .toList();
  }
  final fuentes = FuentesDatos(claveTmdb: claveTmdb, claveOmdb: '');

  Navegador? navegador;
  final iguales = <Campo, int>{};
  final distintos = <Campo, int>{};
  var leidas = 0, seguras = 0;

  for (final (i, p) in elegidas.indexed) {
    final datos = (
      titulo: p.titulo,
      tituloOriginal: p.tituloOriginal,
      anio: p.anio,
      direccion: p.direccion,
    );
    print(
      '\n[${i + 1}/${elegidas.length}] ${p.titulo} (${p.anio}) · ${p.direccion}',
    );
    var enlace = p.enlaceFilmaffinity;
    if (enlace.isEmpty) {
      if (claveTmdb.isEmpty) {
        print('   ✗ Sin enlace y sin clave de TMDB para buscarlo.');
        continue;
      }
      try {
        enlace = await fuentes.buscarEnlaceFilmaffinity(datos) ?? '';
      } on Exception catch (e) {
        print('   ✗ $e');
        continue;
      }
      if (enlace.isEmpty) {
        print('   ✗ TMDB/Wikidata no dan el enlace de FilmAffinity.');
        continue;
      }
    }
    if (navegador == null) {
      navegador = await Navegador.abrir(enlace, perfil: carpetas.navegador);
    } else {
      await navegador.ir(enlace);
    }

    final id = idFichaFilmaffinity(enlace)!;
    FichaFilmaffinity? ficha;
    for (var intento = 0; intento < 120 && ficha == null; intento++) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      final pagina = await navegador.paginaActual();
      if (pagina == null || idFichaFilmaffinity(pagina.url) != id) continue;
      final codigo = await navegador.html(pagina.id);
      if (codigo != null) ficha = leerFichaFilmaffinity(codigo, pagina.url);
    }
    if (ficha == null) {
      print('   ✗ No se ha podido leer $enlace');
      continue;
    }
    leidas++;
    final c = ficha.comparar(datos);
    if (c.titulo && c.anio && c.director) seguras++;
    print(
      '   ${c.titulo && c.anio && c.director ? '✓' : '?'} '
      '${ficha.titulo} (${ficha.anio}) $enlace · ${ficha.explicacion(datos)}',
    );
    final tuyos = {
      Campo.tituloOriginal: p.tituloOriginal,
      Campo.generos: p.generos,
      Campo.sinopsis: p.sinopsis,
      Campo.direccion: p.direccion,
      Campo.reparto: p.reparto,
      Campo.guion: p.guion,
      Campo.musica: p.musica,
      Campo.fotografia: p.fotografia,
      Campo.productora: p.productora,
      Campo.pais: p.pais,
      Campo.temas: p.temas,
      Campo.premios: p.premios,
    };
    for (final MapEntry(key: campo, value: dato) in ficha.datos().entries) {
      final tuyo = tuyos[campo] ?? '';
      final igual =
          tuyo == dato.valor ||
          (campo == Campo.sinopsis &&
              tuyo.length >= 200 &&
              dato.valor.startsWith(tuyo.trimRight()));
      if (tuyo.isNotEmpty) {
        (igual ? iguales : distintos)[campo] =
            ((igual ? iguales : distintos)[campo] ?? 0) + 1;
      }
      final marca = tuyo.isEmpty ? '+' : (igual ? '=' : '≠');
      final valor = dato.valor.length > 150
          ? '${dato.valor.substring(0, 150)}… (${dato.valor.length})'
          : dato.valor;
      print('   $marca ${campo.nombre.padRight(22)} $valor');
      if (marca == '≠') {
        final t = tuyo.length > 150
            ? '${tuyo.substring(0, 150)}… (${tuyo.length})'
            : tuyo;
        print('     ${''.padRight(22)} tuyo: $t');
      }
    }
    // Como quien navega a mano.
    await Future<void>.delayed(const Duration(seconds: 8));
  }

  print(
    '\n── Resumen: $leidas fichas leídas, $seguras con título, año y director ──',
  );
  print('Comparado con tus datos (= iguales / ≠ distintos):');
  for (final c in Campo.values) {
    if (iguales[c] == null && distintos[c] == null) continue;
    print(
      '  ${c.nombre.padRight(22)} = ${iguales[c] ?? 0}  ≠ ${distintos[c] ?? 0}',
    );
  }
  exit(0);
}
