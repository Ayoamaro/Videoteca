import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:videoteca/disco/caratula_mp4.dart';
import 'package:videoteca/disco/lector_archivo.dart';
import 'package:videoteca/modelos/pelicula.dart';
import 'package:videoteca/pantallas/lectura.dart';
import 'package:videoteca/tema/tema.dart';

/// Caja de un `.mp4`: 4 bytes de tamaño + 4 letras de nombre + contenido.
List<int> caja(String nombre, List<int> contenido) {
  final cabecera = ByteData(8)..setUint32(0, 8 + contenido.length);
  return [
    ...cabecera.buffer.asUint8List(0, 4),
    ...nombre.codeUnits,
    ...contenido,
  ];
}

/// Un `.mp4` mínimo con la carátula [imagen] en moov › udta › meta › ilst.
Uint8List mp4ConCaratula(List<int> imagen) {
  final data = caja('data', [0, 0, 0, 13, 0, 0, 0, 0, ...imagen]);
  final meta = caja('meta', [
    0, 0, 0, 0, // versión y flags
    ...caja('hdlr', List.filled(25, 0)),
    ...caja('ilst', caja('covr', data)),
  ]);
  return Uint8List.fromList([
    ...caja('ftyp', 'isom'.codeUnits),
    ...caja('moov', [
      ...caja('mvhd', List.filled(100, 0)),
      ...caja('udta', meta),
    ]),
    ...caja('mdat', List.filled(1000, 7)),
  ]);
}

void main() {
  group('Carátula incrustada', () {
    late Directory temporal;
    setUp(() => temporal = Directory.systemTemp.createTempSync('videoteca'));
    tearDown(() => temporal.deleteSync(recursive: true));

    test('se encuentra dentro de moov › udta › meta › ilst › covr', () {
      final imagen = [0xFF, 0xD8, 0xFF, 0xE0, 1, 2, 3, 4, 0xFF, 0xD9];
      final archivo = File('${temporal.path}/con_caratula.mp4')
        ..writeAsBytesSync(mp4ConCaratula(imagen));
      expect(leerCaratulaMp4(archivo.path), imagen);
    });

    test('devuelve null si el archivo no tiene carátula', () {
      final archivo = File('${temporal.path}/sin_caratula.mp4')
        ..writeAsBytesSync([
          ...caja('ftyp', 'isom'.codeUnits),
          ...caja('moov', caja('mvhd', List.filled(100, 0))),
        ]);
      expect(leerCaratulaMp4(archivo.path), isNull);
    });
  });

  test('Los datos de Windows se convierten en una película', () {
    final d = DatosArchivo(
      ruta: r'D:\Comedias\Comedia\Malas Madres 2꞉ Navidad (2017).mp4',
      propiedades: {
        'System.Media.SubTitle': "A Bad Moms Christmas",
        'System.Music.Genre': ['Comedia. Navidad'],
        'System.Music.Artist': ['Mila Kunis', 'Kristen Bell'],
        'System.Rating': 75,
        'System.Media.Duration': 62 * 600000000,
        'System.Video.FrameWidth': 1920,
        'System.Video.FrameHeight': 800,
      },
      caratula: null,
      tamanoBytes: 1 << 30,
    );
    final p = Pelicula.desdeArchivo(d);
    // Sin System.Title ni System.Media.Year: se sacan del nombre del archivo.
    expect(p.titulo, 'Malas Madres 2: Navidad');
    expect(p.anio, 2017);
    expect(p.generos, ['Comedia', 'Navidad']);
    expect(p.reparto, 'Mila Kunis, Kristen Bell');
    expect(p.estrellas, 4);
    expect(p.duracionTexto, '1 h 2 min');
    expect(p.resolucion, '1080p · 1920 × 800');
    expect(p.tamanoTexto, '1,0 GB');
  });

  testWidgets('La pantalla de lectura enseña los datos leídos', (tester) async {
    tester.view.physicalSize = const Size(1400, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final contenedor = ProviderContainer();
    addTearDown(contenedor.dispose);
    contenedor
        .read(ultimaLecturaProvider.notifier)
        .guardar(
          DatosArchivo(
            ruta: r'D:\Drama y Musical\Drama\Herida (1992).mp4',
            propiedades: {
              'System.Title': 'Herida',
              'System.Video.Director': ['Louis Malle'],
            },
            caratula: null,
            tamanoBytes: 0,
          ),
        );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: contenedor,
        child: MaterialApp(
          theme: construirTema(Brightness.dark),
          home: const Scaffold(body: PantallaLectura()),
        ),
      ),
    );
    expect(find.text('Herida'), findsWidgets);
    expect(find.text('Louis Malle'), findsOneWidget);
    expect(find.text('System.Video.Director'), findsOneWidget);
  });

  // Solo en el PC con el disco de películas conectado.
  final real = Platform.isWindows ? _primerMp4(r'D:\') : null;
  test('Lee un .mp4 real del disco D:', () {
    final d = leerArchivo(real!);
    expect(d.titulo, isNotEmpty);
    expect(d.anio, greaterThan(1900));
    expect(d.duracionMin, greaterThan(0));
    expect(d.caratula, isNotNull);
  }, skip: real == null ? 'No hay disco D: con películas' : false);
}

String? _primerMp4(String raiz) {
  List<FileSystemEntity> listar(Directory d) {
    try {
      return d.listSync();
    } on FileSystemException {
      return const []; // Carpetas del sistema sin permiso de lectura.
    }
  }

  if (!Directory(raiz).existsSync()) return null;
  // Sin la papelera ($RECYCLE.BIN) ni otras carpetas de sistema.
  bool deSistema(Directory d) {
    final nombre = d.path.split(Platform.pathSeparator).last;
    return nombre.startsWith(r'$') || nombre == 'System Volume Information';
  }

  for (final grupo in listar(
    Directory(raiz),
  ).whereType<Directory>().where((d) => !deSistema(d))) {
    for (final genero in listar(grupo).whereType<Directory>()) {
      for (final f in listar(genero).whereType<File>()) {
        if (f.path.toLowerCase().endsWith('.mp4')) return f.path;
      }
    }
  }
  return null;
}
