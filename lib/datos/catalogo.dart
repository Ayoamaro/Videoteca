import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../disco/caratula_mp4.dart';
import '../disco/escaner.dart';
import '../modelos/pelicula.dart';
import '../utilidades.dart';
import 'base_datos.dart';
import 'buscador.dart';
import 'carpetas_app.dart';
import 'filtros.dart';

// "Proveedores" (Riverpod): piezas que guardan datos y avisan a las pantallas
// cuando cambian. Aquí se conecta la base de datos con la app.

/// La base de datos y las carpetas de la app. Se abren en `main()` antes de
/// arrancar y se entregan aquí.
final baseDatosProvider = Provider<BaseDatos>(
  (ref) => throw UnimplementedError('Se da en main()'),
);
final carpetasAppProvider = Provider<CarpetasApp>(
  (ref) => throw UnimplementedError('Se da en main()'),
);

/// Ajustes guardados al arrancar la app.
final ajustesInicialesProvider = Provider<Map<String, String>>(
  (ref) => const {},
);

/// Carpeta raíz de la colección (p. ej. `D:\`), o `null` si todavía no se ha
/// elegido (entonces se muestra el asistente de primer arranque).
final carpetaRaizProvider = NotifierProvider<CarpetaRaiz, String?>(
  CarpetaRaiz.new,
);

class CarpetaRaiz extends Notifier<String?> {
  static const clave = 'carpetaRaiz';

  @override
  String? build() => ref.read(ajustesInicialesProvider)[clave];

  Future<void> cambiar(String ruta) async {
    await ref.read(baseDatosProvider).guardarAjuste(clave, ruta);
    state = ruta;
  }
}

/// Todas las películas del catálogo, cargadas de la base de datos.
final catalogoProvider = AsyncNotifierProvider<Catalogo, List<Pelicula>>(
  Catalogo.new,
);

class Catalogo extends AsyncNotifier<List<Pelicula>> {
  /// El buscador de la última lista cargada, preparado junto con ella.
  ({List<Pelicula> lista, Buscador buscador})? _preparado;

  @override
  Future<List<Pelicula>> build() => _cargar();

  Future<List<Pelicula>> _cargar() async {
    final carpetas = ref.read(carpetasAppProvider);
    final filas = await ref.read(baseDatosProvider).todasLasPeliculas();
    // Con toda la colección, las fichas y el buscador se preparan en otro
    // hilo (unas décimas de segundo) para que la pantalla no se quede
    // parada cada vez que se guarda algo.
    final (lista, buscador) = filas.length < 500
        ? _preparar(filas, carpetas)
        : await _prepararAparte(filas, carpetas);
    _preparado = (lista: lista, buscador: buscador);
    return lista;
  }

  /// El buscador ya preparado para [lista], si es la última cargada.
  Buscador? buscadorDe(List<Pelicula> lista) =>
      identical(_preparado?.lista, lista) ? _preparado!.buscador : null;

  /// Vuelve a leer la base de datos (p. ej. después de escanear). Con
  /// [olvidarImagenes] se descartan las miniaturas ya cargadas en memoria,
  /// por si alguna ha cambiado.
  Future<void> recargar({bool olvidarImagenes = false}) async {
    final peliculas = await _cargar();
    if (olvidarImagenes) PaintingBinding.instance.imageCache.clear();
    state = AsyncData(peliculas);
    ref.invalidate(desaparecidasProvider);
  }

  /// Quita del catálogo películas que ya no están en el disco (y sus
  /// miniaturas). Nunca toca el disco.
  Future<void> quitar(Iterable<int> ids) async {
    final carpetas = ref.read(carpetasAppProvider);
    await ref.read(baseDatosProvider).borrarPeliculas(ids);
    for (final id in ids) {
      final miniatura = File(carpetas.miniatura(id));
      if (miniatura.existsSync()) miniatura.deleteSync();
    }
    await recargar();
  }

  /// Saca películas de la bandeja de Películas nuevas.
  Future<void> quitarDeNuevas(Iterable<int> ids) async {
    await ref.read(baseDatosProvider).marcarNuevas(ids, nueva: false);
    await recargar();
  }

