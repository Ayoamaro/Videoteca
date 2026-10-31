import 'package:http/http.dart' as http;

import 'conexion.dart';

// TMDB (The Movie Database, https://www.themoviedb.org): base de datos de
// películas gratuita con API. De aquí salen el país, el guion, la
// fotografía, la saga, la calificación por edades en España y el enlace a
// IMDb. Los textos se piden en español de España (`es-ES`).
//
// Hace falta una clave gratuita: vale la «Clave de la API» (32 caracteres)
// o el «Token de acceso de lectura» (empieza por `eyJ`).
//
// No usa nada de Flutter.

/// Una película que sale al buscar en TMDB (solo lo básico).
class CandidatoTmdb {
  const CandidatoTmdb({
    required this.id,
    required this.titulo,
    required this.tituloOriginal,
    required this.anio,
    this.cartel = '',
  });

  final int id;

  /// Título en España (si TMDB lo tiene; si no, el original).
  final String titulo;
  final String tituloOriginal;

  /// Año del estreno (0 si no se sabe).
  final int anio;

  /// Cartel de TMDB (ruta, p. ej. «/abc.jpg»; vacío si no tiene). Solo se
  /// enseña para reconocer la película al elegirla: nunca se pone como
  /// carátula.
  final String cartel;

  String get enlace => 'https://www.themoviedb.org/movie/$id';

  /// Dirección del cartel en pequeño (154 px de ancho), o `null`.
  String? get enlaceCartel =>
      cartel.isEmpty ? null : 'https://image.tmdb.org/t/p/w154$cartel';

  @override
  String toString() => '$titulo ($anio) [$id]';
}

/// Cuántos del reparto se traen de TMDB.
const maximoRepartoTmdb = 15;

/// La ficha completa de una película en TMDB.
class FichaTmdb extends CandidatoTmdb {
  const FichaTmdb({
    required super.id,
    required super.titulo,
    required super.tituloOriginal,
    required super.anio,
    super.cartel,
    this.otrosTitulos = const [],
    this.directores = const [],
    this.nombresDirectores = const [],
    this.guion = const [],
    this.fotografia = const [],
    this.sinopsis = '',
    this.reparto = const [],
    this.productoras = const [],
    this.musica = const [],
    this.paises = const [],
    this.saga = '',
    this.numeroSaga = 0,
    this.edadEspana = '',
    this.edadEeuu = '',
    this.imdb = '',
  });

  /// Títulos alternativos (de otros países, antiguos…), para identificarla.
  final List<String> otrosTitulos;
  final List<String> directores;

  /// Los nombres de los directores tal como los tiene TMDB (a veces en su
  /// alfabeto: 近藤喜文), para identificar la película.
  final List<String> nombresDirectores;
  final List<String> guion;
  final List<String> fotografia;

  /// La sinopsis en español de España (vacía si TMDB no la tiene).
  final String sinopsis;

  /// Los primeros del reparto, por orden de créditos (como mucho
  /// [maximoRepartoTmdb]).
  final List<String> reparto;
  final List<String> productoras;
  final List<String> musica;

  /// Países de origen, con su nombre en español («Estados Unidos»).
  final List<String> paises;

  /// Nombre de la saga, ya sin «- Colección» («Harry Potter»), y lugar de
  /// la película en ella por fecha de estreno (0 = no es de ninguna saga).
  final String saga;
  final int numeroSaga;

  /// Calificación por edades tal como la da TMDB: en España «TP», «7»,
  /// «12», «16», «18» o «X»; en EE. UU. «G», «PG», «PG-13», «R» o «NC-17».
  /// Vacío si no la tiene.
  final String edadEspana;
  final String edadEeuu;

  /// Código de IMDb, p. ej. «tt0111161».
  final String imdb;
}

class Tmdb {
  Tmdb(this.clave, {http.Client? cliente})
    : _cliente = cliente ?? http.Client();

  final String clave;
  final http.Client _cliente;

  static const _servicio = 'TMDB';
  static const _base = 'https://api.themoviedb.org/3';

  /// El token de lectura (largo) va en la cabecera; la clave corta, en la
  /// dirección.
  bool get _esToken => clave.startsWith('eyJ');

  Map<String, String>? _paises;

