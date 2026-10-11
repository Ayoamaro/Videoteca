import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:videoteca/datos/base_datos.dart';
import 'package:videoteca/datos/carpetas_app.dart';
import 'package:videoteca/tablon/cifrado.dart';
import 'package:videoteca/tablon/formato.dart';
import 'package:videoteca/tablon/github.dart';
import 'package:videoteca/tablon/lector.dart';
import 'package:videoteca/tablon/publicador.dart';

import 'ayuda/github_falso.dart';

void main() {
  // Parámetros pequeños para que los tests vayan rápido.
  final parametros = ParametrosLlave(
    sal: Uint8List.fromList(List.filled(16, 7)),
    memoria: 64,
    iteraciones: 1,
  );

  group('Cifrado', () {
    test('cifra y descifra; el mismo contenido da los mismos bytes', () async {
      final llave = await derivarLlave('contraseña común', parametros);
      final datos = utf8.encode('Hola, ¿qué tal?' * 100);
      final a = llave.cifrar('catalogo/000.bin', datos);
      final b = llave.cifrar('catalogo/000.bin', datos);
      expect(a, b);
      expect(llave.descifrar('catalogo/000.bin', a), datos);
      // Otro contenido u otra ruta: bytes distintos.
      expect(llave.cifrar('catalogo/001.bin', datos), isNot(a));
      expect(llave.cifrar('catalogo/000.bin', [...datos, 1]), isNot(a));
      // No se ve el texto.
      expect(latin1.decode(a, allowInvalid: true), isNot(contains('Hola')));
    });

    test(
      'otra contraseña, otra ruta o un byte cambiado no se descifran',
      () async {
        final llave = await derivarLlave('buena', parametros);
        final otra = await derivarLlave('mala', parametros);
        final sobre = llave.cifrar('indice.bin', [1, 2, 3]);
        expect(
          () => otra.descifrar('indice.bin', sobre),
          throwsA(isA<ContrasenaIncorrecta>()),
        );
        expect(
          () => llave.descifrar('catalogo/000.bin', sobre),
          throwsA(isA<ContrasenaIncorrecta>()),
        );
        final tocado = Uint8List.fromList(sobre)..[20] ^= 1;
        expect(
          () => llave.descifrar('indice.bin', tocado),
          throwsA(isA<ContrasenaIncorrecta>()),
        );
      },
    );

    test('la llave guardada como texto es la misma', () async {
      final llave = await derivarLlave('x', parametros);
      final copia = LlaveTablon.desdeTexto(llave.aTexto());
      expect(copia.huella, llave.huella);
      expect(copia.descifrar('a', llave.cifrar('a', [9])), [9]);
    });

    test('los parámetros van y vuelven por JSON', () {
      final p = ParametrosLlave.nuevos();
      final q = ParametrosLlave.desdeJson(
        jsonDecode(jsonEncode(p.toJson())) as Map<String, dynamic>,
      );
      expect(q.sal, p.sal);
      expect(q.memoria, 65536);
      expect(q.iteraciones, 3);
    });
  });

  group('Formato', () {
    test('huella de Git como la de `git hash-object`', () {
      // printf 'hola\n' | git hash-object --stdin
      expect(
        huellaGit(utf8.encode('hola\n')),
        '5c1b14949828006ed75a3e8858957f86a2f7e2eb',
      );
    });

    test('grupos de 100 películas', () {
      expect(grupoDe(5), '000');
      expect(grupoDe(99), '000');
      expect(grupoDe(100), '001');
      expect(grupoDe(5541), '055');
    });

    test('paquete de carátulas', () {
      final imagenes = {
        3: Uint8List.fromList([1, 2, 3]),
        1: Uint8List.fromList([4]),
        2: Uint8List(0),
      };
      final leidas = leerPaqueteCaratulas(paqueteCaratulas(imagenes));
      expect(leidas.keys, [1, 2, 3]);
      expect(leidas[3], [1, 2, 3]);
      expect(leidas[2], isEmpty);
    });

    test('índice', () {
      final indice = IndiceTablon(
        version: 4,
        fecha: DateTime.utc(2026, 10, 4, 12),
        peliculas: 2,
        catalogo: {'000': 'abc'},
        caratulas: {},
      );
      final leido = IndiceTablon.desdeBytes(indice.aBytes());
      expect(leido.version, 4);
      expect(leido.fecha, DateTime.utc(2026, 10, 4, 12));
      expect(leido.catalogo, {'000': 'abc'});
    });
  });

  group('Publicar', () {
    late Directory temporal;
    late CarpetasApp carpetas;
    late BaseDatos bd;
    late GitHubFalso falso;
    late LlaveTablon llave;

    setUp(() async {
      temporal = Directory.systemTemp.createTempSync('tablon');
      carpetas = CarpetasApp.preparar(temporal.path);
      bd = BaseDatos(NativeDatabase.memory());
      falso = GitHubFalso();
      llave = await derivarLlave('común', parametros);
      final jpeg = img.encodeJpg(img.Image(width: 240, height: 343));
      for (final (id, titulo) in [(1, 'Uno'), (2, 'Dos'), (150, 'Tres')]) {
        await bd.guardarPelicula(
          PeliculasCompanion.insert(
            id: Value(id),
            ruta: 'D:\\Drama\\Drama\\$titulo (2000).mp4',
            titulo: titulo,
            anio: const Value(2000),
            grupo: const Value('Drama'),
            generoCarpeta: const Value('Drama'),
            sinopsis: Value('Sinopsis de $titulo'),
            tieneMiniatura: Value(id != 2),
            anadida: DateTime(2020),
            modificado: DateTime(2020),
            escaneada: DateTime(2020),
          ),
        );
        if (id != 2) File(carpetas.miniatura(id)).writeAsBytesSync(jpeg);
      }
    });

    tearDown(() async {
      await bd.close();
      temporal.deleteSync(recursive: true);
    });

    Future<ResultadoPublicacion> publicar({String red = ''}) async =>
        publicarTablon(
          github: GitHub('yo/tablon', 'llave', cliente: falso.cliente),
          llave: llave,
          parametros: parametros,
          filas: await bd.todasLasPeliculas(),
          raiz: 'D:\\',
          carpetas: carpetas,
          red: red,
        );

    test(
      'la primera vez lo sube todo y se puede leer con la contraseña',
      () async {
        final r = await publicar();
        expect(r.version, 1);
        expect(r.peliculas, 3);
        expect(r.sinCambios, isFalse);
        expect(
          falso.archivos.keys,
          unorderedEquals([
            'README.md',
            'tablon.json',
            'indice.bin',
            'catalogo/000.bin',
            'catalogo/001.bin',
            'caratulas/000.bin',
            'caratulas/001.bin',
          ]),
        );

        // Leerlo como el móvil, sin llave de GitHub.
        final lector = LectorTablon('yo/tablon', cliente: falso.cliente);
        final commit = await lector.ultimoCommit();
        final p = await lector.parametros(commit);
        final llaveMovil = await derivarLlave('común', p);
        final indice = await lector.indice(commit, llaveMovil);
        expect(indice.version, 1);
        expect(indice.peliculas, 3);
        final fichas = await lector.catalogo(commit, '000', llaveMovil);
        expect(fichas.map((f) => f['titulo']), ['Uno', 'Dos']);
        expect(fichas.first['ruta'], r'Drama\Drama\Uno (2000).mp4');
        expect(fichas.first['caratula'], true);
        expect(fichas.last.containsKey('caratula'), isFalse);
        expect(fichas.first.containsKey('pais'), isFalse); // vacío: no va
        final caratulas = await lector.caratulas(commit, '000', llaveMovil);
        expect(caratulas.keys, [1]);
        expect(img.decodeWebP(caratulas[1]!)!.width, anchoMiniaturaTablon);

        // Con otra contraseña, nada.
        final mala = await derivarLlave('otra', p);
        expect(
          () => lector.indice(commit, mala),
          throwsA(isA<ContrasenaIncorrecta>()),
        );
      },
    );

    test('sin cambios no publica; con un cambio sube solo su grupo', () async {
      await publicar();
      final subidosAntes = falso.subidas;
      final otra = await publicar();
      expect(otra.sinCambios, isTrue);
      expect(otra.version, 1);
      expect(falso.subidas, subidosAntes);
      expect(falso.commits, 1);

      await (bd.update(bd.peliculas)..where((p) => p.id.equals(150))).write(
        const PeliculasCompanion(pais: Value('Francia')),
      );
      final r = await publicar();
      expect(r.version, 2);
      // El grupo 001 del catálogo y el índice; las carátulas no cambian.
      expect(r.subidos, 2);
      expect(falso.commits, 2);
    });

    test('la ruta de red va cifrada en el índice; cambiarla publica', () async {
      final lector = LectorTablon('yo/tablon', cliente: falso.cliente);
      Future<String> redPublicada() async =>
          (await lector.indice(await lector.ultimoCommit(), llave)).red;

      await publicar();
      expect(await redPublicada(), '');
      // Solo cambia la ruta: se publica una versión nueva con solo el índice.
      final r = await publicar(red: r'\\CASA-PC\Pelis\Películas');
      expect(r.sinCambios, isFalse);
      expect(r.version, 2);
      expect(r.subidos, 1);
      expect(await redPublicada(), r'\\CASA-PC\Pelis\Películas');
      // La misma ruta otra vez: nada que publicar.
      expect(
        (await publicar(red: r'\\CASA-PC\Pelis\Películas')).sinCambios,
        isTrue,
      );
      // Quitarla también se publica.
      expect((await publicar()).version, 3);
      expect(await redPublicada(), '');
    });

    test('un índice con la ruta de red se lee igual que uno sin ella', () {
      // Así lo leen las apps 1.0, que no conocen la ruta: el formato es el
      // mismo y lo demás no cambia.
      final indice = IndiceTablon(
        version: 7,
        fecha: DateTime.utc(2026, 10, 11),
        peliculas: 3,
        catalogo: const {'000': 'a'},
        caratulas: const {},
        red: r'\\CASA-PC\Pelis',
      );
      final json = jsonDecode(
        utf8.decode(gzip.decode(indice.aBytes())),
      ) as Map<String, dynamic>;
      expect(json['formato'], formatoTablon);
      expect(json['red'], r'\\CASA-PC\Pelis');
      final leido = IndiceTablon.desdeBytes(indice.aBytes());
      expect(
        (leido.version, leido.peliculas, leido.red),
        (7, 3, r'\\CASA-PC\Pelis'),
      );
      // Sin ruta, ni siquiera aparece.
      final sinRed = IndiceTablon(
        version: 1,
        fecha: DateTime.utc(2026),
        peliculas: 0,
        catalogo: const {},
        caratulas: const {},
      );
      expect(utf8.decode(gzip.decode(sinRed.aBytes())), isNot(contains('red')));
    });

    test('al quitar una película desaparece su grupo vacío', () async {
      await publicar();
      await bd.borrarPeliculas([150]);
      final r = await publicar();
      expect(r.version, 2);
      expect(falso.archivos.keys, isNot(contains('catalogo/001.bin')));
      expect(falso.archivos.keys, isNot(contains('caratulas/001.bin')));
    });

    test(
      'con otra contraseña se vuelve a cifrar todo y sigue la versión',
      () async {
        await publicar();
        llave = await derivarLlave('nueva', parametros);
        final r = await publicarTablon(
          github: GitHub('yo/tablon', 'llave', cliente: falso.cliente),
          llave: llave,
          parametros: parametros,
          filas: await bd.todasLasPeliculas(),
          raiz: 'D:\\',
          carpetas: carpetas,
          versionAnterior: 1,
        );
        expect(r.version, 2);
        expect(r.subidos, 5); // 2 + 2 paquetes y el índice
      },
    );

    test('una llave sin permiso da un mensaje claro', () async {
      falso.sinPermiso = true;
      expect(
        publicar,
        throwsA(
          isA<TablonException>().having((e) => e.llaveMala, 'llaveMala', true),
        ),
      );
    });
  });
}
