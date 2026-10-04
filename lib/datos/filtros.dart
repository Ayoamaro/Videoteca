import '../modelos/pelicula.dart';
import 'buscador.dart';

// Filtros combinables del Catálogo. Aquí solo está la lógica (qué películas
// pasan y cuántas hay de cada opción); el panel que se ve está en
// `pantallas/catalogo.dart`.

/// Años que se consideran válidos (un año mal escrito, p. ej. 20222, no
/// estira la barra de años).
const anioMinimoValido = 1880;
final anioMaximoValido = DateTime.now().year + 2;
bool anioValido(int anio) =>
    anio >= anioMinimoValido && anio <= anioMaximoValido;

/// Edad corta para filtrar: "TP", "7", "12"… o "" si no tiene.
String edadDe(Pelicula p) => _cacheEdades[p] ??= p.edadCorta;

/// Países de una película (el campo puede traer varios: "EE. UU., Reino Unido").
List<String> paisesDe(Pelicula p) => _cachePaises[p] ??= separarNombres(p.pais);

/// Los filtros elegidos. Cada grupo con varias opciones marcadas deja pasar
/// las películas que cumplan **alguna** (p. ej. Comedia o Drama); grupos
/// distintos se combinan: tienen que cumplirse **todos**.
class Filtros {
  const Filtros({
    this.generos = const {},
    this.grupos = const {},
    this.subcarpetas = const {},
    this.desde,
    this.hasta,
    this.paises = const {},
    this.estrellasMin = 0,
    this.edades = const {},
    this.sagas = const {},
    this.director,
    this.actor,
  });

  /// Géneros de la ficha ("Comedia", "Drama"…; una película puede tener
  /// varios).
  final Set<String> generos;

  /// Carpetas donde están: de primer nivel ("Comedias") o de segundo
  /// ("Romance", dentro de "Comedias"). Basta con estar en una.
  final Set<String> grupos;
  final Set<String> subcarpetas;

  bool get hayCarpeta => grupos.isNotEmpty || subcarpetas.isNotEmpty;

  /// Años, ambos incluidos. `null` = sin límite.
  final int? desde;
  final int? hasta;

  final Set<String> paises;

  /// Mínimo de estrellas (0 = cualquiera).
  final int estrellasMin;

  /// Edades cortas: "TP", "7", "12"… ("" = sin clasificar).
  final Set<String> edades;

  final Set<String> sagas;
  final String? director;
  final String? actor;

  static const ninguno = Filtros();

  bool get hayAnio => desde != null || hasta != null;

  /// Cuántos grupos de filtros hay activos.
  int get activos => [
    generos.isNotEmpty,
    hayCarpeta,
    hayAnio,
    paises.isNotEmpty,
    estrellasMin > 0,
    edades.isNotEmpty,
    sagas.isNotEmpty,
    director != null,
    actor != null,
  ].where((a) => a).length;

  bool get vacios => activos == 0;

  Filtros copyWith({
    Set<String>? generos,
    Set<String>? grupos,
    Set<String>? subcarpetas,
    int? Function()? desde,
    int? Function()? hasta,
    Set<String>? paises,
    int? estrellasMin,
    Set<String>? edades,
    Set<String>? sagas,
    String? Function()? director,
    String? Function()? actor,
  }) => Filtros(
    generos: generos ?? this.generos,
    grupos: grupos ?? this.grupos,
    subcarpetas: subcarpetas ?? this.subcarpetas,
    desde: desde == null ? this.desde : desde(),
    hasta: hasta == null ? this.hasta : hasta(),
    paises: paises ?? this.paises,
    estrellasMin: estrellasMin ?? this.estrellasMin,
    edades: edades ?? this.edades,
    sagas: sagas ?? this.sagas,
    director: director == null ? this.director : director(),
    actor: actor == null ? this.actor : actor(),
  );

  /// Marca o desmarca [valor] en un conjunto (devuelve uno nuevo).
  static Set<String> alternar(Set<String> conjunto, String valor, bool si) =>
      si ? {...conjunto, valor} : ({...conjunto}..remove(valor));

  /// ¿Pasa la película todos los filtros? Con [salvo] se ignora un grupo
  /// (sirve para contar cuántas habría de cada opción de ese grupo).
  bool deja(Pelicula p, {Grupo? salvo}) {
    if (salvo != Grupo.genero && generos.isNotEmpty) {
      if (!_generosLimpios.any(generosDe(p).contains)) return false;
    }
    if (salvo != Grupo.carpeta && hayCarpeta) {
      if (!grupos.contains(p.grupo) && !subcarpetas.contains(p.generoCarpeta)) {
        return false;
      }
    }
    if (salvo != Grupo.anio && hayAnio) {
      if (!anioValido(p.anio)) return false;
      if (desde != null && p.anio < desde!) return false;
      if (hasta != null && p.anio > hasta!) return false;
    }
    if (salvo != Grupo.pais && paises.isNotEmpty) {
      if (!paisesDe(p).any(paises.contains)) return false;
    }
    if (salvo != Grupo.estrellas && p.estrellas < estrellasMin) return false;
    if (salvo != Grupo.edad && edades.isNotEmpty) {
      if (!edades.contains(edadDe(p))) return false;
    }
    if (salvo != Grupo.saga && sagas.isNotEmpty) {
      if (!sagas.contains(p.saga)) return false;
    }
    if (salvo != Grupo.director && director != null) {
      if (!_directoresDe(p).contains(_directorLimpio)) return false;
    }
    if (salvo != Grupo.actor && actor != null) {
      if (!_actoresDe(p).contains(_actorLimpio)) return false;
    }
    return true;
  }

  List<Pelicula> aplicar(Iterable<Pelicula> peliculas) =>
      vacios ? peliculas.toList() : peliculas.where(deja).toList();

