import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:videoteca/datos/catalogo.dart' show peliculasPorIdProvider;
import 'package:videoteca/datos/fuentes.dart';
import 'package:videoteca/datos/lote.dart' show siguienteDudosa;
import 'package:videoteca/datos/nuevas.dart';
import 'package:videoteca/datos/vigilancia.dart';
import 'package:videoteca/disco/escritor.dart' show Campo;
import 'package:videoteca/fuentes/conexion.dart';
import 'package:videoteca/fuentes/conversiones.dart';
import 'package:videoteca/fuentes/datos_automaticos.dart';
import 'package:videoteca/fuentes/identificacion.dart';
import 'package:videoteca/fuentes/lote.dart';
import 'package:videoteca/fuentes/tmdb.dart';
import 'package:videoteca/modelos/pelicula.dart';

// Pruebas de las fuentes de datos sin internet: las respuestas de TMDB, OMDb
// y Wikidata se fabrican aquí. Con datos reales se prueba con
// `dart run tool/probar_fuentes.dart`.

/// Una película de TMDB de mentira.
Map<String, Object?> _pelicula(
  int id,
  String titulo,
  String original,
  String fecha, {
  List<String> directores = const [],
  Map<String, String> edades = const {},
  Map<String, Object?>? saga,
  String imdb = '',
  List<String> paises = const ['US'],
  String sinopsis = '',
  List<String> reparto = const [],
  List<String> productoras = const [],
  String musica = '',
}) => {
  'id': id,
  'title': titulo,
  'original_title': original,
  'release_date': fecha,
  'imdb_id': imdb,
  'origin_country': paises,
  'belongs_to_collection': saga,
  'overview': sinopsis,
  'production_companies': [
    for (final c in productoras) {'name': c},
  ],
  'credits': {
    // Desordenado a propósito: cuenta el `order` de los créditos.
    'cast': [
      for (var i = reparto.length - 1; i >= 0; i--)
        {'name': reparto[i], 'order': i},
    ],
    'crew': [
      if (musica.isNotEmpty)
        {
          'name': musica,
          'job': 'Original Music Composer',
          'department': 'Sound',
        },
      for (final d in directores)
        {'name': d, 'job': 'Director', 'department': 'Directing'},
      {'name': 'Jonathan Nolan', 'job': 'Screenplay', 'department': 'Writing'},
      {
        'name': 'Christopher Nolan',
        'job': 'Screenplay',
        'department': 'Writing',
      },
      {'name': 'Jonathan Nolan', 'job': 'Story', 'department': 'Writing'},
      {
        'name': 'Wally Pfister',
        'job': 'Director of Photography',
        'department': 'Camera',
      },
    ],
  },
  'release_dates': {
    'results': [
      for (final MapEntry(:key, :value) in edades.entries)
        {
          'iso_3166_1': key,
          'release_dates': [
            {'type': 1, 'certification': ''},
            {'type': 3, 'certification': value},
          ],
        },
    ],
  },
  'alternative_titles': {'titles': []},
};

