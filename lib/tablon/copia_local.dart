import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;

import '../datos/base_datos.dart';
import '../datos/carpetas_app.dart';
import 'cifrado.dart';
import 'formato.dart';
import 'lector.dart';

// La copia del tablón en el modo consulta: se descarga, se descifra y se
// guarda en la base de datos propia del modo consulta (y las carátulas, en
// archivos WebP), para poder usar la app sin internet.
//
// Cada vez que se abre la app se mira si hay un commit nuevo en el tablón y,
// si lo hay, se bajan **solo los paquetes cuya huella ha cambiado** (al
// guardar una ficha en el PC cambia un paquete de 100 películas). Lo que ya
// está descargado se apunta paquete a paquete: si se corta a medias, la
// siguiente vez sigue donde iba.
//
// No usa nada de Flutter.

/// Ajustes de la base de datos del modo consulta.
abstract final class AjusteConsulta {
  static const repositorio = 'repoTablon';
  static const llave = 'llaveTablon';
  static const parametros = 'parametrosTablon';

  /// Qué hay descargado ([EstadoCopia] en JSON).
  static const copia = 'copiaTablon';
}

/// La contraseña común ha cambiado (o el tablón es otro): hay que volver a
/// entrar. La copia descargada se puede seguir viendo mientras tanto.
class ContrasenaCambiada implements Exception {
  const ContrasenaCambiada();

  @override
  String toString() =>
      'La contraseña común ha cambiado: hay que volver a entrar.';
}

/// Lo que hay descargado en este aparato.
class EstadoCopia {
  const EstadoCopia({
    required this.repositorio,
    this.commit = '',
    this.version = 0,
    this.fecha,
    this.peliculas = 0,
    this.catalogo = const {},
    this.caratulas = const {},
  });

  factory EstadoCopia.desdeJson(Map<String, dynamic> json) {
    Map<String, String> mapa(Object? m) =>
        (m as Map<String, dynamic>? ?? const {}).cast<String, String>();
    return EstadoCopia(
      repositorio: json['repositorio'] as String? ?? '',
      commit: json['commit'] as String? ?? '',
      version: json['version'] as int? ?? 0,
      fecha: DateTime.tryParse(json['fecha'] as String? ?? ''),
      peliculas: json['peliculas'] as int? ?? 0,
      catalogo: mapa(json['catalogo']),
      caratulas: mapa(json['caratulas']),
    );
  }

  /// Lee el estado guardado en los ajustes ([ajustes] de la base de datos).
  factory EstadoCopia.deAjustes(Map<String, String> ajustes) {
    try {
      return EstadoCopia.desdeJson(
        jsonDecode(ajustes[AjusteConsulta.copia] ?? '{}')
            as Map<String, dynamic>,
      );
    } on Object {
      return const EstadoCopia(repositorio: '');
    }
  }

  final String repositorio;

  /// Commit del tablón descargado entero (vacío = ninguno todavía).
  final String commit;

  /// Versión del tablón descargada y su fecha de publicación.
  final int version;
  final DateTime? fecha;
  final int peliculas;

  /// Grupo → huella de los paquetes ya descargados.
  final Map<String, String> catalogo;
  final Map<String, String> caratulas;

  bool get vacia => commit.isEmpty && catalogo.isEmpty;

  EstadoCopia copyWith({
    String? commit,
    int? version,
    DateTime? fecha,
    int? peliculas,
    Map<String, String>? catalogo,
    Map<String, String>? caratulas,
  }) => EstadoCopia(
    repositorio: repositorio,
    commit: commit ?? this.commit,
    version: version ?? this.version,
    fecha: fecha ?? this.fecha,
    peliculas: peliculas ?? this.peliculas,
    catalogo: catalogo ?? this.catalogo,
    caratulas: caratulas ?? this.caratulas,
  );

  Map<String, Object?> toJson() => {
    'repositorio': repositorio,
    'commit': commit,
    'version': version,
    'fecha': fecha?.toUtc().toIso8601String(),
    'peliculas': peliculas,
    'catalogo': catalogo,
    'caratulas': caratulas,
  };
}

/// Cómo va la descarga: [fase] es «fichas» o «carátulas».
typedef ProgresoDescarga = ({String fase, int hechos, int total});