  Future<Map<String, dynamic>> _pedir(
    String ruta, [
    Map<String, String> parametros = const {},
  ]) async {
    if (clave.trim().isEmpty) {
      throw FuenteException(_servicio, 'Falta la clave.', claveMala: true);
    }
    final direccion = Uri.parse('$_base$ruta').replace(
      queryParameters: {
        'language': 'es-ES',
        ...parametros,
        if (!_esToken) 'api_key': clave.trim(),
      },
    );
    final json = await pedirJson(
      _cliente,
      _servicio,
      direccion,
      cabeceras: {
        'Accept': 'application/json',
        if (_esToken) 'Authorization': 'Bearer ${clave.trim()}',
      },
      interpretar: (codigo, json) => switch (codigo) {
        401 => FuenteException(
          _servicio,
          'La clave no es válida.',
          claveMala: true,
        ),
        404 => FuenteException(_servicio, 'No existe esa película.'),
        _ => null,
      },
    );
    return json as Map<String, dynamic>;
  }

  /// Comprueba que la clave funciona. Lanza [FuenteException] si no.
  Future<void> probar() => _pedir('/configuration');

  /// Busca películas por título. Con [anio], solo las de ese año.
  Future<List<CandidatoTmdb>> buscar(String titulo, {int? anio}) async {
    final json = await _pedir('/search/movie', {
      'query': titulo,
      'include_adult': 'false',
      if (anio != null && anio > 0) 'year': '$anio',
    });
    return [
      for (final r in json['results'] as List)
        CandidatoTmdb(
          id: r['id'] as int,
          titulo: (r['title'] as String?) ?? '',
          tituloOriginal: (r['original_title'] as String?) ?? '',
          anio: _anio(r['release_date']),
          cartel: (r['poster_path'] as String?) ?? '',
        ),
    ];
  }

  /// La ficha completa de la película [id] (créditos, fechas de estreno con
  /// las edades, títulos alternativos y saga).
  Future<FichaTmdb> ficha(int id) async {
    final json = await _pedir('/movie/$id', {
      'append_to_response': 'release_dates,alternative_titles',
    });
    // El equipo se pide en inglés: en español, TMDB escribe algunos nombres
    // en su alfabeto original (奥井敦 en vez de Atsushi Okui).
    final creditos = await _pedir('/movie/$id/credits', {'language': 'en-US'});
    final equipo = [
      for (final p in (creditos['crew'] as List?) ?? const [])
        (
          id: (p['id'] as int?) ?? 0,
          nombre: (p['name'] as String?)?.trim() ?? '',
          trabajo: (p['job'] as String?) ?? '',
        ),
    ];
    List<({int id, String nombre})> conTrabajo(Set<String> trabajos) {
      final vistos = <String>{};
      return [
        for (final p in equipo)
          if (trabajos.contains(p.trabajo) &&
              p.nombre.isNotEmpty &&
              vistos.add(p.nombre))
            (id: p.id, nombre: p.nombre),
      ];
    }

    // Los nombres escritos en otro alfabeto (近藤喜文) se cambian por como
    // se escriben en el nuestro (Yoshifumi Kondo), si TMDB lo sabe.
    Future<List<String>> latinos(List<({int id, String nombre})> personas) =>
        Future.wait([
          for (final p in personas)
            esLatino(p.nombre) || p.id == 0
                ? Future.value(p.nombre)
                : nombreLatino(p.id, p.nombre),
        ]);

    final directores = conTrabajo({'Director'});

    // Reparto: los primeros por orden de créditos (como FilmAffinity, que
    // no los pone todos).
    final actores = [
      for (final p in (creditos['cast'] as List?) ?? const [])
        (
          id: (p['id'] as int?) ?? 0,
          nombre: (p['name'] as String?)?.trim() ?? '',
          orden: (p['order'] as int?) ?? 999,
        ),
    ]..sort((a, b) => a.orden.compareTo(b.orden));
    final vistos = <String>{};
    final reparto = [
      for (final a in actores)
        if (a.nombre.isNotEmpty && vistos.add(a.nombre))
          (id: a.id, nombre: a.nombre),
    ].take(maximoRepartoTmdb).toList();

    // Música: quien compuso la banda sonora; si no consta, «Music».
    var musica = conTrabajo({'Original Music Composer'});
    if (musica.isEmpty) musica = conTrabajo({'Music', 'Composer'});

    // Guion: quienes escribieron el guion; si no consta ninguno, el
    // argumento.
    var guion = conTrabajo({'Screenplay', 'Writer', 'Script', 'Dialogue'});
    if (guion.isEmpty) guion = conTrabajo({'Story', 'Screenstory'});

    // Países: los «de origen» (los que da FilmAffinity); si no hay, los de
    // producción.
    final nombresPaises = await paises();
    var codigos = [
      for (final c in (json['origin_country'] as List?) ?? const [])
        c as String,
    ];
    if (codigos.isEmpty) {
      codigos = [
        for (final c in (json['production_countries'] as List?) ?? const [])
          c['iso_3166_1'] as String,
      ];
    }

    // Saga y lugar en ella.
    var saga = '';
    var numeroSaga = 0;
    final coleccion = json['belongs_to_collection'];
    if (coleccion is Map) {
      saga = limpiarNombreSaga((coleccion['name'] as String?) ?? '');
      numeroSaga = await _lugarEnSaga(coleccion['id'] as int, id);
    }

    final imdb = (json['imdb_id'] as String?) ?? '';
    return FichaTmdb(
      id: id,
      titulo: (json['title'] as String?) ?? '',
      tituloOriginal: (json['original_title'] as String?) ?? '',
      anio: _anio(json['release_date']),
      cartel: (json['poster_path'] as String?) ?? '',
      otrosTitulos: [
        for (final t
            in (json['alternative_titles']?['titles'] as List?) ?? const [])
          if ((t['title'] as String?)?.isNotEmpty ?? false)
            t['title'] as String,
      ],
      directores: await latinos(directores),
      nombresDirectores: [for (final d in directores) d.nombre],
      guion: await latinos(guion),
      fotografia: await latinos(conTrabajo({'Director of Photography'})),
      sinopsis: ((json['overview'] as String?) ?? '').trim(),
      reparto: await latinos(reparto),
      productoras: [
        for (final c in (json['production_companies'] as List?) ?? const [])
          if (((c['name'] as String?) ?? '').trim().isNotEmpty)
            (c['name'] as String).trim(),
      ],
      musica: await latinos(musica),
      paises: [for (final c in codigos) nombresPaises[c] ?? c],
      saga: saga,
      numeroSaga: numeroSaga,
      edadEspana: _edad(json, 'ES'),
      edadEeuu: _edad(json, 'US'),
      imdb: imdb.startsWith('tt') ? imdb : '',
    );
  }

