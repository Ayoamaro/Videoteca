// El buscador de la colección.
//
// Prepara una sola vez, al cargar el catálogo, una versión "limpia" de los
// títulos y nombres de cada película (sin tildes, sin mayúsculas y sin signos)
// y luego, con cada letra que se escribe, la compara con todas. Con 5.541
// películas tarda unos pocos milisegundos, así que los resultados salen al
// momento mientras se escribe.
//
// No usa nada de Flutter: también funciona desde la terminal
// (`dart run tool/probar_busqueda.dart`).

/// Dónde buscar: en todo o solo en una clase de dato.
enum AmbitoBusqueda { todo, titulos, actores, directores }

/// Papel de una persona en una película.
enum Rol { actor, director }

/// Lo que el buscador necesita saber de cada película.
typedef DatosBuscables = ({
  int id,
  String titulo,
  String tituloOriginal,
  int anio,
  String direccion,
  String reparto,
});

/// Una película encontrada, con lo bien que encaja ([puntos]) y, si ha
/// aparecido por una persona y no por el título, quién es.
class Coincidencia {
  const Coincidencia(this.id, this.puntos, {this.persona, this.rol});

  final int id;
  final int puntos;
  final String? persona;
  final Rol? rol;
}

/// Una persona de la colección (actor o director) y en cuántas películas está.
class SugerenciaPersona {
  const SugerenciaPersona(this.nombre, this.rol, this.total);

  final String nombre;
  final Rol rol;
  final int total;
}

/// Quita tildes, pasa a minúsculas y cambia los signos por espacios:
/// «¡Átame!» → «atame», «Spider-Man» → «spider man», «Ocean's» → «oceans»,
/// «S.W.A.T.» → «swat». Los dos puntos especiales del disco (`꞉`) también.
String limpiarParaBuscar(String texto) {
  // Los mismos nombres y títulos se limpian muchas veces (un actor sale en
  // muchas películas y todo se vuelve a preparar cada vez que cambia el
  // catálogo): se recuerdan los textos cortos ya limpiados.
  if (texto.length > 120) return _limpiar(texto);
  if (_limpios.length > 200000) _limpios.clear();
  return _limpios[texto] ??= _limpiar(texto);
}

final _limpios = <String, String>{};

String _limpiar(String texto) {
  // Se trabaja con números de letra (y no con textos de una letra): con las
  // 5.541 películas y sus repartos se llama decenas de miles de veces.
  final salida = <int>[];
  var espacio = true; // para no poner dos espacios seguidos
  for (final runa in texto.toLowerCase().runes) {
    final sinTilde = _sinTilde[runa];
    if (sinTilde != null || _esLetraOCifra(runa)) {
      salida.add(sinTilde ?? runa);
      espacio = false;
    } else if (_seQuitan.contains(runa)) {
      continue; // se pegan: «ocean's» → «oceans»
    } else if (!espacio) {
      salida.add(0x20);
      espacio = true;
    }
  }
  if (salida.isNotEmpty && salida.last == 0x20) salida.removeLast();
  return String.fromCharCodes(salida);
}

/// Cada letra con tilde y la misma sin ella.
final _sinTilde = {
  for (var i = 0; i < _conTildes.length; i++)
    _conTildes.codeUnitAt(i): _sinTildes.codeUnitAt(i),
};
const _conTildes = 'áàäâãåéèëêíìïîóòöôõøúùüûñçýÿæœ';
const _sinTildes = 'aaaaaaeeeeiiiioooooouuuuncyyæœ';
final _seQuitan = "'’´`.".codeUnits.toSet();

bool _esLetraOCifra(int runa) =>
    (runa >= 0x30 && runa <= 0x39) || // 0-9
    (runa >= 0x61 && runa <= 0x7A) || // a-z
    (runa >= 0xDF && runa <= 0x24F && runa != 0xF7) || // letras latinas
    (runa >= 0x370 && runa <= 0x52F) || // griego y cirílico
    (runa >= 0x3040 && runa <= 0x9FFF); // japonés, chino

/// Separa la lista de nombres de un campo ("Tom Hanks, Robin Wright").
List<String> separarNombres(String texto) => [
  for (final n in texto.split(_separadorNombres))
    if (n.trim().isNotEmpty) n.trim(),
];

final _separadorNombres = RegExp(r'[,;]');

/// Un texto preparado para comparar: limpio y, aparte, sin espacios (para
/// que «spiderman» encuentre «Spider-Man»).
class _Texto {
  _Texto(String original) : limpio = limpiarParaBuscar(original) {
    compacto = limpio.replaceAll(' ', '');
    // Dónde empieza cada palabra dentro de [compacto].
    var posicion = 0;
    for (final palabra in limpio.split(' ')) {
      _inicios.add(posicion);
      posicion += palabra.length;
    }
  }

