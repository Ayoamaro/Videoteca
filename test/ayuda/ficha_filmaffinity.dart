import 'dart:convert';
import 'dart:typed_data';

// Una ficha de FilmAffinity inventada que imita la estructura de las de
// verdad (los textos son de mentira), y lo que guarda Windows al copiarla
// del navegador.

const urlFichaEjemplo = 'https://www.filmaffinity.com/es/film123456.html';

const paginaFilmaffinity = '''
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

/// Lo que guarda el navegador en el portapapeles («HTML Format» de Windows)
/// al copiar la página [html] de la dirección [url]: una cabecera con las
/// posiciones en bytes y el HTML con el trozo copiado marcado.
Uint8List htmlCopiado(String html, {String url = urlFichaEjemplo}) {
  const marca = '<!--StartFragment-->';
  final cuerpo = '<html><body>$marca$html<!--EndFragment--></body></html>';
  String cabecera(int a, int b, int c, int d) =>
      'Version:0.9\r\n'
      'StartHTML:${a.toString().padLeft(10, '0')}\r\n'
      'EndHTML:${b.toString().padLeft(10, '0')}\r\n'
      'StartFragment:${c.toString().padLeft(10, '0')}\r\n'
      'EndFragment:${d.toString().padLeft(10, '0')}\r\n'
      'SourceURL:$url\r\n';
  final largo = utf8.encode(cabecera(0, 0, 0, 0)).length;
  final bytesCuerpo = utf8.encode(cuerpo);
  final inicioTrozo = largo + utf8.encode('<html><body>$marca').length;
  final finTrozo =
      largo + utf8.encode(cuerpo.split('<!--EndFragment-->').first).length;
  return Uint8List.fromList([
    ...utf8.encode(
      cabecera(largo, largo + bytesCuerpo.length, inicioTrozo, finTrozo),
    ),
    ...bytesCuerpo,
    0,
  ]);
}
