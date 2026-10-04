import 'package:flutter_test/flutter_test.dart';
import 'package:videoteca/datos/buscador.dart';

DatosBuscables _p(
  int id,
  String titulo, {
  String original = '',
  int anio = 2000,
  String direccion = '',
  String reparto = '',
}) => (
  id: id,
  titulo: titulo,
  tituloOriginal: original,
  anio: anio,
  direccion: direccion,
  reparto: reparto,
);

void main() {
  final buscador = Buscador([
    _p(
      1,
      'Los Vengadores 3꞉ Infinity War',
      original: 'Avengers: Infinity War',
      anio: 2018,
      direccion: 'Anthony Russo, Joe Russo',
      reparto: 'Robert Downey Jr., Chris Hemsworth',
    ),
    _p(2, 'Los Vengadores 1', original: 'The Avengers', anio: 2012),
    _p(3, '¡Átame!', anio: 1989, direccion: 'Pedro Almodóvar'),
    _p(4, 'Spider-Man 2', anio: 2004, reparto: 'Tobey Maguire'),
    _p(5, 'Forrest Gump', anio: 1994, reparto: 'Tom Hanks, Robin Wright'),
    _p(6, 'Big', anio: 1988, reparto: 'Tom Hanks'),
    _p(7, 'The Great American Chase', anio: 1979),
    _p(8, 'Ocean\'s Eleven', anio: 2001),
  ]);

  List<int> ids(String consulta, [AmbitoBusqueda a = AmbitoBusqueda.todo]) => [
    for (final c in buscador.buscar(consulta, ambito: a)) c.id,
  ];

  test('limpia tildes, mayúsculas y signos', () {
    expect(limpiarParaBuscar('¡Átame!'), 'atame');
    expect(
      limpiarParaBuscar('Los Vengadores 3꞉ Infinity War'),
      'los vengadores 3 infinity war',
    );
    expect(limpiarParaBuscar("Ocean's Eleven"), 'oceans eleven');
    expect(limpiarParaBuscar('S.W.A.T.'), 'swat');
    expect(limpiarParaBuscar('España'), 'espana');
  });

  test('encuentra por título sin importar tildes ni mayúsculas', () {
    expect(ids('vengadores'), [2, 1]); // por orden alfabético
    expect(ids('VENGADORES'), [2, 1]);
    expect(ids('atame'), [3]);
    expect(ids('ÁTAME'), [3]);
    expect(ids('oceans'), [8]);
  });

  test('autocompleta con palabras a medias y en cualquier orden', () {
    expect(ids('veng'), [2, 1]);
    expect(ids('infinity veng'), [1]);
  });

  test('encuentra por título original, actor y director', () {
    expect(ids('avengers'), containsAll([1, 2]));
    expect(ids('almodovar'), [3]);
    expect(ids('tom hanks'), [6, 5]);
    expect(buscador.buscar('hanks').first.persona, 'Tom Hanks');
  });

  test('«spiderman» encuentra «Spider-Man», pero no letras sueltas', () {
    expect(ids('spiderman'), [4]);
    // «atame» no debe salir en «Gre-at Ame-rican».
    expect(ids('atame'), isNot(contains(7)));
  });

  test('el título exacto va primero', () {
    expect(ids('big').first, 6);
  });

  test('lo que está a mitad de palabra va detrás', () {
    final b = Buscador([
      _p(1, 'Phantoms', anio: 1998),
      _p(2, 'Big', reparto: 'Tom Hanks'),
    ]);
    expect([for (final c in b.buscar('tom ha')) c.id], [2, 1]);
  });

  test('se puede buscar solo en un campo', () {
    expect(ids('tom', AmbitoBusqueda.titulos), isEmpty);
    expect(ids('tom', AmbitoBusqueda.actores), [6, 5]);
    expect(ids('russo', AmbitoBusqueda.directores), [1]);
    expect(ids('russo', AmbitoBusqueda.actores), isEmpty);
  });

  test('título y año juntos', () {
    expect(ids('vengadores 2012'), [2]);
  });

  test('sugiere personas con su número de películas', () {
    final p = buscador.personas('tom ha');
    expect(p.single.nombre, 'Tom Hanks');
    expect(p.single.total, 2);
    expect(p.single.rol, Rol.actor);
    expect(buscador.personas('to'), isEmpty); // menos de 3 letras
  });

  test('sin resultados', () {
    expect(ids('xyzzy'), isEmpty);
    expect(ids('   '), isEmpty);
  });
}
