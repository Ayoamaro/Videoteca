import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../fuentes/conexion.dart' show agenteVideoteca;

// Hablar con GitHub para publicar el tablón (API REST, con la llave de
// acceso del administrador). Solo se usan los «datos de Git» (archivos,
// árboles y commits), que permiten subir solo lo que ha cambiado y cambiarlo
// todo de golpe en un solo commit: el móvil nunca ve medio tablón.
//
// No usa nada de Flutter.

/// Algo ha fallado al hablar con GitHub. [mensaje] se puede enseñar tal cual.
class TablonException implements Exception {
  TablonException(
    this.mensaje, {
    this.llaveMala = false,
    this.sinInternet = false,
  });

  final String mensaje;

  /// La llave de acceso no vale, ha caducado o no tiene permiso.
  final bool llaveMala;
  final bool sinInternet;

  @override
  String toString() => mensaje;
}

/// Lo que importa del repositorio del tablón.
typedef InfoRepositorio = ({String nombre, bool privado, String rama});

/// Un archivo del repositorio (de `GitHub.arbol`).
typedef ArchivoRemoto = ({String huella, int tamano});

class GitHub {
  GitHub(this.repositorio, this.llave, {http.Client? cliente})
    : _cliente = cliente ?? http.Client();

  /// «usuario/nombre».
  final String repositorio;
  final String llave;
  final http.Client _cliente;

  /// Peticiones que crean algo (GitHub pide no pasar de ~80 por minuto).
  final _creaciones = <DateTime>[];

  /// ¿Es un nombre de repositorio válido («usuario/nombre»)?
  static bool nombreValido(String texto) =>
      RegExp(r'^[A-Za-z0-9-]+/[A-Za-z0-9._-]+$').hasMatch(texto);

  void cerrar() => _cliente.close();

  /// Comprueba que el repositorio existe y que la llave llega a él.
  Future<InfoRepositorio> info() async {
    final json = await _pedir('GET', '') as Map<String, dynamic>;
    final permisos = json['permissions'] as Map<String, dynamic>?;
    if (permisos != null && permisos['push'] == false) {
      throw TablonException(
        'La llave puede ver el repositorio pero no escribir en él. Al crearla, '
        'en «Contents» hay que elegir «Read and write».',
        llaveMala: true,
      );
    }
    return (
      nombre: json['full_name'] as String,
      privado: json['private'] as bool,
      rama: json['default_branch'] as String,
    );
  }

  /// El último commit de [rama], o `null` si el repositorio está vacío.
  Future<String?> ultimoCommit(String rama) async {
    try {
      final json =
          await _pedir('GET', '/git/ref/heads/$rama') as Map<String, dynamic>;
      return (json['object'] as Map<String, dynamic>)['sha'] as String;
    } on _NoEncontrado {
      return null;
    }
  }

  /// Todos los archivos del commit [commit] (ruta → huella y tamaño).
  Future<Map<String, ArchivoRemoto>> arbol(String commit) async {
    final c =
        await _pedir('GET', '/git/commits/$commit') as Map<String, dynamic>;
    final arbol = (c['tree'] as Map<String, dynamic>)['sha'] as String;
    final json = await _pedir(
      'GET',
      '/git/trees/$arbol?recursive=1',
    ) as Map<String, dynamic>;
    return {
      for (final e in json['tree'] as List)
        if ((e as Map<String, dynamic>)['type'] == 'blob')
          e['path'] as String: (
            huella: e['sha'] as String,
            tamano: e['size'] as int? ?? 0,
          ),
    };
  }

  /// El contenido del archivo con huella [huella].
  Future<Uint8List> descargar(String huella) async {
    final json =
        await _pedir('GET', '/git/blobs/$huella') as Map<String, dynamic>;
    return base64.decode((json['content'] as String).replaceAll('\n', ''));
  }

  /// Un repositorio recién creado está vacío y la API de Git no deja
  /// trabajar en él: se crea el primer archivo con la otra API.
  Future<void> iniciar(String ruta, Uint8List contenido) async {
    await _pedir('PUT', '/contents/$ruta', {
      'message': 'Tablón de Videoteca',
      'content': base64.encode(contenido),
    });
  }

  /// Sube un archivo y devuelve su huella.
  Future<String> subir(Uint8List contenido) async {
    await _esperarTurno();
    final json = await _pedir('POST', '/git/blobs', {
      'content': base64.encode(contenido),
      'encoding': 'base64',
    }) as Map<String, dynamic>;
    return json['sha'] as String;
  }

