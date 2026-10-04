import 'package:http/http.dart' as http;

import 'conexion.dart';

// Wikidata (https://www.wikidata.org): la enciclopedia de datos de Wikipedia.
// Guarda, para cada película, su código de IMDb (propiedad P345) y su número
// de FilmAffinity (P480), así que sirve de puente para conseguir el enlace a
// FilmAffinity sin entrar en FilmAffinity. No necesita clave.
//
// No usa nada de Flutter.

class Wikidata {
  Wikidata({http.Client? cliente}) : _cliente = cliente ?? http.Client();

  final http.Client _cliente;

  /// Número de FilmAffinity de la película con código de IMDb [imdb]
  /// (p. ej. «tt0111161» → «195768»), o `null` si Wikidata no lo tiene.
  Future<String?> idFilmaffinity(String imdb) async {
    if (!RegExp(r'^tt\d+$').hasMatch(imdb)) return null;
    final consulta =
        'SELECT ?fa WHERE { ?p wdt:P345 "$imdb"; wdt:P480 ?fa . } LIMIT 1';
    final json = await pedirJson(
      _cliente,
      'Wikidata',
      Uri.https('query.wikidata.org', '/sparql', {
        'query': consulta,
        'format': 'json',
      }),
      cabeceras: {'Accept': 'application/sparql-results+json'},
    );
    final filas = ((json as Map)['results']?['bindings'] as List?) ?? const [];
    if (filas.isEmpty) return null;
    final id = filas.first['fa']?['value'] as String?;
    return id != null && RegExp(r'^\d+$').hasMatch(id) ? id : null;
  }
}

/// Enlace a la ficha de FilmAffinity (en español) con ese número.
String enlaceFilmaffinity(String id) =>
    'https://www.filmaffinity.com/es/film$id.html';

/// Enlace a la ficha de IMDb con ese código.
String enlaceImdb(String imdb) => 'https://www.imdb.com/title/$imdb/';
