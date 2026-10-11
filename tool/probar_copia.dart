// Prueba «Copiar película» desde la terminal: copia una película como lo
// hace la app (en otro hilo, con el nombre provisional «.parcial» y
// comprobando al final que está entera) y va diciendo cómo va. La película
// solo se lee.
//
//   dart run tool/probar_copia.dart
//   dart run tool/probar_copia.dart <película> <carpeta> [cancelar | reemplazar]
//
// Sin nada, enseña las unidades de este PC como las ve la ventana «¿Dónde
// quieres guardarla?». Con «cancelar», la copia se cancela a la mitad; con
// «reemplazar», si ya está en la carpeta se sustituye (si no, se para).
// Las rutas de red (\\PC\…) hay que pasarlas desde PowerShell: Git Bash
// estropea las barras del principio.

// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:io';

import 'package:videoteca/disco/copiador.dart';

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    final reloj = Stopwatch()..start();
    final unidades = unidadesDeEstePc();
    for (final u in unidades) {
      print(
        '${u.nombre} · ${u.tipo} · ${u.sistema} · '
        '${textoBytes(u.libre)} libres de ${textoBytes(u.total)}'
        '${u.soloLectura ? ' · solo lectura' : ''}',
      );
    }
    print('(${unidades.length} unidades en ${reloj.elapsedMilliseconds} ms)');
    return;
  }
  if (args.length < 2) {
    stderr.writeln(
      'Uso: dart run tool/probar_copia.dart <película> <carpeta> '
      '[cancelar | reemplazar]',
    );
    exit(64);
  }
  final origen = args[0];
  final carpeta = args[1];
  final cancelar = args.contains('cancelar');
  final reemplazar = args.contains('reemplazar');
  final nombre = origen.substring(origen.lastIndexOf(r'\') + 1);
  final destino = '${carpeta.endsWith(r'\') ? carpeta : '$carpeta\\'}$nombre';

  final volumen = volumenDe(carpeta) ?? volumenDe(File(carpeta).parent.path);
  final tamano = File(origen).lengthSync();
  print('$nombre · ${textoBytes(tamano)} → $destino');
  if (volumen != null) {
    print(
      'Destino: ${volumen.sistema}, ${textoBytes(volumen.libre)} libres · '
      '${impedimentoCopia(volumen, tamano)?.name ?? 'cabe'}',
    );
  }

  final reloj = Stopwatch()..start();
  final trabajo = copiarAparte(origen, destino, reemplazar: reemplazar);
  var ultimo = 0;
  final avance = trabajo.avance.listen((a) {
    if (a.comprobando) {
      print('Comprobando que la copia está completa…');
      return;
    }
    final segundos = reloj.elapsedMilliseconds / 1000;
    final porcentaje = a.total == 0 ? 0 : a.copiados * 100 ~/ a.total;
    if (porcentaje >= ultimo + 10 || a.copiados == a.total) {
      ultimo = porcentaje - porcentaje % 10;
      final velocidad = segundos == 0 ? 0 : a.copiados / segundos;
      print(
        '$porcentaje % · ${textoBytes(a.copiados)} de ${textoBytes(a.total)} · '
        '${textoBytes(velocidad.round())}/s',
      );
    }
    if (cancelar && a.copiados * 2 >= a.total) trabajo.cancelar();
  });
  final r = await trabajo.resultado;
  await avance.cancel();
  print(
    'Resultado: ${r.fin.name}'
    '${r.fallo == null ? '' : ' (${r.fallo!.name})'}'
    '${r.detalle == null ? '' : ': ${r.detalle}'}'
    '${r.restos == null ? '' : ' · ha quedado ${r.restos}'}'
    ' · ${(reloj.elapsedMilliseconds / 1000).toStringAsFixed(1)} s',
  );
  print(
    'En la carpeta: ${File(destino).existsSync() ? textoBytes(File(destino).lengthSync()) : 'no está'}'
    '${File('$destino$finalParcial').existsSync() ? ' · ¡queda el .parcial!' : ''}',
  );
}