  /// Anota que la ficha de [id] se ha guardado desde «Completar ficha».
  Future<void> marcarCompletada(int id) async {
    await ref.read(baseDatosProvider).marcarCompletada(id, DateTime.now());
    await recargar();
  }
}

(List<Pelicula>, Buscador) _preparar(
  List<FilaPelicula> filas,
  CarpetasApp carpetas,
) {
  final lista = [for (final f in filas) peliculaDesdeFila(f, carpetas)];
  return (lista, Buscador(datosBuscables(lista)));
}

// Función suelta (no un método): desde un método con `ref`, `Isolate.run`
// falla («object is unsendable»).
Future<(List<Pelicula>, Buscador)> _prepararAparte(
  List<FilaPelicula> filas,
  CarpetasApp carpetas,
) => Isolate.run(() => _preparar(filas, carpetas));

/// Lo que el buscador necesita de cada película.
Iterable<DatosBuscables> datosBuscables(List<Pelicula> lista) => [
  for (final p in lista)
    (
      id: p.id,
      titulo: p.titulo,
      tituloOriginal: p.tituloOriginal,
      anio: p.anio,
      direccion: p.direccion,
      reparto: p.reparto,
    ),
];

/// Películas que estaban en el catálogo y ya no están en el disco.
final desaparecidasProvider = FutureProvider<List<Pelicula>>((ref) async {
  final carpetas = ref.read(carpetasAppProvider);
  final filas = await ref.read(baseDatosProvider).peliculasDesaparecidas();
  return [for (final f in filas) peliculaDesdeFila(f, carpetas)];
});

/// Convierte una fila de la base de datos en una [Pelicula].
Pelicula peliculaDesdeFila(FilaPelicula f, CarpetasApp carpetas) {
  List<String> trocear(String texto, String separador) => [
    for (final s in texto.split(separador))
      if (s.trim().isNotEmpty) s.trim(),
  ];
  return Pelicula(
    id: f.id,
    titulo: f.titulo,
    tituloOriginal: f.tituloOriginal,
    anio: f.anio,
    ruta: f.ruta,
    grupo: f.grupo,
    generos: trocear(f.generos, '.'),
    temas: trocear(f.temas, ';'),
    sinopsis: f.sinopsis,
    direccion: f.direccion,
    guion: f.guion,
    reparto: f.reparto,
    musica: f.musica,
    fotografia: f.fotografia,
    productora: f.productora,
    pais: f.pais,
    premios: f.premios,
    clasificacion: f.clasificacion,
    estrellas: f.estrellas,
    duracionMin: f.duracionMin,
    resolucion: f.resolucion,
    tamanoBytes: f.tamanoBytes,
    saga: f.saga,
    numeroSaga: f.numeroSaga,
    enlaceFilmaffinity: f.enlaceFilmaffinity,
    enlaceImdb: f.enlaceImdb,
    anadida: f.anadida,
    nueva: f.nueva,
    completada: f.completada,
    errorLectura: f.errorLectura,
    desaparecida: f.desaparecida,
    tieneCaratula: f.tieneCaratula,
    miniatura: f.tieneMiniatura ? carpetas.miniatura(f.id) : null,
    tono: _tonos[f.titulo.hashCode % _tonos.length],
  );
}

/// Colores para las carátulas provisionales (películas sin carátula).
const _tonos = [
  Color(0xFF2E4034),
  Color(0xFF4A2330),
  Color(0xFF23344A),
  Color(0xFF4A3B23),
  Color(0xFF3A2A4A),
  Color(0xFF2A4447),
];

/// Todas las películas por su número (id).
final peliculasPorIdProvider = Provider<Map<int, Pelicula>>(
  (ref) => {
    for (final p in ref.watch(catalogoProvider).value ?? const <Pelicula>[])
      p.id: p,
  },
);

/// Una película por su número, o `null` si no está.
final peliculaPorIdProvider = Provider.family<Pelicula?, int>(
  (ref, id) => ref.watch(peliculasPorIdProvider)[id],
);

/// Las 6 últimas añadidas a la colección (para Inicio).
final recientesProvider = Provider<List<Pelicula>>((ref) {
  final antiguo = DateTime(1900);
  final todas = [...ref.watch(catalogoProvider).value ?? const <Pelicula>[]]
    ..sort((a, b) => (b.anadida ?? antiguo).compareTo(a.anadida ?? antiguo));
  return todas.take(6).toList();
});

