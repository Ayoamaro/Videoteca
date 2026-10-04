import 'package:flutter_test/flutter_test.dart';
import 'package:videoteca/datos/buscador.dart';
import 'package:videoteca/datos/filtros.dart';
import 'package:videoteca/modelos/pelicula.dart';

Pelicula _p(
  int id,
  String titulo,
  int anio, {
  String ruta = r'D:\Comedias\Comedia\x.mp4',
  String grupo = 'Comedias',
  List<String> generos = const [],
  String direccion = '',
  String reparto = '',
  String pais = '',
  int estrellas = 0,
  String edad = '',
  String saga = '',
}) => Pelicula(
  id: id,
  titulo: titulo,
  anio: anio,
  ruta: ruta,
  grupo: grupo,
  generos: generos,
  direccion: direccion,
  reparto: reparto,
  pais: pais,
  estrellas: estrellas,
  clasificacion: edad,
  saga: saga,
);

void main() {
  final peliculas = [
    _p(
      1,
      '¡Átame!',
      1989,
      ruta: r'D:\Drama y Musical\Drama\Átame (1989).mp4',
      grupo: 'Drama y Musical',
      direccion: 'Pedro Almodóvar',
      reparto: 'Antonio Banderas, Victoria Abril',
      pais: 'España',
      estrellas: 4,
      edad: 'No recomendado para menores de 18 años',
    ),
    _p(
      2,
      'Big',
      1988,
      ruta: r'D:\Comedias\Comedia\Big (1988).mp4',
      direccion: 'Penny Marshall',
      reparto: 'Tom Hanks',
      pais: 'Estados Unidos',
      estrellas: 3,
      edad: 'Apto para todos los públicos',
    ),
    _p(
      3,
      'Forrest Gump',
      1994,
      ruta: r'D:\Drama y Musical\Drama\Forrest Gump (1994).mp4',
      grupo: 'Drama y Musical',
      generos: ['Comedia', 'Drama'],
      direccion: 'Robert Zemeckis',
      reparto: 'Tom Hanks, Robin Wright',
      pais: 'Estados Unidos',
      estrellas: 4,
      edad: 'No recomendado para menores de 13 años',
    ),
    _p(
      4,
      'Toy Story',
      1995,
      ruta: r'D:\Animación\Animación\Toy Story (1995).mp4',
      grupo: 'Animación',
      generos: ['Animación'],
      reparto: 'Tom Hanks',
      estrellas: 5,
      saga: 'Toy Story',
    ),
    _p(5, 'Año mal escrito', 20222, estrellas: 2),
  ];

  List<int> ids(Filtros f) => [for (final p in f.aplicar(peliculas)) p.id];

  test('sin filtros pasan todas', () {
    expect(ids(Filtros.ninguno), [1, 2, 3, 4, 5]);
    expect(Filtros.ninguno.vacios, isTrue);
  });

  test('género: el de la ficha, sin importar tildes ni mayúsculas', () {
    expect(ids(const Filtros(generos: {'Comedia'})), [3]);
    expect(ids(const Filtros(generos: {'animacion'})), [4]);
    // Varias opciones del mismo grupo: vale cualquiera.
    expect(ids(const Filtros(generos: {'Drama', 'Animación'})), [3, 4]);
  });

  test('carpeta: de primer o de segundo nivel', () {
    expect(ids(const Filtros(grupos: {'Drama y Musical'})), [1, 3]);
    expect(ids(const Filtros(subcarpetas: {'Comedia'})), [2, 5]);
    // Basta con estar en una de las marcadas.
    expect(
      ids(const Filtros(grupos: {'Animación'}, subcarpetas: {'Comedia'})),
      [2, 4, 5],
    );
  });

  test('grupos distintos se combinan', () {
    const f = Filtros(subcarpetas: {'Drama'}, estrellasMin: 4);
    expect(ids(f), [1, 3]);
    expect(ids(f.copyWith(generos: {'Comedia'})), [3]);
    expect(f.activos, 2);
  });

  test('carpeta, país, edad y saga', () {
    expect(ids(const Filtros(paises: {'Estados Unidos'})), [2, 3]);
    expect(ids(const Filtros(edades: {'TP', '13'})), [2, 3]);
    expect(ids(const Filtros(edades: {''})), [4, 5]);
    expect(ids(const Filtros(sagas: {'Toy Story'})), [4]);
  });

  test('años: rango, y los años mal escritos se quedan fuera', () {
    expect(ids(const Filtros(desde: 1990)), [3, 4]);
    expect(ids(const Filtros(hasta: 1989)), [1, 2]);
    expect(ids(const Filtros(desde: 1980, hasta: 1989)), [1, 2]);
  });

  test('director y actor, sin importar tildes ni mayúsculas', () {
    expect(ids(const Filtros(director: 'pedro almodovar')), [1]);
    expect(ids(const Filtros(actor: 'Tom Hanks')), [2, 3, 4]);
    // Tiene que ser el nombre completo, no un trozo.
    expect(ids(const Filtros(actor: 'Tom')), isEmpty);
  });

  test('facetas: cuentan cada opción con el resto de filtros', () {
    final f = Facetas(peliculas, const Filtros(actor: 'Tom Hanks'));
    expect(f.grupos, {'Comedias': 1, 'Drama y Musical': 1, 'Animación': 1});
    expect(f.subcarpetas, {'Comedia': 1, 'Drama': 1, 'Animación': 1});
    expect(f.decadas, {1980: 1, 1990: 2});
    expect(f.conAlMenos(4), 2);
    expect(f.edades, {'TP': 1, '13': 1, '': 1});
    // El propio grupo no se filtra a sí mismo: con "Comedia" marcada se
    // sigue viendo cuántas hay de los demás géneros.
    final g = Facetas(peliculas, const Filtros(generos: {'Comedia'}));
    expect(g.generos, {'comedia': 1, 'drama': 1, 'animacion': 1});
    // El año 20222 no estira la barra de años.
    expect(Facetas(peliculas, Filtros.ninguno).anioMax, 1995);
  });

  test('personas: se juntan aunque cambien las tildes', () {
    final lista = contarNombres([
      _p(1, 'a', 2000, direccion: 'Pedro Almodóvar'),
      _p(2, 'b', 2001, direccion: 'Pedro Almodovar'),
      _p(3, 'c', 2002, direccion: 'Anthony Russo, Joe Russo'),
    ], (p) => separarNombres(p.direccion));
    expect(lista.first, ('Pedro Almodóvar', 2));
    expect(lista.length, 3);
  });

  test('edades en orden', () {
    expect((['18', '', 'TP', '13', '7']..sort(compararEdades)), [
      'TP',
      '7',
      '13',
      '18',
      '',
    ]);
  });
}
