import 'package:flutter_test/flutter_test.dart';
import 'package:videoteca/datos/pendientes.dart';
import 'package:videoteca/modelos/pelicula.dart';

/// Película con todos los datos importantes rellenos (salvo lo que se cambie).
Pelicula _p(
  int id,
  String ruta, {
  String? titulo,
  int anio = 2010,
  String edad = 'No recomendado para menores de 12 años',
  String sinopsis = 'Algo pasa.',
  bool caratula = true,
  DateTime? desaparecida,
}) => Pelicula(
  id: id,
  titulo: titulo ?? ruta.split(r'\').last.split(' (').first,
  anio: anio,
  ruta: ruta,
  tituloOriginal: 'Original',
  generos: const ['Drama'],
  sinopsis: sinopsis,
  direccion: 'Alguien',
  reparto: 'Gente',
  musica: 'Alguien',
  productora: 'Productora',
  clasificacion: edad,
  estrellas: 3,
  tieneCaratula: caratula,
  desaparecida: desaparecida,
);

void main() {
  final catalogo = [
    _p(1, r'D:\Comedias\Comedia\Origen (2010).mp4'),
    _p(2, r'D:\Suspense\Thriller\Origen (2010).mp4'),
    _p(
      3,
      r'D:\Ciencia\Ciencia\Predator (2018).mp4',
      titulo: 'Depredador 4',
      anio: 2018,
    ),
    _p(4, r'D:\Ciencia\Ciencia\Depredador 4 (2018).mp4', anio: 2018),
    _p(5, r'D:\Drama\Drama\Bien (2001).mp4', anio: 2001),
    _p(
      6,
      r'D:\Drama\Drama\Sin Datos (2003).mp4',
      anio: 2003,
      sinopsis: '',
      edad: '',
    ),
    _p(7, r'D:\Anim\Anim\Supermascotas (2022).mp4', anio: 20222),
    _p(8, r'D:\Anim\Anim\Caballero 3 (2008).mp4', anio: 2012),
    _p(
      9,
      r'D:\Anim\Anim\Jurassic (2018).mp4',
      anio: 2018,
      edad: 'Michael Giacchino',
    ),
    _p(
      10,
      r'D:\Anim\Anim\Errata (2018).mp4',
      anio: 2018,
      edad: 'No recomendado para menores de 16 año',
    ),
    _p(11, r'D:\Anim\Anim\Pato (1990)-1.mp4', anio: 1990),
    _p(12, r'D:\Anim\Anim\Sin Cara (1999).mp4', anio: 1999, caratula: false),
  ];
  final r = buscarPendientes(
    catalogo,
    desaparecidas: [
      _p(
        13,
        r'D:\Drama\Drama\Ida (2013).mp4',
        anio: 2013,
        desaparecida: DateTime(2026, 10, 4),
      ),
    ],
  );
  List<int> ids(TipoPendiente t) =>
      [for (final p in r.pendientes[t]!) ...p.peliculas.map((x) => x.id)]
        ..sort();

  test('duplicadas por título y año o por nombre de archivo', () {
    expect(r.pendientes[TipoPendiente.duplicadas], hasLength(2));
    expect(ids(TipoPendiente.duplicadas), [1, 2, 3, 4]);
  });

  test('incompletas dice qué falta', () {
    final inc = r.pendientes[TipoPendiente.incompletas]!.single;
    expect(inc.pelicula.id, 6);
    expect(inc.motivos.single, 'Falta: Sinopsis, Edad');
  });

  test('datos que revisar', () {
    expect(ids(TipoPendiente.datosRaros), [7, 8, 9, 10]);
    String motivo(int id) => r.pendientes[TipoPendiente.datosRaros]!
        .firstWhere((p) => p.pelicula.id == id)
        .motivos
        .single;
    expect(motivo(7), 'El año «20222» no es posible');
    expect(motivo(8), 'El nombre dice 2008 y los datos 2012');
    expect(motivo(9), 'La edad dice «Michael Giacchino»');
    expect(motivo(10), contains('mal escrita'));
  });

  test('nombre fuera de formato, sin carátula y desaparecidas', () {
    final fuera = r.pendientes[TipoPendiente.fueraDeFormato]!.single;
    expect(fuera.pelicula.id, 11);
    expect(fuera.motivos.single, 'Sobra «-1» después del año');
    expect(ids(TipoPendiente.sinCaratula), [12]);
    expect(ids(TipoPendiente.desaparecidas), [13]);
    expect(
      r.pendientes[TipoPendiente.desaparecidas]!.single.motivos.single,
      'No está desde el 04/10/2026',
    );
  });

  test('lo revisado sale aparte', () {
    final clave = r.pendientes[TipoPendiente.fueraDeFormato]!.single.clave;
    final otra = buscarPendientes(catalogo, revisados: {clave});
    expect(otra.pendientes[TipoPendiente.fueraDeFormato], isEmpty);
    expect(otra.revisados[TipoPendiente.fueraDeFormato], hasLength(1));
  });
}