typedef ResultadoDescarga = ({
  EstadoCopia estado,

  /// Ya estaba al día: no se ha bajado nada.
  bool alDia,

  /// Era la primera descarga.
  bool primera,

  /// Películas que no estaban, que han cambiado y que ya no están.
  int nuevas,
  int cambiadas,
  int quitadas,

  /// Ha cambiado alguna carátula.
  bool caratulasCambiadas,
});

/// Entrar en el modo consulta: saca la llave de la [contrasena] con los
/// parámetros del tablón y comprueba que abre su índice. Lanza
/// [ContrasenaIncorrecta] si no, y `TablonException` si no se llega al
/// tablón.
Future<({LlaveTablon llave, ParametrosLlave parametros, IndiceTablon indice})>
comprobarContrasena(LectorTablon lector, String contrasena) async {
  final commit = await lector.ultimoCommit();
  final parametros = await lector.parametros(commit);
  final llave = await derivarLlaveAparte(contrasena, parametros);
  final indice = await lector.indice(commit, llave);
  return (llave: llave, parametros: parametros, indice: indice);
}

/// Paquetes que se bajan a la vez.
const _descargasALaVez = 4;

/// Pone al día la copia de [bd] con el último commit del tablón.
///
/// [parametros] son los de la llave con la que se entró: si el tablón ya usa
/// otros (la contraseña ha cambiado) lanza [ContrasenaCambiada]. Si falla la
/// conexión lanza `TablonException` (con `sinInternet`); lo descargado hasta
/// entonces se queda y la próxima vez sigue donde iba.
///
/// [alTenerFichas] se llama cuando ya están todas las fichas (antes de las
/// carátulas, que pesan mucho más), para enseñarlas cuanto antes.
Future<ResultadoDescarga> actualizarCopia({
  required LectorTablon lector,
  required LlaveTablon llave,
  required ParametrosLlave parametros,
  required BaseDatos bd,
  required CarpetasApp carpetas,
  void Function(ProgresoDescarga progreso)? alAvanzar,
  Future<void> Function()? alTenerFichas,
}) async {
  final ajustes = await bd.todosLosAjustes();
  var estado = EstadoCopia.deAjustes(ajustes);

  // Una copia de otro tablón no sirve: se empieza de cero.
  if (estado.repositorio != lector.repositorio) {
    await bd.vaciarPeliculas();
    _borrarCaratulas(carpetas);
    estado = EstadoCopia(repositorio: lector.repositorio);
    await _guardar(bd, estado);
  }
  final primera = estado.vacia;

  final commit = await lector.ultimoCommit();
  if (commit == estado.commit) {
    return (
      estado: estado,
      alDia: true,
      primera: false,
      nuevas: 0,
      cambiadas: 0,
      quitadas: 0,
      caratulasCambiadas: false,
    );
  }

  final remotos = await lector.parametros(commit);
  if (!_mismosParametros(remotos, parametros)) throw const ContrasenaCambiada();
  final IndiceTablon indice;
  try {
    indice = await lector.indice(commit, llave);
  } on ContrasenaIncorrecta {
    throw const ContrasenaCambiada();
  }

  final antes = {for (final f in await bd.todasLasPeliculas()) f.id: f};
  var nuevas = 0, cambiadas = 0, quitadas = 0;

  // 1. Fichas.
  final catalogo = Map.of(estado.catalogo);
  final fichasQueBajar = [
    for (final MapEntry(key: grupo, value: huella) in indice.catalogo.entries)
      if (catalogo[grupo] != huella) grupo,
  ]..sort();
  var hechos = 0;
  alAvanzar?.call((fase: 'fichas', hechos: 0, total: fichasQueBajar.length));
  await _porTandas(fichasQueBajar, (grupo) async {
    final ruta = rutaCatalogo(grupo);
    final fichas = await _abrirCatalogo(
      llave.bytes,
      ruta,
      await lector.archivo(commit, ruta),
    );
    final (desde, hasta) = _rango(grupo);
    final filas = [for (final f in fichas) filaDesdeFicha(f, indice.fecha)];
    for (final f in filas) {
      final previa = antes[f.id.value];
      if (previa == null) {
        nuevas++;
      } else if (_distinta(previa, f)) {
        cambiadas++;
      }
    }
    quitadas += antes.keys
        .where((id) => id >= desde && id <= hasta)
        .where((id) => !filas.any((f) => f.id.value == id))
        .length;
    await bd.reemplazarPeliculas(desde, hasta, filas);
    catalogo[grupo] = indice.catalogo[grupo]!;
    estado = estado.copyWith(catalogo: catalogo);
    await _guardar(bd, estado);
    alAvanzar?.call((
      fase: 'fichas',
      hechos: ++hechos,
      total: fichasQueBajar.length,
    ));
  });
  // Grupos que ya no están en el tablón.
  for (final grupo in [...catalogo.keys]) {
    if (indice.catalogo.containsKey(grupo)) continue;
    final (desde, hasta) = _rango(grupo);
    quitadas += antes.keys.where((id) => id >= desde && id <= hasta).length;
    await bd.reemplazarPeliculas(desde, hasta, const []);
    catalogo.remove(grupo);
  }
  estado = estado.copyWith(catalogo: catalogo);
  await _guardar(bd, estado);
  if (fichasQueBajar.isNotEmpty || primera) await alTenerFichas?.call();

  // 2. Carátulas.
  final caratulas = Map.of(estado.caratulas);
  final caratulasQueBajar = [
    for (final MapEntry(key: grupo, value: huella) in indice.caratulas.entries)
      if (caratulas[grupo] != huella) grupo,
  ]..sort();
  hechos = 0;
  alAvanzar?.call((
    fase: 'carátulas',
    hechos: 0,
    total: caratulasQueBajar.length,
  ));
  await _porTandas(caratulasQueBajar, (grupo) async {
    final ruta = rutaCaratulas(grupo);
    final imagenes = await _abrirCaratulas(
      llave.bytes,
      ruta,
      await lector.archivo(commit, ruta),
    );
    final (desde, hasta) = _rango(grupo);
    for (var id = desde; id <= hasta; id++) {
      final archivo = File(carpetas.miniatura(id));
      final imagen = imagenes[id];
      if (imagen != null) {
        await archivo.writeAsBytes(imagen);
      } else if (archivo.existsSync()) {
        await archivo.delete();
      }
    }
    caratulas[grupo] = indice.caratulas[grupo]!;
    estado = estado.copyWith(caratulas: caratulas);
    await _guardar(bd, estado);
    alAvanzar?.call((
      fase: 'carátulas',
      hechos: ++hechos,
      total: caratulasQueBajar.length,
    ));
  });
  for (final grupo in [...caratulas.keys]) {
    if (indice.caratulas.containsKey(grupo)) continue;
    final (desde, hasta) = _rango(grupo);
    for (var id = desde; id <= hasta; id++) {
      final archivo = File(carpetas.miniatura(id));
      if (archivo.existsSync()) archivo.deleteSync();
    }
    caratulas.remove(grupo);
  }

  // 3. Todo descargado: se apunta el commit.
  estado = estado.copyWith(
    commit: commit,
    version: indice.version,
    fecha: indice.fecha,
    peliculas: indice.peliculas,
    caratulas: caratulas,
  );
  await _guardar(bd, estado);
  return (
    estado: estado,
    alDia: false,
    primera: primera,
    nuevas: primera ? 0 : nuevas,
    cambiadas: cambiadas,
    quitadas: quitadas,
    caratulasCambiadas: caratulasQueBajar.isNotEmpty,
  );
}

