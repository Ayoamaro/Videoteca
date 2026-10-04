import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

// Lo común a los servicios de internet (TMDB, OMDb, Wikidata): pedir una
// dirección, esperar como mucho unos segundos, reintentar si el servicio
// pide calma y convertir los fallos en mensajes claros.
//
// No usa nada de Flutter.

/// Un servicio de datos ha fallado. [mensaje] se puede enseñar tal cual.
class FuenteException implements Exception {
  FuenteException(
    this.servicio,
    this.mensaje, {
    this.claveMala = false,
    this.sinInternet = false,
    this.limite = false,
  });

  /// «TMDB», «OMDb» o «Wikidata».
  final String servicio;
  final String mensaje;

  /// La clave no es válida (o falta, o no está activada).
  final bool claveMala;
  final bool sinInternet;

  /// Se ha llegado al máximo de consultas del día.
  final bool limite;

  @override
  String toString() => '$servicio: $mensaje';
}

/// Identificación de la app ante los servicios (Wikidata la exige). Solo
/// puede llevar letras sin tildes: con una tilde, la petición ni sale.
const agenteVideoteca =
    'Videoteca/0.2 (catalogo personal de peliculas; '
    'https://github.com/Ayoamaro/Videoteca)';

/// Pide [direccion] y devuelve su JSON. Si la respuesta es 429 («demasiadas
/// peticiones») espera un poco y vuelve a intentarlo. [interpretar] decide
/// qué hacer con los códigos de error propios de cada servicio.
Future<Object?> pedirJson(
  http.Client cliente,
  String servicio,
  Uri direccion, {
  Map<String, String> cabeceras = const {},
  Duration espera = const Duration(seconds: 20),
  FuenteException? Function(int codigo, Object? json)? interpretar,
}) async {
  for (var intento = 1; ; intento++) {
    final http.Response respuesta;
    try {
      respuesta = await cliente
          .get(
            direccion,
            headers: {'User-Agent': agenteVideoteca, ...cabeceras},
          )
          .timeout(espera);
    } on TimeoutException {
      throw FuenteException(
        servicio,
        'No contesta (más de ${espera.inSeconds} s).',
        sinInternet: true,
      );
    } on SocketException {
      throw FuenteException(
        servicio,
        'Sin conexión a internet.',
        sinInternet: true,
      );
    } on http.ClientException {
      throw FuenteException(
        servicio,
        'Sin conexión a internet.',
        sinInternet: true,
      );
    }
    if (respuesta.statusCode == 429 && intento < 4) {
      final segundos =
          int.tryParse(respuesta.headers['retry-after'] ?? '') ?? intento;
      await Future<void>.delayed(Duration(seconds: segundos.clamp(1, 10)));
      continue;
    }
    Object? json;
    try {
      json = jsonDecode(utf8.decode(respuesta.bodyBytes));
    } on FormatException {
      json = null;
    }
    final error = interpretar?.call(respuesta.statusCode, json);
    if (error != null) throw error;
    if (respuesta.statusCode != 200 || json == null) {
      throw FuenteException(
        servicio,
        'Respuesta inesperada (código ${respuesta.statusCode}).',
      );
    }
    return json;
  }
}