  final String limpio;
  late final String compacto;
  final _inicios = <int>[];

  bool get vacio => limpio.isEmpty;

  /// Cómo de bien aparece la palabra [p]: 3 = al principio de una palabra,
  /// 2 = dentro de una palabra, 1 = juntando palabras seguidas («spiderman»
  /// en «spider man»), 0 = no aparece.
  int encaje(String p) {
    final i = limpio.indexOf(p);
    if (i < 0) {
      // Solo vale si empieza donde empieza una palabra; si no, «atame»
      // aparecería en «gre*at ame*rican».
      for (final inicio in _inicios) {
        if (compacto.startsWith(p, inicio)) return 1;
      }
      return 0;
    }
    if (i == 0 || limpio.startsWith(' $p', i - 1)) return 3;
    return limpio.contains(' $p') ? 3 : 2;
  }
}

class _Persona {
  _Persona(this.nombre) : texto = _Texto(nombre);

  final String nombre;
  final _Texto texto;
}

class _Ficha {
  /// [personas]: las ya vistas en otras películas (cada actor se prepara
  /// una sola vez aunque salga en muchas).
  _Ficha(DatosBuscables d, Map<String, _Persona> personas)
    : id = d.id,
      anio = d.anio,
      titulo = _Texto(d.titulo),
      original = _Texto(d.tituloOriginal),
      directores = [
        for (final n in separarNombres(d.direccion))
          personas[n] ??= _Persona(n),
      ],
      actores = [
        for (final n in separarNombres(d.reparto)) personas[n] ??= _Persona(n),
      ] {
    todo = [
      titulo.compacto,
      original.compacto,
      for (final p in [...directores, ...actores]) p.texto.compacto,
      '$anio',
    ].join('|');
  }

  final int id;
  final int anio;
  final _Texto titulo;
  final _Texto original;
  final List<_Persona> directores;
  final List<_Persona> actores;

  /// Todos los datos juntos, para descartar rápido las que no tienen nada
  /// que ver.
  late final String todo;
}

class Buscador {
  Buscador(Iterable<DatosBuscables> peliculas) : _fichas = [] {
    final vistas = <String, _Persona>{};
    for (final d in peliculas) {
      _fichas.add(_Ficha(d, vistas));
    }
    // Lista de personas sin repetir, con su número de películas.
    final cuenta = <(String, Rol), int>{};
    final nombres = <(String, Rol), String>{};
    for (final f in _fichas) {
      for (final (lista, rol) in [
        (f.directores, Rol.director),
        (f.actores, Rol.actor),
      ]) {
        for (final p in lista) {
          final clave = (p.texto.limpio, rol);
          if (clave.$1.isEmpty) continue;
          cuenta[clave] = (cuenta[clave] ?? 0) + 1;
          nombres[clave] ??= p.nombre;
        }
      }
    }
    _personas = [
      for (final MapEntry(key: clave, value: total) in cuenta.entries)
        (vistas[nombres[clave]!]!, clave.$2, total),
    ];
  }

  final List<_Ficha> _fichas;
  late final List<(_Persona, Rol, int)> _personas;

  int get total => _fichas.length;

  /// Palabras de la búsqueda, ya limpias.
  static List<String> palabras(String consulta) => [
    for (final p in limpiarParaBuscar(consulta).split(' '))
      if (p.isNotEmpty) p,
  ];

