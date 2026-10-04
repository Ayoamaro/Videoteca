import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../disco/escritor.dart';
import '../fuentes/conexion.dart';
import '../fuentes/datos_automaticos.dart';
import '../fuentes/lote.dart';
import '../modelos/pelicula.dart';
import 'base_datos.dart';
import 'catalogo.dart';
import 'edicion.dart';
import 'fuentes.dart';

// «Completar mi colección»: el lote que rellena los campos vacíos de todas
// las películas, de una en una y en segundo plano.
//
// Lo hecho con cada película se guarda en la tabla `Lote` de la base de
// datos, así que se puede pausar, cerrar la app y seguir otro día. Se
// trabaja por tandas («primero 50»), y cada tanda se puede deshacer entera.
// Cada escritura pasa por lo mismo que «Editar ficha»: comprobación con
// Windows, registro de cambios y deshacer.

/// Los datos de [p] como textos por campo (como `valoresFicha`, pero desde
/// el catálogo).
Map<Campo, String> valoresPelicula(Pelicula p) => {
  Campo.titulo: p.titulo,
  Campo.tituloOriginal: p.tituloOriginal,
  Campo.anio: p.anio == 0 ? '' : '${p.anio}',
  Campo.generos: p.generos.join('. '),
  Campo.sinopsis: p.sinopsis,
  Campo.direccion: p.direccion,
  Campo.reparto: p.reparto,
  Campo.guion: p.guion,
  Campo.musica: p.musica,
  Campo.fotografia: p.fotografia,
  Campo.productora: p.productora,
  Campo.pais: p.pais,
  Campo.clasificacion: p.clasificacion,
  Campo.estrellas: p.estrellas == 0 ? '' : '${p.estrellas}',
  Campo.temas: p.temas.join('; '),
  Campo.premios: p.premios,
  Campo.saga: p.saga,
  Campo.numeroSaga: p.numeroSaga == 0 ? '' : '${p.numeroSaga}',
  Campo.enlaceFilmaffinity: p.enlaceFilmaffinity,
  Campo.enlaceImdb: p.enlaceImdb,
};

enum Marcha {
  /// Sin tanda abierta.
  parado,
  enMarcha,

  /// Se ha pedido pausar: se termina la película de ahora y se para.
  pausando,

  /// Tanda abierta, parada (por ti, por falta de internet…).
  pausado,

  /// Deshaciendo una tanda.
  deshaciendo,
}

/// Una tanda abierta: su número y cuántas películas tiene que hacer
/// (`null` = todas las que queden).
typedef Tanda = ({int numero, int? objetivo});

class EstadoColeccion {
  const EstadoColeccion({
    this.cargado = false,
    this.filas = const {},
    this.opciones = const {},
    this.marcha = Marcha.parado,
    this.tanda,
    this.actual,
    this.aviso,
    this.sinOmdb = false,
    this.segundosPorPelicula,
    this.progresoDeshacer,
  });

  final bool cargado;

  /// Película → lo hecho con ella en el lote.
  final Map<int, FilaLote> filas;

  /// Lo que se rellena.
  final Set<OpcionLote> opciones;
  final Marcha marcha;
  final Tanda? tanda;

  /// La película que se está haciendo ahora.
  final Pelicula? actual;

  /// Por qué se ha parado solo (sin internet, disco desconectado…).
  final String? aviso;

  /// Hoy ya no quedan consultas de OMDb: no se piden estrellas.
  final bool sinOmdb;

  /// Lo que tarda de media cada película (para calcular lo que queda).
  final double? segundosPorPelicula;

  /// Al deshacer: (hechas, total).
  final (int, int)? progresoDeshacer;

  bool get trabajando =>
      marcha == Marcha.enMarcha ||
      marcha == Marcha.pausando ||
      marcha == Marcha.deshaciendo;

  /// Cuántas lleva la tanda abierta.
  int get hechasTanda {
    final t = tanda;
    if (t == null) return 0;
    return filas.values.where((f) => f.tanda == t.numero).length;
  }

