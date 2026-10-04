import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as img;
import 'package:videoteca/datos/base_datos.dart';
import 'package:videoteca/datos/carpetas_app.dart';
import 'package:videoteca/tablon/cifrado.dart';
import 'package:videoteca/tablon/formato.dart';
import 'package:videoteca/tablon/github.dart';
import 'package:videoteca/tablon/lector.dart';
import 'package:videoteca/tablon/publicador.dart';

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

    Future<ResultadoPublicacion> publicar() async => publicarTablon(
      github: GitHub('yo/tablon', 'llave', cliente: falso.cliente),
      llave: llave,
      parametros: parametros,
      filas: await bd.todasLasPeliculas(),
      raiz: 'D:\\',
      carpetas: carpetas,
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

/// GitHub de mentira, en memoria: lo justo para publicar y leer.
class GitHubFalso {
  final blobs = <String, Uint8List>{};
  final arboles = <String, Map<String, String>>{};
  final commitsArbol = <String, String>{};
  String? rama;
  int subidas = 0;
  int commits = 0;
  bool sinPermiso = false;

  /// Archivos del último commit (ruta → huella).
  Map<String, String> get archivos => arboles[commitsArbol[rama]]!;

  late final cliente = MockClient((peticion) async {
    final url = peticion.url;
    final camino = url.path;
    Object? cuerpo = peticion.body.isEmpty ? null : jsonDecode(peticion.body);
    http.Response json(Object? valor, [int codigo = 200]) =>
        http.Response(jsonEncode(valor), codigo);

    if (url.host == 'raw.githubusercontent.com') {
      final partes = camino.split('/').skip(3).toList();
      final commit = partes.first;
      final ruta = partes.skip(1).join('/');
      final huella = arboles[commitsArbol[commit]]?[ruta];
      return huella == null
          ? http.Response('', 404)
          : http.Response.bytes(blobs[huella]!, 200);
    }
    final base = '/repos/yo/tablon';
    if (!camino.startsWith(base)) return json({'message': 'Not Found'}, 404);
    final resto = camino.substring(base.length);
    final metodo = peticion.method;

    if (metodo == 'GET' && resto == '') {
      return json({
        'full_name': 'yo/tablon',
        'private': false,
        'default_branch': 'main',
        'permissions': {'push': !sinPermiso},
      });
    }
    if (metodo == 'GET' && resto == '/commits/HEAD') {
      return http.Response(rama ?? '', rama == null ? 409 : 200);
    }
    if (metodo == 'GET' && resto == '/git/ref/heads/main') {
      return rama == null
          ? json({'message': 'Git Repository is empty.'}, 409)
          : json({
              'object': {'sha': rama},
            });
    }
    if (metodo == 'PUT' && resto.startsWith('/contents/')) {
      final datos = base64.decode((cuerpo as Map)['content'] as String);
      final huella = guardar(datos);
      rama = nuevoCommit({resto.substring('/contents/'.length): huella});
      return json({}, 201);
    }
    if (metodo == 'GET' && resto.startsWith('/git/commits/')) {
      final sha = resto.split('/').last;
      return json({
        'tree': {'sha': commitsArbol[sha]},
      });
    }
    if (metodo == 'GET' && resto.startsWith('/git/trees/')) {
      final sha = resto.split('/').last;
      return json({
        'tree': [
          for (final MapEntry(:key, :value) in arboles[sha]!.entries)
            {
              'path': key,
              'type': 'blob',
              'sha': value,
              'size': blobs[value]!.length,
            },
        ],
      });
    }
    if (metodo == 'GET' && resto.startsWith('/git/blobs/')) {
      final sha = resto.split('/').last;
      return json({
        'content': base64.encode(blobs[sha]!),
        'encoding': 'base64',
      });
    }
    if (metodo == 'POST' && resto == '/git/blobs') {
      if (sinPermiso) return json({'message': 'Forbidden'}, 403);
      subidas++;
      final datos = base64.decode((cuerpo as Map)['content'] as String);
      return json({'sha': guardar(datos)}, 201);
    }
    if (metodo == 'POST' && resto == '/git/trees') {
      final arbol = {
        for (final e in (cuerpo as Map)['tree'] as List)
          (e as Map)['path'] as String: e['sha'] as String,
      };
      for (final h in arbol.values) {
        if (!blobs.containsKey(h)) return json({'message': 'falta'}, 422);
      }
      final sha = 'arbol${arboles.length}';
      arboles[sha] = arbol;
      return json({'sha': sha}, 201);
    }
    if (metodo == 'POST' && resto == '/git/commits') {
      final sha = 'commit${commitsArbol.length}';
      commitsArbol[sha] = (cuerpo as Map)['tree'] as String;
      commits++;
      return json({'sha': sha}, 201);
    }
    if (metodo == 'PATCH' && resto == '/git/refs/heads/main') {
      rama = (cuerpo as Map)['sha'] as String;
      return json({});
    }
    return json({'message': 'No esperado: $metodo $resto'}, 500);
  });

  String guardar(Uint8List datos) {
    final huella = crypto.sha1.convert([
      ...utf8.encode('blob ${datos.length}\u0000'),
      ...datos,
    ]).toString();
    blobs[huella] = datos;
    return huella;
  }

  String nuevoCommit(Map<String, String> arbol) {
    final a = 'arbol${arboles.length}';
    arboles[a] = arbol;
    final c = 'commit${commitsArbol.length}';
    commitsArbol[c] = a;
    return c;
  }
}
