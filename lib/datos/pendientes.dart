import '../modelos/pelicula.dart';
import 'buscador.dart';
import 'filtros.dart';

// Pendientes: lo que necesita atención en la colección (copias repetidas,
// fichas a medias, datos raros…). Solo se detecta: la app nunca cambia ni
// borra nada del disco por su cuenta.
//
// No usa nada de Flutter, para poder probarlo desde la terminal.

enum TipoPendiente {
  duplicadas(
    'Duplicadas',
    'La misma película está más de una vez. Elige cuál conservar; la app no '
        'borra nada por su cuenta.',
  ),
  sinCaratula('Sin carátula', 'Películas que no tienen carátula incrustada.'),
  incompletas(
    'Incompletas',
    'Les faltan datos importantes en las propiedades del archivo.',
  ),
  datosRaros(
    'Datos que revisar',
    'Datos que parecen un error: años imposibles o distintos al del nombre '
        'del archivo, frases de edad mal escritas…',
  ),
  fueraDeFormato(
    'Nombre fuera de formato',
    'No siguen el formato «Título (Año).mp4».',
  ),
  desaparecidas(
    'Desaparecidas',
    'Estaban en el catálogo pero ya no están en el disco. Si las has movido '
        'a otra carpeta de la colección, se reconocen solas.',
  );

  const TipoPendiente(this.nombre, this.descripcion);

  final String nombre;
  final String descripcion;
}

/// Una cosa pendiente: una película (o varias, si son copias repetidas) y
/// por qué está aquí.
class Pendiente {
  Pendiente(this.tipo, this.peliculas, this.motivos);

  final TipoPendiente tipo;
  final List<Pelicula> peliculas;
  final List<String> motivos;

  Pelicula get pelicula => peliculas.first;

  /// Identifica el pendiente para recordar que ya se ha revisado. En las
  /// duplicadas incluye todas las rutas: si aparece otra copia, vuelve a
  /// salir.
  String get clave =>
      '${tipo.name}:${(peliculas.map((p) => p.ruta).toList()..sort()).join('|')}';
}

/// Campos que debería tener toda ficha (los que ya rellenaba a mano el
/// usuario). Los nuevos (guion, país…) los completa «Completar colección».
final camposImportantes = <String, bool Function(Pelicula)>{
  'Título original': (p) => p.tituloOriginal.trim().isNotEmpty,
  'Año': (p) => p.anio > 0,
  'Géneros': (p) => p.generos.isNotEmpty,
  'Sinopsis': (p) => p.sinopsis.trim().isNotEmpty,
  'Dirección': (p) => p.direccion.trim().isNotEmpty,
  'Reparto': (p) => p.reparto.trim().isNotEmpty,
  'Música': (p) => p.musica.trim().isNotEmpty,
  'Productora': (p) => p.productora.trim().isNotEmpty,
  'Edad': (p) => p.clasificacion.trim().isNotEmpty,
  'Estrellas': (p) => p.estrellas > 0,
};

final _formatoNombre = RegExp(
  r'^.+ \((\d{4})\)\.(mp4|m4v)$',
  caseSensitive: false,
);
final _anioEnNombre = RegExp(r'\((\d{4})\)');
final _fraseEdad = RegExp(
  r'^(Apto para todos los públicos|No recomendado para menores de \d{1,2} años)$',
);

/// Año que pone el nombre del archivo, entre paréntesis (el último), o `null`.
int? anioDelNombre(Pelicula p) {
  final m = _anioEnNombre.allMatches(p.archivo).lastOrNull;
  return m == null ? null : int.parse(m.group(1)!);
}

/// Busca todos los pendientes.
///
/// [catalogo] son las películas que están en el disco y [desaparecidas] las
/// que ya no. Lo que esté en [revisados] (por su [Pendiente.clave]) se
/// devuelve aparte, en el segundo mapa.
({
  Map<TipoPendiente, List<Pendiente>> pendientes,
  Map<TipoPendiente, List<Pendiente>> revisados,
})
buscarPendientes(
  List<Pelicula> catalogo, {
  List<Pelicula> desaparecidas = const [],
  Set<String> revisados = const {},
}) {
  final todos = <Pendiente>[
    ..._duplicadas(catalogo),
    for (final p in catalogo) ...?_deUna(p),
    for (final p in desaparecidas)
      Pendiente(
        TipoPendiente.desaparecidas,
        [p],
        [
          if (p.desaparecida case final fecha?)
            'No está desde el ${_fecha(fecha)}',
        ],
      ),
  ];
  final pendientes = {for (final t in TipoPendiente.values) t: <Pendiente>[]};
  final yaRevisados = {for (final t in TipoPendiente.values) t: <Pendiente>[]};
  for (final p in todos) {
    (revisados.contains(p.clave) ? yaRevisados : pendientes)[p.tipo]!.add(p);
  }
  for (final lista in [...pendientes.values, ...yaRevisados.values]) {
    lista.sort((a, b) => a.pelicula.titulo.compareTo(b.pelicula.titulo));
  }
  return (pendientes: pendientes, revisados: yaRevisados);
}

