import 'package:flutter_test/flutter_test.dart';

import 'package:videoteca/disco/escritor.dart' show Campo;
import 'package:videoteca/fuentes/filmaffinity.dart';

// Pruebas del lector de fichas de FilmAffinity con una página inventada que
// imita la estructura de las de verdad (los textos son de mentira). Con
// páginas reales se prueba con `dart run tool/probar_filmaffinity.dart`.

const _url = 'https://www.filmaffinity.com/es/film123456.html';

const _pagina = '''
<html><body>
<h1 id="main-title">
  <span itemprop="name">El Faro del Norte</span>
  <span class="movie-type"></span>
</h1>
<dl class="movie-info">
  <dt>Título original</dt>
  <dd>
    The Northern Lighthouse <span class="akas-button">aka</span>
  </dd>
  <dt>Año</dt>
  <dd itemprop="datePublished">1998</dd>
  <dt>Duración</dt>
  <dd itemprop="duration">112 min.</dd>
  <dt>País</dt>
  <dd><span id="country-img"><img alt="Reino Unido"></span>&nbsp;Reino Unido</dd>
  <dt>Dirección</dt>
  <dd class="directors"><div class="credits"><span class="nb"><a href="x" title="Ana Pérez"><span>Ana Pérez</span></a>,</span> <span class="nb"><a href="x" title="John Smith">John Smith</a></span></div></dd>
  <dt>Guion</dt>
  <dd><div class="credits"><span class="nb"><a href="x" title="Ana Pérez">Ana Pérez</a>. </span><i> Novela:</i> <span class="nb"><a href="x" title="Mary Jones">Mary Jones</a></span></div></dd>
  <dt>Reparto</dt>
  <dd class="card-cast-debug"><ul>
    <li itemprop="actor"><a href="x" title="Actor Uno"><div class="name" itemprop="name">Actor Uno</div></a></li>
    <li itemprop="actor"><a href="x" title="Actriz Dos"><div class="name" itemprop="name">Actriz Dos</div></a></li>
    <li class="see-more-cre"><a href="x">Ver todos los créditos</a></li>
  </ul></dd>
  <dt>Música</dt>
  <dd><div class="credits"><span class="nb"><a href="x" title="Compositor Tres">Compositor Tres</a></span></div></dd>
  <dt>Fotografía</dt>
  <dd><div class="credits"><span class="nb"><a href="x" title="Luz Cuatro">Luz Cuatro</a></span></div></dd>
  <dt>Compañías</dt>
  <dd class="card-producer"><div class="credits"><span class="nb"><a href="x" title="Estudios Uno">Estudios Uno</a>,</span> <span class="nb"><a href="x" title="Films; Dos">Films; Dos</a>. </span><i> Productor:</i> <span class="nb"><a href="x" title="Pedro Productor">Pedro Productor</a></span></div></dd>
  <dt>Género</dt>
  <dd class="card-genres">
    <span itemprop="genre"><a href="https://www.filmaffinity.com/es/moviegenre.php?genre=DR">Drama</a></span>.
    <span itemprop="genre"><a href="https://www.filmaffinity.com/es/moviegenre.php?genre=TH">Thriller</a></span> |
    <a href="https://www.filmaffinity.com/es/movietopic.php?topic=1">Faros</a>.
    <a href="https://www.filmaffinity.com/es/movietopic.php?topic=2">Años 50</a>
  </dd>
  <dt>Sinopsis</dt>
  <dd itemprop="description">Un farero descubre algo raro en la costa. (FILMAFFINITY)</dd>
</dl>
<dl class="margin-top movie-info">
  <dt>Premios</dt>
  <dd class="award">
    <div class="margin-bottom"><a href="x">1998</a>: Premios Inventados: Mejor fotografía. 3[2*] nom.</div>
    <div class="margin-bottom"><a href="x">1999</a>: Festival de Mentira: Sección oficial</div>
    <div><em><a href="x">mostrar todos</a></em></div>
  </dd>
</dl>
</body></html>
''';

