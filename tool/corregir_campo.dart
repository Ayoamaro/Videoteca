// Cambia un valor por otro en un campo de todas las películas que lo tengan
// exactamente (p. ej. una frase de edad mal escrita). Cada archivo se
// escribe y se comprueba como en «Editar ficha», y queda en el Registro de
// cambios de la app con origen «Corregir datos» (se puede deshacer desde
// allí).
//
//     dart run tool/corregir_campo.dart clasificacion "…de 16 año" "…de 16 años"
//     dart run tool/corregir_campo.dart clasificacion "…" "…" hacer
//
// Sin «hacer» solo enseña qué películas cambiaría. Los campos son los
// nombres de `Campo` (clasificacion, pais, direccion, productora…).

// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

import 'package:videoteca/datos/base_datos.dart';
import 'package:videoteca/datos/carpetas_app.dart';
import 'package:videoteca/disco/escritor.dart';
import 'package:videoteca/disco/lector_archivo.dart';

Future<void> main(List<String> args) async {
  final campo = args.isEmpty ? null : Campo.porNombre(args[0]);
  if (campo == null || args.length < 3) {
    print('Uso: dart run tool/corregir_campo.dart <campo> <de> <a> [hacer]');
    exit(64);
  }
  final de = args[1];
  final a = args[2];
  final hacer = args.contains('hacer');
  final problema = validarCampo(campo, a);
  if (problema != null) {
    print('«$a» no vale: $problema');
    exit(1);
  }

  final bd = BaseDatos.abrir(CarpetasApp(carpetaDatosApp()).baseDatos);
  final peliculas = await bd.todasLasPeliculas();
  var hechas = 0;
  var fallos = 0;
  for (final p in peliculas) {
    // Primero se busca en el catálogo y después se confirma en el archivo.
    if (!jsonEncode(p.toJson()).contains(jsonEncode(de))) continue;
    final DatosArchivo datos;
    try {
      datos = leerArchivo(p.ruta);
    } catch (e) {
      print('✗ ${p.titulo}: no se puede leer ($e)');
      fallos++;
      continue;
    }
    if (valoresFicha(datos)[campo] != de) continue;
    if (!hacer) {
      print('· ${p.titulo} (${p.anio})');
      hechas++;
      continue;
    }
    try {
      final r = escribirFicha(p.ruta, {campo: a});
      if (r.sinCambios) continue;
      await bd.anotarCambio(
        CambiosCompanion.insert(
          pelicula: p.id,
          ruta: p.ruta,
          titulo: p.titulo,
          fecha: DateTime.now(),
          origen: 'Corregir datos',
          antes: jsonEncode({campo.name: de}),
          despues: jsonEncode({campo.name: a}),
        ),
      );
      print('✓ ${p.titulo} (${p.anio})');
      hechas++;
    } on EscrituraException catch (e) {
      print('✗ ${p.titulo}: ${e.mensaje}');
      fallos++;
    }
  }
  await bd.close();
  print(
    hacer
        ? '\n$hechas corregidas${fallos == 0 ? '' : ', $fallos con problemas'}.'
        : '\n$hechas películas tienen «$de» en ${campo.nombre}. '
              'Añade «hacer» para corregirlas.',
  );
}
