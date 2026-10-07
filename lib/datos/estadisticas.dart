import '../fuentes/sagas.dart';
import '../modelos/pelicula.dart';
import 'buscador.dart' show separarNombres;
import 'filtros.dart';

// Estadísticas de la colección: cuántas películas hay por género, década y
// país, qué directores y actores salen más y qué sagas están incompletas.
// Aquí solo están las cuentas; la pantalla está en `pantallas/estadisticas.dart`.
//
// No usa nada de Flutter.

/// Una saga de la que faltan películas.
class SagaIncompleta {
  const SagaIncompleta({
    required this.nombre,
    required this.tengo,
    required this.total,
    required this.faltan,
    required this.segunTmdb,
  });

  /// Nombre como está en tus fichas (para filtrar el Catálogo).
  final String nombre;
  final int tengo;
  final int total;

  /// Las que faltan: «Título (año)» si se sabe por TMDB; si no, «Nº 3».
  final List<String> faltan;

  /// El total viene de TMDB. Si no, se deduce de los números de las que
  /// tienes (con la 1 y la 4, faltan la 2 y la 3; si falta la última, no se
  /// puede saber).
  final bool segunTmdb;
}

class Estadisticas {
  const Estadisticas({
    required this.peliculas,
    required this.minutos,
    required this.bytes,
    required this.conCaratula,
    required this.mediaEstrellas,
    required this.generos,
    required this.decadas,
    required this.paises,
    required this.directores,
    required this.actores,
    required this.sagas,
    required this.sagasCompletas,
    required this.sagasIncompletas,
    this.masAntigua,
    this.masLarga,
  });

  final int peliculas;
  final int minutos;
  final int bytes;
  final int conCaratula;

  /// Media de las que tienen estrellas (0 si ninguna).
  final double mediaEstrellas;

  /// Nombre y número de películas, de más a menos.
  final List<(String, int)> generos;
  final List<(String, int)> paises;
  final List<(String, int)> directores;
  final List<(String, int)> actores;

  /// Cada década (1980, 1990…) con su número de películas, de la más antigua
  /// a la más reciente, sin saltarse ninguna (las vacías, con 0).
  final List<(int, int)> decadas;

  /// Sagas con al menos dos películas, completas o no.
  final int sagas;
  final int sagasCompletas;

  /// Las que faltan menos, primero.
  final List<SagaIncompleta> sagasIncompletas;

  final Pelicula? masAntigua;
  final Pelicula? masLarga;

  /// Hace las cuentas con [lista]. Con [tmdb] (lo comprobado en TMDB) se
  /// sabe el total de cada saga y los títulos que faltan.
  factory Estadisticas.de(List<Pelicula> lista, {SagasTmdb? tmdb}) {
    var minutos = 0, bytes = 0, conCaratula = 0, sumaEstrellas = 0;
    var conEstrellas = 0;
    Pelicula? masAntigua, masLarga;
    final decadas = <int, int>{};
    final porSaga = <String, List<Pelicula>>{};
    for (final p in lista) {
      minutos += p.duracionMin;
      bytes += p.tamanoBytes;
      if (p.tieneCaratula) conCaratula++;
      if (p.estrellas > 0) {
        sumaEstrellas += p.estrellas;
        conEstrellas++;
      }
      if (anioValido(p.anio)) {
        decadas[p.anio ~/ 10 * 10] = (decadas[p.anio ~/ 10 * 10] ?? 0) + 1;
        if (masAntigua == null || p.anio < masAntigua.anio) masAntigua = p;
      }
      if (p.duracionMin > (masLarga?.duracionMin ?? 0)) masLarga = p;
      if (p.saga.trim().isNotEmpty) {
        porSaga.putIfAbsent(claveSaga(p.saga), () => []).add(p);
      }
    }

    final incompletas = <SagaIncompleta>[];
    var sagas = 0, completas = 0;
    for (final MapEntry(key: clave, value: suyas) in porSaga.entries) {
      final saga = _revisarSaga(suyas, tmdb?.sagas[clave]);
      if (saga == null) continue;
      if (saga.total >= 2) sagas++;
      if (saga.faltan.isEmpty) {
        if (saga.total >= 2) completas++;
      } else {
        incompletas.add(saga);
      }
    }
    incompletas.sort((a, b) {
      var c = a.faltan.length.compareTo(b.faltan.length);
      if (c == 0) c = b.tengo.compareTo(a.tengo);
      return c != 0 ? c : a.nombre.compareTo(b.nombre);
    });

    final listaDecadas = <(int, int)>[];
    if (decadas.isNotEmpty) {
      final claves = decadas.keys.toList()..sort();
      for (var d = claves.first; d <= claves.last; d += 10) {
        listaDecadas.add((d, decadas[d] ?? 0));
      }
    }

    return Estadisticas(
      peliculas: lista.length,
      minutos: minutos,
      bytes: bytes,
      conCaratula: conCaratula,
      mediaEstrellas: conEstrellas == 0 ? 0 : sumaEstrellas / conEstrellas,
      generos: contarNombres(lista, (p) => p.generos),
      decadas: listaDecadas,
      paises: contarNombres(lista, paisesDe),
      directores: contarNombres(lista, (p) => separarNombres(p.direccion)),
      actores: contarNombres(lista, (p) => separarNombres(p.reparto)),
      sagas: sagas,
      sagasCompletas: completas,
      sagasIncompletas: incompletas,
      masAntigua: masAntigua,
      masLarga: masLarga,
    );
  }