/// El buscador, preparado de nuevo cada vez que cambia el catálogo
/// (normalmente ya viene hecho de la carga).
final buscadorProvider = Provider<Buscador>((ref) {
  final lista = ref.watch(catalogoProvider).value ?? const <Pelicula>[];
  return ref.read(catalogoProvider.notifier).buscadorDe(lista) ??
      Buscador(datosBuscables(lista));
});

/// El cuadro de búsqueda de Inicio, para poder llevar allí el cursor desde
/// cualquier pantalla con Ctrl + K.
final focoBusquedaProvider = Provider<FocusNode>((ref) {
  final foco = FocusNode(debugLabel: 'Buscar');
  ref.onDispose(foco.dispose);
  return foco;
});

/// Géneros según las carpetas, con su número de películas (de más a menos).
final generosProvider = Provider<List<(String, int)>>((ref) {
  final cuenta = <String, int>{};
  for (final p in ref.watch(catalogoProvider).value ?? const <Pelicula>[]) {
    final g = p.generoCarpeta;
    if (g.isNotEmpty) cuenta[g] = (cuenta[g] ?? 0) + 1;
  }
  return [for (final e in cuenta.entries) (e.key, e.value)]
    ..sort((a, b) => b.$2.compareTo(a.$2));
});

/// Carpetas de la colección en árbol: cada carpeta de primer nivel con su
/// número de películas y sus subcarpetas.
final arbolCarpetasProvider = Provider<List<CarpetaArbol>>((ref) {
  final grupos = <String, int>{};
  final subs = <String, Map<String, int>>{};
  for (final p in ref.watch(catalogoProvider).value ?? const <Pelicula>[]) {
    if (p.grupo.isEmpty) continue;
    grupos[p.grupo] = (grupos[p.grupo] ?? 0) + 1;
    final suyas = subs.putIfAbsent(p.grupo, () => {});
    suyas[p.generoCarpeta] = (suyas[p.generoCarpeta] ?? 0) + 1;
  }
  return [
    for (final (grupo, total) in Facetas.ordenadas(grupos))
      (
        nombre: grupo,
        total: total,
        // Una sola subcarpeta con el mismo nombre (o la propia carpeta) no
        // aporta nada: no se enseña.
        subcarpetas: [
          for (final sub in Facetas.ordenadas(subs[grupo]!))
            if (sub.$1 != grupo) sub,
        ],
      ),
  ];
});

/// Una carpeta de primer nivel con sus subcarpetas.
typedef CarpetaArbol = ({
  String nombre,
  int total,
  List<(String, int)> subcarpetas,
});

/// Géneros de las fichas ("Comedia", "Drama"…) con su número de películas.
final generosFichaProvider = Provider<List<(String, int)>>(
  (ref) => contarNombres(
    ref.watch(catalogoProvider).value ?? const <Pelicula>[],
    (p) => p.generos,
  ),
);

/// Directores y actores de la colección con su número de películas (para
/// los filtros del Catálogo).
final directoresProvider = Provider<List<(String, int)>>(
  (ref) => contarNombres(
    ref.watch(catalogoProvider).value ?? const <Pelicula>[],
    (p) => separarNombres(p.direccion),
  ),
);
final actoresProvider = Provider<List<(String, int)>>(
  (ref) => contarNombres(
    ref.watch(catalogoProvider).value ?? const <Pelicula>[],
    (p) => separarNombres(p.reparto),
  ),
);

/// Años más antiguo y más reciente de la colección (sin contar años mal
/// escritos), para la barra de años de los filtros.
final aniosProvider = Provider<(int, int)?>((ref) {
  int? minimo, maximo;
  for (final p in ref.watch(catalogoProvider).value ?? const <Pelicula>[]) {
    if (!anioValido(p.anio)) continue;
    if (minimo == null || p.anio < minimo) minimo = p.anio;
    if (maximo == null || p.anio > maximo) maximo = p.anio;
  }
  return minimo == null ? null : (minimo, maximo!);
});

/// El Catálogo se ve en lista (`true`) o en cuadrícula. Se recuerda.
final vistaListaProvider = NotifierProvider<VistaLista, bool>(VistaLista.new);