  // Los nombres se comparan "limpios" (sin tildes ni mayúsculas): «Pedro
  // Almodovar» = «Pedro Almodóvar».
  _Limpios get _limpios => _cacheFiltros[this] ??= (
    generos: generos.map(limpiarParaBuscar).toSet(),
    director: limpiarParaBuscar(director ?? ''),
    actor: limpiarParaBuscar(actor ?? ''),
  );
  Set<String> get _generosLimpios => _limpios.generos;
  String get _directorLimpio => _limpios.director;
  String get _actorLimpio => _limpios.actor;
}

typedef _Limpios = ({Set<String> generos, String director, String actor});
final _cacheFiltros = Expando<_Limpios>();

// Lo que se compara de cada película se limpia una sola vez y se recuerda
// (un `Expando` es como una nota pegada a cada película): así filtrar las
// 5.541 tarda unos pocos milisegundos.
final _cacheGeneros = Expando<Set<String>>();
final _cacheEdades = Expando<String>();
final _cachePaises = Expando<List<String>>();
final _cacheDirectores = Expando<Set<String>>();
final _cacheActores = Expando<Set<String>>();

/// Géneros de la ficha, limpios: «Ciencia ficción» → «ciencia ficcion».
Set<String> generosDe(Pelicula p) =>
    _cacheGeneros[p] ??= {for (final g in p.generos) limpiarParaBuscar(g)};
Set<String> _directoresDe(Pelicula p) => _cacheDirectores[p] ??= {
  for (final n in separarNombres(p.direccion)) limpiarParaBuscar(n),
};
Set<String> _actoresDe(Pelicula p) => _cacheActores[p] ??= {
  for (final n in separarNombres(p.reparto)) limpiarParaBuscar(n),
};

/// Grupos de filtros.
enum Grupo {
  genero,
  carpeta,
  anio,
  pais,
  estrellas,
  edad,
  saga,
  director,
  actor,
}

/// Cuántas películas hay de cada opción, teniendo en cuenta el **resto** de
/// filtros (como en las tiendas: al marcar "Comedia" los años muestran
/// cuántas comedias hay de cada década).
class Facetas {
  Facetas(Iterable<Pelicula> peliculas, Filtros f) {
    for (final p in peliculas) {
      if (f.deja(p, salvo: Grupo.genero)) {
        for (final g in generosDe(p)) {
          _sumar(generos, g);
        }
      }
      if (f.deja(p, salvo: Grupo.carpeta)) {
        _sumar(grupos, p.grupo);
        _sumar(subcarpetas, p.generoCarpeta);
      }
      if (f.deja(p, salvo: Grupo.anio) && anioValido(p.anio)) {
        _sumar(decadas, p.anio ~/ 10 * 10);
        if (anioMin == null || p.anio < anioMin!) anioMin = p.anio;
        if (anioMax == null || p.anio > anioMax!) anioMax = p.anio;
      }
      if (f.deja(p, salvo: Grupo.pais)) {
        for (final pais in paisesDe(p)) {
          _sumar(paises, pais);
        }
      }
      if (f.deja(p, salvo: Grupo.estrellas)) {
        _sumar(estrellas, p.estrellas.clamp(0, 5));
      }
      if (f.deja(p, salvo: Grupo.edad)) _sumar(edades, edadDe(p));
      if (f.deja(p, salvo: Grupo.saga) && p.saga.isNotEmpty) {
        _sumar(sagas, p.saga);
      }
    }
  }

  /// Por género **limpio** (ver [generosDe]).
  final generos = <String, int>{};
  final grupos = <String, int>{};
  final subcarpetas = <String, int>{};
  final decadas = <int, int>{};
  final paises = <String, int>{};
  final estrellas = <int, int>{};
  final edades = <String, int>{};
  final sagas = <String, int>{};
  int? anioMin;
  int? anioMax;

  static void _sumar<T>(Map<T, int> mapa, T clave) =>
      mapa[clave] = (mapa[clave] ?? 0) + 1;

  /// Películas con al menos [n] estrellas.
  int conAlMenos(int n) => estrellas.entries
      .where((e) => e.key >= n)
      .fold(0, (suma, e) => suma + e.value);

  /// Opciones de un mapa ordenadas de más a menos películas.
  static List<(String, int)> ordenadas(Map<String, int> mapa) =>
      [
        for (final e in mapa.entries)
          if (e.key.isNotEmpty) (e.key, e.value),
      ]..sort((a, b) {
        final c = b.$2.compareTo(a.$2);
        return c != 0 ? c : a.$1.compareTo(b.$1);
      });
}

/// Orden de las edades para mostrarlas: TP, 7, 10, 12… y al final "sin
/// clasificar".
int compararEdades(String a, String b) {
  int valor(String e) =>
      e == 'TP' ? 0 : (e.isEmpty ? 999 : int.tryParse(e) ?? 998);
  return valor(a).compareTo(valor(b));
}

/// Nombres (géneros, directores, actores…) de la colección con su número de
/// películas, de más a menos. Se juntan los que solo cambian en tildes o
/// mayúsculas («Cine negro» y «Cine Negro»).
List<(String, int)> contarNombres(
  Iterable<Pelicula> peliculas,
  Iterable<String> Function(Pelicula) nombres,
) {
  final cuenta = <String, (String, int)>{};
  for (final p in peliculas) {
    for (final nombre in nombres(p)) {
      final clave = limpiarParaBuscar(nombre);
      final previo = cuenta[clave];
      cuenta[clave] = (previo?.$1 ?? nombre, (previo?.$2 ?? 0) + 1);
    }
  }
  return cuenta.values.toList()..sort((a, b) => b.$2.compareTo(a.$2));
}