/// Pendientes de una sola película (todos menos duplicadas y desaparecidas).
List<Pendiente>? _deUna(Pelicula p) {
  final lista = <Pendiente>[];

  if (!p.tieneCaratula) {
    lista.add(Pendiente(TipoPendiente.sinCaratula, [p], const []));
  }

  final faltan = [
    for (final MapEntry(:key, :value) in camposImportantes.entries)
      if (!value(p)) key,
  ];
  if (faltan.isNotEmpty) {
    lista.add(
      Pendiente(
        TipoPendiente.incompletas,
        [p],
        ['Falta: ${faltan.join(', ')}'],
      ),
    );
  }

  final raros = <String>[];
  if (p.errorLectura != null) {
    raros.add('Windows no pudo leer el archivo: ${p.errorLectura}');
  }
  final anioNombre = anioDelNombre(p);
  if (p.anio != 0 && !anioValido(p.anio)) {
    raros.add('El año «${p.anio}» no es posible');
  } else if (anioNombre != null && p.anio != 0 && anioNombre != p.anio) {
    raros.add('El nombre dice $anioNombre y los datos ${p.anio}');
  }
  final edad = p.clasificacion;
  if (edad.trim().isNotEmpty && !_fraseEdad.hasMatch(edad)) {
    // Si no tiene ni un número, ni siquiera es una frase de edad.
    raros.add(
      _numeroOPublico.hasMatch(edad)
          ? 'Frase de edad mal escrita: «$edad»'
          : 'La edad dice «$edad»',
    );
  }
  if (raros.isNotEmpty) {
    lista.add(Pendiente(TipoPendiente.datosRaros, [p], raros));
  }

  if (!_formatoNombre.hasMatch(p.archivo)) {
    lista.add(
      Pendiente(
        TipoPendiente.fueraDeFormato,
        [p],
        [_problemaNombre(p.archivo)],
      ),
    );
  }
  return lista;
}

String _problemaNombre(String archivo) {
  final sobra = RegExp(r'\(\d{4}\)(.+)\.\w+$').firstMatch(archivo);
  if (sobra != null) return 'Sobra «${sobra.group(1)}» después del año';
  if (!_anioEnNombre.hasMatch(archivo)) return 'Falta el año entre paréntesis';
  return 'Falta un espacio antes del año o sobra algo';
}

/// Copias de la misma película: mismo título y año, o mismo nombre de
/// archivo (en carpetas distintas).
List<Pendiente> _duplicadas(List<Pelicula> catalogo) {
  // Se agrupan con las dos pistas a la vez: si A y B tienen el mismo título
  // y B y C el mismo nombre de archivo, son las tres la misma.
  final grupo = List<int>.generate(catalogo.length, (i) => i);
  int raiz(int i) {
    while (grupo[i] != i) {
      i = grupo[i] = grupo[grupo[i]];
    }
    return i;
  }

  final primeraCon = <String, int>{};
  void unir(String pista, int i) {
    final otra = primeraCon.putIfAbsent(pista, () => i);
    if (otra != i) grupo[raiz(i)] = raiz(otra);
  }

  for (var i = 0; i < catalogo.length; i++) {
    final p = catalogo[i];
    if (p.titulo.trim().isNotEmpty && p.anio > 0) {
      unir('t:${limpiarParaBuscar(p.titulo)}:${p.anio}', i);
    }
    final archivo = p.archivo.replaceFirst(_extension, '');
    unir('a:${limpiarParaBuscar(archivo)}', i);
  }

  final copias = <int, List<Pelicula>>{};
  for (var i = 0; i < catalogo.length; i++) {
    (copias[raiz(i)] ??= []).add(catalogo[i]);
  }
  return [
    for (final lista in copias.values)
      if (lista.length > 1)
        Pendiente(TipoPendiente.duplicadas, lista..sort(_porRuta), [
          '${lista.length} copias',
        ]),
  ];
}

final _extension = RegExp(r'\.\w+$');
final _numeroOPublico = RegExp(r'\d|público');

int _porRuta(Pelicula a, Pelicula b) => a.ruta.compareTo(b.ruta);

String _fecha(DateTime f) =>
    '${f.day.toString().padLeft(2, '0')}/${f.month.toString().padLeft(2, '0')}/${f.year}';
