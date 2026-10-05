import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../tablon/cifrado.dart';
import '../tablon/github.dart';
import '../tablon/publicador.dart';
import 'catalogo.dart';

// La publicación del catálogo en el tablón de GitHub, desde el PC del
// administrador.
//
// Cuando cambia el catálogo (al guardar una ficha, al llegar una película
// nueva…) se espera a que haya 30 s de calma y se publica solo. Si no hay
// internet se vuelve a intentar al rato. Lo que se guarda en este PC: el
// repositorio, la llave de GitHub y la llave sacada de la contraseña común
// (la contraseña en sí no se guarda).

/// Ajustes donde se guarda la configuración.
abstract final class _Ajuste {
  static const repositorio = 'repoTablon';
  static const llaveGithub = 'llaveGithub';
  static const llave = 'llaveTablon';
  static const parametros = 'parametrosTablon';
  static const automatico = 'publicarSolo';
  static const version = 'versionTablon';
  static const fecha = 'fechaTablon';
}

enum FasePublicacion {
  /// Sin configurar.
  apagada,

  /// Configurado y al día (o esperando a que cambie algo).
  quieta,

  /// Ha cambiado el catálogo: se publicará tras unos segundos de calma.
  esperando,
  publicando,
  error,
}

class EstadoTablon {
  const EstadoTablon({
    this.repositorio = '',
    this.llaveGithub = '',
    this.llave,
    this.parametros,
    this.automatico = true,
    this.version = 0,
    this.fecha,
    this.fase = FasePublicacion.apagada,
    this.progreso,
    this.error,
    this.errorDeLlave = false,
    this.ultimo,
  });

  final String repositorio;
  final String llaveGithub;
  final LlaveTablon? llave;
  final ParametrosLlave? parametros;

  /// Publicar solo al cambiar el catálogo.
  final bool automatico;

  /// Última versión publicada y cuándo.
  final int version;
  final DateTime? fecha;

  final FasePublicacion fase;
  final ProgresoPublicacion? progreso;
  final String? error;

  /// El error es de la llave de GitHub (no se reintenta solo).
  final bool errorDeLlave;

  /// Lo que pasó en la última publicación de esta sesión.
  final ResultadoPublicacion? ultimo;

  bool get configurado =>
      repositorio.isNotEmpty && llaveGithub.isNotEmpty && llave != null;

  EstadoTablon copyWith({
    String? repositorio,
    String? llaveGithub,
    LlaveTablon? llave,
    ParametrosLlave? parametros,
    bool? automatico,
    int? version,
    DateTime? fecha,
    FasePublicacion? fase,
    ProgresoPublicacion? progreso,
    String? error,
    bool errorDeLlave = false,
    ResultadoPublicacion? ultimo,
  }) => EstadoTablon(
    repositorio: repositorio ?? this.repositorio,
    llaveGithub: llaveGithub ?? this.llaveGithub,
    llave: llave ?? this.llave,
    parametros: parametros ?? this.parametros,
    automatico: automatico ?? this.automatico,
    version: version ?? this.version,
    fecha: fecha ?? this.fecha,
    fase: fase ?? this.fase,
    progreso: progreso,
    error: error,
    errorDeLlave: errorDeLlave,
    ultimo: ultimo ?? this.ultimo,
  );
}

final tablonProvider = NotifierProvider<Tablon, EstadoTablon>(Tablon.new);

class Tablon extends Notifier<EstadoTablon> {
  /// Calma que se espera tras un cambio antes de publicar, y lo máximo que
  /// se deja esperar si no paran de llegar cambios (p. ej. durante un lote).
  static const calma = Duration(seconds: 30);
  static const esperaMaxima = Duration(minutes: 5);

  Timer? _temporizador;
  DateTime? _primerCambio;
  bool _otraVez = false;

  @override
  EstadoTablon build() {
    ref.onDispose(() => _temporizador?.cancel());
    final a = ref.read(ajustesInicialesProvider);
    ParametrosLlave? parametros;
    try {
      final json = a[_Ajuste.parametros];
      if (json != null) {
        parametros = ParametrosLlave.desdeJson(
          jsonDecode(json) as Map<String, dynamic>,
        );
      }
    } on Object {
      parametros = null;
    }
    final textoLlave = a[_Ajuste.llave] ?? '';
    final estado = EstadoTablon(
      repositorio: a[_Ajuste.repositorio] ?? '',
      llaveGithub: a[_Ajuste.llaveGithub] ?? '',
      llave: textoLlave.isEmpty || parametros == null
          ? null
          : LlaveTablon.desdeTexto(textoLlave),
      parametros: parametros,
      automatico: a[_Ajuste.automatico] != '0',
      version: int.tryParse(a[_Ajuste.version] ?? '') ?? 0,
      fecha: DateTime.tryParse(a[_Ajuste.fecha] ?? ''),
    );

    // Cada cambio del catálogo (no la primera carga) programa una
    // publicación.
    ref.listen(catalogoProvider, (antes, ahora) {
      if (antes?.value != null && ahora.value != null) _programar();
    });
    if (estado.configurado) {
      // Al abrir la app, por si quedó algo sin publicar la otra vez.
      if (estado.automatico) {
        _temporizador = Timer(const Duration(minutes: 1), publicarAhora);
      }
      return estado.copyWith(fase: FasePublicacion.quieta);
    }
    return estado;
  }

