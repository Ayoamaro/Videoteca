import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:videoteca/datos/base_datos.dart';
import 'package:videoteca/disco/escaner.dart';

void main() {
  final sep = Platform.pathSeparator;

  group('Carpetas de la colección', () {
    late Directory raiz;

    setUp(() {
      raiz = Directory.systemTemp.createTempSync('videoteca_');
      for (final ruta in [
        'Comedias/Comedia/Joy (2015).mp4',
        'Comedias/Comedia/Otra (2001).MP4',
        'Comedias/Romance/Amor (1999).mp4',
        'Drama y Musical/Musical/Wonka (2023).m4v',
        'Suelta (2010).mp4',
        'Comedias/Comedia/notas.txt',
        '.oculta/Escondida (2000).mp4',
      ]) {
        File('${raiz.path}/$ruta')
          ..createSync(recursive: true)
          ..writeAsBytesSync([0]);
      }
      // En Windows, "oculta" es un atributo de la carpeta, no el punto.
      if (Platform.isWindows) {
        Process.runSync('attrib', ['+h', '${raiz.path}$sep.oculta']);
      }
    });

    tearDown(() => raiz.deleteSync(recursive: true));

    test('encuentra los .mp4 y .m4v y se salta lo demás', () {
      final nombres = buscarMp4(raiz.path)
          .map((a) => a.ruta.split(sep).last)
          .toList();
      expect(nombres, hasLength(5));
      expect(nombres, contains('Wonka (2023).m4v'));
      expect(nombres, contains('Otra (2001).MP4'));
      expect(nombres, isNot(contains('notas.txt')));
      expect(nombres, isNot(contains('Escondida (2000).mp4')));
    });

    test('detecta grupos y géneros de las carpetas', () {
      final e = EstructuraColeccion(raiz.path, buscarMp4(raiz.path));
      expect(e.porGenero['Comedia'], 2);
      expect(e.porGenero['Musical'], 1);
      expect(e.porGrupo.keys, containsAll(['Comedias', 'Drama y Musical']));
      expect(e.generos.first, ('Comedia', 2));
    });
  });

  test('grupo y género según la ruta', () {
    final raiz = 'D:$sep';
    expect(
      ubicacionEnColeccion(raiz, 'D:${sep}Comedias${sep}Comedia${sep}Joy.mp4'),
      (grupo: 'Comedias', genero: 'Comedia'),
    );
    expect(ubicacionEnColeccion(raiz, 'D:${sep}Western${sep}Rio.mp4'), (
      grupo: '',
      genero: 'Western',
    ));
    expect(ubicacionEnColeccion(raiz, 'D:${sep}Suelta.mp4'), (
      grupo: '',
      genero: '',
    ));
  });

  test('la miniatura mide 240 px de ancho y pesa mucho menos', () {
    final original = img.Image(width: 350, height: 500);
    img.fill(original, color: img.ColorRgb8(200, 120, 40));
    final jpeg = img.encodeJpg(original, quality: 100);
    final miniatura = crearMiniatura(jpeg)!;
    final leida = img.decodeJpg(miniatura)!;
    expect(leida.width, anchoMiniatura);
    expect(leida.height, closeTo(343, 1));
    expect(miniatura.length, lessThan(jpeg.length));
  });

  test('progreso: porcentaje y tiempo restante', () {
    const p = ProgresoEscaneo(
      fase: FaseEscaneo.leyendo,
      porLeer: 100,
      leidas: 25,
      transcurrido: Duration(seconds: 10),
    );
    expect(p.fraccion, 0.25);
    expect(p.restante, const Duration(seconds: 30));
  });

  group('Base de datos', () {
    late BaseDatos bd;

    setUp(() => bd = BaseDatos(NativeDatabase.memory()));
    tearDown(() => bd.close());

    PeliculasCompanion fila(String titulo) => PeliculasCompanion.insert(
      ruta: r'D:\Comedias\Comedia\Joy (2015).mp4',
      titulo: titulo,
      anio: const Value(2015),
      anadida: DateTime(2026, 10, 1),
      modificado: DateTime(2026, 10, 1),
      escaneada: DateTime(2026, 10, 4),
    );

    test(
      'volver a guardar la misma ruta actualiza y conserva el número',
      () async {
        final id = await bd.guardarPelicula(fila('Joy'));
        final id2 = await bd.guardarPelicula(fila('Joy (corregido)'));
        expect(id2, id);
        final todas = await bd.todasLasPeliculas();
        expect(todas.single.titulo, 'Joy (corregido)');
        expect(await bd.contarPeliculas(), 1);
      },
    );

    test('borrar rutas y ajustes', () async {
      final id = await bd.guardarPelicula(fila('Joy'));
      expect(await bd.borrarRutas([r'D:\Comedias\Comedia\Joy (2015).mp4']), [
        id,
      ]);
      expect(await bd.contarPeliculas(), 0);

      await bd.guardarAjuste('carpetaRaiz', r'D:\');
      await bd.guardarAjuste('carpetaRaiz', r'E:\Pelis');
      expect(await bd.todosLosAjustes(), {'carpetaRaiz': r'E:\Pelis'});
    });
  });
}
