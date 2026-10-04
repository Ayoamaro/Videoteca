import 'package:http/http.dart' as http;

import 'conexion.dart';

// OMDb (https://www.omdbapi.com): de aquí sale la nota de Rotten Tomatoes,
// buscando por el código de IMDb. La clave gratuita permite 1.000 consultas
// al día.
//
// No usa nada de Flutter.

class Omdb {
  Omdb(this.clave, {http.Client? cliente})
    : _cliente = cliente ?? http.Client();

  final String clave;
  final http.Client _cliente;

  static const _servicio = 'OMDb';

  Future<Map<String, dynamic>> _pedir(String imdb) async {
    if (clave.trim().isEmpty) {
      throw FuenteException(_servicio, 'Falta la clave.', claveMala: true);
    }
    final json = await pedirJson(
      _cliente,
      _servicio,
      Uri.https('www.omdbapi.com', '/', {'i': imdb, 'apikey': clave.trim()}),
      interpretar: (codigo, json) {
        final error = json is Map ? (json['Error'] as String?) ?? '' : '';
        if (error.contains('limit')) {
          return FuenteException(
            _servicio,
            'Se ha llegado al máximo de consultas de hoy (1.000 con la clave '
            'gratuita). Mañana se puede seguir.',
            limite: true,
          );
        }
        if (codigo == 401 || error.contains('API key')) {
          return FuenteException(
            _servicio,
            error.contains('activated') || error.contains('activate')
                ? 'La clave aún no está activada: pulsa el enlace del correo '
                      'de OMDb.'
                : 'La clave no es válida.',
            claveMala: true,
          );
        }
        return null;
      },
    );
    return json as Map<String, dynamic>;
  }

  /// Comprueba que la clave funciona. Lanza [FuenteException] si no.
  Future<void> probar() => _pedir('tt0111161');

  /// Nota de Rotten Tomatoes (0–100) de la película con código de IMDb
  /// [imdb], o `null` si no tiene.
  Future<int?> rottenTomatoes(String imdb) async {
    final json = await _pedir(imdb);
    if (json['Response'] != 'True') return null;
    for (final nota in (json['Ratings'] as List?) ?? const []) {
      if (nota['Source'] == 'Rotten Tomatoes') {
        return int.tryParse((nota['Value'] as String).replaceAll('%', ''));
      }
    }
    return null;
  }
}
