// Prueba de lectura: muestra lo que la app lee de unos cuantos .mp4 reales,
// para compararlo con "Propiedades → Detalles" del Explorador de Windows.
//
// Uso:  dart run tool/probar_lectura.dart [carpeta raíz] [cuántas]
//       (por defecto D:\ y 10 películas repartidas por todas las carpetas)
//
// Solo lee: no modifica ningún archivo.

// ignore_for_file: avoid_print

import 'dart:io';

import 'package:videoteca/disco/lector_archivo.dart';

void main(List<String> argumentos) {
  final raiz = argumentos.isNotEmpty ? argumentos[0] : r'D:\';
  final cuantas = argumentos.length > 1 ? int.parse(argumentos[1]) : 10;

  final todas = <String>[];
  for (final grupo in Directory(raiz).listSync().whereType<Directory>()) {
    final nombre = grupo.path.split(r'\').last;
    if (nombre.startsWith(r'$') ||
        nombre.startsWith('!') ||
        nombre == 'System Volume Information') {
      continue;
    }
    for (final genero in grupo.listSync().whereType<Directory>()) {
      todas.addAll(
        genero
            .listSync()
            .whereType<File>()
            .map((f) => f.path)
            .where((p) => p.toLowerCase().endsWith('.mp4')),
      );
    }
  }
  todas.sort();
  print('Encontrados ${todas.length} .mp4 en $raiz\n');
  if (todas.isEmpty) return;

  // Repartidas a lo largo de la lista para probar carpetas distintas.
  final paso = (todas.length / cuantas).ceil().clamp(1, todas.length);
  final elegidas = [for (var i = 0; i < todas.length; i += paso) todas[i]];

  final reloj = Stopwatch()..start();
  for (final ruta in elegidas) {
    final d = leerArchivo(ruta);
    print('━' * 78);
    print(ruta);
    print(
      '  → Título: ${d.titulo} · Año: ${d.anio} · Estrellas: ${d.estrellas}'
      ' · Géneros: ${d.generos.join(' / ')}',
    );
    print(
      '  → ${d.duracionMin} min · ${d.resolucion} · '
      '${(d.tamanoBytes / (1 << 30)).toStringAsFixed(2)} GB · '
      'carátula: ${d.caratula == null ? 'NO' : '${d.caratula!.length} bytes '
                '(${_formato(d.caratula!)})'}',
    );
    for (final MapEntry(key: nombre, value: etiqueta)
        in propiedadesLeidas.entries) {
      var valor = d.texto(nombre);
      if (valor.isEmpty) continue;
      if (valor.length > 90) valor = '${valor.substring(0, 87)}...';
      print('    ${etiqueta.padRight(20)} $valor');
    }
  }
  print('━' * 78);
  print(
    '${elegidas.length} películas leídas en ${reloj.elapsedMilliseconds} ms',
  );
}

String _formato(List<int> b) {
  if (b.length > 3 && b[0] == 0xFF && b[1] == 0xD8) return 'JPEG';
  if (b.length > 3 && b[0] == 0x89 && b[1] == 0x50) return 'PNG';
  return '¿?';
}
