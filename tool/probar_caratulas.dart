// Compara tamaños y calidades de las miniaturas del tablón (issue #6). Solo
// lee los `.mp4` y las miniaturas del PC: no escribe nada en el disco de las
// películas ni en la base de datos.
//
// Uso:  dart run tool/probar_caratulas.dart <carpeta de salida> [n]
//
//   n   cuántas películas, repartidas por orden alfabético (20 si no se dice)
//
// Para cada variante (ancho × calidad) dice el peso medio y el total
// estimado para toda la colección, y deja en la carpeta de salida las
// imágenes y una lámina `comparar.png` con todas las variantes, ampliadas
// como las vería un móvil (×3) para mirarlas una al lado de otra, y
// `detalle.png` con un trozo del centro de cada una, a tamaño real.

// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:videoteca/datos/base_datos.dart';
import 'package:videoteca/datos/carpetas_app.dart';
import 'package:videoteca/disco/caratula_mp4.dart';
import 'package:videoteca/tablon/formato.dart';

/// (origen, ancho, calidad): origen «pc» = miniatura JPEG del PC (como hasta
/// ahora), «mp4» = carátula original del archivo.
const _variantes = [
  ('pc', 180, 65),
  ('mp4', 180, 65),
  ('mp4', 240, 65),
  ('mp4', 300, 60),
  ('mp4', 300, 70),
  ('mp4', 350, 55),
  ('mp4', 350, 65),
];

Future<void> main(List<String> argumentos) async {
  if (argumentos.isEmpty) {
    print('Uso: dart run tool/probar_caratulas.dart <carpeta de salida> [n]');
    exit(1);
  }
  final salida = Directory(argumentos[0])..createSync(recursive: true);
  final n = argumentos.length > 1 ? int.parse(argumentos[1]) : 20;
  final carpetas = CarpetasApp(carpetaDatosApp());
  final bd = BaseDatos.abrir(carpetas.baseDatos);
  final todas = (await bd.todasLasPeliculas())
    ..sort((a, b) => a.titulo.compareTo(b.titulo));
  await bd.close();
  final elegidas = [for (var i = 0; i < n; i++) todas[i * todas.length ~/ n]];

  final pesos = {for (final v in _variantes) v: <int>[]};
  final lamina = <List<img.Image>>[];
  for (final p in elegidas) {
    final mp4 = File(p.ruta).existsSync() ? leerCaratulaMp4(p.ruta) : null;
    final pc = File(carpetas.miniatura(p.id));
    final jpegPc = pc.existsSync() ? pc.readAsBytesSync() : null;
    if (mp4 == null || jpegPc == null) {
      print('— Sin carátula: ${p.titulo}');
      continue;
    }
    final fila = <img.Image>[];
    for (final v in _variantes) {
      final (origen, ancho, calidad) = v;
      final webp = miniaturaTablon(
        origen == 'pc' ? jpegPc : mp4,
        ancho: ancho,
        calidad: calidad,
      )!;
      pesos[v]!.add(webp.length);
      File('${salida.path}/${p.id}-$origen-$ancho-q$calidad.webp')
          .writeAsBytesSync(webp);
      fila.add(_comoEnElMovil(webp));
    }
    lamina.add(fila);
    print('✓ ${p.titulo}');
  }

  print(
    '\nVariante              media     toda la colección (${todas.length})',
  );
  for (final v in _variantes) {
    final lista = pesos[v]!;
    if (lista.isEmpty) continue;
    final media = lista.reduce((a, b) => a + b) / lista.length;
    final (origen, ancho, calidad) = v;
    print(
      '${'$origen $ancho px q$calidad'.padRight(20)}'
      '${(media / 1024).toStringAsFixed(1).padLeft(6)} KB'
      '${(media * todas.length / 1024 / 1024).toStringAsFixed(0).padLeft(9)} MB',
    );
  }
  if (lamina.isNotEmpty) {
    File('${salida.path}/comparar.png').writeAsBytesSync(_lamina(lamina));
    File('${salida.path}/detalle.png').writeAsBytesSync(_detalle(lamina));
    print('\nLámina: ${salida.path}${Platform.pathSeparator}comparar.png');
  }
}

/// La miniatura como se ve en una tarjeta de 120 puntos en un móvil ×3
/// (360 px reales): el móvil la estira hasta ese ancho.
img.Image _comoEnElMovil(Uint8List webp) => img.copyResize(
  img.decodeWebP(webp)!,
  width: 360,
  interpolation: img.Interpolation.linear,
);

/// Una fila por película y una columna por variante.
Uint8List _lamina(List<List<img.Image>> filas) {
  const hueco = 8;
  final ancho = filas.first.first.width;
  final alto = filas.first.first.height;
  final columnas = filas.first.length;
  // Solo las 4 primeras películas (la lámina entera sería enorme).
  final usadas = filas.take(4).toList();
  final lienzo = img.Image(
    width: columnas * (ancho + hueco),
    height: usadas.length * (alto + hueco),
  );
  img.fill(lienzo, color: img.ColorRgb8(15, 14, 19));
  for (var f = 0; f < usadas.length; f++) {
    for (var c = 0; c < columnas; c++) {
      img.compositeImage(
        lienzo,
        usadas[f][c],
        dstX: c * (ancho + hueco),
        dstY: f * (alto + hueco),
      );
    }
  }
  return img.encodePng(lienzo);
}

/// El centro de cada variante de las 2 primeras películas, a tamaño real
/// (una columna por variante), para ver los detalles.
Uint8List _detalle(List<List<img.Image>> filas) {
  const lado = 200;
  const hueco = 8;
  final usadas = filas.take(2).toList();
  final columnas = usadas.first.length;
  final lienzo = img.Image(
    width: columnas * (lado + hueco),
    height: usadas.length * (lado + hueco),
  );
  img.fill(lienzo, color: img.ColorRgb8(15, 14, 19));
  for (var f = 0; f < usadas.length; f++) {
    for (var c = 0; c < columnas; c++) {
      final i = usadas[f][c];
      img.compositeImage(
        lienzo,
        img.copyCrop(
          i,
          x: (i.width - lado) ~/ 2,
          y: (i.height - lado) ~/ 2,
          width: lado,
          height: lado,
        ),
        dstX: c * (lado + hueco),
        dstY: f * (lado + hueco),
      );
    }
  }
  return img.encodePng(lienzo);
}
