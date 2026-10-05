import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../tablon/cifrado.dart';
import '../tablon/copia_local.dart';
import '../tablon/github.dart' show TablonException;
import '../tablon/lector.dart';
import '../utilidades.dart';
import 'catalogo.dart';

// El modo consulta: la copia del catálogo descargada del tablón.
//
// Al abrir la app se enseña lo que ya hay descargado (funciona sin internet)
// y, mientras, se mira si se ha publicado una versión nueva; si la hay, se
// bajan solo los cambios. También se mira al volver a la app (en el móvil) y
// cada 30 minutos con la app abierta.

enum FaseCopia {
  /// Esperando (al día, o sin haber mirado todavía).
  quieta,
  buscando,
  descargando,

  /// No se ha podido mirar (sin internet, GitHub no contesta…).
  error,

  /// La contraseña común ha cambiado: hay que volver a entrar.
  contrasenaCambiada,
}

class EstadoConsulta {
  const EstadoConsulta({
    required this.copia,
    this.fase = FaseCopia.quieta,
    this.progreso,
    this.error,
    this.sinInternet = false,
    this.comprobada,
    this.ultimo,
  });

  /// Lo descargado.
  final EstadoCopia copia;
  final FaseCopia fase;
  final ProgresoDescarga? progreso;
  final String? error;
  final bool sinInternet;

  /// Cuándo se miró por última vez que estaba al día.
  final DateTime? comprobada;

  /// Lo que trajo la última actualización de esta sesión.
  final ResultadoDescarga? ultimo;

  String get repositorio => copia.repositorio;
  bool get trabajando =>
      fase == FaseCopia.buscando || fase == FaseCopia.descargando;

  EstadoConsulta copyWith({
    EstadoCopia? copia,
    required FaseCopia fase,
    ProgresoDescarga? progreso,
    String? error,
    bool sinInternet = false,
    DateTime? comprobada,
    ResultadoDescarga? ultimo,
  }) => EstadoConsulta(
    copia: copia ?? this.copia,
    fase: fase,
    progreso: progreso,
    error: error,
    sinInternet: sinInternet,
    comprobada: comprobada ?? this.comprobada,
    ultimo: ultimo ?? this.ultimo,
  );
}

final consultaProvider = NotifierProvider<Consulta, EstadoConsulta>(
  Consulta.new,
);

class Consulta extends Notifier<EstadoConsulta> {
  /// Cada cuánto se mira si hay versión nueva con la app abierta.
  static const cadaCuanto = Duration(minutes: 30);

  /// Al volver a la app, no se mira otra vez si se miró hace menos de esto.
  static const minimo = Duration(minutes: 5);

  Timer? _temporizador;
  LectorTablon? _lector;

  @override
  EstadoConsulta build() {
    ref.onDispose(() {
      _temporizador?.cancel();
      _lector?.cerrar();
    });
    final a = ref.read(ajustesInicialesProvider);
    final copia = EstadoCopia.deAjustes(a);
    final repositorio = a[AjusteConsulta.repositorio] ?? '';
    // Al abrir la app, se mira enseguida.
    Future.microtask(comprobar);
    _temporizador = Timer.periodic(cadaCuanto, (_) => comprobar());
    return EstadoConsulta(
      copia: copia.repositorio == repositorio
          ? copia
          : EstadoCopia(repositorio: repositorio),
    );
  }

  /// Mira si hay una versión nueva del tablón y, si la hay, la descarga.
  /// Con [siHaceRato] no hace nada si se miró hace menos de [minimo].
  Future<void> comprobar({bool siHaceRato = false}) async {
    if (state.trabajando || state.fase == FaseCopia.contrasenaCambiada) return;
    final comprobada = state.comprobada;
    if (siHaceRato &&
        comprobada != null &&
        DateTime.now().difference(comprobada) < minimo) {
      return;
    }
    final a = ref.read(ajustesInicialesProvider);
    final repositorio = a[AjusteConsulta.repositorio] ?? '';
    final textoLlave = a[AjusteConsulta.llave] ?? '';
    final ParametrosLlave parametros;
    try {
      parametros = ParametrosLlave.desdeJson(
        jsonDecode(a[AjusteConsulta.parametros] ?? '') as Map<String, dynamic>,
      );
    } on Object {
      state = state.copyWith(fase: FaseCopia.contrasenaCambiada);
      return;
    }
    if (repositorio.isEmpty || textoLlave.isEmpty) {
      state = state.copyWith(fase: FaseCopia.contrasenaCambiada);
      return;
    }

    final lector = _lector ??= LectorTablon(repositorio);
    final catalogo = ref.read(catalogoProvider.notifier);
    state = state.copyWith(fase: FaseCopia.buscando);
    try {
      final r = await actualizarCopia(
        lector: lector,
        llave: LlaveTablon.desdeTexto(textoLlave),
        parametros: parametros,
        bd: ref.read(baseDatosProvider),
        carpetas: ref.read(carpetasAppProvider),
        alAvanzar: (p) =>
            state = state.copyWith(fase: FaseCopia.descargando, progreso: p),
        alTenerFichas: catalogo.recargar,
      );
      if (!r.alDia) {
        await catalogo.recargar(olvidarImagenes: r.caratulasCambiadas);
      }
      state = state.copyWith(
        copia: r.estado,
        fase: FaseCopia.quieta,
        comprobada: DateTime.now(),
        ultimo: r.alDia ? null : r,
      );
    } on ContrasenaCambiada {
      state = state.copyWith(fase: FaseCopia.contrasenaCambiada);
    } on TablonException catch (e) {
      state = state.copyWith(
        fase: FaseCopia.error,
        error: e.mensaje,
        sinInternet: e.sinInternet,
      );
    } on Object catch (e) {
      state = state.copyWith(
        fase: FaseCopia.error,
        error: 'No se ha podido descargar el catálogo: $e',
      );
    }
  }
}

/// Texto corto de lo que ha cambiado: «3 películas nuevas · 1 cambiada».
String textoNovedades(ResultadoDescarga r) {
  String plural(int n, String una, String varias) =>
      n == 1 ? una : '${formatoNumero(n)} $varias';
  final partes = [
    if (r.nuevas > 0) plural(r.nuevas, '1 película nueva', 'películas nuevas'),
    if (r.cambiadas > 0)
      plural(r.cambiadas, '1 ficha cambiada', 'fichas cambiadas'),
    if (r.quitadas > 0)
      plural(r.quitadas, '1 película quitada', 'películas quitadas'),
  ];
  if (partes.isNotEmpty) return partes.join(' · ');
  return r.caratulasCambiadas
      ? 'carátulas nuevas'
      : 'sin cambios en las fichas';
}