  EstadoColeccion copyWith({
    bool? cargado,
    Map<int, FilaLote>? filas,
    Set<OpcionLote>? opciones,
    Marcha? marcha,
    Tanda? Function()? tanda,
    Pelicula? Function()? actual,
    String? Function()? aviso,
    bool? sinOmdb,
    double? segundosPorPelicula,
    (int, int)? Function()? progresoDeshacer,
  }) => EstadoColeccion(
    cargado: cargado ?? this.cargado,
    filas: filas ?? this.filas,
    opciones: opciones ?? this.opciones,
    marcha: marcha ?? this.marcha,
    tanda: tanda == null ? this.tanda : tanda(),
    actual: actual == null ? this.actual : actual(),
    aviso: aviso == null ? this.aviso : aviso(),
    sinOmdb: sinOmdb ?? this.sinOmdb,
    segundosPorPelicula: segundosPorPelicula ?? this.segundosPorPelicula,
    progresoDeshacer: progresoDeshacer == null
        ? this.progresoDeshacer
        : progresoDeshacer(),
  );
}

/// Origen con el que quedan anotados los cambios en el registro.
const origenLote = 'Completar mi colección';

final coleccionProvider = NotifierProvider<Coleccion, EstadoColeccion>(
  Coleccion.new,
);

/// Películas que aún tiene que hacer el lote (las que no se han hecho y
/// tienen vacío alguno de los campos elegidos), en el orden del disco.
final pendientesLoteProvider = Provider<List<Pelicula>>((ref) {
  final estado = ref.watch(coleccionProvider);
  final campos = OpcionLote.camposDe(estado.opciones);
  final catalogo = ref.watch(catalogoProvider).value ?? const <Pelicula>[];
  if (!estado.cargado || campos.isEmpty) return const [];
  return [
    for (final p in catalogo)
      if (!estado.filas.containsKey(p.id) &&
          camposVacios(valoresPelicula(p), campos).isNotEmpty)
        p,
  ]..sort((a, b) => a.ruta.compareTo(b.ruta));
});

/// Cuántas películas tienen vacío cada campo (para las casillas).
final vaciosPorOpcionProvider = Provider<Map<OpcionLote, int>>((ref) {
  final catalogo = ref.watch(catalogoProvider).value ?? const <Pelicula>[];
  final cuenta = {for (final o in OpcionLote.values) o: 0};
  for (final p in catalogo) {
    final v = valoresPelicula(p);
    for (final o in OpcionLote.values) {
      if (o.campos.any((c) => v[c]!.isEmpty)) cuenta[o] = cuenta[o]! + 1;
    }
  }
  return cuenta;
});

class Coleccion extends Notifier<EstadoColeccion> {
  static const _ajusteOpciones = 'loteOpciones';
  static const _ajusteTanda = 'loteTanda';
  static const _ajusteSinOmdb = 'loteSinOmdb';

  /// Cada cuántas películas se vuelve a cargar el catálogo.
  static const _recargarCada = 20;

  @override
  EstadoColeccion build() {
    final ajustes = ref.read(ajustesInicialesProvider);
    final guardadas = ajustes[_ajusteOpciones];
    final opciones = guardadas == null
        ? OpcionLote.values.toSet()
        : {
            for (final n in guardadas.split(','))
              ...OpcionLote.values.where((o) => o.name == n),
          };
    Tanda? tanda;
    try {
      final t = jsonDecode(ajustes[_ajusteTanda] ?? '') as Map;
      tanda = (numero: t['numero'] as int, objetivo: t['objetivo'] as int?);
    } catch (_) {}
    Future.microtask(_cargar);
    return EstadoColeccion(
      opciones: opciones,
      tanda: tanda,
      // Una tanda que quedó abierta (p. ej. al cerrar la app) sigue en pausa.
      marcha: tanda == null ? Marcha.parado : Marcha.pausado,
      sinOmdb: ajustes[_ajusteSinOmdb] == _hoy(),
    );
  }

  BaseDatos get _bd => ref.read(baseDatosProvider);

  static String _hoy() => DateTime.now().toIso8601String().substring(0, 10);

  Future<void> _cargar() async {
    List<FilaLote> filas;
    try {
      filas = await _bd.filasLote();
    } catch (_) {
      // Sin base de datos (p. ej. en las pruebas de pantallas).
      filas = const [];
    }
    state = state.copyWith(
      cargado: true,
      filas: {for (final f in filas) f.pelicula: f},
    );
  }