/// La fila de la base de datos para la ficha [f] del tablón. [fecha] es la
/// de la versión descargada.
PeliculasCompanion filaDesdeFicha(Map<String, dynamic> f, DateTime fecha) {
  String texto(String clave) => f[clave] as String? ?? '';
  int numero(String clave) => f[clave] as int? ?? 0;
  final anadida = DateTime.tryParse(texto('anadida'))?.toLocal() ?? fecha;
  return PeliculasCompanion.insert(
    id: Value(f['id'] as int),
    ruta: texto('ruta'),
    grupo: Value(texto('grupo')),
    generoCarpeta: Value(texto('generoCarpeta')),
    titulo: texto('titulo'),
    tituloOriginal: Value(texto('tituloOriginal')),
    anio: Value(numero('anio')),
    generos: Value(texto('generos')),
    temas: Value(texto('temas')),
    sinopsis: Value(texto('sinopsis')),
    direccion: Value(texto('direccion')),
    guion: Value(texto('guion')),
    reparto: Value(texto('reparto')),
    musica: Value(texto('musica')),
    fotografia: Value(texto('fotografia')),
    productora: Value(texto('productora')),
    pais: Value(texto('pais')),
    premios: Value(texto('premios')),
    clasificacion: Value(texto('clasificacion')),
    estrellas: Value(numero('estrellas')),
    saga: Value(texto('saga')),
    numeroSaga: Value(numero('numeroSaga')),
    enlaceFilmaffinity: Value(texto('enlaceFilmaffinity')),
    enlaceImdb: Value(texto('enlaceImdb')),
    duracionMin: Value(numero('duracionMin')),
    resolucion: Value(texto('resolucion')),
    tamanoBytes: Value(numero('tamanoBytes')),
    tieneCaratula: Value(f['caratula'] == true),
    tieneMiniatura: Value(f['caratula'] == true),
    anadida: anadida,
    modificado: fecha,
    escaneada: fecha,
  );
}