class VistaLista extends Notifier<bool> {
  static const clave = 'vistaCatalogo';

  @override
  bool build() => ref.read(ajustesInicialesProvider)[clave] == 'lista';

  Future<void> cambiar(bool lista) async {
    state = lista;
    await ref
        .read(baseDatosProvider)
        .guardarAjuste(clave, lista ? 'lista' : 'cuadricula');
  }
}

/// Carátula completa leída del `.mp4` (para la ficha). `null` si el archivo
/// no tiene carátula o el disco no está conectado.
final caratulaCompletaProvider = FutureProvider.autoDispose
    .family<Uint8List?, String>((ref, ruta) async {
      try {
        return await Isolate.run(() => leerCaratulaMp4(ruta));
      } catch (_) {
        return null;
      }
    });

// ── Escaneo ──────────────────────────────────────────────────────────────

/// Progreso del escaneo en marcha (o del último), `null` si no se ha hecho.
final escaneoProvider = NotifierProvider<Escaneo, ProgresoEscaneo?>(
  Escaneo.new,
);

class Escaneo extends Notifier<ProgresoEscaneo?> {
  Escaner? _escaner;

  /// Ha llegado un aviso de cambios mientras se escaneaba: al terminar se
  /// vuelve a revisar.
  bool _revisarOtraVez = false;
  Timer? _reintento;
  var _esperaReintento = const Duration(seconds: 15);

  @override
  ProgresoEscaneo? build() {
    ref.onDispose(() => _reintento?.cancel());
    return null;
  }

  bool get enMarcha => state?.enMarcha ?? false;

  /// Escanea la carpeta raíz (o [raiz], si se da). Con [completo] vuelve a
  /// leer todos los archivos; si no, solo los nuevos o cambiados.
  ///
  /// Con [automatico] (revisiones que pide el vigilante), si cambia algo se
  /// avisa con un mensaje en la parte de abajo de la pantalla. Con
  /// [coleccionNueva] (el asistente, al elegir carpeta) no se marca nada como
  /// «nueva»: serían todas.
  Future<void> iniciar({
    String? raiz,
    bool completo = false,
    bool automatico = false,
    bool coleccionNueva = false,
  }) async {
    raiz ??= ref.read(carpetaRaizProvider);
    if (raiz == null || enMarcha) return;
    _reintento?.cancel();
    final bd = ref.read(baseDatosProvider);
    final escaner = _escaner = Escaner(
      bd: bd,
      raiz: raiz,
      carpetas: ref.read(carpetasAppProvider),
      // En el primer escaneo no se marcan como nuevas (serían todas).
      marcarNuevas: !coleccionNueva && ref.read(ultimoEscaneoProvider) != null,
    );
    var leidasAlRecargar = 0;
    await for (final progreso in escaner.ejecutar(completo: completo)) {
      state = progreso;
      // Mientras escanea, el catálogo se va llenando cada 500 películas.
      if (progreso.leidas - leidasAlRecargar >= 500) {
        leidasAlRecargar = progreso.leidas;
        unawaited(ref.read(catalogoProvider.notifier).recargar());
      }
    }
    _escaner = null;
    final fin = state!;
    if (fin.fase == FaseEscaneo.terminado) {
      await ref.read(ultimoEscaneoProvider.notifier).guardar(DateTime.now());
    }
    if (fin.hayCambios || !automatico) {
      await ref
          .read(catalogoProvider.notifier)
          .recargar(olvidarImagenes: fin.actualizadas > 0 || !automatico);
    }
    if (automatico && fin.hayCambios) {
      ref.read(avisoCambiosProvider.notifier).avisar(fin);
    }

    // Archivos que se estaban copiando: se mira otra vez dentro de un rato
    // (cada vez se espera más, hasta 5 minutos, por si uno no acaba nunca).
    if (fin.enUso > 0) {
      _reintento = Timer(_esperaReintento, revisar);
      _esperaReintento = Duration(
        seconds: (_esperaReintento.inSeconds * 2).clamp(15, 300),
      );
    } else {
      _esperaReintento = const Duration(seconds: 15);
    }
    if (_revisarOtraVez) {
      _revisarOtraVez = false;
      unawaited(revisar());
    }
  }