  /// El nombre de la persona [id] en letras latinas (de sus «también
  /// conocido como»), o [nombre] si no tiene ninguno.
  Future<String> nombreLatino(int id, String nombre) async {
    if (_nombres[id] case final n?) return n;
    var latino = nombre;
    try {
      final json = await _pedir('/person/$id');
      for (final otro in (json['also_known_as'] as List?) ?? const []) {
        if (otro is String && otro.trim().contains(' ') && esLatino(otro)) {
          latino = otro.trim();
          break;
        }
      }
    } on FuenteException catch (e) {
      if (e.claveMala || e.sinInternet) rethrow;
    }
    return _nombres[id] = latino;
  }

  final _nombres = <int, String>{};

  /// Código de país → nombre en español («US» → «Estados Unidos»). Se pide
  /// una sola vez.
  Future<Map<String, String>> paises() async {
    if (_paises != null) return _paises!;
    final json = await pedirJson(
      _cliente,
      _servicio,
      Uri.parse('$_base/configuration/countries').replace(
        queryParameters: {
          'language': 'es-ES',
          if (!_esToken) 'api_key': clave.trim(),
        },
      ),
      cabeceras: {if (_esToken) 'Authorization': 'Bearer ${clave.trim()}'},
    );
    return _paises = {
      for (final p in json as List)
        p['iso_3166_1'] as String: nombrePais(
          p['iso_3166_1'] as String,
          (p['native_name'] as String?) ?? (p['english_name'] as String),
        ),
    };
  }

  /// Puesto de la película [id] dentro de la saga [saga], ordenando sus
  /// películas por fecha de estreno (las que aún no tienen fecha, al final).
  Future<int> _lugarEnSaga(int saga, int id) async {
    final json = await _pedir('/collection/$saga');
    final partes =
        [
          for (final p in (json['parts'] as List?) ?? const [])
            (id: p['id'] as int, fecha: (p['release_date'] as String?) ?? ''),
        ]..sort((a, b) {
          if (a.fecha.isEmpty != b.fecha.isEmpty) {
            return a.fecha.isEmpty ? 1 : -1;
          }
          return a.fecha.compareTo(b.fecha);
        });
    return partes.indexWhere((p) => p.id == id) + 1;
  }