  /// Películas en las que aparecen **todas** las palabras de [consulta], de
  /// la que mejor encaja a la que peor. Primero las que lo tienen en el
  /// título, luego en el título original, la dirección y el reparto.
  List<Coincidencia> buscar(
    String consulta, {
    AmbitoBusqueda ambito = AmbitoBusqueda.todo,
    int? limite,
  }) {
    final palabras = Buscador.palabras(consulta);
    if (palabras.isEmpty) return const [];
    final frase = palabras.join(' ');
    // Con una o dos letras solo valen los principios de palabra («v» →
    // «Venus», no todo lo que lleve una uve).
    final corta = frase.length < 3;
    final resultados = <(Coincidencia, _Ficha)>[];

    final titulos =
        ambito == AmbitoBusqueda.todo || ambito == AmbitoBusqueda.titulos;
    final directores =
        ambito == AmbitoBusqueda.todo || ambito == AmbitoBusqueda.directores;
    final actores =
        ambito == AmbitoBusqueda.todo || ambito == AmbitoBusqueda.actores;

    for (final f in _fichas) {
      if (!palabras.every(f.todo.contains)) continue;
      var mejor = 0;
      _Persona? persona;
      Rol? rol;

      void probar(_Texto t, int peso, [_Persona? quien, Rol? papel]) {
        if (t.vacio) return;
        final p = _puntos(t, palabras, frase, peso, corta);
        if (p > mejor) {
          mejor = p;
          persona = quien;
          rol = papel;
        }
      }

      if (titulos) {
        probar(f.titulo, 1000);
        probar(f.original, 900);
      }
      if (directores) {
        for (final d in f.directores) {
          probar(d.texto, 600, d, Rol.director);
        }
      }
      if (actores) {
        for (var i = 0; i < f.actores.length; i++) {
          // Los primeros del reparto (protagonistas) cuentan algo más.
          final a = f.actores[i];
          probar(a.texto, 500 - (i < 20 ? i * 5 : 100), a, Rol.actor);
        }
      }

      // Palabras repartidas entre varios datos, p. ej. «matrix 1999» o
      // «nolan dicaprio» (solo al buscar en todo).
      if (mejor == 0 &&
          ambito == AmbitoBusqueda.todo &&
          palabras.length > 1 &&
          !corta) {
        final ok = palabras.every(
          (p) =>
              f.titulo.encaje(p) > 0 ||
              f.original.encaje(p) > 0 ||
              p == '${f.anio}' ||
              f.directores.any((d) => d.texto.encaje(p) > 0) ||
              f.actores.any((a) => a.texto.encaje(p) > 0),
        );
        if (ok) mejor = 100;
      }

      if (mejor > 0) {
        resultados.add((
          Coincidencia(f.id, mejor, persona: persona?.nombre, rol: rol),
          f,
        ));
      }
    }

    // Más puntos primero; a igualdad, por orden alfabético (así las sagas
    // salen en orden: 1, 2, 3…) y después la más reciente.
    resultados.sort((a, b) {
      var c = b.$1.puntos.compareTo(a.$1.puntos);
      if (c == 0) c = a.$2.titulo.limpio.compareTo(b.$2.titulo.limpio);
      if (c == 0) c = b.$2.anio.compareTo(a.$2.anio);
      return c;
    });
    final lista = [for (final r in resultados) r.$1];
    return limite == null || lista.length <= limite
        ? lista
        : lista.sublist(0, limite);
  }

  /// Actores y directores cuyo nombre encaja con [consulta] (para el
  /// autocompletado). Pide al menos 3 letras.
  List<SugerenciaPersona> personas(
    String consulta, {
    int limite = 3,
    AmbitoBusqueda ambito = AmbitoBusqueda.todo,
  }) {
    final palabras = Buscador.palabras(consulta);
    if (palabras.join().length < 3 || ambito == AmbitoBusqueda.titulos) {
      return const [];
    }
    final encontradas = <SugerenciaPersona>[];
    for (final (persona, rol, total) in _personas) {
      if (ambito == AmbitoBusqueda.actores && rol != Rol.actor) continue;
      if (ambito == AmbitoBusqueda.directores && rol != Rol.director) continue;
      // Todas las palabras tienen que estar al principio de una palabra del
      // nombre («tom han» → Tom Hanks).
      if (!palabras.every((p) => persona.texto.encaje(p) == 3)) continue;
      encontradas.add(SugerenciaPersona(persona.nombre, rol, total));
    }
    // Las que más películas tienen en la colección, primero.
    encontradas.sort((a, b) => b.total.compareTo(a.total));
    return encontradas.take(limite).toList();
  }

  /// Puntos de un texto si contiene todas las palabras; 0 si falta alguna.
  static int _puntos(
    _Texto t,
    List<String> palabras,
    String frase,
    int peso,
    bool corta,
  ) {
    var minimo = 3;
    for (final p in palabras) {
      final e = t.encaje(p);
      if (e == 0 || (corta && e < 3)) return 0;
      if (e < minimo) minimo = e;
    }
    // Si alguna palabra solo aparece a mitad de otra («tom» en «Phantoms»),
    // cuenta poco: por detrás de cualquier coincidencia buena (un actor con
    // ese nombre, por ejemplo).
    if (minimo == 2) return peso ~/ 4;
    var puntos = peso + (minimo == 3 ? 90 : 60);
    if (t.limpio == frase) {
      puntos += 400; // idéntico
    } else if (t.limpio.startsWith(frase)) {
      puntos += 200; // empieza igual
    } else if (t.limpio.contains(frase)) {
      puntos += 100; // la frase entera, seguida
    }
    return puntos;
  }
}
