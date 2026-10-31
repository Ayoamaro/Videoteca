import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:videoteca/disco/escritor.dart' show Campo;
import 'package:videoteca/fuentes/filmaffinity.dart';

import 'ayuda/ficha_filmaffinity.dart';

// Pruebas del lector de fichas de FilmAffinity con una página inventada que
// imita la estructura de las de verdad (ver `ayuda/ficha_filmaffinity.dart`).

void main() {
  test('reconoce las direcciones de las fichas', () {
    expect(idFichaFilmaffinity(urlFichaEjemplo), '123456');
    expect(
      idFichaFilmaffinity('https://www.filmaffinity.com/us/film123456.html'),
      '123456',
    );
    expect(fichaEnEspanol(urlFichaEjemplo), isTrue);
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
    final f = leerFichaFilmaffinity(paginaFilmaffinity, urlFichaEjemplo)!;
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
    final datos = leerFichaFilmaffinity(
      paginaFilmaffinity,
      urlFichaEjemplo,
    )!.datos();
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
    expect(v(Campo.enlaceFilmaffinity), urlFichaEjemplo);
    expect(datos.values.every((d) => d.origen == 'FilmAffinity'), isTrue);
  });

  test('comprueba título, año y director', () {
    final f = leerFichaFilmaffinity(paginaFilmaffinity, urlFichaEjemplo)!;
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
      leerFichaFilmaffinity(
        '<html><title>Un momento…</title></html>',
        urlFichaEjemplo,
      ),
      isNull,
    );
    expect(
      leerFichaFilmaffinity(
        paginaFilmaffinity,
        'https://www.filmaffinity.com/es/search.php?stext=faro',
      ),
      isNull,
    );
  });

  group('Ficha copiada del navegador (issue #5)', () {
    test('se lee lo copiado en «HTML Format»', () {
      final copiado = leerHtmlCopiado(htmlCopiado(paginaFilmaffinity))!;
      expect(copiado.url, urlFichaEjemplo);
      expect(copiado.html, contains('El Faro del Norte'));
      final r = fichaCopiada(htmlCopiado(paginaFilmaffinity));
      expect(r.fallo, isNull);
      expect(r.ficha!.titulo, 'El Faro del Norte');
      expect(r.ficha!.anio, 1998);
      expect(r.ficha!.temas, isNotEmpty);
    });

    test('con tildes y eñes (posiciones en bytes UTF-8)', () {
      final r = fichaCopiada(
        htmlCopiado(paginaFilmaffinity.replaceAll('Norte', 'Señor Ñandú')),
      );
      expect(r.ficha!.titulo, 'El Faro del Señor Ñandú');
    });

    test('lo que no sirve dice por qué', () {
      expect(fichaCopiada(null).fallo, FalloCopiado.nada);
      expect(
        fichaCopiada(null, texto: urlFichaEjemplo).fallo,
        FalloCopiado.soloDireccion,
      );
      expect(
        fichaCopiada(null, texto: 'Me gusta filmaffinity.com/es/').fallo,
        FalloCopiado.nada,
      );
      expect(
        fichaCopiada(Uint8List.fromList('hola'.codeUnits)).fallo,
        FalloCopiado.nada,
      );
      expect(
        fichaCopiada(
          htmlCopiado('<p>Hola</p>', url: 'https://www.imdb.com/title/tt1/'),
        ).fallo,
        FalloCopiado.otraWeb,
      );
      expect(
        fichaCopiada(
          htmlCopiado(
            '<p>Resultados</p>',
            url: busquedaFilmaffinity('El faro'),
          ),
        ).fallo,
        FalloCopiado.noEsFicha,
      );
      expect(
        fichaCopiada(
          htmlCopiado(
            paginaFilmaffinity,
            url: 'https://www.filmaffinity.com/us/film123456.html',
          ),
        ).fallo,
        FalloCopiado.otroIdioma,
      );
    });
  });
}