  /// Comprueba el [repositorio] y la [llaveGithub] con GitHub y, si se da,
  /// saca la llave de la [contrasena] común. Si todo va bien lo guarda y
  /// publica. Lanza [TablonException] si GitHub no los acepta (y entonces
  /// no se guarda nada).
  Future<InfoRepositorio> configurar({
    required String repositorio,
    required String llaveGithub,
    String? contrasena,
  }) async {
    repositorio = repositorio.trim();
    llaveGithub = llaveGithub.trim();
    if (!GitHub.nombreValido(repositorio)) {
      throw TablonException(
        'El repositorio se escribe «usuario/nombre», p. ej. '
        '«Ayoamaro/Videoteca_Tablon».',
      );
    }
    final github = GitHub(repositorio, llaveGithub);
    final InfoRepositorio info;
    try {
      info = await github.info();
    } finally {
      github.cerrar();
    }
    final bd = ref.read(baseDatosProvider);
    var llave = state.llave, parametros = state.parametros;
    if (contrasena != null) {
      parametros = ParametrosLlave.nuevos();
      llave = await derivarLlaveAparte(contrasena, parametros);
      await bd.guardarAjuste(
        _Ajuste.parametros,
        jsonEncode(parametros.toJson()),
      );
      await bd.guardarAjuste(_Ajuste.llave, llave.aTexto());
    }
    await bd.guardarAjuste(_Ajuste.repositorio, info.nombre);
    await bd.guardarAjuste(_Ajuste.llaveGithub, llaveGithub);
    state = state.copyWith(
      repositorio: info.nombre,
      llaveGithub: llaveGithub,
      llave: llave,
      parametros: parametros,
      fase: FasePublicacion.quieta,
    );
    unawaited(publicarAhora());
    return info;
  }

  /// Cambia la contraseña común: se vuelve a cifrar y subir todo. Los
  /// móviles tendrán que entrar con la nueva.
  Future<void> cambiarContrasena(String contrasena) => configurar(
    repositorio: state.repositorio,
    llaveGithub: state.llaveGithub,
    contrasena: contrasena,
  );

  Future<void> cambiarAutomatico(bool automatico) async {
    await ref
        .read(baseDatosProvider)
        .guardarAjuste(_Ajuste.automatico, automatico ? '1' : '0');
    state = state.copyWith(
      automatico: automatico,
      fase: state.fase,
      progreso: state.progreso,
      error: state.error,
      errorDeLlave: state.errorDeLlave,
    );
    if (automatico && state.fase != FasePublicacion.publicando) _programar();
  }

  /// Deja de publicar en este PC (olvida la llave de GitHub; el tablón se
  /// queda como está).
  Future<void> olvidar() async {
    _temporizador?.cancel();
    final bd = ref.read(baseDatosProvider);
    for (final clave in [_Ajuste.llaveGithub, _Ajuste.llave]) {
      await bd.guardarAjuste(clave, '');
    }
    state = EstadoTablon(
      repositorio: state.repositorio,
      parametros: state.parametros,
      automatico: state.automatico,
      version: state.version,
      fecha: state.fecha,
    );
  }

  /// Publica ya (si ya se está publicando, se repite al terminar).
  Future<void> publicarAhora() async {
    _temporizador?.cancel();
    _primerCambio = null;
    if (!state.configurado) return;
    if (state.fase == FasePublicacion.publicando) {
      _otraVez = true;
      return;
    }
    final raiz = ref.read(carpetaRaizProvider);
    if (raiz == null) return;
    final github = GitHub(state.repositorio, state.llaveGithub);
    state = state.copyWith(fase: FasePublicacion.publicando);
    try {
      final filas = await ref.read(baseDatosProvider).todasLasPeliculas();
      final r = await publicarTablon(
        github: github,
        llave: state.llave!,
        parametros: state.parametros!,
        filas: filas,
        raiz: raiz,
        carpetas: ref.read(carpetasAppProvider),
        versionAnterior: state.version,
        alAvanzar: (p) => state = state.copyWith(
          fase: FasePublicacion.publicando,
          progreso: p,
        ),
      );
      final bd = ref.read(baseDatosProvider);
      final fecha = r.sinCambios ? state.fecha : DateTime.now();
      await bd.guardarAjuste(_Ajuste.version, '${r.version}');
      if (fecha != null) {
        await bd.guardarAjuste(_Ajuste.fecha, fecha.toIso8601String());
      }
      state = state.copyWith(
        fase: FasePublicacion.quieta,
        version: r.version,
        fecha: fecha,
        ultimo: r,
      );
    } on TablonException catch (e) {
      state = state.copyWith(
        fase: FasePublicacion.error,
        error: e.mensaje,
        errorDeLlave: e.llaveMala,
      );
      // Sin internet: se vuelve a intentar dentro de un rato.
      if (e.sinInternet) _programar(espera: const Duration(minutes: 5));
    } on Object catch (e) {
      state = state.copyWith(
        fase: FasePublicacion.error,
        error: 'No se ha podido publicar: $e',
      );
    } finally {
      github.cerrar();
    }
    if (_otraVez) {
      _otraVez = false;
      unawaited(publicarAhora());
    }
  }

  /// Programa una publicación tras [espera] de calma (con cada cambio se
  /// vuelve a empezar a contar, como mucho [esperaMaxima]).
  void _programar({Duration espera = calma}) {
    if (!state.configurado || !state.automatico) return;
    if (state.fase == FasePublicacion.publicando) {
      _otraVez = true;
      return;
    }
    if (state.errorDeLlave) return;
    final ahora = DateTime.now();
    _primerCambio ??= ahora;
    final limite = _primerCambio!.add(esperaMaxima);
    final cuando = ahora.add(espera).isAfter(limite)
        ? limite
        : ahora.add(espera);
    _temporizador?.cancel();
    _temporizador = Timer(cuando.difference(ahora), publicarAhora);
    if (state.fase != FasePublicacion.error) {
      state = state.copyWith(fase: FasePublicacion.esperando);
    }
  }
}