  /// Sagas («colecciones» de TMDB) que se llaman como [nombre]: número y
  /// nombre de cada una.
  Future<List<(int, String)>> buscarSagas(String nombre) async {
    final json = await _pedir('/search/collection', {'query': nombre});
    return [
      for (final r in json['results'] as List)
        (r['id'] as int, (r['name'] as String?) ?? ''),
    ];
  }

  /// Películas ya estrenadas (hasta [hoy]) de la saga [saga], por orden de
  /// estreno: el mismo orden que el número dentro de la saga.
  Future<List<({String titulo, int anio})>> partesSaga(
    int saga, {
    DateTime? hoy,
  }) async {
    final json = await _pedir('/collection/$saga');
    final limite = (hoy ?? DateTime.now()).toIso8601String().substring(0, 10);
    final partes = [
      for (final p in (json['parts'] as List?) ?? const [])
        if (((p['release_date'] as String?) ?? '') case final fecha
            when fecha.isNotEmpty && fecha.compareTo(limite) <= 0)
          (
            fecha: fecha,
            titulo: (p['title'] as String?) ?? '',
            anio: _anio(fecha),
          ),
    ]..sort((a, b) => a.fecha.compareTo(b.fecha));
    return [for (final p in partes) (titulo: p.titulo, anio: p.anio)];
  }

  static int _anio(Object? fecha) => fecha is String && fecha.length >= 4
      ? int.tryParse(fecha.substring(0, 4)) ?? 0
      : 0;

  /// La calificación de edad del país [pais], preferiblemente la del estreno
  /// en cines.
  static String _edad(Map<String, dynamic> json, String pais) {
    for (final r in (json['release_dates']?['results'] as List?) ?? const []) {
      if (r['iso_3166_1'] != pais) continue;
      final fechas = [...(r['release_dates'] as List)]
        ..sort((a, b) {
          // Cines (3) primero; luego el resto en su orden.
          final ta = a['type'] == 3 ? 0 : 1;
          final tb = b['type'] == 3 ? 0 : 1;
          return ta.compareTo(tb);
        });
      for (final f in fechas) {
        final c = ((f['certification'] as String?) ?? '').trim();
        if (c.isNotEmpty) return pais == 'ES' ? _edadEspana(c) : c;
      }
    }
    return '';
  }

  /// TMDB escribe las de España de varias formas («A», «Ai», «7i», «APTA»…).
  static String _edadEspana(String c) {
    final t = c.toUpperCase().replaceAll(' ', '');
    if (t == 'A' || t == 'AI' || t == 'TP' || t.startsWith('APTA')) return 'TP';
    final n = RegExp(r'\d+').firstMatch(t)?.group(0);
    if (n != null) return n;
    return t;
  }
}

/// «Harry Potter - Colección» → «Harry Potter»; «Colección Toy Story» →
/// «Toy Story».
String limpiarNombreSaga(String nombre) {
  var n = nombre.trim();
  for (final patron in [
    RegExp(
      r'\s*[-–:]\s*(colecci[oó]n|saga|trilog[ií]a)\s*$',
      caseSensitive: false,
    ),
    RegExp(r'\s*\((colecci[oó]n|saga|trilog[ií]a)\)\s*$', caseSensitive: false),
    RegExp(r'\s+(colecci[oó]n|collection)\s*$', caseSensitive: false),
    RegExp(
      r'^(colecci[oó]n|saga|trilog[ií]a)\s+(de\s+)?',
      caseSensitive: false,
    ),
  ]) {
    n = n.replaceFirst(patron, '');
  }
  return n.trim();
}

/// Nombre del país como lo escribe FilmAffinity (TMDB pone alguno largo).
String nombrePais(String codigo, String nombre) =>
    const {
      'US': 'Estados Unidos',
      'GB': 'Reino Unido',
      'KR': 'Corea del Sur',
      'KP': 'Corea del Norte',
      'RU': 'Rusia',
      'CZ': 'República Checa',
      'IR': 'Irán',
      'TW': 'Taiwán',
      'HK': 'Hong Kong',
      'VN': 'Vietnam',
      'NL': 'Países Bajos',
      'SU': 'Unión Soviética',
    }[codigo] ??
    nombre;

/// El texto está escrito con letras latinas (con o sin tildes).
bool esLatino(String texto) => texto.runes.every((r) => r < 0x370);