  /// Marca o desmarca lo que se rellena (no mientras trabaja).
  Future<void> cambiarOpcion(OpcionLote o, bool marcada) async {
    if (state.trabajando) return;
    final opciones = {...state.opciones};
    marcada ? opciones.add(o) : opciones.remove(o);
    state = state.copyWith(opciones: opciones);
    await _bd.guardarAjuste(
      _ajusteOpciones,
      [
        for (final o in OpcionLote.values)
          if (opciones.contains(o)) o.name,
      ].join(','),
    );
  }

  /// Abre una tanda nueva de [cuantas] películas (`null` = todas) y empieza.
  Future<void> empezar(int? cuantas) async {
    if (state.marcha != Marcha.parado) return;
    final numero =
        state.filas.values.fold(0, (m, f) => f.tanda > m ? f.tanda : m) + 1;
    final tanda = (numero: numero, objetivo: cuantas);
    await _bd.guardarAjuste(
      _ajusteTanda,
      jsonEncode({'numero': tanda.numero, 'objetivo': tanda.objetivo}),
    );
    state = state.copyWith(tanda: () => tanda, aviso: () => null);
    await _seguir();
  }

  /// Sigue con la tanda en pausa.
  Future<void> reanudar() async {
    if (state.marcha != Marcha.pausado) return;
    state = state.copyWith(aviso: () => null);
    await _seguir();
  }

  /// Para al terminar la película de ahora.
  void pausar() {
    if (state.marcha == Marcha.enMarcha) {
      state = state.copyWith(marcha: Marcha.pausando);
    }
  }

  /// Cierra la tanda en pausa (lo hecho se queda hecho).
  Future<void> terminarTanda() async {
    if (state.marcha != Marcha.pausado) return;
    await _cerrarTanda();
  }

  Future<void> _cerrarTanda() async {
    await _bd.guardarAjuste(_ajusteTanda, '');
    state = state.copyWith(
      marcha: Marcha.parado,
      tanda: () => null,
      actual: () => null,
    );
  }

  /// Para solo, con un [aviso] de por qué.
  void _pararSolo(String aviso) {
    state = state.copyWith(
      marcha: Marcha.pausado,
      actual: () => null,
      aviso: () => aviso,
    );
  }

  Future<void> _seguir() async {
    state = state.copyWith(marcha: Marcha.enMarcha);
    final edicion = ref.read(edicionProvider);
    final tiempos = <double>[];
    var desdeRecarga = 0;
    try {
      while (state.marcha == Marcha.enMarcha) {
        final tanda = state.tanda!;
        if (tanda.objetivo != null && state.hechasTanda >= tanda.objetivo!) {
          await _cerrarTanda();
          break;
        }
        final fuentes = ref.read(fuentesDatosProvider);
        if (fuentes == null) {
          _pararSolo('Falta la clave de TMDB (Ajustes → Servicios de datos).');
          break;
        }
        if (!(ref.read(discoConectadoProvider).value ?? true)) {
          _pararSolo('El disco no está conectado.');
          break;
        }
        final p = ref.read(pendientesLoteProvider).firstOrNull;
        if (p == null) {
          await _cerrarTanda();
          break;
        }
        state = state.copyWith(actual: () => p);
        final reloj = Stopwatch()..start();
        final fila = await _hacer(p, fuentes, edicion, tanda.numero);
        if (fila == null) break; // Se ha parado solo (sin internet…).
        await _bd.anotarLote(fila.toCompanion(true));
        tiempos.add(reloj.elapsedMilliseconds / 1000);
        if (tiempos.length > 20) tiempos.removeAt(0);
        state = state.copyWith(
          filas: {...state.filas, p.id: fila},
          segundosPorPelicula: tiempos.reduce((a, b) => a + b) / tiempos.length,
        );
        if (fila.cambio != null && ++desdeRecarga >= _recargarCada) {
          desdeRecarga = 0;
          await edicion.recargarCatalogo();
        }
      }
    } finally {
      if (state.marcha == Marcha.pausando || state.marcha == Marcha.enMarcha) {
        state = state.copyWith(marcha: Marcha.pausado, actual: () => null);
      }
      await edicion.recargarCatalogo();
    }
  }