/// ¿Ha cambiado algo que se vea de la película?
bool _distinta(FilaPelicula a, PeliculasCompanion b) {
  final nueva = a.copyWith(
    ruta: b.ruta.value,
    titulo: b.titulo.value,
    tituloOriginal: b.tituloOriginal.value,
    anio: b.anio.value,
    generos: b.generos.value,
    temas: b.temas.value,
    sinopsis: b.sinopsis.value,
    direccion: b.direccion.value,
    guion: b.guion.value,
    reparto: b.reparto.value,
    musica: b.musica.value,
    fotografia: b.fotografia.value,
    productora: b.productora.value,
    pais: b.pais.value,
    premios: b.premios.value,
    clasificacion: b.clasificacion.value,
    estrellas: b.estrellas.value,
    saga: b.saga.value,
    numeroSaga: b.numeroSaga.value,
    enlaceFilmaffinity: b.enlaceFilmaffinity.value,
    enlaceImdb: b.enlaceImdb.value,
    tieneCaratula: b.tieneCaratula.value,
  );
  return nueva != a;
}

bool _mismosParametros(ParametrosLlave a, ParametrosLlave b) =>
    base64.encode(a.sal) == base64.encode(b.sal) &&
    a.memoria == b.memoria &&
    a.iteraciones == b.iteraciones &&
    a.paralelismo == b.paralelismo;

/// Números de película de un grupo: «003» → 300–399.
(int, int) _rango(String grupo) {
  final n = int.parse(grupo);
  return (n * peliculasPorGrupo, (n + 1) * peliculasPorGrupo - 1);
}

Future<void> _guardar(BaseDatos bd, EstadoCopia estado) =>
    bd.guardarAjuste(AjusteConsulta.copia, jsonEncode(estado.toJson()));

void _borrarCaratulas(CarpetasApp carpetas) {
  final carpeta = Directory(carpetas.miniaturas);
  if (!carpeta.existsSync()) return;
  for (final archivo in carpeta.listSync().whereType<File>()) {
    archivo.deleteSync();
  }
}

/// Hace [trabajo] con cada elemento, varios a la vez. Si uno falla, espera a
/// los que estaban en marcha y lanza el error.
Future<void> _porTandas(
  List<String> elementos,
  Future<void> Function(String) trabajo,
) async {
  for (var i = 0; i < elementos.length; i += _descargasALaVez) {
    final tanda = elementos.skip(i).take(_descargasALaVez);
    await Future.wait([for (final e in tanda) trabajo(e)], eagerError: false);
  }
}

// Descifrar y descomprimir, en otro hilo para no frenar la pantalla
// (funciones sueltas: ver `edicion.dart`).

Future<List<Map<String, dynamic>>> _abrirCatalogo(
  Uint8List llave,
  String ruta,
  Uint8List sobre,
) => Isolate.run(
  () => leerPaqueteCatalogo(LlaveTablon(llave).descifrar(ruta, sobre)),
);

Future<Map<int, Uint8List>> _abrirCaratulas(
  Uint8List llave,
  String ruta,
  Uint8List sobre,
) => Isolate.run(
  () => leerPaqueteCaratulas(LlaveTablon(llave).descifrar(ruta, sobre)),
);
