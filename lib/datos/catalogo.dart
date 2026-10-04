import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../disco/caratula_mp4.dart';
import '../disco/escaner.dart';
import '../modelos/pelicula.dart';
import 'base_datos.dart';
import 'carpetas_app.dart';

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
  @override
  Future<List<Pelicula>> build() => _cargar();

  Future<List<Pelicula>> _cargar() async {
    final carpetas = ref.read(carpetasAppProvider);
    final filas = await ref.read(baseDatosProvider).todasLasPeliculas();
    return [for (final f in filas) peliculaDesdeFila(f, carpetas)];
  }

  /// Vuelve a leer la base de datos (p. ej. después de escanear). Con
  /// [olvidarImagenes] se descartan las miniaturas ya cargadas en memoria,
  /// por si alguna ha cambiado.
  Future<void> recargar({bool olvidarImagenes = false}) async {
    final peliculas = await _cargar();
    if (olvidarImagenes) PaintingBinding.instance.imageCache.clear();
    state = AsyncData(peliculas);
  }
}

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

/// Una película por su número, o `null` si no está.
final peliculaPorIdProvider = Provider.family<Pelicula?, int>((ref, id) {
  for (final p in ref.watch(catalogoProvider).value ?? const <Pelicula>[]) {
    if (p.id == id) return p;
  }
  return null;
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

  @override
  ProgresoEscaneo? build() => null;

  bool get enMarcha => state?.enMarcha ?? false;

  /// Escanea la carpeta raíz (o [raiz], si se da). Con [completo] vuelve a
  /// leer todos los archivos; si no, solo los nuevos o cambiados.
  Future<void> iniciar({String? raiz, bool completo = false}) async {
    raiz ??= ref.read(carpetaRaizProvider);
    if (raiz == null || enMarcha) return;
    final bd = ref.read(baseDatosProvider);
    final escaner = _escaner = Escaner(
      bd: bd,
      raiz: raiz,
      carpetas: ref.read(carpetasAppProvider),
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
    await bd.guardarAjuste('ultimoEscaneo', DateTime.now().toIso8601String());
    await ref.read(catalogoProvider.notifier).recargar(olvidarImagenes: true);
  }

  void cancelar() => _escaner?.cancelar();
}

/// ¿Existe la carpeta raíz? (Si el disco está desconectado, no.)
bool carpetaDisponible(String? ruta) =>
    ruta != null && Directory(ruta).existsSync();
