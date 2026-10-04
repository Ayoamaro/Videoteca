// Prueba el buscador con el catálogo guardado, desde la terminal.
//
// Uso:  dart run tool/probar_busqueda.dart [base de datos] [búsquedas…]
//
// Sin argumentos usa la base de datos de la app y unas búsquedas de ejemplo.
// Muestra los 5 primeros resultados de cada una y cuánto ha tardado.

// ignore_for_file: avoid_print

import 'package:videoteca/datos/base_datos.dart';
import 'package:videoteca/datos/buscador.dart';
import 'package:videoteca/datos/carpetas_app.dart';

Future<void> main(List<String> argumentos) async {
  final ruta = argumentos.isNotEmpty && argumentos.first.endsWith('.sqlite')
      ? argumentos.first
      : CarpetasApp(carpetaDatosApp()).baseDatos;
  final consultas = argumentos.where((a) => !a.endsWith('.sqlite')).toList();
  if (consultas.isEmpty) {
    consultas.addAll([
      'vengadores',
      'VENGADORES',
      'avengers',
      'atame',
      'spiderman',
      'tom hanks',
      'nolan',
      'almodovar',
      'el senor de los anillos',
      'origen 2010',
      'v',
      've',
      'xyzzy',
    ]);
  }

  final bd = BaseDatos.abrir(ruta);
  final filas = await bd.todasLasPeliculas();
  await bd.close();
  final titulos = {for (final f in filas) f.id: '${f.titulo} (${f.anio})'};

  final reloj = Stopwatch()..start();
  final buscador = Buscador([
    for (final f in filas)
      (
        id: f.id,
        titulo: f.titulo,
        tituloOriginal: f.tituloOriginal,
        anio: f.anio,
        direccion: f.direccion,
        reparto: f.reparto,
      ),
  ]);
  print(
    'Índice de ${buscador.total} películas preparado en '
    '${reloj.elapsedMilliseconds} ms\n',
  );

  for (final consulta in consultas) {
    reloj.reset();
    final resultados = buscador.buscar(consulta);
    final personas = buscador.personas(consulta);
    final ms = reloj.elapsedMicroseconds / 1000;
    print(
      '«$consulta» → ${resultados.length} películas en '
      '${ms.toStringAsFixed(1)} ms',
    );
    for (final r in resultados.take(5)) {
      final motivo = r.persona == null
          ? ''
          : '  [${r.rol == Rol.director ? 'dirige' : 'sale'} ${r.persona}]';
      print('   ${r.puntos.toString().padLeft(4)}  ${titulos[r.id]}$motivo');
    }
    for (final p in personas) {
      print('   persona: ${p.nombre} (${p.rol.name}, ${p.total})');
    }
    print('');
  }
}
