// Prueba las fuentes de datos (TMDB, OMDb, Wikidata) con películas de tu
// catálogo. Solo lee: no escribe nada en los archivos ni en la base de datos.
//
// Uso:  dart run tool/probar_fuentes.dart [n | nombre] [sin-omdb] [semilla=N]
//
//   n          cuántas películas al azar (20 si no se dice)
//   nombre     las películas cuyo título contiene ese texto
//   sin-omdb   no consulta OMDb (para no gastar las 1.000 consultas del día)
//
// Las claves se leen de los ajustes de la app (Ajustes → Servicios de datos)
// o de las variables de entorno TMDB_CLAVE y OMDB_CLAVE.
//
// Al final enseña cómo encajan las edades de TMDB (España / EE. UU.) con tus
// frases y las estrellas calculadas con las tuyas.

// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:math';

import 'package:videoteca/datos/base_datos.dart';
import 'package:videoteca/datos/carpetas_app.dart';
import 'package:videoteca/disco/escritor.dart' show Campo;
import 'package:videoteca/fuentes/conexion.dart';
import 'package:videoteca/fuentes/conversiones.dart';
import 'package:videoteca/fuentes/datos_automaticos.dart';
import 'package:videoteca/fuentes/identificacion.dart';

Future<void> main(List<String> argumentos) async {
  final carpetas = CarpetasApp(carpetaDatosApp());
  final bd = BaseDatos.abrir(carpetas.baseDatos);
  final ajustes = await bd.todosLosAjustes();
  final claveTmdb =
      Platform.environment['TMDB_CLAVE'] ?? ajustes['claveTmdb'] ?? '';
  final sinOmdb = argumentos.contains('sin-omdb');
  final claveOmdb = sinOmdb
      ? ''
      : Platform.environment['OMDB_CLAVE'] ?? ajustes['claveOmdb'] ?? '';
  if (claveTmdb.isEmpty) {
    print('Falta la clave de TMDB (Ajustes → Servicios de datos).');
    exit(1);
  }
  final semilla =
      int.tryParse(
        argumentos
            .firstWhere((a) => a.startsWith('semilla='), orElse: () => '')
            .replaceFirst('semilla=', ''),
      ) ??
      10;
  final libres = argumentos
      .where((a) => a != 'sin-omdb' && !a.startsWith('semilla='))
      .toList();

  final todas = await bd.todasLasPeliculas();
  await bd.close();
  final n = libres.isEmpty ? 20 : int.tryParse(libres.first);
  final List<FilaPelicula> elegidas;
  if (n != null) {
    elegidas = ([...todas]..shuffle(Random(semilla))).take(n).toList();
  } else {
    final texto = libres.join(' ').toLowerCase();
    elegidas = todas
        .where((p) => p.titulo.toLowerCase().contains(texto))
        .toList();
  }

  final fuentes = FuentesDatos(claveTmdb: claveTmdb, claveOmdb: claveOmdb);
  final cuenta = {for (final s in Seguridad.values) s: 0};
  final edades = <String, Map<String, int>>{}; // «ES / US» → tu frase → n
  final estrellas = <String, int>{}; // «tuyas → calculadas» → n
  var notas = 0;
  final reloj = Stopwatch()..start();

  for (final (i, p) in elegidas.indexed) {
    final cabecera =
        '[${i + 1}/${elegidas.length}] ${p.titulo} (${p.anio}) · ${p.direccion}';
    final ResultadoDatos r;
    try {
      r = await fuentes.buscar((
        titulo: p.titulo,
        tituloOriginal: p.tituloOriginal,
        anio: p.anio,
        direccion: p.direccion,
      ));
    } on FuenteException catch (e) {
      print('$cabecera\n   ✗ $e');
      if (e.claveMala || e.sinInternet) break;
      continue;
    }
    final id = r.identificacion;
    cuenta[id.seguridad] = cuenta[id.seguridad]! + 1;
    final marca = switch (id.seguridad) {
      Seguridad.segura => '✓',
      Seguridad.dudosa => '?',
      Seguridad.noEncontrada => '✗',
    };
    print('$cabecera\n   $marca ${id.motivo}');
    if (id.seguridad == Seguridad.dudosa) {
      for (final c in id.candidatos.take(3)) {
        print(
          '      · ${c.ficha} ${c.ficha.directores.join(', ')} — ${c.explicacion}',
        );
      }
    }
    final ficha = id.ficha;
    if (ficha == null) continue;
    print(
      '     TMDB: ${ficha.titulo} / ${ficha.tituloOriginal} (${ficha.anio}) ${ficha.enlace}',
    );
    for (final MapEntry(key: c, value: d) in r.datos.entries) {
      final detalle = d.detalle.isEmpty ? '' : '  [${d.detalle}]';
      print('     ${c.nombre.padRight(22)} ${d.valor}$detalle');
    }
    for (final a in r.avisos) {
      print('     ! $a');
    }

    final clave =
        '${ficha.edadEspana.isEmpty ? '—' : ficha.edadEspana} / '
        '${ficha.edadEeuu.isEmpty ? '—' : ficha.edadEeuu}';
    final tuya = _edadCorta(p.clasificacion);
    edades.putIfAbsent(clave, () => {});
    edades[clave]![tuya] = (edades[clave]![tuya] ?? 0) + 1;

    final calculadas = r.datos[Campo.estrellas]?.valor;
    if (calculadas != null) {
      notas++;
      final k = '${p.estrellas} → $calculadas';
      estrellas[k] = (estrellas[k] ?? 0) + 1;
    }
  }

  print(
    '\n── Resumen (${elegidas.length} películas, ${reloj.elapsed.inSeconds} s) ──',
  );
  print(
    'Seguras: ${cuenta[Seguridad.segura]} · dudosas: ${cuenta[Seguridad.dudosa]} · '
    'no encontradas: ${cuenta[Seguridad.noEncontrada]}',
  );
  print('\nEdades: TMDB España / EE. UU. → tus frases');
  for (final e
      in edades.entries.toList()..sort((a, b) => a.key.compareTo(b.key))) {
    final detalle =
        (e.value.entries.toList()..sort((a, b) => b.value - a.value))
            .map((x) => '${x.key}: ${x.value}')
            .join(' · ');
    print('  ${e.key.padRight(14)} $detalle');
  }
  if (notas > 0) {
    print('\nEstrellas tuyas → calculadas (tramos de 20 %), $notas con nota:');
    for (final e
        in estrellas.entries.toList()..sort((a, b) => a.key.compareTo(b.key))) {
      print('  ${e.key}: ${e.value}');
    }
    final iguales = estrellas.entries
        .where((e) => e.key[0] == e.key[e.key.length - 1])
        .fold(0, (s, e) => s + e.value);
    print('  Iguales: $iguales de $notas');
  }
  print(
    '\nTramos: ${tramosEstrellas.map((t) => '${t.estrellas}★ ${t.desde}–${t.hasta} %').join(' · ')}',
  );
  exit(0);
}

String _edadCorta(String frase) {
  if (frase.isEmpty) return '(vacía)';
  if (frase.toLowerCase().contains('todos')) return 'TP';
  return RegExp(r'\d+').firstMatch(frase)?.group(0) ?? frase;
}
