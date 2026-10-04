import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../fuentes/conexion.dart' show agenteVideoteca;
import 'cifrado.dart';
import 'formato.dart';
import 'github.dart' show TablonException;

// Leer el tablón como lo hará el móvil: sin llave de GitHub (el repositorio
// es público; lo que hay dentro está cifrado), con la contraseña común.
//
// Se pide primero el último commit y después los archivos *de ese commit*:
// así nunca se mezclan archivos de dos versiones, y la copia de GitHub en
// caché (que tarda unos minutos en refrescarse) no molesta.
//
// No usa nada de Flutter.

class LectorTablon {
  LectorTablon(this.repositorio, {http.Client? cliente})
    : _cliente = cliente ?? http.Client();

  /// «usuario/nombre».
  final String repositorio;
  final http.Client _cliente;

  void cerrar() => _cliente.close();

  /// El último commit publicado.
  Future<String> ultimoCommit() async {
    final r = await _pedir(
      Uri.parse('https://api.github.com/repos/$repositorio/commits/HEAD'),
      {'Accept': 'application/vnd.github.sha'},
    );
    return utf8.decode(r).trim();
  }

  /// Un archivo del commit [commit].
  Future<Uint8List> archivo(String commit, String ruta) => _pedir(
    Uri.parse('https://raw.githubusercontent.com/$repositorio/$commit/$ruta'),
  );

  /// Los parámetros para sacar la llave de la contraseña.
  Future<ParametrosLlave> parametros(String commit) async {
    final json = jsonDecode(
      utf8.decode(await archivo(commit, rutaDescripcion)),
    ) as Map<String, dynamic>;
    if ((json['formato'] as int) > formatoTablon) {
      throw TablonException(
        'El tablón es de una versión más nueva de la app: hay que actualizarla.',
      );
    }
    return ParametrosLlave.desdeJson(json['llave'] as Map<String, dynamic>);
  }

  /// El índice. Lanza [ContrasenaIncorrecta] si la llave no es la buena.
  Future<IndiceTablon> indice(String commit, LlaveTablon llave) async =>
      IndiceTablon.desdeBytes(
        llave.descifrar(rutaIndice, await archivo(commit, rutaIndice)),
      );

  /// Las fichas de un grupo del catálogo.
  Future<List<Map<String, dynamic>>> catalogo(
    String commit,
    String grupo,
    LlaveTablon llave,
  ) async {
    final ruta = rutaCatalogo(grupo);
    return leerPaqueteCatalogo(
      llave.descifrar(ruta, await archivo(commit, ruta)),
    );
  }

  /// Las carátulas de un grupo (número de película → WebP).
  Future<Map<int, Uint8List>> caratulas(
    String commit,
    String grupo,
    LlaveTablon llave,
  ) async {
    final ruta = rutaCaratulas(grupo);
    return leerPaqueteCaratulas(
      llave.descifrar(ruta, await archivo(commit, ruta)),
    );
  }

  Future<Uint8List> _pedir(Uri direccion, [Map<String, String>? extra]) async {
    final http.Response r;
    try {
      r = await _cliente
          .get(direccion, headers: {'User-Agent': agenteVideoteca, ...?extra})
          .timeout(const Duration(seconds: 60));
    } on TimeoutException {
      throw TablonException('GitHub no contesta.', sinInternet: true);
    } on SocketException {
      throw TablonException('Sin conexión a internet.', sinInternet: true);
    } on http.ClientException {
      throw TablonException('Sin conexión a internet.', sinInternet: true);
    }
    if (r.statusCode == 404) {
      throw TablonException(
        'No se encuentra el tablón «$repositorio» (¿es privado o está vacío?).',
      );
    }
    if (r.statusCode != 200) {
      throw TablonException(
        'GitHub ha contestado con un error (${r.statusCode}).',
      );
    }
    return r.bodyBytes;
  }
}
