import 'package:html/dom.dart';
import 'package:html/parser.dart' as html;

import '../disco/escritor.dart' show Campo;
import 'datos_automaticos.dart' show DatoEncontrado;
import 'identificacion.dart';

// Leer la ficha de una película de FilmAffinity (la página
// `filmaffinity.com/es/filmNNNNNN.html`) a partir de su HTML, que la app
// toma de la ventana de Edge (ver `navegador.dart`).
//
// No usa nada de Flutter.

/// Lo que dice la ficha de FilmAffinity.
class FichaFilmaffinity {
  const FichaFilmaffinity({
    required this.id,
    required this.titulo,
    this.tituloOriginal = '',
    this.anio = 0,
    this.duracionMin = 0,
    this.pais = '',
    this.direccion = const [],
    this.guion = const [],
    this.reparto = const [],
    this.musica = const [],
    this.fotografia = const [],
    this.productoras = const [],
    this.generos = const [],
    this.temas = const [],
    this.sinopsis = '',
    this.premios = const [],
  });

  /// El número de la ficha (`film809297.html` → «809297»).
  final String id;

  /// El título en España.
  final String titulo;
  final String tituloOriginal;
  final int anio;
  final int duracionMin;
  final String pais;
  final List<String> direccion;
  final List<String> guion;
  final List<String> reparto;
  final List<String> musica;
  final List<String> fotografia;
  final List<String> productoras;

  /// Los géneros de FilmAffinity («Drama», «Comedia»…).
  final List<String> generos;

  /// Los temas («Mafia», «Años 40»…).
  final List<String> temas;
  final String sinopsis;

  /// Una línea por premio, como las enseña la ficha («1972: 3 Oscars: …»).
  final List<String> premios;

  String get enlace => enlaceFichaFilmaffinity(id);

  /// Qué coincide con nuestra película [p] (título, año ±1 y director).
  ({bool titulo, bool anio, bool director}) comparar(DatosIdentificacion p) =>
      coincidencias(
        p,
        titulos: {titulo, tituloOriginal},
        anio: anio,
        directores: direccion,
      );

  /// «Coinciden título, año y director.», «Coinciden título y año; no
  /// coincide director (Fulano).»…
  String explicacion(DatosIdentificacion p) {
    final c = comparar(p);
    return explicarCoincidencias(
      titulo: c.titulo,
      anio: c.anio,
      director: c.director,
      suAnio: anio,
      susDirectores: direccion,
    );
  }

  /// Los datos como campos de la ficha (los que no tiene la ficha de
  /// FilmAffinity no aparecen). El título en España no se toca: es el del
  /// nombre del archivo.
  Map<Campo, DatoEncontrado> datos() {
    final datos = <Campo, DatoEncontrado>{};
    void poner(Campo c, String valor, [String detalle = '']) {
      if (valor.trim().isNotEmpty) {
        datos[c] = DatoEncontrado(
          valor.trim(),
          'FilmAffinity',
          detalle: detalle,
        );
      }
    }

    // Windows separa por «;» los valores de las listas: en esas no se deja.
    String lista(List<String> nombres) =>
        nombres.map((n) => n.replaceAll(';', ',')).join(', ');

    poner(Campo.tituloOriginal, tituloOriginal);
    poner(Campo.generos, generos.join('. '));
    poner(Campo.sinopsis, sinopsis);
    poner(Campo.direccion, lista(direccion));
    poner(Campo.reparto, lista(reparto));
    poner(Campo.guion, lista(guion));
    poner(Campo.musica, lista(musica));
    poner(Campo.fotografia, lista(fotografia));
    poner(Campo.productora, lista(productoras));
    poner(Campo.pais, pais);
    poner(Campo.temas, temas.join('; '));
    poner(Campo.premios, premios.join(' · '));
    poner(Campo.enlaceFilmaffinity, enlace);
    return datos;
  }
}

/// Enlace a la ficha en español de FilmAffinity con el número [id].
String enlaceFichaFilmaffinity(String id) =>
    'https://www.filmaffinity.com/es/film$id.html';

final _urlFicha = RegExp(
  r'^https?://(?:www\.)?filmaffinity\.com/(\w+)/film(\d+)\.html',
);

/// El número de ficha si [url] es la ficha de una película de FilmAffinity
/// (en cualquier idioma), o `null`.
String? idFichaFilmaffinity(String url) => _urlFicha.firstMatch(url)?.group(2);

/// La ficha está en español (las etiquetas que se leen son las de la
/// versión española).
bool fichaEnEspanol(String url) => _urlFicha.firstMatch(url)?.group(1) == 'es';

/// Página de búsqueda de FilmAffinity con [texto].
String busquedaFilmaffinity(String texto) =>
    'https://www.filmaffinity.com/es/search.php?stype=title&stext='
    '${Uri.encodeQueryComponent(texto.replaceAll('꞉', ':'))}';

