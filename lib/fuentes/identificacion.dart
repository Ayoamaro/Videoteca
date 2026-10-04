import '../datos/buscador.dart' show limpiarParaBuscar, separarNombres;
import 'tmdb.dart';

// Identificación segura: averiguar qué película de TMDB es la de nuestro
// archivo. Solo se da por buena si coinciden las tres cosas:
// - el título (el de España o el original, admitiendo pequeñas diferencias);
// - el año (se admite ±1: el de FilmAffinity a veces es el del rodaje o el
//   del festival, y el de TMDB, el del estreno);
// - el director.
// Si hay dudas, no se rellena nada sin que lo confirmes.
//
// No usa nada de Flutter.

/// Lo que se sabe de nuestra película para identificarla.
typedef DatosIdentificacion = ({
  String titulo,
  String tituloOriginal,
  int anio,
  String direccion,
});

enum Seguridad {
  /// Título, año y director coinciden con una sola película.
  segura,

  /// Hay parecidas, pero falta algo: hay que elegir a mano.
  dudosa,

  /// TMDB no tiene nada parecido.
  noEncontrada,
}

/// Una película de TMDB y qué coincide con la nuestra.
class Candidato {
  const Candidato(
    this.ficha, {
    required this.titulo,
    required this.anio,
    required this.director,
  });

  final FichaTmdb ficha;
  final bool titulo;
  final bool anio;
  final bool director;

  int get aciertos => (titulo ? 1 : 0) + (anio ? 1 : 0) + (director ? 1 : 0);
  bool get todo => aciertos == 3;

  /// «Coinciden título y año; el director no (TMDB: Fulano)».
  String get explicacion => explicarCoincidencias(
    titulo: titulo,
    anio: anio,
    director: director,
    suAnio: ficha.anio,
    susDirectores: ficha.directores,
  );
}

/// Explica qué coincide entre nuestra película y la de una fuente («Coinciden
/// título y año; no coincide director (Fulano)»).
String explicarCoincidencias({
  required bool titulo,
  required bool anio,
  required bool director,
  required int suAnio,
  required List<String> susDirectores,
}) {
  final si = [if (titulo) 'título', if (anio) 'año', if (director) 'director'];
  final no = [
    if (!titulo) 'título',
    if (!anio) 'año ($suAnio)',
    if (!director)
      'director${susDirectores.isEmpty ? '' : ' (${susDirectores.join(', ')})'}',
  ];
  String lista(List<String> l) => l.length == 1
      ? l.first
      : '${l.sublist(0, l.length - 1).join(', ')} y ${l.last}';
  if (no.isEmpty) return 'Coinciden título, año y director.';
  if (si.isEmpty) return 'No coincide nada: ${lista(no)}.';
  return 'Coincide${si.length > 1 ? 'n' : ''} ${lista(si)}; '
      'no coincide${no.length > 1 ? 'n' : ''} ${lista(no)}.';
}

/// Qué coincide entre nuestra película [p] y una de otra fuente.
({bool titulo, bool anio, bool director}) coincidencias(
  DatosIdentificacion p, {
  required Iterable<String> titulos,
  required int anio,
  required Iterable<String> directores,
}) {
  final nuestros = {p.titulo, p.tituloOriginal}
    ..removeWhere((t) => t.trim().isEmpty);
  final titulo = nuestros.any(
    (a) => titulos.any((b) => titulosParecidos(a, b)),
  );
  final mismoAnio = p.anio > 0 && anio > 0 && (anio - p.anio).abs() <= 1;
  final nuestrosDirectores = separarNombres(
    p.direccion.replaceAll(' y ', ', '),
  );
  final director = nuestrosDirectores.any(
    (a) => directores.any((b) => mismaPersona(a, b)),
  );
  return (titulo: titulo, anio: mismoAnio, director: director);
}

class Identificacion {
  const Identificacion(this.seguridad, this.candidatos, this.motivo);

  final Seguridad seguridad;

  /// De más a menos parecida. Si es [Seguridad.segura], la primera es la
  /// buena.
  final List<Candidato> candidatos;

  /// Explicación para enseñar («La ficha no tiene director»…).
  final String motivo;

  FichaTmdb? get ficha =>
      seguridad == Seguridad.segura ? candidatos.first.ficha : null;
}

/// Cuántas fichas completas se piden como mucho por película.
const _maxFichas = 5;

