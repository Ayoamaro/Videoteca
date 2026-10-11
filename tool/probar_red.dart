// Prueba la red de casa desde la terminal, solo leyendo: busca entre las
// carpetas compartidas de este PC la que lleva a la colección (como hace la
// app en Ajustes → Red de casa) y comprueba una ruta de red.
//
//   dart run tool/probar_red.dart <raíz de la colección> [ruta de red]
//
// Por ejemplo: dart run tool/probar_red.dart D:\ \\AYO-PC\Multimedia\Películas
//
// Las películas de prueba salen de la propia colección (una de cada
// carpeta de género), sin usar la base de datos.

// ignore_for_file: avoid_print

import 'dart:io';

import 'package:videoteca/disco/red.dart';

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    stderr.writeln(
      'Uso: dart run tool/probar_red.dart <raíz de la colección> [ruta de red]',
    );
    exit(64);
  }
  final raiz = args[0];

  // Una película de cada carpeta de género (Raíz\Grupo\Género\*.mp4).
  final relativas = <String>[];
  for (final grupo in Directory(raiz).listSync().whereType<Directory>()) {
    final nombre = grupo.path.split(r'\').last;
    if (nombre.startsWith(r'$') || nombre.startsWith('!')) continue;
    try {
      for (final genero in grupo.listSync().whereType<Directory>()) {
        final pelicula = genero
            .listSync()
            .whereType<File>()
            .where((f) => RegExp(r'\.(mp4|m4v)$').hasMatch(f.path))
            .firstOrNull;
        if (pelicula != null) {
          relativas.add(rutaRelativa(pelicula.path, raiz)!);
        }
      }
    } on FileSystemException {
      continue;
    }
  }
  final muestras = muestraPeliculas(relativas);
  print(
    'Películas de prueba: ${muestras.length} (de ${relativas.length} '
    'carpetas de género)',
  );

  final reloj = Stopwatch()..start();
  final compartidas = carpetasCompartidasDeEstePc();
  print('Carpetas compartidas de este PC (${reloj.elapsedMilliseconds} ms):');
  for (final c in compartidas) {
    print('  $c');
  }

  reloj.reset();
  final propuesta = await buscarRutaRed(raiz: raiz, muestras: muestras);
  print(
    propuesta == null
        ? 'Propuesta: ninguna (${reloj.elapsedMilliseconds} ms)'
        : 'Propuesta: ${propuesta.ruta} · encontradas '
              '${propuesta.encontradas} de ${propuesta.probadas} '
              '(${reloj.elapsedMilliseconds} ms)',
  );

  final ruta = args.length > 1 ? limpiarRutaRed(args[1]) : propuesta?.ruta;
  if (ruta == null) return;
  reloj.reset();
  final r = await comprobarRuta(ruta, muestras);
  print(
    'Comprobar $ruta: ${r.estado.name} · encontradas ${r.encontradas} de '
    '${r.probadas}${r.codigo == null ? '' : ' · error ${r.codigo}'} '
    '(${reloj.elapsedMilliseconds} ms)',
  );
}
