import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:videoteca/datos/base_datos.dart';
import 'package:videoteca/datos/carpetas_app.dart';
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

  group('Cambios en el disco', () {
    late Directory raiz;
    late Directory datos;
    late BaseDatos bd;

    setUp(() {
      raiz = Directory.systemTemp.createTempSync('videoteca_raiz_');
      datos = Directory.systemTemp.createTempSync('videoteca_datos_');
      bd = BaseDatos(NativeDatabase.memory());
    });
    tearDown(() async {
      await bd.close();
      raiz.deleteSync(recursive: true);
      datos.deleteSync(recursive: true);
    });

    File crear(String ruta, int tamano) {
      final f = File('${raiz.path}$sep$ruta')..createSync(recursive: true);
      f.writeAsBytesSync(List.filled(tamano, 7));
      f.setLastModifiedSync(DateTime(2020, 1, 1, 12));
      return f;
    }

    Future<ProgresoEscaneo> escanear({bool marcarNuevas = true}) => Escaner(
      bd: bd,
      raiz: raiz.path,
      carpetas: CarpetasApp.preparar(datos.path),
      trabajadores: 1,
      marcarNuevas: marcarNuevas,
    ).ejecutar().last;

    Future<FilaPelicula> fila(String nombre) async =>
        (await bd.todasLasPeliculas()).singleWhere(
          (f) => f.ruta.endsWith('$sep$nombre'),
        );

    test('nuevas, movidas, desaparecidas y de vuelta', () async {
      crear('Comedias${sep}Comedia${sep}Joy (2015).mp4', 100);
      final big = crear('Comedias${sep}Comedia${sep}Big (1988).mp4', 200);
      crear('Drama${sep}Drama${sep}Gump (1994).mp4', 300);

      // Primer escaneo: nada es «nuevo».
      var r = await escanear(marcarNuevas: false);
      expect(r.fase, FaseEscaneo.terminado);
      expect(r.leidas, 3);
      expect((await bd.todasLasPeliculas()).where((f) => f.nueva), isEmpty);
      final idJoy = (await fila('Joy (2015).mp4')).id;

      // Mover Joy a otra carpeta: conserva su número y no se vuelve a leer.
      Directory('${raiz.path}${sep}Romance').createSync();
      File('${raiz.path}${sep}Comedias${sep}Comedia${sep}Joy (2015).mp4')
          .renameSync('${raiz.path}${sep}Romance${sep}Joy (2015).mp4');
      r = await escanear();
      expect(r.movidas, 1);
      expect(r.nuevas, 0);
      expect(r.actualizadas, 0);
      final joy = await fila('Joy (2015).mp4');
      expect(joy.id, idJoy);
      expect(joy.generoCarpeta, 'Romance');
      expect(joy.grupo, '');

      // Una película nueva.
      crear('Drama${sep}Drama${sep}Wonka (2023).m4v', 400);
      r = await escanear();
      expect(r.nuevas, 1);
      final wonka = await fila('Wonka (2023).m4v');
      expect(wonka.nueva, isTrue);
      expect(r.idsNuevos, [wonka.id]);

      // Big desaparece: no se borra, se marca.
      big.deleteSync();
      r = await escanear();
      expect(r.desaparecidas, 1);
      expect(
        (await bd.peliculasDesaparecidas()).single.ruta,
        endsWith('Big (1988).mp4'),
      );
      expect(await bd.todasLasPeliculas(), hasLength(3));

      // Si se escanea otra vez, no cuenta de nuevo.
      r = await escanear();
      expect(r.desaparecidas, 0);
      expect(r.hayCambios, isFalse);

      // Y vuelve igual que estaba.
      crear('Comedias${sep}Comedia${sep}Big (1988).mp4', 200);
      r = await escanear();
      expect(r.recuperadas, 1);
      expect(r.nuevas, 0);
      expect(await bd.peliculasDesaparecidas(), isEmpty);
    });

    test('no lee un archivo que se está copiando', () async {
      crear('Drama${sep}Drama${sep}Gump (1994).mp4', 300);
      await escanear(marcarNuevas: false);
      final copiando = crear('Drama${sep}Drama${sep}Nueva (2025).mp4', 50);
      final abierto = copiando.openSync(mode: FileMode.append);
      try {
        expect(archivoEnUso(copiando.path), isTrue);
        final r = await escanear();
        expect(r.enUso, 1);
        expect(r.nuevas, 0);
      } finally {
        abierto.closeSync();
      }
      expect(archivoEnUso(copiando.path), isFalse);
      expect((await escanear()).nuevas, 1);
    }, skip: Platform.isWindows ? false : 'Solo en Windows');

    test('empareja copias idénticas por el nombre', () {
      final fecha = DateTime(2020);
      ArchivoConocido c(int id) => (
        id: id,
        tamano: 10,
        modificado: fecha,
        conError: false,
        desaparecida: false,
      );
      ArchivoEncontrado a(String ruta) =>
          (ruta: ruta, tamano: 10, modificado: fecha, creado: fecha);
      final parejas = emparejarMovidas(
        {'A${sep}Uno.mp4': c(1), 'B${sep}Uno.mp4': c(2)},
        [a('C${sep}Uno.mp4'), a('D${sep}Uno.mp4')],
      );
      // Mismo nombre en las dos: hay dudas y no se empareja nada.
      expect(parejas, isEmpty);

      final otra = emparejarMovidas(
        {'A${sep}Uno.mp4': c(1), 'B${sep}Dos.mp4': c(2)},
        [a('C${sep}Dos.mp4'), a('D${sep}Uno.mp4')],
      );
      expect(otra, hasLength(2));
      expect(
        {for (final (de, a) in otra) de: a.ruta},
        {
          'A${sep}Uno.mp4': 'D${sep}Uno.mp4',
          'B${sep}Dos.mp4': 'C${sep}Dos.mp4',
        },
      );
    });
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

    test('borrar, nuevas, desaparecidas y ajustes', () async {
      final id = await bd.guardarPelicula(
        fila('Joy').copyWith(nueva: const Value(true)),
      );
      // Al volver a guardarla (archivo cambiado) sigue siendo «nueva».
      await bd.guardarPelicula(fila('Joy'));
      expect((await bd.todasLasPeliculas()).single.nueva, isTrue);

      await bd.marcarDesaparecidas([id], DateTime(2026, 10, 4));
      expect(await bd.todasLasPeliculas(), isEmpty);
      expect((await bd.peliculasDesaparecidas()).single.id, id);
      expect(await bd.contarPeliculas(), 0);

      await bd.borrarPeliculas([id]);
      expect(await bd.peliculasDesaparecidas(), isEmpty);

      await bd.guardarAjuste('carpetaRaiz', r'D:\');
      await bd.guardarAjuste('carpetaRaiz', r'E:\Pelis');
      expect(await bd.todosLosAjustes(), {'carpetaRaiz': r'E:\Pelis'});
    });
  });

  test('abre una base que una versión antigua de la app dejó anotada como '
      'más vieja', () async {
    final temporal = Directory.systemTemp.createTempSync('bd');
    final ruta = '${temporal.path}${Platform.pathSeparator}v.sqlite';
    var bd = BaseDatos(NativeDatabase(File(ruta)));
    await bd.guardarAjuste('a', 'b');
    // Lo que hizo la v0.1 al abrirla: dejar la versión en 2.
    await bd.customStatement('PRAGMA user_version = 2');
    await bd.close();

    bd = BaseDatos(NativeDatabase(File(ruta)));
    expect(await bd.todosLosAjustes(), {'a': 'b'});
    final version = await bd.customSelect('PRAGMA user_version').getSingle();
    expect(version.read<int>('user_version'), 5);
    await bd.close();
    temporal.deleteSync(recursive: true);
  });
}