  /// Revisión rápida pedida por el vigilante (o al arrancar). Si ya hay un
  /// escaneo en marcha, se hace otra al terminar.
  Future<void> revisar() async {
    if (enMarcha) {
      _revisarOtraVez = true;
      return;
    }
    await iniciar(automatico: true);
  }

  void cancelar() => _escaner?.cancelar();
}

/// Cuándo terminó el último escaneo (`null` si nunca se ha completado uno).
final ultimoEscaneoProvider = NotifierProvider<UltimoEscaneo, DateTime?>(
  UltimoEscaneo.new,
);

class UltimoEscaneo extends Notifier<DateTime?> {
  static const clave = 'ultimoEscaneo';

  @override
  DateTime? build() =>
      DateTime.tryParse(ref.read(ajustesInicialesProvider)[clave] ?? '');

  Future<void> guardar(DateTime fecha) async {
    state = fecha;
    await ref
        .read(baseDatosProvider)
        .guardarAjuste(clave, fecha.toIso8601String());
  }
}

/// Último resultado de una revisión automática con cambios, para avisar
/// («1 película nueva: …»). El marco lo enseña y lo vacía.
final avisoCambiosProvider = NotifierProvider<AvisoCambios, ProgresoEscaneo?>(
  AvisoCambios.new,
);

class AvisoCambios extends Notifier<ProgresoEscaneo?> {
  @override
  ProgresoEscaneo? build() => null;

  void avisar(ProgresoEscaneo resultado) => state = resultado;
}

/// ¿Existe la carpeta raíz? (Si el disco está desconectado, no.)
bool carpetaDisponible(String? ruta) =>
    ruta != null && Directory(ruta).existsSync();

// ── Disco ────────────────────────────────────────────────────────────────

/// ¿Está conectado el disco de la colección? Se comprueba al arrancar y cada
/// 5 segundos. Sin disco la app sigue funcionando (el catálogo está en la base
/// de datos), pero no se puede reproducir ni abrir la carpeta. En el modo
/// consulta (sin disco propio) siempre es `true`.
final discoConectadoProvider = StreamProvider<bool>((ref) {
  final raiz = ref.watch(carpetaRaizProvider);
  if (!esAdministrador || raiz == null) return Stream.value(true);
  Future<bool> comprobar() => Directory(raiz).exists();
  return (() async* {
    yield await comprobar();
    yield* Stream.periodic(const Duration(seconds: 5))
        .asyncMap((_) => comprobar());
  })().distinct();
});

/// ¿Sigue el archivo en su sitio? (Puede haberse movido o borrado desde el
/// último escaneo.) Se vuelve a mirar cuando el disco se conecta.
final archivoExisteProvider = FutureProvider.autoDispose.family<bool, String>((
  ref,
  ruta,
) async {
  if (!(ref.watch(discoConectadoProvider).value ?? true)) return false;
  return File(ruta).exists();
});

/// Nombre corto de la carpeta raíz para los avisos: `D:\` → «el disco D:».
String nombreDisco(String? raiz) {
  if (raiz == null) return 'el disco';
  final unidad = RegExp(r'^([A-Za-z]):').firstMatch(raiz);
  if (unidad != null) return 'el disco ${unidad.group(1)!.toUpperCase()}:';
  return raiz.startsWith(r'\') ? 'la carpeta de red' : 'la carpeta';
}

// ── Personas ─────────────────────────────────────────────────────────────

/// Si una persona aparece como director o como actor.
enum Papel { direccion, reparto }

/// Películas de la colección de una persona, de la más reciente a la más
/// antigua. Los nombres se comparan sin tildes ni mayúsculas.
final peliculasDePersonaProvider =
    Provider.family<List<Pelicula>, (String, Papel)>((ref, persona) {
      final (nombre, papel) = persona;
      final filtro = papel == Papel.direccion
          ? Filtros(director: nombre)
          : Filtros(actor: nombre);
      return filtro.aplicar(
        ref.watch(catalogoProvider).value ?? const <Pelicula>[],
      )..sort((a, b) {
        final c = b.anio.compareTo(a.anio);
        return c != 0 ? c : a.titulo.compareTo(b.titulo);
      });
    });