  /// Publica un commit con exactamente estos [archivos] (ruta → huella, ya
  /// subidos) y deja [rama] apuntando a él. El commit no lleva historia
  /// detrás: así el repositorio no crece con cada versión.
  Future<String> publicar(
    String rama,
    Map<String, String> archivos,
    String mensaje, {
    required bool ramaExiste,
  }) async {
    await _esperarTurno();
    final arbol = await _pedir('POST', '/git/trees', {
      'tree': [
        for (final MapEntry(key: ruta, value: huella) in archivos.entries)
          {'path': ruta, 'mode': '100644', 'type': 'blob', 'sha': huella},
      ],
    }) as Map<String, dynamic>;
    await _esperarTurno();
    final commit = await _pedir('POST', '/git/commits', {
      'message': mensaje,
      'tree': arbol['sha'],
      'parents': <String>[],
    }) as Map<String, dynamic>;
    final sha = commit['sha'] as String;
    await _esperarTurno();
    if (ramaExiste) {
      await _pedir('PATCH', '/git/refs/heads/$rama', {
        'sha': sha,
        'force': true,
      });
    } else {
      await _pedir('POST', '/git/refs', {
        'ref': 'refs/heads/$rama',
        'sha': sha,
      });
    }
    return sha;
  }

  /// Espera si en el último minuto ya se han hecho muchas peticiones que
  /// crean cosas (GitHub las frena si pasan de ~80 por minuto).
  Future<void> _esperarTurno() async {
    const maximo = 70;
    final ahora = DateTime.now();
    _creaciones.removeWhere(
      (t) => ahora.difference(t) > const Duration(minutes: 1),
    );
    if (_creaciones.length >= maximo) {
      final espera =
          const Duration(minutes: 1) - ahora.difference(_creaciones.first);
      await Future<void>.delayed(espera + const Duration(milliseconds: 200));
      _creaciones.removeAt(0);
    }
    _creaciones.add(DateTime.now());
  }

  Future<Object?> _pedir(String metodo, String camino, [Object? cuerpo]) async {
    final direccion = Uri.parse(
      'https://api.github.com/repos/$repositorio$camino',
    );
    for (var intento = 1; ; intento++) {
      final http.Response r;
      try {
        final peticion = http.Request(metodo, direccion)
          ..headers.addAll({
            'Authorization': 'Bearer $llave',
            'Accept': 'application/vnd.github+json',
            'X-GitHub-Api-Version': '2022-11-28',
            'User-Agent': agenteVideoteca,
          });
        if (cuerpo != null) {
          peticion
            ..headers['Content-Type'] = 'application/json'
            ..bodyBytes = utf8.encode(jsonEncode(cuerpo));
        }
        r = await http.Response.fromStream(
          await _cliente.send(peticion).timeout(const Duration(seconds: 60)),
        ).timeout(const Duration(minutes: 2));
      } on TimeoutException {
        throw TablonException('GitHub no contesta.', sinInternet: true);
      } on SocketException {
        throw TablonException('Sin conexión a internet.', sinInternet: true);
      } on http.ClientException {
        throw TablonException('Sin conexión a internet.', sinInternet: true);
      }
      final codigo = r.statusCode;
      Object? json;
      try {
        json = r.body.isEmpty ? null : jsonDecode(r.body);
      } on FormatException {
        json = null;
      }
      final mensaje = json is Map ? '${json['message'] ?? ''}' : '';

      // GitHub pide calma: se espera lo que diga (como mucho 1 minuto) y se
      // vuelve a intentar.
      final limite =
          codigo == 429 ||
          (codigo == 403 &&
              (r.headers['retry-after'] != null ||
                  r.headers['x-ratelimit-remaining'] == '0' ||
                  mensaje.contains('rate limit')));
      if (limite && intento < 4) {
        final segundos = int.tryParse(r.headers['retry-after'] ?? '') ?? 60;
        await Future<void>.delayed(Duration(seconds: segundos.clamp(5, 60)));
        continue;
      }
      // Fallos pasajeros del servidor.
      if (codigo >= 500 && intento < 3) {
        await Future<void>.delayed(Duration(seconds: 3 * intento));
        continue;
      }
      if (codigo >= 200 && codigo < 300) return json;
      if (codigo == 401) {
        throw TablonException(
          'GitHub no acepta la llave de acceso (¿caducada o mal copiada?).',
          llaveMala: true,
        );
      }
      if (codigo == 404 && camino.isEmpty) {
        throw TablonException(
          'No se encuentra el repositorio «$repositorio», o la llave no '
          'tiene acceso a él.',
          llaveMala: true,
        );
      }
      if (codigo == 403) {
        throw TablonException(
          'La llave no tiene permiso para escribir en «$repositorio» '
          '(«Contents: Read and write»).',
          llaveMala: true,
        );
      }
      // Ref que no existe, o repositorio vacío.
      if (metodo == 'GET' && (codigo == 404 || codigo == 409)) {
        throw _NoEncontrado();
      }
      throw TablonException(
        'GitHub ha contestado con un error ($codigo${mensaje.isEmpty ? '' : ': $mensaje'}).',
      );
    }
  }
}

class _NoEncontrado implements Exception {}
