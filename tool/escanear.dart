// Escanea una colección desde la terminal, igual que el asistente de la app.
//
// Uso:  dart run tool/escanear.dart <carpeta raíz> <carpeta de datos> [completo]
//
// Ejemplo: dart run tool/escanear.dart D:\ C:\Temp\prueba-videoteca
//
// La carpeta de datos es donde se crean la base de datos y las miniaturas
// (para probar sin tocar las de la app). Solo lee los .mp4.

// ignore_for_file: avoid_print

import 'dart:io';

import 'package:videoteca/datos/base_datos.dart';
import 'package:videoteca/datos/carpetas_app.dart';
import 'package:videoteca/disco/escaner.dart';

Future<void> main(List<String> argumentos) async {
  if (argumentos.length < 2) {
    print(
      'Uso: dart run tool/escanear.dart <raíz> <carpeta de datos> [completo]',
    );
    exit(1);
  }
  final raiz = argumentos[0];
  final carpetas = CarpetasApp.preparar(argumentos[1]);
  final bd = BaseDatos.abrir(carpetas.baseDatos);

  final escaner = Escaner(bd: bd, raiz: raiz, carpetas: carpetas);
  var ultimo = -1;
  late ProgresoEscaneo fin;
  await for (final p in escaner.ejecutar(
    completo: argumentos.contains('completo'),
  )) {
    fin = p;
    if (p.fase == FaseEscaneo.leyendo && p.leidas ~/ 250 != ultimo) {
      ultimo = p.leidas ~/ 250;
      final resta = p.restante == null ? '' : ' · faltan ${_t(p.restante!)}';
      print(
        '${p.leidas}/${p.porLeer} (${_t(p.transcurrido)}$resta) ${p.actual}',
      );
    }
  }
  print('');
  print('Resultado: ${fin.fase.name} ${fin.mensaje}');
  print(
    'En el disco: ${fin.encontradas} · leídas: ${fin.leidas} · '
    'errores: ${fin.errores} · quitadas: ${fin.borradas} · '
    'tiempo: ${_t(fin.transcurrido)}',
  );

  final filas = await bd.todasLasPeliculas();
  final generos = <String, int>{};
  for (final f in filas) {
    generos[f.generoCarpeta] = (generos[f.generoCarpeta] ?? 0) + 1;
  }
  print(
    'En el catálogo: ${filas.length} películas · '
    '${filas.where((f) => f.tieneMiniatura).length} con miniatura · '
    '${filas.where((f) => !f.tieneCaratula).length} sin carátula',
  );
  for (final e
      in generos.entries.toList()..sort((a, b) => b.value.compareTo(a.value))) {
    print('  ${e.key.padRight(22)} ${e.value}');
  }
  for (final f in filas.where((f) => f.errorLectura != null).take(10)) {
    print('ERROR ${f.ruta}: ${f.errorLectura}');
  }
  await bd.close();
}

String _t(Duration d) =>
    '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