/// Busca en TMDB la película [p] y decide si se ha identificado sin dudas.
Future<Identificacion> identificar(Tmdb tmdb, DatosIdentificacion p) async {
  final titulos = {
    if (p.titulo.trim().isNotEmpty) p.titulo.trim(),
    if (p.tituloOriginal.trim().isNotEmpty) p.tituloOriginal.trim(),
  };
  final encontrados = <int, CandidatoTmdb>{};
  // Primero con el año; si no sale nada, sin él (por si TMDB lo tiene con
  // otro año).
  for (final conAnio in [true, false]) {
    if (!conAnio && p.anio <= 0) break;
    for (final t in titulos) {
      for (final c in await tmdb.buscar(
        _paraBuscar(t),
        anio: conAnio ? p.anio : null,
      )) {
        encontrados.putIfAbsent(c.id, () => c);
      }
    }
    if (encontrados.isNotEmpty) break;
  }
  if (encontrados.isEmpty) {
    return const Identificacion(
      Seguridad.noEncontrada,
      [],
      'TMDB no tiene ninguna película con ese título.',
    );
  }

  // Se miran a fondo las que más se parecen por título y año.
  final ordenados = encontrados.values.toList()
    ..sort((a, b) => _parecidoRapido(b, p).compareTo(_parecidoRapido(a, p)));
  final candidatos = <Candidato>[];
  for (final c in ordenados.take(_maxFichas)) {
    final ficha = await tmdb.ficha(c.id);
    candidatos.add(_comparar(ficha, p));
    // Cuando una ya coincide en todo, se mira solo una más (por si hubiera
    // otra igual) y se para.
    final primera = candidatos.indexWhere((x) => x.todo);
    if (primera >= 0 && candidatos.length > primera + 1) break;
  }
  candidatos.sort((a, b) {
    final d = b.aciertos.compareTo(a.aciertos);
    if (d != 0) return d;
    return (a.ficha.anio - p.anio).abs().compareTo(
      (b.ficha.anio - p.anio).abs(),
    );
  });

  final buenas = candidatos.where((c) => c.todo).toList();
  if (p.direccion.trim().isEmpty) {
    return Identificacion(
      Seguridad.dudosa,
      candidatos,
      'La ficha no tiene director: no se puede asegurar cuál es.',
    );
  }
  if (buenas.length == 1) {
    return Identificacion(
      Seguridad.segura,
      candidatos,
      buenas.first.explicacion,
    );
  }
  if (buenas.length > 1) {
    // Varias coinciden en todo: vale la del año exacto si es solo una.
    final exactas = buenas.where((c) => c.ficha.anio == p.anio).toList();
    if (exactas.length == 1) {
      return Identificacion(Seguridad.segura, [
        exactas.first,
        ...candidatos.where((c) => c != exactas.first),
      ], exactas.first.explicacion);
    }
    return Identificacion(
      Seguridad.dudosa,
      candidatos,
      'Hay ${buenas.length} películas que coinciden en todo.',
    );
  }
  return Identificacion(
    Seguridad.dudosa,
    candidatos,
    'Ninguna coincide en todo. La más parecida: '
    '${candidatos.first.explicacion[0].toLowerCase()}'
    '${candidatos.first.explicacion.substring(1)}',
  );
}

/// Para películas nuevas, cuyo archivo aún no tiene director (y por eso
/// nunca se identifican sin dudas): la única candidata que coincide en
/// título y año (primero el año exacto; si no, ±1), o `null` si hay varias
/// o ninguna.
///
/// No es una identificación segura: la app la enseña como «probable» y no
/// se escribe nada hasta que tú lo revisas y guardas.
Candidato? candidataProbable(Identificacion id, DatosIdentificacion p) {
  if (id.seguridad != Seguridad.dudosa || p.direccion.trim().isNotEmpty) {
    return null;
  }
  for (final exacto in [true, false]) {
    final buenas = [
      for (final c in id.candidatos)
        if (c.titulo && (exacto ? c.ficha.anio == p.anio : c.anio)) c,
    ];
    if (buenas.length == 1) return buenas.single;
    if (buenas.length > 1) return null;
  }
  return null;
}

Candidato _comparar(FichaTmdb f, DatosIdentificacion p) {
  final c = coincidencias(
    p,
    titulos: {f.titulo, f.tituloOriginal, ...f.otrosTitulos},
    anio: f.anio,
    directores: {...f.directores, ...f.nombresDirectores},
  );
  return Candidato(f, titulo: c.titulo, anio: c.anio, director: c.director);
}

/// Para ordenar los resultados de la búsqueda antes de pedir sus fichas.
int _parecidoRapido(CandidatoTmdb c, DatosIdentificacion p) {
  var puntos = 0;
  if ({p.titulo, p.tituloOriginal}.any(
    (a) =>
        a.isNotEmpty &&
        (titulosParecidos(a, c.titulo) ||
            titulosParecidos(a, c.tituloOriginal)),
  )) {
    puntos += 2;
  }
  if (c.anio == p.anio) {
    puntos += 2;
  } else if ((c.anio - p.anio).abs() == 1) {
    puntos += 1;
  }
  return puntos;
}