  /// Hace una película. Devuelve su fila del lote, o `null` si hay que
  /// parar (sin internet, clave mala…), y entonces la película queda
  /// pendiente.
  Future<FilaLote?> _hacer(
    Pelicula p,
    FuentesDatos fuentes,
    Edicion edicion,
    int tanda,
  ) async {
    FilaLote fila(EstadoLote e, String mensaje, [int? cambio]) => FilaLote(
      pelicula: p.id,
      tanda: tanda,
      estado: e.name,
      mensaje: mensaje,
      cambio: cambio,
      fecha: DateTime.now(),
    );

    if (!File(p.ruta).existsSync()) {
      return fila(EstadoLote.error, 'No se encuentra el archivo.');
    }
    final PlanLote plan;
    try {
      plan = await planificarLote(
        fuentes,
        datos: (
          titulo: p.titulo,
          tituloOriginal: p.tituloOriginal,
          anio: p.anio,
          direccion: p.direccion,
        ),
        actuales: valoresPelicula(p),
        campos: OpcionLote.camposDe(state.opciones),
        sinOmdb: state.sinOmdb,
      );
    } on FuenteException catch (e) {
      if (e.sinInternet || e.claveMala || e.limite) {
        _pararSolo('$e');
        return null;
      }
      return fila(EstadoLote.error, '$e');
    } catch (e) {
      return fila(EstadoLote.error, 'Ha fallado: $e');
    }

    if (plan.limiteOmdb && !state.sinOmdb) {
      state = state.copyWith(sinOmdb: true);
      await _bd.guardarAjuste(_ajusteSinOmdb, _hoy());
    }
    final avisos = [
      for (final f in plan.fallos)
        f.limite ? '${f.servicio}: sin consultas hasta mañana' : '$f',
    ];
    String conAvisos(String m) =>
        avisos.isEmpty ? m : '$m · ${avisos.join(' · ')}';
    if (plan.cambios.isEmpty) return fila(plan.estado, conAvisos(plan.mensaje));
    try {
      final cambio = await edicion.guardar(
        p,
        plan.cambios,
        origen: origenLote,
        soloVacios: true,
        recargar: false,
      );
      if (cambio == null) {
        return fila(
          EstadoLote.sinDatos,
          conAvisos('El archivo ya tenía esos datos.'),
        );
      }
      return fila(EstadoLote.completada, conAvisos(plan.mensaje), cambio);
    } on EscrituraException catch (e) {
      return fila(EstadoLote.error, 'No se ha escrito: ${e.mensaje}');
    } catch (e) {
      return fila(EstadoLote.error, 'No se ha escrito: $e');
    }
  }

  /// Vuelve a dejar pendientes las películas con error (para intentarlo
  /// otra vez).
  Future<void> reintentarErrores() async {
    if (state.trabajando) return;
    final ids = [
      for (final f in state.filas.values)
        if (f.estado == EstadoLote.error.name) f.pelicula,
    ];
    await _bd.olvidarLote(ids);
    state = state.copyWith(
      filas: {...state.filas}..removeWhere((id, _) => ids.contains(id)),
    );
  }

  /// Deshace todo lo escrito en la tanda [numero] y la olvida (sus películas
  /// vuelven a quedar pendientes). Las que se han cambiado después a mano no
  /// se tocan. Devuelve (deshechas, saltadas por haber cambiado, errores).
  Future<(int, int, List<String>)> deshacerTanda(int numero) async {
    if (state.marcha != Marcha.parado) return (0, 0, const <String>[]);
    final edicion = ref.read(edicionProvider);
    final filas = [
      for (final f in state.filas.values)
        if (f.tanda == numero) f,
    ];
    final conCambio = filas.where((f) => f.cambio != null).toList();
    state = state.copyWith(
      marcha: Marcha.deshaciendo,
      progresoDeshacer: () => (0, conCambio.length),
    );
    var deshechas = 0;
    var saltadas = 0;
    final errores = <String>[];
    final olvidar = <int>[
      for (final f in filas)
        if (f.cambio == null) f.pelicula,
    ];
    try {
      for (final (i, f) in conCambio.indexed) {
        state = state.copyWith(progresoDeshacer: () => (i, conCambio.length));
        final titulo =
            ref.read(peliculasPorIdProvider)[f.pelicula]?.titulo ?? '';
        try {
          final cambio = await _bd.cambio(f.cambio!);
          if (cambio?.deshecho != null) {
            olvidar.add(f.pelicula);
            continue;
          }
          if ((await edicion.conflictos(f.cambio!)).isNotEmpty) {
            saltadas++;
            continue;
          }
          await edicion.deshacer(f.cambio!, recargar: false);
          deshechas++;
          olvidar.add(f.pelicula);
        } on Exception catch (e) {
          errores.add('$titulo: ${e is EscrituraException ? e.mensaje : e}');
        }
      }
      await _bd.olvidarLote(olvidar);
      state = state.copyWith(
        filas: {...state.filas}..removeWhere((id, _) => olvidar.contains(id)),
      );
    } finally {
      state = state.copyWith(
        marcha: Marcha.parado,
        progresoDeshacer: () => null,
      );
      await edicion.recargarCatalogo();
    }
    return (deshechas, saltadas, errores);
  }

