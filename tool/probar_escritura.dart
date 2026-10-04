// Prueba la escritura en `.mp4` con COPIAS de películas reales (los
// originales nunca se tocan):
//
//     dart run tool/probar_escritura.dart D:\ <carpeta temporal> [cuántas]
//     dart run tool/probar_escritura.dart D:\ <carpeta temporal> "Superfrikis"
//
// (Con un texto en lugar de un número, prueba las películas cuyo nombre lo
// contiene.)
//
// Copia unas cuantas películas a la carpeta temporal y, en cada copia:
// 1. escribe campos nuevos (guion, país, temas, saga…): la carátula y el
//    vídeo tienen que quedar intactos;
// 2. cambia año, estrellas, sinopsis y reparto (con textos de más de 255
//    letras, que Windows no sabe guardar);
// 3. pone otra carátula;
// 4. lo deshace todo: tiene que quedar exactamente como el original.
// Al terminar borra las copias.
import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:videoteca/disco/escaner.dart';
import 'package:videoteca/disco/escritor.dart';
import 'package:videoteca/disco/lector_archivo.dart';

void main(List<String> args) {
  if (args.length < 2) {
    stderr.writeln(
      'Uso: dart run tool/probar_escritura.dart D:\\ <carpeta temporal> [n]',
    );
    exit(64);
  }
  final eleccion = args.length > 2 ? args[2] : '3';
  final temporal = Directory(args[1])..createSync(recursive: true);
  // Las más pequeñas, para que copiar no tarde demasiado.
  final archivos = buscarMp4(args[0])..sort((a, b) => a.tamano - b.tamano);
  final elegidas = int.tryParse(eleccion) == null
      ? archivos.where((a) => a.ruta.contains(eleccion))
      : archivos.take(int.parse(eleccion));
  var fallos = 0;
  for (final original in elegidas) {
    final nombre = original.ruta.split(r'\').last;
    final copia = '${temporal.path}\\$nombre';
    stdout.writeln('\n$nombre (${original.tamano ~/ 1048576} MB)');
    File(original.ruta).copySync(copia);
    try {
      fallos += _probar(copia);
      final igual = _mismoContenido(original.ruta, copia);
      stdout.writeln(
        '  ${igual ? '✓' : '✗'} el archivo final es idéntico al original, '
        'byte a byte',
      );
      if (!igual) fallos++;
    } on EscrituraException catch (e) {
      stdout.writeln('  ✗ $e');
      fallos++;
    } finally {
      File(copia).deleteSync();
    }
  }
  stdout.writeln(
    fallos == 0 ? '\nTodo correcto.' : '\n$fallos comprobaciones fallidas.',
  );
  exit(fallos == 0 ? 0 : 1);
}

int _probar(String ruta) {
  var fallos = 0;
  void comprobar(bool bien, String que) {
    stdout.writeln('  ${bien ? '✓' : '✗'} $que');
    if (!bien) fallos++;
  }

  final antes = leerArchivo(ruta);
  final valores = valoresFicha(antes);
  final huella = HuellaVideo.de(ruta);
  final reloj = Stopwatch()..start();

  // 1. Campos nuevos.
  var r = escribirFicha(ruta, {
    Campo.guion: 'Guionista de prueba',
    Campo.pais: 'Estados Unidos',
    Campo.fotografia: 'Fotógrafa de prueba',
    Campo.temas: 'Navidad; Fantasmas; Amistad',
    Campo.saga: 'Saga de prueba',
    Campo.numeroSaga: '2',
    Campo.premios: '2001: Premio de prueba',
    Campo.enlaceImdb: 'https://www.imdb.com/title/tt0000001/',
  });
  comprobar(
    r.despues.length == 8,
    '8 campos nuevos escritos y comprobados (${reloj.elapsedMilliseconds} ms)',
  );
  comprobar(
    mismaImagen(r.datos.caratula, antes.caratula),
    'la carátula sigue idéntica',
  );
  comprobar(HuellaVideo.de(ruta) == huella, 'el vídeo sigue idéntico');

  // 2. Cambiar datos que ya tenía.
  reloj.reset();
  r = escribirFicha(ruta, {
    Campo.anio: '1999',
    Campo.estrellas: valores[Campo.estrellas] == '5' ? '1' : '5',
    // Textos largos: Windows no sabe guardar más de 255 letras.
    Campo.sinopsis: 'Sinopsis de prueba con tildes: ñ, á, «comillas». ' * 14,
    Campo.reparto: List.generate(30, (i) => 'Actriz Número $i').join(', '),
  });
  comprobar(
    r.despues.length == 4 && r.datos.texto('System.Comment').length > 600,
    'año, estrellas, sinopsis de '
    '${r.datos.texto('System.Comment').length} letras y reparto de '
    '${r.datos.texto('System.Music.Artist').length} '
    '(${reloj.elapsedMilliseconds} ms)',
  );
  comprobar(HuellaVideo.de(ruta) == huella, 'el vídeo sigue idéntico');

  // 3. Otra carátula (la misma, en espejo).
  if (antes.caratula != null) {
    final espejo = img.encodeJpg(
      img.flipHorizontal(img.decodeImage(antes.caratula!)!),
      quality: 90,
    );
    reloj.reset();
    r = escribirFicha(ruta, const {}, caratula: CaratulaNueva(espejo));
    comprobar(
      r.caratulaCambiada && mismaImagen(r.datos.caratula, espejo),
      'carátula nueva escrita tal cual (${reloj.elapsedMilliseconds} ms)',
    );
  }

  // 4. Deshacer todo.
  reloj.reset();
  escribirFicha(
    ruta,
    valores,
    caratula: antes.caratula == null ? null : CaratulaNueva(antes.caratula),
  );
  final alFinal = leerArchivo(ruta);
  final distintos = [
    for (final c in Campo.values)
      if (valoresFicha(alFinal)[c] != valores[c]) c.nombre,
  ];
  comprobar(
    distintos.isEmpty,
    distintos.isEmpty
        ? 'deshecho: todos los campos como al principio '
              '(${reloj.elapsedMilliseconds} ms)'
        : 'deshecho, pero distintos: ${distintos.join(', ')}',
  );
  comprobar(
    mismaImagen(alFinal.caratula, antes.caratula),
    'carátula original recuperada byte a byte',
  );
  comprobar(HuellaVideo.de(ruta) == huella, 'el vídeo sigue idéntico');
  return fallos;
}

/// ¿Tienen los dos archivos exactamente el mismo contenido?
bool _mismoContenido(String a, String b) {
  final fa = File(a).openSync();
  final fb = File(b).openSync();
  try {
    if (fa.lengthSync() != fb.lengthSync()) return false;
    while (true) {
      final x = fa.readSync(1 << 22);
      final y = fb.readSync(1 << 22);
      if (!mismaImagen(x, y)) return false;
      if (x.isEmpty) return true;
    }
  } finally {
    fa.closeSync();
    fb.closeSync();
  }
}
