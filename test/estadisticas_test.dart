import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:videoteca/datos/base_datos.dart';
import 'package:videoteca/datos/carpetas_app.dart';
import 'package:videoteca/datos/copia_seguridad.dart';
import 'package:videoteca/datos/estadisticas.dart';
import 'package:videoteca/datos/excel.dart';
import 'package:videoteca/fuentes/sagas.dart';
import 'package:videoteca/modelos/pelicula.dart';

Pelicula _p(
  int id,
  String titulo,
  int anio, {
  List<String> generos = const ['Drama'],
  String pais = 'Estados Unidos',
  String direccion = '',
  String reparto = '',
  String saga = '',
  int numero = 0,
  int minutos = 100,
  int estrellas = 0,
}) => Pelicula(
  id: id,
  titulo: titulo,
  anio: anio,
  ruta: 'D:\\Drama\\Drama\\$titulo ($anio).mp4',
  grupo: 'Drama',
  generos: generos,
  pais: pais,
  direccion: direccion,
  reparto: reparto,
  saga: saga,
  numeroSaga: numero,
  duracionMin: minutos,
  estrellas: estrellas,
  tamanoBytes: 2 << 30,
);

void main() {
  group('Estadísticas', () {
    final lista = [
      _p(
        1,
        'Harry Potter y la piedra filosofal',
        2001,
        saga: 'Harry Potter',
        numero: 1,
        direccion: 'Chris Columbus',
        reparto: 'Daniel Radcliffe, Emma Watson',
        estrellas: 4,
      ),
      _p(
        2,
        'Harry Potter y el prisionero de Azkaban',
        2004,
        saga: 'Harry Potter',
        numero: 3,
        reparto: 'Daniel Radcliffe',
        pais: 'Reino Unido, Estados Unidos',
        estrellas: 5,
      ),
      _p(
        3,
        'Rocky',
        1976,
        saga: 'Rocky',
        numero: 1,
        generos: ['Drama', 'Deporte'],
      ),
      _p(4, 'Rocky II', 1979, saga: 'Rocky', numero: 2, minutos: 119),
      _p(5, 'Metrópolis', 1927, pais: 'Alemania', minutos: 153),
      _p(6, 'Sin año', 0),
    ];

    test('resumen, décadas y países', () {
      final e = Estadisticas.de(lista);
      expect(e.peliculas, 6);
      expect(e.minutos, 100 * 4 + 119 + 153);
      expect(e.mediaEstrellas, 4.5);
      expect(e.masAntigua?.titulo, 'Metrópolis');
      expect(e.masLarga?.titulo, 'Metrópolis');
      // De 1920 a 2000 sin saltarse ninguna; la de año 0 no cuenta.
      expect(e.decadas.first, (1920, 1));
      expect(e.decadas.last, (2000, 2));
      expect(e.decadas.length, 9);
      expect(e.decadas.firstWhere((d) => d.$1 == 1950), (1950, 0));
      expect(e.decadas.firstWhere((d) => d.$1 == 1970), (1970, 2));
      // «Reino Unido, Estados Unidos» cuenta para los dos países.
      expect(e.paises.first, ('Estados Unidos', 5));
      expect(e.paises, contains(('Reino Unido', 1)));
      expect(e.generos.first, ('Drama', 6));
      expect(e.actores.first, ('Daniel Radcliffe', 2));
    });

    test('sagas incompletas por el número de cada película', () {
      final e = Estadisticas.de(lista);
      expect(e.sagas, 2);
      expect(e.sagasCompletas, 1); // Rocky (no se sabe que hay más)
      final hp = e.sagasIncompletas.single;
      expect(hp.nombre, 'Harry Potter');
      expect((hp.tengo, hp.total), (2, 3));
      expect(hp.faltan, ['Nº 2']);
      expect(hp.segunTmdb, isFalse);
    });

    test('sagas incompletas según TMDB', () {
      final tmdb = SagasTmdb(
        fecha: DateTime(2026, 10, 7),
        sagas: {
          claveSaga('Harry Potter'): const InfoSaga(
            id: 1241,
            nombre: 'Harry Potter',
            partes: [
              (titulo: 'Harry Potter y la piedra filosofal', anio: 2001),
              (titulo: 'Harry Potter y la cámara secreta', anio: 2002),
              (titulo: 'Harry Potter y el prisionero de Azkaban', anio: 2004),
              (titulo: 'Harry Potter y el cáliz de fuego', anio: 2005),
            ],
          ),
          claveSaga('Rocky'): const InfoSaga(
            id: 1575,
            nombre: 'Rocky',
            partes: [
              (titulo: 'Rocky', anio: 1976),
              (titulo: 'Rocky II', anio: 1979),
              (titulo: 'Rocky III', anio: 1982),
            ],
          ),
        },
      );
      final e = Estadisticas.de(lista, tmdb: tmdb);
      expect(e.sagasCompletas, 0);
      // Primero la que tiene menos que faltan.
      expect(e.sagasIncompletas.map((s) => s.nombre), [
        'Rocky',
        'Harry Potter',
      ]);
      final rocky = e.sagasIncompletas.first;
      expect((rocky.tengo, rocky.total), (2, 3));
      expect(rocky.faltan, ['Rocky III (1982)']);
      expect(rocky.segunTmdb, isTrue);
      expect(e.sagasIncompletas.last.faltan, [
        'Harry Potter y la cámara secreta (2002)',
        'Harry Potter y el cáliz de fuego (2005)',
      ]);
    });

    test('con un año mal escrito se reconoce por su número', () {
      // «Licencia para matar» es de 1989, pero la ficha dice 1985 (el año
      // de «Panorama para matar»).
      final bond = [
        _p(1, 'Panorama para matar', 1985, saga: 'James Bond', numero: 1),
        _p(2, 'Alta tensión', 1987, saga: 'James Bond', numero: 2),
        _p(3, 'Licencia para matar', 1985, saga: 'James Bond', numero: 3),
        _p(4, 'Goldeneye', 1995, saga: 'James Bond'), // sin número
      ];
      final tmdb = SagasTmdb(
        fecha: DateTime(2026),
        sagas: {
          'james bond': const InfoSaga(
            id: 645,
            nombre: 'James Bond',
            partes: [
              (titulo: 'Panorama para matar', anio: 1985),
              (titulo: 'Alta tensión', anio: 1987),
              (titulo: 'Licencia para matar', anio: 1989),
              (titulo: 'Goldeneye', anio: 1995),
              (titulo: 'El mañana nunca muere', anio: 1997),
            ],
          ),
        },
      );
      final saga = Estadisticas.de(bond, tmdb: tmdb).sagasIncompletas.single;
      expect((saga.tengo, saga.total), (4, 5));
      expect(saga.faltan, ['El mañana nunca muere (1997)']);
    });

    test('TMDB no se usa si sus números no cuadran con los tuyos', () {
      final tmdb = SagasTmdb(
        fecha: DateTime(2026),
        sagas: {
          claveSaga('Harry Potter'): const InfoSaga(
            id: 1,
            nombre: 'Harry Potter',
            partes: [(titulo: 'Otra', anio: 2001), (titulo: 'Más', anio: 2002)],
          ),
        },
      );
      final hp = Estadisticas.de(lista, tmdb: tmdb).sagasIncompletas.single;
      expect(hp.segunTmdb, isFalse);
      expect(hp.faltan, ['Nº 2']);
    });

    test('lo comprobado en TMDB se guarda y se vuelve a leer igual', () {
      final datos = SagasTmdb(
        fecha: DateTime(2026, 10, 7, 12),
        sagas: {
          'rocky': const InfoSaga(
            id: 1575,
            nombre: 'Rocky',
            partes: [(titulo: 'Rocky', anio: 1976)],
          ),
          'doraemon': null,
        },
      );
      final leidos = SagasTmdb.deJson(datos.aJson());
      expect(leidos.fecha, datos.fecha);
      expect(leidos.sagas.keys, ['rocky', 'doraemon']);
      expect(leidos.sagas['rocky']!.partes.single, (
        titulo: 'Rocky',
        anio: 1976,
      ));
      expect(leidos.sagas['doraemon'], isNull);
    });

    test('nombres de saga equivalentes', () {
      expect(claveSaga('Harry Potter - Colección'), claveSaga('harry potter'));
      expect(claveSaga('Colección Toy Story'), 'toy story');
    });
  });

  group('Excel', () {
    test('un .xlsx con una fila por película, textos escapados y enlaces', () {
      final bytes = crearExcel([
        Pelicula(
          id: 1,
          titulo: 'Tom & Jerry <2>',
          anio: 2021,
          ruta: r'D:\Animación\Animación\Tom & Jerry (2021).mp4',
          sinopsis: 'Con "comillas"\u0001 y control',
          enlaceFilmaffinity: 'https://www.filmaffinity.com/es/film1.html',
          tamanoBytes: 3 << 30,
        ),
        _p(2, 'Star Wars꞉ Episodio IV', 1977),
      ]);
      final zip = ZipDecoder().decodeBytes(bytes);
      String leer(String nombre) =>
          utf8.decode(zip.findFile(nombre)!.readBytes()!);
      for (final parte in [
        '[Content_Types].xml',
        '_rels/.rels',
        'xl/workbook.xml',
        'xl/_rels/workbook.xml.rels',
        'xl/styles.xml',
      ]) {
        expect(zip.findFile(parte), isNotNull, reason: parte);
      }
      final hoja = leer('xl/worksheets/sheet1.xml');
      expect(hoja, contains('<row r="3">'));
      expect(hoja, isNot(contains('<row r="4">')));
      expect(hoja, contains('Tom &amp; Jerry &lt;2&gt;'));
      expect(hoja, contains('Con &quot;comillas&quot; y control'));
      expect(hoja, contains('Star Wars꞉ Episodio IV'));
      expect(hoja, contains('<v>2021</v>'));
      expect(hoja, contains('<v>3.0</v>')); // GB
      expect(
        hoja,
        contains(
          'HYPERLINK(&quot;https://www.filmaffinity.com/es/film1.html&quot;,'
          '&quot;FilmAffinity&quot;)',
        ),
      );
      expect(hoja, contains('<autoFilter ref="A1:Z3"/>'));
      expect(leer('xl/workbook.xml'), contains('name="Películas"'));
    });
  });

  group('Copia de seguridad', () {
    late Directory temporal;
    setUp(() => temporal = Directory.systemTemp.createTempSync('copia'));
    tearDown(() => temporal.deleteSync(recursive: true));

    Future<BaseDatos> base(CarpetasApp carpetas, String titulo) async {
      final bd = BaseDatos.abrir(carpetas.baseDatos);
      await bd.guardarPelicula(
        PeliculasCompanion.insert(
          id: const Value(7),
          ruta: 'D:\\Drama\\Drama\\$titulo (2000).mp4',
          titulo: titulo,
          anio: const Value(2000),
          anadida: DateTime(2020),
          modificado: DateTime(2020),
          escaneada: DateTime(2020),
        ),
      );
      return bd;
    }

    test(
      'se hace sin claves y se restaura conservando las de este PC',
      () async {
        // El PC de antes, con su copia.
        final antes = CarpetasApp.preparar('${temporal.path}\\antes');
        final bdAntes = await base(antes, 'Original');
        await bdAntes.guardarAjuste('claveTmdb', 'secreta');
        await bdAntes.guardarAjuste('vistaCatalogo', 'lista');
        await bdAntes.guardarAjuste('versionTablon', '3');
        File(antes.miniatura(7)).writeAsBytesSync([1, 2, 3]);
        File(antes.copiaCaratula(1, antes: true)).writeAsBytesSync([4, 5]);
        final zip = '${temporal.path}\\copia.zip';
        final info = await crearCopia(
          carpetas: antes,
          destino: zip,
          copiarBase: bdAntes.copiarA,
        );
        await bdAntes.close();
        expect(info.peliculas, 1);
        expect(info.versionBase, 5);
        expect(
          File('${antes.raiz}\\copia-temporal.sqlite').existsSync(),
          isFalse,
        );

        // Las claves no van dentro.
        final dentro = ZipDecoder().decodeBytes(File(zip).readAsBytesSync());
        expect(
          dentro.files.map((f) => f.name),
          containsAll([
            'videoteca.sqlite',
            'videoteca-copia.json',
            'miniaturas/7.jpg',
            'copias/1-antes.img',
          ]),
        );
        final sinClaves = File('${temporal.path}\\sin-claves.sqlite')
          ..writeAsBytesSync(dentro.findFile('videoteca.sqlite')!.readBytes()!);
        final bdCopia = BaseDatos.abrir(sinClaves.path);
        final ajustesCopia = await bdCopia.todosLosAjustes();
        await bdCopia.close();
        expect(ajustesCopia.containsKey('claveTmdb'), isFalse);
        expect(ajustesCopia['vistaCatalogo'], 'lista');

        // Una copia de una versión más nueva de la app no se acepta.
        await expectLater(
          leerCopia(zip, versionBase: 4),
          throwsA(isA<CopiaException>()),
        );
        await expectLater(
          leerCopia(sinClaves.path, versionBase: 5),
          throwsA(isA<CopiaException>()),
        );
        expect((await leerCopia(zip, versionBase: 5)).peliculas, 1);

        // El PC nuevo, con otra película y su propia clave.
        final nuevo = CarpetasApp.preparar('${temporal.path}\\nuevo');
        final bdNuevo = await base(nuevo, 'Otra');
        await bdNuevo.guardarAjuste('claveTmdb', 'la-nueva');
        await bdNuevo.guardarAjuste('versionTablon', '9');
        File(nuevo.miniatura(99)).writeAsBytesSync([9]);
        await bdNuevo.close();
        await restaurarCopia(
          zip,
          nuevo,
          conservar: {'claveTmdb': 'la-nueva', 'versionTablon': '9'},
        );

        final bd = BaseDatos.abrir(nuevo.baseDatos);
        final peliculas = await bd.todasLasPeliculas();
        final ajustes = await bd.todosLosAjustes();
        await bd.close();
        expect(peliculas.single.titulo, 'Original');
        expect(ajustes['claveTmdb'], 'la-nueva');
        expect(ajustes['versionTablon'], '9');
        expect(ajustes['vistaCatalogo'], 'lista');
        expect(File(nuevo.miniatura(7)).readAsBytesSync(), [1, 2, 3]);
        expect(File(nuevo.miniatura(99)).existsSync(), isFalse);
        expect(File(nuevo.copiaCaratula(1, antes: true)).existsSync(), isTrue);
        expect(
          File('${nuevo.raiz}\\videoteca-antes-de-restaurar.sqlite')
              .existsSync(),
          isTrue,
        );
        expect(Directory('${nuevo.raiz}\\restaurando').existsSync(), isFalse);
      },
    );
  });
}