void main() {
  test('reconoce las direcciones de las fichas', () {
    expect(idFichaFilmaffinity(_url), '123456');
    expect(
      idFichaFilmaffinity('https://www.filmaffinity.com/us/film123456.html'),
      '123456',
    );
    expect(fichaEnEspanol(_url), isTrue);
    expect(
      fichaEnEspanol('https://www.filmaffinity.com/us/film123456.html'),
      isFalse,
    );
    expect(
      idFichaFilmaffinity('https://www.filmaffinity.com/es/search.php?x=1'),
      isNull,
    );
    expect(
      busquedaFilmaffinity('Origen꞉ 2'),
      'https://www.filmaffinity.com/es/search.php?stype=title&stext=Origen%3A+2',
    );
  });

  test('lee todos los apartados de la ficha', () {
    final f = leerFichaFilmaffinity(_pagina, _url)!;
    expect(f.id, '123456');
    expect(f.titulo, 'El Faro del Norte');
    expect(f.tituloOriginal, 'The Northern Lighthouse');
    expect(f.anio, 1998);
    expect(f.duracionMin, 112);
    expect(f.pais, 'Reino Unido');
    expect(f.direccion, ['Ana Pérez', 'John Smith']);
    // Solo el guion, no la novela.
    expect(f.guion, ['Ana Pérez']);
    expect(f.reparto, ['Actor Uno', 'Actriz Dos']);
    expect(f.musica, ['Compositor Tres']);
    expect(f.fotografia, ['Luz Cuatro']);
    // Solo las compañías, no el productor.
    expect(f.productoras, ['Estudios Uno', 'Films; Dos']);
    expect(f.generos, ['Drama', 'Thriller']);
    expect(f.temas, ['Faros', 'Años 50']);
    expect(f.sinopsis, 'Un farero descubre algo raro en la costa.');
    expect(f.premios, [
      '1998: Premios Inventados: Mejor fotografía. 3 nom.',
      '1999: Festival de Mentira: Sección oficial',
    ]);
  });

  test('lo pasa a los campos de la ficha con tu formato', () {
    final datos = leerFichaFilmaffinity(_pagina, _url)!.datos();
    String v(Campo c) => datos[c]!.valor;
    expect(datos.containsKey(Campo.titulo), isFalse);
    expect(v(Campo.generos), 'Drama. Thriller');
    expect(v(Campo.temas), 'Faros; Años 50');
    expect(v(Campo.direccion), 'Ana Pérez, John Smith');
    // Sin «;», que Windows tomaría como separador.
    expect(v(Campo.productora), 'Estudios Uno, Films, Dos');
    expect(
      v(Campo.premios),
      '1998: Premios Inventados: Mejor fotografía. 3 nom. · '
      '1999: Festival de Mentira: Sección oficial',
    );
    expect(v(Campo.enlaceFilmaffinity), _url);
    expect(datos.values.every((d) => d.origen == 'FilmAffinity'), isTrue);
  });

  test('comprueba título, año y director', () {
    final f = leerFichaFilmaffinity(_pagina, _url)!;
    final buena = f.comparar((
      titulo: 'El faro del norte',
      tituloOriginal: '',
      anio: 1999,
      direccion: 'John Smith',
    ));
    expect([buena.titulo, buena.anio, buena.director], [true, true, true]);
    final mala = (
      titulo: 'Northern Lighthouse',
      tituloOriginal: '',
      anio: 2005,
      direccion: 'Otro Director',
    );
    expect(
      f.explicacion(mala),
      'Coincide título; no coinciden año (1998) y director '
      '(Ana Pérez, John Smith).',
    );
  });

  test('una página que no es una ficha no se lee', () {
    expect(
      leerFichaFilmaffinity('<html><title>Un momento…</title></html>', _url),
      isNull,
    );
    expect(
      leerFichaFilmaffinity(
        _pagina,
        'https://www.filmaffinity.com/es/search.php?stext=faro',
      ),
      isNull,
    );
  });
}