  /// Cuántas tienes de una saga y cuáles faltan. `null` si no se puede saber
  /// (ninguna lleva número y TMDB no la conoce).
  static SagaIncompleta? _revisarSaga(List<Pelicula> suyas, InfoSaga? info) {
    final nombre = suyas.first.saga.trim();
    final numeros = {
      for (final p in suyas)
        if (p.numeroSaga > 0) p.numeroSaga,
    };
    // TMDB solo sirve si sus números cuadran con los tuyos (si tienes la 9
    // y TMDB dice que hay 8, la saga de tus fichas es otra cosa).
    if (info != null &&
        info.partes.isNotEmpty &&
        numeros.every((n) => n <= info.partes.length)) {
      final n = info.partes.length;
      // Qué película de TMDB es cada una tuya, en tres pasadas: por su
      // número si el año casi coincide; si no, por el año entre las que
      // quedan; y si no, por su número aunque el año no cuadre (hay fichas
      // con el año mal: «Licencia para matar» con 1985).
      final tuyas = <int>{};
      final quedan = [...suyas];
      bool porNumero(Pelicula p, {required bool mirarAnio}) {
        final i = p.numeroSaga - 1;
        if (i < 0 || i >= n || tuyas.contains(i)) return false;
        if (mirarAnio && (info.partes[i].anio - p.anio).abs() > 1) {
          return false;
        }
        return tuyas.add(i);
      }

      bool porAnio(Pelicula p) {
        for (var i = 0; i < n; i++) {
          if (info.partes[i].anio == p.anio && tuyas.add(i)) return true;
        }
        return false;
      }

      quedan.removeWhere((p) => porNumero(p, mirarAnio: true));
      quedan.removeWhere(porAnio);
      quedan.removeWhere((p) => porNumero(p, mirarAnio: false));
      final faltan = <String>[];
      var tengo = 0;
      for (var i = 0; i < n; i++) {
        final parte = info.partes[i];
        if (tuyas.contains(i)) {
          tengo++;
        } else {
          faltan.add(
            parte.anio > 0 ? '${parte.titulo} (${parte.anio})' : parte.titulo,
          );
        }
      }
      return SagaIncompleta(
        nombre: nombre,
        tengo: tengo,
        total: n,
        faltan: faltan,
        segunTmdb: true,
      );
    }
    if (numeros.isEmpty) return null;
    final ultimo = numeros.reduce((a, b) => a > b ? a : b);
    return SagaIncompleta(
      nombre: nombre,
      tengo: numeros.length,
      total: ultimo,
      faltan: [
        for (var i = 1; i <= ultimo; i++)
          if (!numeros.contains(i)) 'Nº $i',
      ],
      segunTmdb: false,
    );
  }

  /// Años de cada saga de [lista] (lo que hay que comprobar en TMDB).
  static Map<String, Set<int>> sagasDe(Iterable<Pelicula> lista) {
    final sagas = <String, Set<int>>{};
    final nombres = <String, String>{};
    for (final p in lista) {
      if (p.saga.trim().isEmpty) continue;
      final nombre = nombres.putIfAbsent(
        claveSaga(p.saga),
        () => p.saga.trim(),
      );
      sagas.putIfAbsent(nombre, () => {}).add(p.anio);
    }
    return sagas;
  }
}