/// El título tal como se manda a buscar: sin los dos puntos especiales del
/// disco (`꞉`) ni lo que TMDB no entiende.
String _paraBuscar(String titulo) => titulo.replaceAll('꞉', ':').trim();

/// Los dos títulos son el mismo, con pequeñas diferencias: tildes, signos,
/// «2» / «II», «The» delante, o uno que es el principio del otro
/// («Alien» / «Alien, el octavo pasajero»).
bool titulosParecidos(String a, String b) {
  final x = _palabrasTitulo(a);
  final y = _palabrasTitulo(b);
  if (x.isEmpty || y.isEmpty) return false;
  final cx = x.join();
  final cy = y.join();
  if (cx == cy) return true;
  // Uno empieza por el otro entero (con al menos 4 letras).
  final (corto, largo) = x.length <= y.length ? (x, y) : (y, x);
  if (corto.join().length >= 4 && _empiezaPor(largo, corto)) return true;
  // La mayoría de las palabras en común.
  final comunes = x.toSet().intersection(y.toSet()).length;
  final todas = x.toSet().union(y.toSet()).length;
  return todas > 0 && comunes / todas >= 0.6;
}

bool _empiezaPor(List<String> largo, List<String> corto) {
  for (var i = 0; i < corto.length; i++) {
    if (largo[i] != corto[i]) return false;
  }
  return true;
}

const _romanos = {
  'ii': '2',
  'iii': '3',
  'iv': '4',
  'v': '5',
  'vi': '6',
  'vii': '7',
  'viii': '8',
  'ix': '9',
  'x': '10',
};
const _articulos = {
  'the',
  'a',
  'an',
  'el',
  'la',
  'los',
  'las',
  'le',
  'les',
  'il',
  'der',
  'die',
  'das',
};

List<String> _palabrasTitulo(String t) {
  final palabras = [
    for (final w in limpiarParaBuscar(t.replaceAll('&', ' and ')).split(' '))
      if (w.isNotEmpty) _romanos[w] ?? (w == 'y' ? 'and' : w),
  ];
  // Se ignora el artículo del principio («The Matrix» = «Matrix»).
  if (palabras.length > 1 && _articulos.contains(palabras.first)) {
    palabras.removeAt(0);
  }
  return palabras;
}

/// Los dos nombres son la misma persona: «J.J. Abrams» / «J. J. Abrams»,
/// «Bong Joon-ho» / «Bong Joon Ho», «Andrei Tarkovsky» / «Andrey
/// Tarkovskiy» (mismo apellido y la primera letra del nombre, o casi
/// iguales letra a letra).
bool mismaPersona(String a, String b) {
  final x = limpiarParaBuscar(a).split(' ').where((w) => w.isNotEmpty).toList();
  final y = limpiarParaBuscar(b).split(' ').where((w) => w.isNotEmpty).toList();
  if (x.isEmpty || y.isEmpty) return false;
  if (x.join() == y.join()) return true;
  if (x.toSet().containsAll(y) && y.toSet().containsAll(x)) return true;
  if (x.length > 1 &&
      y.length > 1 &&
      _casiIgual(x.last, y.last) &&
      x.first[0] == y.first[0]) {
    return true;
  }
  return _casiIgual(x.join(), y.join());
}

/// Las dos listas de nombres («A, B») son las mismas personas, aunque se
/// escriban un poco distinto («Yoshifumi Kondô» / «Yoshifumi Kondo»).
bool mismasPersonas(String a, String b) {
  final x = separarNombres(a);
  final y = separarNombres(b);
  if (x.isEmpty || x.length != y.length) return false;
  return x.every((n) => y.any((m) => mismaPersona(n, m))) &&
      y.every((m) => x.any((n) => mismaPersona(n, m)));
}

/// Distancia de edición pequeña respecto a la longitud (≤ 15 %).
bool _casiIgual(String a, String b) {
  if (a == b) return true;
  final limite = (a.length > b.length ? a.length : b.length) * 0.15;
  if ((a.length - b.length).abs() > limite) return false;
  return _distancia(a, b) <= limite;
}

int _distancia(String a, String b) {
  var previa = List<int>.generate(b.length + 1, (i) => i);
  for (var i = 1; i <= a.length; i++) {
    final actual = List<int>.filled(b.length + 1, 0)..[0] = i;
    for (var j = 1; j <= b.length; j++) {
      final coste = a[i - 1] == b[j - 1] ? 0 : 1;
      actual[j] = [
        previa[j] + 1,
        actual[j - 1] + 1,
        previa[j - 1] + coste,
      ].reduce((m, v) => v < m ? v : m);
    }
    previa = actual;
  }
  return previa[b.length];
}