/// Lee la ficha a partir del [codigo] HTML de la página [url]. `null` si
/// no es la ficha de una película (o todavía no ha cargado).
FichaFilmaffinity? leerFichaFilmaffinity(String codigo, String url) {
  final id = idFichaFilmaffinity(url);
  if (id == null) return null;
  final doc = html.parse(codigo);
  final titulo = _texto(doc.querySelector('#main-title [itemprop=name]'));
  if (titulo.isEmpty) return null;

  // Los datos van en listas <dt>Etiqueta</dt><dd>valor</dd>.
  final campos = <String, Element>{};
  for (final dl in doc.querySelectorAll('dl.movie-info')) {
    String? etiqueta;
    for (final hijo in dl.children) {
      if (hijo.localName == 'dt') {
        etiqueta = _texto(hijo);
      } else if (hijo.localName == 'dd' && etiqueta != null) {
        campos.putIfAbsent(etiqueta, () => hijo);
      }
    }
  }
  Element? campo(String etiqueta) => campos[etiqueta];

  final generos = <String>[];
  final temas = <String>[];
  for (final a in campo('Género')?.querySelectorAll('a') ?? <Element>[]) {
    final href = a.attributes['href'] ?? '';
    final nombre = _texto(a);
    if (nombre.isEmpty) continue;
    if (href.contains('moviegenre.php')) {
      if (!generos.contains(nombre)) generos.add(nombre);
    } else if (href.contains('movietopic.php')) {
      if (!temas.contains(nombre)) temas.add(nombre);
    }
  }

  return FichaFilmaffinity(
    id: id,
    titulo: titulo,
    tituloOriginal: _tituloOriginal(campo('Título original')),
    anio: int.tryParse(_texto(campo('Año'))) ?? 0,
    duracionMin:
        int.tryParse(
          RegExp(r'\d+').firstMatch(_texto(campo('Duración')))?[0] ?? '',
        ) ??
        0,
    pais: _texto(campo('País')),
    direccion: _personas(campo('Dirección')),
    guion: _personas(campo('Guion')),
    reparto: _reparto(campo('Reparto')),
    musica: _personas(campo('Música')),
    fotografia: _personas(campo('Fotografía')),
    productoras: _personas(campo('Compañías')),
    generos: generos,
    temas: temas,
    sinopsis: _sinopsis(_texto(campo('Sinopsis'))),
    premios: _premios(campo('Premios')),
  );
}

/// Texto de un elemento con los espacios arreglados.
String _texto(Element? e) =>
    (e?.text ?? '').replaceAll(' ', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();

/// El título original, sin los añadidos («aka», etiquetas…).
String _tituloOriginal(Element? dd) {
  if (dd == null) return '';
  final copia = dd.clone(true);
  for (final e in copia.querySelectorAll('span, div, ul, i, a')) {
    e.remove();
  }
  return _texto(copia);
}

/// Los nombres de un apartado de créditos. Solo los del principio: lo que va
/// detrás de un subtítulo en cursiva («Novela: …», «Productor: …») es otra
/// cosa.
List<String> _personas(Element? dd) {
  if (dd == null) return const [];
  final creditos = dd.querySelector('.credits') ?? dd;
  final nombres = <String>[];
  for (final nodo in creditos.nodes) {
    if (nodo is! Element) continue;
    if (nodo.localName == 'i') break;
    if (!nodo.classes.contains('nb')) continue;
    // «Fulano (Creador)» → «Fulano»; los nombres llevan el completo en
    // el `title` del enlace.
    final a = nodo.querySelector('a');
    var nombre = a?.attributes['title']?.trim() ?? '';
    if (nombre.isEmpty) nombre = _texto(a ?? nodo);
    nombre = nombre.replaceAll(RegExp(r'[,.]\s*$'), '').trim();
    if (nombre.isNotEmpty && !nombres.contains(nombre)) nombres.add(nombre);
  }
  return nombres;
}

List<String> _reparto(Element? dd) {
  if (dd == null) return const [];
  final nombres = <String>[];
  for (final li in dd.querySelectorAll('[itemprop=actor]')) {
    final nombre = _texto(li.querySelector('.name, [itemprop=name]'));
    if (nombre.isNotEmpty && !nombres.contains(nombre)) nombres.add(nombre);
  }
  return nombres.isEmpty ? _personas(dd) : nombres;
}

/// Sin la firma «(FILMAFFINITY)» del final (en tus fichas no está).
String _sinopsis(String texto) => texto
    .replaceFirst(
      RegExp(r'\s*\(\s*FILMAFFINITY\s*\)\s*$', caseSensitive: false),
      '',
    )
    .trim();

List<String> _premios(Element? dd) {
  if (dd == null) return const [];
  return [
    for (final div in dd.querySelectorAll('div'))
      if (div.querySelector('em') == null)
        _texto(div)
            // «11[10*] nom.» → «11 nom.»
            .replaceAll(RegExp(r'\[\d+\*\]'), '')
            .replaceAllMapped(RegExp(r'\s+([:.,])'), (m) => m[1]!),
  ]..removeWhere((p) => p.isEmpty);
}