/// Un cliente que contesta como TMDB/OMDb/Wikidata con [peliculas].
MockClient _servicios(
  List<Map<String, Object?>> peliculas, {
  Map<String, int> rotten = const {},
  Map<String, String> filmaffinity = const {},
  List<String>? registro,
}) => MockClient((peticion) async {
  final u = peticion.url;
  registro?.add('${u.host}${u.path}');
  http.Response json(Object o, [int codigo = 200]) =>
      http.Response.bytes(utf8.encode(jsonEncode(o)), codigo);
  if (u.host == 'api.themoviedb.org') {
    if (u.queryParameters['api_key'] != 'buena') {
      return json({'status_code': 7}, 401);
    }
    final ruta = u.path.replaceFirst('/3', '');
    if (ruta == '/configuration/countries') {
      return json([
        {
          'iso_3166_1': 'US',
          'english_name': 'United States of America',
          'native_name': 'Estados Unidos de América',
        },
        {'iso_3166_1': 'ES', 'english_name': 'Spain', 'native_name': 'España'},
      ]);
    }
    if (ruta == '/search/movie') {
      final q = u.queryParameters['query']!.toLowerCase();
      final anio = u.queryParameters['year'];
      return json({
        'results': [
          for (final p in peliculas)
            if (('${p['title']} ${p['original_title']}').toLowerCase().contains(
                  q,
                ) &&
                (anio == null ||
                    (p['release_date'] as String).startsWith(anio)))
              p,
        ],
      });
    }
    if (ruta.startsWith('/collection/')) {
      return json({
        'parts': [
          {'id': 3, 'release_date': '2012-07-20'},
          {'id': 1, 'release_date': '2005-06-15'},
          {'id': 2, 'release_date': '2008-07-18'},
        ],
      });
    }
    if (ruta.endsWith('/credits')) {
      final id = int.parse(ruta.split('/')[2]);
      return json(peliculas.firstWhere((p) => p['id'] == id)['credits']!);
    }
    final id = int.parse(ruta.split('/').last);
    return json(peliculas.firstWhere((p) => p['id'] == id));
  }
  if (u.host == 'www.omdbapi.com') {
    final nota = rotten[u.queryParameters['i']];
    return json({
      'Response': 'True',
      'Ratings': [
        {'Source': 'Internet Movie Database', 'Value': '9.0/10'},
        if (nota != null) {'Source': 'Rotten Tomatoes', 'Value': '$nota%'},
      ],
    });
  }
  if (u.host == 'query.wikidata.org') {
    final imdb = RegExp(r'tt\d+')
        .firstMatch(u.queryParameters['query']!)!
        .group(0);
    final fa = filmaffinity[imdb];
    return json({
      'results': {
        'bindings': [
          if (fa != null)
            {
              'fa': {'type': 'literal', 'value': fa},
            },
        ],
      },
    });
  }
  return http.Response('', 404);
});

final _caballero = _pelicula(
  2,
  'El caballero oscuro',
  'The Dark Knight',
  '2008-07-16',
  directores: ['Christopher Nolan'],
  edades: {'ES': '12', 'US': 'PG-13'},
  saga: {'id': 263, 'name': 'El Caballero Oscuro - Colección'},
  imdb: 'tt0468569',
  paises: ['US', 'GB'],
);