  /// Olvida todo lo hecho (no toca los archivos): las películas que aún
  /// tengan campos vacíos vuelven a quedar pendientes.
  Future<void> empezarDeCero() async {
    if (state.marcha != Marcha.parado) return;
    await _bd.olvidarLote(state.filas.keys.toList());
    state = state.copyWith(filas: const {});
  }

  /// Anota que la película [id] se ha revisado a mano (p. ej. una dudosa
  /// resuelta en Editar ficha): sale de su lista.
  Future<void> marcarRevisada(int id) async {
    final f = state.filas[id];
    if (f == null) return;
    final nueva = f.copyWith(
      estado: EstadoLote.completada.name,
      mensaje:
          'Revisada a mano (antes: ${EstadoLote.porNombre(f.estado).texto.toLowerCase()}).',
    );
    await _bd.anotarLote(nueva.toCompanion(true));
    state = state.copyWith(filas: {...state.filas, id: nueva});
  }
}

/// Las tandas hechas, de la más reciente a la más antigua: número, fecha de
/// la última película y cuántas de cada estado.
List<({int numero, DateTime fecha, Map<EstadoLote, int> cuenta})> tandasDe(
  Iterable<FilaLote> filas,
) {
  final porTanda = <int, List<FilaLote>>{};
  for (final f in filas) {
    (porTanda[f.tanda] ??= []).add(f);
  }
  return [
    for (final MapEntry(key: n, value: lista) in porTanda.entries)
      (
        numero: n,
        fecha: lista.map((f) => f.fecha).reduce((a, b) => a.isAfter(b) ? a : b),
        cuenta: {
          for (final e in EstadoLote.values)
            e: lista.where((f) => f.estado == e.name).length,
        },
      ),
  ]..sort((a, b) => b.numero.compareTo(a.numero));
}

// ── Repaso con FilmAffinity ──────────────────────────────────────────────

/// Películas ya repasadas con FilmAffinity (guardadas o saltadas): no se
/// vuelven a proponer. Se guardan en los ajustes.
final repasadasProvider = NotifierProvider<Repasadas, Set<int>>(Repasadas.new);

class Repasadas extends Notifier<Set<int>> {
  static const clave = 'repasoHechas';

  @override
  Set<int> build() {
    try {
      final texto = ref.read(ajustesInicialesProvider)[clave] ?? '[]';
      return {...(jsonDecode(texto) as List).cast<int>()};
    } catch (_) {
      return const {};
    }
  }

  Future<void> marcar(int id) => _guardar({...state, id});

  /// Vuelve a proponer todas.
  Future<void> olvidar() => _guardar(const {});

  Future<void> _guardar(Set<int> ids) async {
    state = ids;
    await ref
        .read(baseDatosProvider)
        .guardarAjuste(clave, jsonEncode(ids.toList()..sort()));
  }
}

/// Las películas por repasar de cada tipo, en el orden del disco.
final colaRepasoProvider = Provider.family<List<Pelicula>, TipoRepaso>((
  ref,
  tipo,
) {
  final catalogo = ref.watch(catalogoProvider).value ?? const <Pelicula>[];
  final hechas = ref.watch(repasadasProvider);
  return [
    for (final p in catalogo)
      if (!hechas.contains(p.id) &&
          entraEnRepaso(tipo, sinopsis: p.sinopsis, temas: p.temas.join('; ')))
        p,
  ]..sort((a, b) => a.ruta.compareTo(b.ruta));
});
