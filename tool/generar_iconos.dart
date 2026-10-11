// Dibuja el icono de la app (la tira de película dorada del diseño sobre el
// fondo oscuro) y lo guarda en todos los tamaños que piden Android y Windows
// (también las imágenes del instalador).
//
//   dart run tool/generar_iconos.dart
//
// Solo hace falta volver a ejecutarlo si se cambia el dibujo.

// ignore_for_file: avoid_print

import 'dart:io';

import 'package:image/image.dart' as img;

final _fondo = img.ColorRgba8(0x0F, 0x0E, 0x13, 255);
final _dorado = img.ColorRgba8(0xE2, 0xAE, 0x4F, 255);

/// La tira de película en una cuadrícula de 24 × 24 (el mismo dibujo que el
/// icono de la pantalla de acceso del diseño), dentro de un lienzo de
/// [lado] píxeles: el dibujo ocupa [escala] del lienzo, centrado.
img.Image _dibujo(
  int lado, {
  required double escala,
  required bool conFondo,
  double radioFondo = 0,
}) {
  // Se dibujan dos máscaras en blanco sobre negro, 4 veces más grandes (así
  // los bordes salen suaves al reducirlas): la tinta dorada y la forma del
  // fondo. Después se colorean.
  const ss = 4;
  final grande = lado * ss;
  final blanco = img.ColorRgb8(255, 255, 255);
  final negro = img.ColorRgb8(0, 0, 0);
  img.Image mascara() => img.fill(
    img.Image(width: grande, height: grande),
    color: negro,
  );

  final u = grande * escala / 24; // una unidad de la cuadrícula
  final origen = (grande - 24 * u) / 2;
  int p(num v) => (origen + v * u).round();
  final g = 1.7 * u; // grosor de las líneas
  int m(num v, double d) => (origen + v * u + d).round();

  final tinta = mascara();
  void rect(int x1, int y1, int x2, int y2, img.Color c, [num radio = 0]) => img
      .fillRect(tinta, x1: x1, y1: y1, x2: x2, y2: y2, color: c, radius: radio);
  // El marco: rectángulo redondeado (x 3–21, y 4–20, radio 2), hueco.
  rect(
    m(3, -g / 2),
    m(4, -g / 2),
    m(21, g / 2),
    m(20, g / 2),
    blanco,
    2 * u + g / 2,
  );
  rect(
    m(3, g / 2),
    m(4, g / 2),
    m(21, -g / 2),
    m(20, -g / 2),
    negro,
    (2 * u - g / 2).clamp(0, 1e9),
  );
  // Las dos líneas verticales y las cuatro marcas de los lados.
  for (final x in [7, 17]) {
    rect(m(x, -g / 2), p(4), m(x, g / 2), p(20), blanco);
  }
  for (final (x1, x2) in [(3, 7), (17, 21)]) {
    for (final y in [9, 15]) {
      rect(p(x1), m(y, -g / 2), p(x2), m(y, g / 2), blanco);
    }
  }

  final forma = mascara();
  if (conFondo) {
    img.fillRect(
      forma,
      x1: 0,
      y1: 0,
      x2: grande - 1,
      y2: grande - 1,
      color: blanco,
      radius: radioFondo * grande,
    );
  }

  img.Image reducir(img.Image i) => img.copyResize(
    i,
    width: lado,
    height: lado,
    interpolation: img.Interpolation.average,
  );
  final t = reducir(tinta);
  final f = reducir(forma);
  final resultado = img.Image(width: lado, height: lado, numChannels: 4);
  for (final px in resultado) {
    final a = t.getPixel(px.x, px.y).r / 255; // cuánto dorado
    final b = conFondo ? f.getPixel(px.x, px.y).r / 255 : a; // opacidad
    num mezcla(num oro, num fondo) =>
        conFondo ? oro * a + fondo * (1 - a) : oro;
    px
      ..r = mezcla(_dorado.r, _fondo.r).round()
      ..g = mezcla(_dorado.g, _fondo.g).round()
      ..b = mezcla(_dorado.b, _fondo.b).round()
      ..a = (b * 255).round();
  }
  return resultado;
}

void _guardar(String ruta, img.Image imagen) {
  File(ruta)
    ..createSync(recursive: true)
    ..writeAsBytesSync(img.encodePng(imagen));
  print(ruta);
}

void _guardarBmp(String ruta, img.Image imagen) {
  File(ruta)
    ..createSync(recursive: true)
    ..writeAsBytesSync(img.encodeBmp(imagen.convert(numChannels: 3)));
  print(ruta);
}

void main() {
  const res = 'android/app/src/main/res';
  const densidades = {
    'mdpi': 1.0,
    'hdpi': 1.5,
    'xhdpi': 2.0,
    'xxhdpi': 3.0,
    'xxxhdpi': 4.0,
  };
  for (final MapEntry(key: nombre, value: factor) in densidades.entries) {
    // Icono clásico (48 dp): cuadrado oscuro con las esquinas redondeadas.
    _guardar(
      '$res/mipmap-$nombre/ic_launcher.png',
      _dibujo(
        (48 * factor).round(),
        escala: 0.72,
        conFondo: true,
        radioFondo: 0.2,
      ),
    );
    // Icono adaptable (Android 8 y posteriores): solo el dibujo, en 108 dp;
    // el fondo lo pone `ic_launcher_fondo` y el móvil recorta la forma.
    _guardar(
      '$res/mipmap-$nombre/ic_launcher_foreground.png',
      _dibujo((108 * factor).round(), escala: 0.46, conFondo: false),
    );
  }

  // Windows: un .ico con varios tamaños.
  final ico = img.IcoEncoder().encodeImages([
    for (final lado in [16, 24, 32, 48, 64, 128, 256])
      _dibujo(lado, escala: 0.8, conFondo: true, radioFondo: 0.18),
  ]);
  File('windows/runner/resources/app_icon.ico').writeAsBytesSync(ico);
  print('windows/runner/resources/app_icon.ico');

  // Instalador de Windows (Inno Setup): la imagen de la izquierda de la
  // primera y la última página y la pequeña de arriba, en BMP sin
  // transparencia, a 100, 150 y 200 % (Inno elige la que va mejor con la
  // pantalla).
  for (final (sufijo, factor) in [('100', 1.0), ('150', 1.5), ('200', 2.0)]) {
    final ancho = (164 * factor).round();
    final alto = (314 * factor).round();
    final grande = img.fill(
      img.Image(width: ancho, height: alto),
      color: _fondo,
    );
    final logo = _dibujo((ancho * 0.62).round(), escala: 0.9, conFondo: false);
    img.compositeImage(
      grande,
      logo,
      dstX: (ancho - logo.width) ~/ 2,
      dstY: (alto * 0.36 - logo.height / 2).round(),
    );
    _guardarBmp('windows/instalador/imagen-grande-$sufijo.bmp', grande);

    final lado = (55 * factor).round();
    final pequena = img.fill(
      img.Image(width: lado, height: lado),
      color: _fondo,
    );
    img.compositeImage(pequena, _dibujo(lado, escala: 0.8, conFondo: false));
    _guardarBmp('windows/instalador/imagen-pequena-$sufijo.bmp', pequena);
  }

  // Para verlo en grande.
  _guardar(
    'build/icono.png',
    _dibujo(512, escala: 0.72, conFondo: true, radioFondo: 0.2),
  );
}