void main() {
  group('Comparar títulos y nombres', () {
    test('títulos parecidos', () {
      expect(
        titulosParecidos('El caballero oscuro', 'El Caballero Oscuro'),
        isTrue,
      );
      expect(titulosParecidos('¡Átame!', 'Atame'), isTrue);
      expect(titulosParecidos('Rocky II', 'Rocky 2'), isTrue);
      expect(titulosParecidos('The Matrix', 'Matrix'), isTrue);
      expect(titulosParecidos('Alien', 'Alien, el octavo pasajero'), isTrue);
      expect(titulosParecidos('Spider-Man', 'Spiderman'), isTrue);
      expect(titulosParecidos('Origen', 'Inception'), isFalse);
      expect(titulosParecidos('Rocky II', 'Rocky III'), isFalse);
    });

    test('misma persona', () {
      expect(mismaPersona('J.J. Abrams', 'J. J. Abrams'), isTrue);
      expect(mismaPersona('Bong Joon-ho', 'Bong Joon Ho'), isTrue);
      expect(mismaPersona('Andrei Tarkovsky', 'Andrey Tarkovskiy'), isTrue);
      expect(mismaPersona('Pedro Almodóvar', 'Pedro Almodovar'), isTrue);
      expect(mismaPersona('Joel Coen', 'Ethan Coen'), isFalse);
      expect(mismaPersona('Tony Scott', 'Ridley Scott'), isFalse);
      // Nombre más largo por delante o por detrás.
      expect(mismaPersona('Kirk Wong', 'Kirk Wong Chi-Keung'), isTrue);
      expect(mismaPersona('Stanley Tong Gwai-Lai', 'Stanley Tong'), isTrue);
      expect(mismaPersona('Martín Cuervo', 'Hugo Martín Cuervo'), isTrue);
      expect(mismaPersona('Jennifer Yuh', 'Jennifer Yuh Nelson'), isTrue);
      expect(mismaPersona('Dennis Dimster-Denk', 'Dennis Dimster'), isTrue);
      // …pero no padre e hijo, ni con una sola palabra.
      expect(mismaPersona('Lon Chaney', 'Lon Chaney Jr.'), isFalse);
      expect(mismaPersona('Upi', 'Upi Avianto'), isFalse);
      expect(mismaPersona('Ron Howard', 'Bryce Dallas Howard'), isFalse);
      expect(mismasPersonas('Yoshifumi Kondô', 'Yoshifumi Kondo'), isTrue);
      expect(
        mismasPersonas('Joel Coen, Ethan Coen', 'Ethan Coen, Joel Coen'),
        isTrue,
      );
      expect(mismasPersonas('Joel Coen', 'Joel Coen, Ethan Coen'), isFalse);
    });

    test('nombre de la saga', () {
      expect(limpiarNombreSaga('Harry Potter - Colección'), 'Harry Potter');
      expect(limpiarNombreSaga('Colección Toy Story'), 'Toy Story');
      expect(limpiarNombreSaga('Saga Crepúsculo'), 'Crepúsculo');
      expect(limpiarNombreSaga('Shrek (Colección)'), 'Shrek');
      expect(limpiarNombreSaga('Alien'), 'Alien');
    });
  });

  test('la identificación de la app no lleva tildes (si no, nada sale)', () {
    expect(agenteVideoteca.codeUnits.every((c) => c >= 32 && c < 127), isTrue);
  });

  test('edad: EE. UU. primero y, si no, España', () {
    expect(fraseEdad(espana: '12', eeuu: 'PG-13'), frasesEdad['13']);
    expect(fraseEdad(espana: '16', eeuu: 'R'), frasesEdad['18']);
    expect(fraseEdad(espana: 'TP', eeuu: 'G'), 'Apto para todos los públicos');
    expect(fraseEdad(espana: '16', eeuu: ''), frasesEdad['16']);
    expect(fraseEdad(espana: '', eeuu: 'NR'), isNull);
    expect(reglasEdadParaVer.first.$2, 'EE. UU.: G · España: TP');
    expect(reglasEdadParaVer.last.$2, 'EE. UU.: R, NC-17 · España: 18, X');
  });

  test('Rotten Tomatoes → estrellas en tramos de 20 %', () {
    expect([0, 19, 20, 39, 40, 59, 60, 79, 80, 100].map(estrellasDeRotten), [
      1,
      1,
      2,
      2,
      3,
      3,
      4,
      4,
      5,
      5,
    ]);
  });

  group('Identificación', () {
    final remake = _pelicula(
      7,
      'El caballero oscuro',
      'The Dark Knight',
      '1950-01-01',
      directores: ['Otro Señor'],
    );

    test('título + año + director → segura', () async {
      final tmdb = Tmdb('buena', cliente: _servicios([_caballero, remake]));
      final r = await identificar(tmdb, (
        titulo: 'El Caballero Oscuro',
        tituloOriginal: 'The Dark Knight',
        anio: 2008,
        direccion: 'Christopher Nolan',
      ));
      expect(r.seguridad, Seguridad.segura);
      expect(r.ficha!.id, 2);
    });

    test('año distinto en uno sí vale; director distinto, no', () async {
      final tmdb = Tmdb('buena', cliente: _servicios([_caballero]));
      final unAnio = await identificar(tmdb, (
        titulo: 'El caballero oscuro',
        tituloOriginal: '',
        anio: 2009,
        direccion: 'Christopher Nolan',
      ));
      expect(unAnio.seguridad, Seguridad.segura);

      final otroDirector = await identificar(tmdb, (
        titulo: 'El caballero oscuro',
        tituloOriginal: '',
        anio: 2008,
        direccion: 'Tim Burton',
      ));
      expect(otroDirector.seguridad, Seguridad.dudosa);
      expect(otroDirector.candidatos.first.explicacion, contains('director'));
    });

    test('sin director en la ficha → dudosa', () async {
      final tmdb = Tmdb('buena', cliente: _servicios([_caballero]));
      final r = await identificar(tmdb, (
        titulo: 'El caballero oscuro',
        tituloOriginal: '',
        anio: 2008,
        direccion: '',
      ));
      expect(r.seguridad, Seguridad.dudosa);
      expect(r.ficha, isNull);
    });

    test('nada parecido → no encontrada', () async {
      final tmdb = Tmdb('buena', cliente: _servicios([_caballero]));
      final r = await identificar(tmdb, (
        titulo: 'Película inexistente',
        tituloOriginal: '',
        anio: 2001,
        direccion: 'Nadie',
      ));
      expect(r.seguridad, Seguridad.noEncontrada);
    });

    test('clave mala', () async {
      final tmdb = Tmdb('mala', cliente: _servicios([_caballero]));
      expect(
        () => tmdb.probar(),
        throwsA(
          isA<FuenteException>().having(
            (e) => e.claveMala,
            'claveMala',
            isTrue,
          ),
        ),
      );
    });
  });

  test('Sinopsis, reparto, productora y música de TMDB (issue #5)', () async {
    final fuentes = FuentesDatos(
      claveTmdb: 'buena',
      claveOmdb: '',
      cliente: _servicios([
        _pelicula(
          7,
          'Origen',
          'Inception',
          '2010-07-16',
          directores: ['Christopher Nolan'],
          sinopsis: 'Dom Cobb es un ladrón con una extraña habilidad…',
          reparto: [for (var i = 1; i <= 20; i++) 'Actor $i'],
          productoras: ['Warner Bros. Pictures', 'Legendary; Syncopy'],
          musica: 'Hans Zimmer',
        ),
      ]),
    );
    final r = await fuentes.buscar((
      titulo: 'Origen',
      tituloOriginal: 'Inception',
      anio: 2010,
      direccion: 'Christopher Nolan',
    ));
    String? v(Campo c) => r.datos[c]?.valor;
    expect(
      v(Campo.sinopsis),
      'Dom Cobb es un ladrón con una extraña habilidad…',
    );
    // Los 15 primeros por orden de créditos.
    expect(
      v(Campo.reparto),
      [for (var i = 1; i <= maximoRepartoTmdb; i++) 'Actor $i'].join(', '),
    );
    // Sin «;» (Windows separa con él los valores de las listas).
    expect(v(Campo.productora), 'Warner Bros. Pictures, Legendary, Syncopy');
    expect(v(Campo.musica), 'Hans Zimmer');
    for (final c in [
      Campo.sinopsis,
      Campo.reparto,
      Campo.productora,
      Campo.musica,
    ]) {
      expect(r.datos[c]!.origen, 'TMDB');
    }
  });

  test('Datos reunidos de las tres fuentes', () async {
    final fuentes = FuentesDatos(
      claveTmdb: 'buena',
      claveOmdb: 'otra',
      cliente: _servicios(
        [_caballero],
        rotten: {'tt0468569': 94},
        filmaffinity: {'tt0468569': '867354'},
      ),
    );
    final r = await fuentes.buscar((
      titulo: 'El caballero oscuro',
      tituloOriginal: 'The Dark Knight',
      anio: 2008,
      direccion: 'Christopher Nolan',
    ));
    String? v(Campo c) => r.datos[c]?.valor;
    expect(v(Campo.guion), 'Jonathan Nolan, Christopher Nolan');
    expect(v(Campo.fotografia), 'Wally Pfister');
    expect(v(Campo.pais), 'Estados Unidos, GB');
    expect(v(Campo.saga), 'El Caballero Oscuro');
    expect(v(Campo.numeroSaga), '2');
    expect(v(Campo.enlaceImdb), 'https://www.imdb.com/title/tt0468569/');
    expect(v(Campo.estrellas), '5');
    expect(r.datos[Campo.estrellas]!.origen, 'OMDb');
    expect(r.datos[Campo.estrellas]!.detalle, '94 % en Rotten Tomatoes');
    expect(
      v(Campo.enlaceFilmaffinity),
      'https://www.filmaffinity.com/es/film867354.html',
    );
    expect(r.datos[Campo.enlaceFilmaffinity]!.origen, 'Wikidata');
    expect(v(Campo.clasificacion), 'No recomendado para menores de 13 años');
  });

  group('Películas nuevas (el archivo aún no tiene director)', () {
    final remake = _pelicula(
      7,
      'El caballero oscuro',
      'The Dark Knight',
      '1990-03-01',
      directores: ['Otro Director'],
    );
    const nueva = (
      titulo: 'El caballero oscuro',
      tituloOriginal: '',
      anio: 2008,
      direccion: '',
    );

    test('la única que coincide en título y año es la probable', () async {
      final tmdb = Tmdb('buena', cliente: _servicios([_caballero, remake]));
      final id = await identificar(tmdb, nueva);
      expect(id.seguridad, Seguridad.dudosa);
      expect(candidataProbable(id, nueva)?.ficha.id, 2);
      // Con director en el archivo no hay «probable»: o segura o dudosa.
      expect(
        candidataProbable(id, (
          titulo: nueva.titulo,
          tituloOriginal: '',
          anio: 2008,
          direccion: 'Fulano',
        )),
        isNull,
      );
    });

    test('si hay dos del mismo título y año, hay que elegir', () async {
      final otra = _pelicula(
        8,
        'El caballero oscuro',
        'Dark Knight',
        '2008-01-01',
      );
      final tmdb = Tmdb('buena', cliente: _servicios([_caballero, otra]));
      final id = await identificar(tmdb, nueva);
      expect(candidataProbable(id, nueva), isNull);
    });

    test('la bandeja busca sola, de una en una', () async {
      final contenedor = ProviderContainer(
        overrides: [
          fuentesDatosProvider.overrideWithValue(
            FuentesDatos(
              claveTmdb: 'buena',
              claveOmdb: '',
              cliente: _servicios([_caballero, remake]),
            ),
          ),
          nuevasProvider.overrideWithValue(const [
            Pelicula(
              id: 1,
              titulo: 'El caballero oscuro',
              anio: 2008,
              ruta: r'D:\Accion\Accion\El caballero oscuro (2008).mp4',
              nueva: true,
            ),
            Pelicula(
              id: 2,
              titulo: 'Película que no existe',
              anio: 2020,
              ruta: r'D:\Drama\Drama\Película que no existe (2020).mp4',
              nueva: true,
            ),
          ]),
        ],
      );
      addTearDown(contenedor.dispose);
      final suscripcion = contenedor.listen(busquedasNuevasProvider, (_, _) {});
      for (var i = 0; i < 200; i++) {
        final estados = suscripcion.read();
        if (estados.length == 2 &&
            estados.values.every((b) => b.estado != EstadoBusqueda.buscando)) {
          break;
        }
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      final estados = suscripcion.read();
      expect(estados[1]!.estado, EstadoBusqueda.lista);
      expect(estados[1]!.probable, isTrue);
      expect(
        estados[1]!.resultado!.datos[Campo.direccion]!.valor,
        'Christopher Nolan',
      );
      expect(estados[2]!.estado, EstadoBusqueda.noEncontrada);

      final p = contenedor.read(nuevasProvider);
      expect(estadoNueva(p[0], estados[1], clave: true), EstadoNueva.lista);
      expect(
        estadoNueva(p[1], estados[2], clave: true),
        EstadoNueva.noEncontrada,
      );
      expect(estadoNueva(p[1], null, clave: false), EstadoNueva.sinClave);
      final guardada = Pelicula(
        id: 3,
        titulo: 'X',
        anio: 2000,
        ruta: 'x',
        completada: DateTime(2026),
      );
      expect(
        estadoNueva(guardada, null, clave: true),
        EstadoNueva.guardadaSinCaratula,
      );

      // Elegir otra a mano.
      const remakeCandidata = Candidato(
        FichaTmdb(
          id: 7,
          titulo: 'El caballero oscuro',
          tituloOriginal: 'The Dark Knight',
          anio: 1990,
          directores: ['Otro Director'],
        ),
        titulo: true,
        anio: false,
        director: false,
      );
      await contenedor
          .read(busquedasNuevasProvider.notifier)
          .elegir(1, remakeCandidata);
      final elegida = suscripcion.read()[1]!;
      expect(elegida.elegida, isTrue);
      expect(elegida.resultado!.datos[Campo.direccion]!.valor, 'Otro Director');
    });

    test('las dudosas del lote se buscan cuando se piden', () async {
      const dudosa = Pelicula(
        id: 5,
        titulo: 'El caballero oscuro',
        anio: 2008,
        direccion: 'Fulano',
        ruta: r'D:\Accion\Accion\El caballero oscuro (2008).mp4',
      );
      const otra = Pelicula(
        id: 6,
        titulo: 'Zorro',
        anio: 2000,
        ruta: r'D:\Accion\Accion\Zorro (2000).mp4',
      );
      final contenedor = ProviderContainer(
        overrides: [
          fuentesDatosProvider.overrideWithValue(
            FuentesDatos(
              claveTmdb: 'buena',
              claveOmdb: '',
              cliente: _servicios([_caballero, remake]),
            ),
          ),
          nuevasProvider.overrideWithValue(const []),
          peliculasPorIdProvider.overrideWithValue({5: dudosa, 6: otra}),
        ],
      );
      addTearDown(contenedor.dispose);
      final suscripcion = contenedor.listen(busquedasNuevasProvider, (_, _) {});
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(suscripcion.read(), isEmpty, reason: 'sin pedirlas no se buscan');

      contenedor.read(busquedasNuevasProvider.notifier).pedir([5]);
      for (var i = 0; i < 200; i++) {
        final b = suscripcion.read()[5];
        if (b != null && b.estado != EstadoBusqueda.buscando) break;
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      // Con un director que no coincide no hay «probable»: hay que elegir.
      final b = suscripcion.read()[5]!;
      expect(b.estado, EstadoBusqueda.elegir);
      expect(b.identificacion!.candidatos, isNotEmpty);

      // La siguiente, por orden del disco (aunque la actual ya no esté).
      expect(siguienteDudosa([dudosa, otra], dudosa)?.id, 6);
      expect(siguienteDudosa([otra], dudosa)?.id, 6);
      expect(siguienteDudosa([dudosa, otra], otra), isNull);
    });
  });

  group('Completar mi colección (lote)', () {
    const datos = (
      titulo: 'El caballero oscuro',
      tituloOriginal: 'The Dark Knight',
      anio: 2008,
      direccion: 'Christopher Nolan',
    );
    final todos = OpcionLote.camposDe(OpcionLote.values);
    FuentesDatos fuentes([List<String>? registro]) => FuentesDatos(
      claveTmdb: 'buena',
      claveOmdb: 'otra',
      cliente: _servicios(
        [_caballero],
        rotten: {'tt0468569': 94},
        filmaffinity: {'tt0468569': '867354'},
        registro: registro,
      ),
    );

    test('solo rellena los campos vacíos', () async {
      final plan = await planificarLote(
        fuentes(),
        datos: datos,
        actuales: {
          Campo.tituloOriginal: 'The Dark Knight (mío)',
          Campo.clasificacion: 'No recomendado para menores de 12 años',
          Campo.estrellas: '4',
          Campo.pais: '',
        },
        campos: todos,
      );
      expect(plan.estado, EstadoLote.completada);
      expect(plan.cambios.keys.toSet(), {
        Campo.pais,
        Campo.guion,
        Campo.fotografia,
        Campo.saga,
        Campo.numeroSaga,
        Campo.enlaceImdb,
        Campo.enlaceFilmaffinity,
      });
      expect(plan.cambios[Campo.saga], 'El Caballero Oscuro');
      expect(plan.mensaje, startsWith('+ Guion, Fotografía, País'));
    });

    test('sin estrellas que buscar, no se gasta OMDb', () async {
      final registro = <String>[];
      await planificarLote(
        fuentes(registro),
        datos: datos,
        actuales: {Campo.estrellas: '3'},
        campos: todos,
      );
      expect(registro.any((r) => r.contains('omdbapi')), isFalse);
      expect(registro.any((r) => r.contains('wikidata')), isTrue);

      registro.clear();
      final plan = await planificarLote(
        fuentes(registro),
        datos: datos,
        actuales: const {},
        campos: todos,
        sinOmdb: true,
      );
      expect(registro.any((r) => r.contains('omdbapi')), isFalse);
      expect(plan.cambios.containsKey(Campo.estrellas), isFalse);
    });

    test('solo los campos elegidos', () async {
      final plan = await planificarLote(
        fuentes(),
        datos: datos,
        actuales: const {},
        campos: OpcionLote.camposDe([OpcionLote.pais, OpcionLote.estrellas]),
      );
      expect(plan.cambios, {
        Campo.pais: 'Estados Unidos, GB',
        Campo.estrellas: '5',
      });
    });

    test('el número de saga no se pone si tu saga es otra', () async {
      final plan = await planificarLote(
        fuentes(),
        datos: datos,
        actuales: {Campo.saga: 'Batman'},
        campos: OpcionLote.camposDe([OpcionLote.saga]),
      );
      expect(plan.estado, EstadoLote.sinDatos);
      final igual = await planificarLote(
        fuentes(),
        datos: datos,
        actuales: {Campo.saga: 'El Caballero Oscuro'},
        campos: OpcionLote.camposDe([OpcionLote.saga]),
      );
      expect(igual.cambios, {Campo.numeroSaga: '2'});
    });

    test('una «saga» que no está en letras latinas no se pone', () async {
      final shinkai = _pelicula(
        9,
        'El lugar que nos prometimos',
        'Kumo no Mukô, Yakusoku no Basho',
        '2004-11-20',
        directores: ['Makoto Shinkai'],
        saga: {'id': 1, 'name': '新海诚（导演作品合集）'},
        imdb: 'tt0381348',
      );
      final plan = await planificarLote(
        FuentesDatos(
          claveTmdb: 'buena',
          claveOmdb: '',
          cliente: _servicios([shinkai]),
        ),
        datos: (
          titulo: 'El Lugar Que Nos Prometimos',
          tituloOriginal: '',
          anio: 2004,
          direccion: 'Makoto Shinkai',
        ),
        actuales: const {},
        campos: todos,
      );
      expect(plan.estado, EstadoLote.completada);
      expect(plan.cambios.containsKey(Campo.saga), isFalse);
      expect(plan.cambios.containsKey(Campo.numeroSaga), isFalse);
    });

    test('dudosas y no encontradas: no se toca nada', () async {
      final sinDirector = await planificarLote(
        fuentes(),
        datos: (
          titulo: 'El caballero oscuro',
          tituloOriginal: '',
          anio: 2008,
          direccion: '',
        ),
        actuales: const {},
        campos: todos,
      );
      expect(sinDirector.estado, EstadoLote.dudosa);
      expect(sinDirector.cambios, isEmpty);

      final otroDirector = await planificarLote(
        fuentes(),
        datos: (
          titulo: 'El caballero oscuro',
          tituloOriginal: '',
          anio: 2008,
          direccion: 'Tim Burton',
        ),
        actuales: const {},
        campos: todos,
      );
      expect(otroDirector.estado, EstadoLote.dudosa);
      expect(otroDirector.cambios, isEmpty);

      final nada = await planificarLote(
        fuentes(),
        datos: (
          titulo: 'Película que no existe',
          tituloOriginal: '',
          anio: 2020,
          direccion: 'Nadie',
        ),
        actuales: const {},
        campos: todos,
      );
      expect(nada.estado, EstadoLote.noEncontrada);
    });

    test('si ya está completa no se consulta nada', () async {
      final registro = <String>[];
      final plan = await planificarLote(
        fuentes(registro),
        datos: datos,
        actuales: {for (final c in todos) c: 'algo'},
        campos: todos,
      );
      expect(plan.estado, EstadoLote.sinDatos);
      expect(registro, isEmpty);
    });

    test('sin internet se para el lote (no se anota como error)', () async {
      final caida = FuentesDatos(
        claveTmdb: 'buena',
        claveOmdb: '',
        cliente: MockClient((_) async => throw http.ClientException('x')),
      );
      expect(
        planificarLote(caida, datos: datos, actuales: const {}, campos: todos),
        throwsA(
          isA<FuenteException>().having(
            (e) => e.sinInternet,
            'sin internet',
            true,
          ),
        ),
      );
    });

    test('sinopsis cortadas y repaso', () {
      final cortada = '${'a' * 250}palab';
      expect(cortada.length, 255);
      expect(sinopsisCortadaProbable(cortada), isTrue);
      expect(sinopsisCortadaProbable('${'a' * 254}.'), isFalse);
      expect(sinopsisCortadaProbable('Corta.'), isFalse);
      expect(sinopsisCortadaProbable('a' * 300), isFalse);
      expect(
        entraEnRepaso(TipoRepaso.sinTemas, sinopsis: '', temas: ''),
        isTrue,
      );
      expect(
        entraEnRepaso(TipoRepaso.sinTemas, sinopsis: '', temas: 'Navidad'),
        isFalse,
      );
    });
  });
}
