// GitHub de mentira para los tests del tablón.

import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// GitHub de mentira, en memoria: lo justo para publicar y leer.
class GitHubFalso {
  final blobs = <String, Uint8List>{};
  final arboles = <String, Map<String, String>>{};
  final commitsArbol = <String, String>{};
  String? rama;
  int subidas = 0;
  int commits = 0;
  bool sinPermiso = false;

  /// Archivos descargados de raw.githubusercontent.com (como el móvil).
  int descargas = 0;

  /// Si se pone, a partir de esa descarga falla la conexión.
  int? cortarTras;

  /// Archivos del último commit (ruta → huella).
  Map<String, String> get archivos => arboles[commitsArbol[rama]]!;

  late final cliente = MockClient((peticion) async {
    final url = peticion.url;
    final camino = url.path;
    Object? cuerpo = peticion.body.isEmpty ? null : jsonDecode(peticion.body);
    http.Response json(Object? valor, [int codigo = 200]) =>
        http.Response(jsonEncode(valor), codigo);

    if (url.host == 'raw.githubusercontent.com') {
      if (cortarTras != null && descargas >= cortarTras!) {
        throw http.ClientException('Sin conexión');
      }
      descargas++;
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
