import 'dart:async';
import 'dart:isolate';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../disco/acciones_windows.dart';
import '../disco/red.dart';
import '../modelos/pelicula.dart';
import '../utilidades.dart';
import 'catalogo.dart';
import 'consulta.dart';

// La red de casa: por qué carpeta ven las películas los PC que no tienen el
// disco.
//
// En el PC del administrador se elige la ruta que se publica (cifrada) en
// el tablón; la app la propone sola buscando entre las carpetas que comparte
// el PC. En un PC de consulta se usa la del tablón o, si se elige otra, la
// de ese PC; y se mira cada minuto si se llega (aparte y con tiempo límite,
// así la app nunca se queda esperando a un PC apagado). El móvil no la usa.

/// Ruta de red guardada en este aparato. En el PC del administrador, la que
/// se publica para los demás (`null` = sin decidir todavía; vacía = sin
/// red). En un PC de consulta, la elegida en ese PC (vacía = la del tablón).
final rutaRedProvider = NotifierProvider<RutaRed, String?>(RutaRed.new);

class RutaRed extends Notifier<String?> {
  static const clave = 'rutaRed';

  @override
  String? build() => ref.read(ajustesInicialesProvider)[clave];

  Future<void> cambiar(String ruta) async {
    await ref.read(baseDatosProvider).guardarAjuste(clave, ruta);
    state = ruta;
  }
}

/// Lo que se hace de verdad con la red y con los archivos de las películas
/// (en las pruebas se cambia por uno de mentira).
class ServicioRed {
  const ServicioRed();

  /// ¿Está el archivo? `null` si el PC de las películas no contesta.
  Future<bool?> existe(String ruta) => archivoEsta(ruta);

  /// Reproduce la película o abre su carpeta (ver [abrirArchivo]).
  Future<ResultadoAbrir> abrir(String ruta, {bool enCarpeta = false}) =>
      abrirArchivo(ruta, enCarpeta: enCarpeta);

  Future<bool> abrirEnExplorador(String carpeta) => explorarCarpeta(carpeta);

  /// Entra en el PC de [ruta] con usuario y contraseña y los deja guardados
  /// en Windows (ver [entrarConUsuario]).
  Future<ResultadoCredenciales> entrar(
    String ruta,
    String usuario,
    String contrasena,
  ) => _entrarAparte(ruta, usuario, contrasena);

  Future<ComprobacionRed> comprobar(String ruta, List<String> muestras) =>
      _comprobarAparte(ruta, muestras);

  Future<PropuestaRed?> buscar(String raiz, List<String> muestras) =>
      _buscarAparte(raiz, muestras);

  /// ¿Es una carpeta de este PC (que los demás no ven así)?
  bool esDeEstePc(String ruta) => equipoDeRuta(ruta) == null;
}

final servicioRedProvider = Provider<ServicioRed>((ref) => const ServicioRed());

enum FaseRed {
  /// No hay ruta (o en este aparato no se usa la red).
  sinRuta,

  /// Hay ruta, pero todavía no se ha mirado.
  sinComprobar,
  disponible,
  sinConexion,
  contrasena,
  noEncontrada,
}

class EstadoRedCasa {
  const EstadoRedCasa({
    this.ruta = '',
    this.deTablon = false,
    this.fase = FaseRed.sinRuta,
    this.comprobando = false,
    this.encontradas = 0,
    this.probadas = 0,
    this.comprobada,
    this.buscando = false,
    this.buscada = false,
    this.propuesta,
  });

  /// La ruta que se usa (vacía = ninguna).
  final String ruta;

  /// En un PC de consulta: la ruta es la del tablón (no se ha elegido otra).
  final bool deTablon;

  /// Lo último que se sabe de la ruta.
  final FaseRed fase;

  /// Se está mirando porque se ha pedido (las comprobaciones de cada minuto
  /// no lo enseñan).
  final bool comprobando;

  /// Películas de prueba encontradas en la última comprobación.
  final int encontradas;
  final int probadas;
  final DateTime? comprobada;

  /// Administrador: buscando la ruta entre las carpetas compartidas, si ya
  /// se ha buscado y lo que se ha encontrado.
  final bool buscando;
  final bool buscada;
  final PropuestaRed? propuesta;

  bool get disponible => fase == FaseRed.disponible;

  /// La ruta de una película por la red; [relativa] es su ruta dentro de la
  /// colección (la del tablón). `null` si no hay ruta de red.
  String? rutaDe(String relativa) =>
      ruta.isEmpty ? null : unirRuta(ruta, relativa);
}

final redCasaProvider = NotifierProvider<RedCasa, EstadoRedCasa>(RedCasa.new);

class RedCasa extends Notifier<EstadoRedCasa> {
  /// Cada cuánto se mira, en un PC de consulta, si se llega a las películas.
  static const cadaCuanto = Duration(minutes: 1);

  /// Lo más que se espera a una comprobación o a una búsqueda.
  static const limite = Duration(seconds: 40);

  /// Al volver a la app, no se vuelve a mirar una ruta disponible
  /// comprobada hace menos de esto.
  static const margenAlVolver = Duration(seconds: 20);

  Timer? _temporizador;

  /// Ruta que se está comprobando ahora (no se comprueba dos veces a la
  /// vez) y cómo va.
  String? _rutaEnCurso;
  Future<void>? _enCurso;

  @override
  EstadoRedCasa build() {
    ref.onDispose(() => _temporizador?.cancel());
    if (!hayRedDeCasa) return const EstadoRedCasa();
    ref.listen(rutaRedProvider, (_, _) => _cambiarRuta());
    if (!esAdministrador) {
      ref.listen(
        consultaProvider.select((e) => e.copia.red ?? ''),
        (_, _) => _cambiarRuta(),
      );
      _temporizador = Timer.periodic(
        cadaCuanto,
        (_) => comprobar(enSilencio: true),
      );
    }
    final inicial = _segunAjustes();
    Future.microtask(() {
      if (inicial.ruta.isNotEmpty) {
        comprobar();
      } else if (esAdministrador && ref.read(rutaRedProvider) == null) {
        // Sin decidir todavía: la app la busca y la propone.
        buscar();
      }
    });
    return inicial;
  }

  /// Ruta y de dónde sale, según los ajustes (y el tablón).
  EstadoRedCasa _segunAjustes() {
    final propia = ref.read(rutaRedProvider) ?? '';
    if (esAdministrador || propia.isNotEmpty) {
      return EstadoRedCasa(
        ruta: propia,
        fase: propia.isEmpty ? FaseRed.sinRuta : FaseRed.sinComprobar,
      );
    }
    final delTablon = ref.read(consultaProvider).copia.red ?? '';
    return EstadoRedCasa(
      ruta: delTablon,
      deTablon: true,
      fase: delTablon.isEmpty ? FaseRed.sinRuta : FaseRed.sinComprobar,
    );
  }

  void _cambiarRuta() {
    final nuevo = _segunAjustes();
    if (nuevo.ruta == state.ruta && nuevo.deTablon == state.deTablon) return;
    state = nuevo;
    if (nuevo.ruta.isNotEmpty) comprobar();
  }

  /// Mira si se llega a la ruta y prueba unas cuantas películas («encontradas
  /// 20 de 20»). Con [enSilencio] no se enseña «Comprobando…».
  Future<void> comprobar({bool enSilencio = false}) {
    final ruta = state.ruta;
    if (ruta.isEmpty) return Future.value();
    if (_rutaEnCurso == ruta) return _enCurso!;
    _rutaEnCurso = ruta;
    return _enCurso = _comprobar(ruta, enSilencio).whenComplete(() {
      if (_rutaEnCurso == ruta) _rutaEnCurso = null;
    });
  }

  Future<void> _comprobar(String ruta, bool enSilencio) async {
    if (!enSilencio) state = _con(state, comprobando: true);
    final muestras = await _muestras();
    final r = await _comprobarConLimite(ruta, muestras);
    if (!ref.mounted || state.ruta != ruta) return;
    state = _con(
      state,
      fase: _fase(r.estado),
      comprobando: false,
      encontradas: r.encontradas,
      probadas: r.probadas,
      comprobada: DateTime.now(),
    );
  }

  /// Al volver a la app (p. ej. del Explorador, después de escribir la
  /// contraseña), se mira otra vez la red, salvo que esté disponible y se
  /// haya mirado hace nada.
  void alVolver() {
    final comprobada = state.comprobada;
    if (state.disponible &&
        comprobada != null &&
        DateTime.now().difference(comprobada) < margenAlVolver) {
      return;
    }
    comprobar(enSilencio: true);
  }

  /// Administrador: busca entre las carpetas compartidas de este PC la que
  /// lleva a las películas y la propone.
  Future<void> buscar() async {
    final raiz = ref.read(carpetaRaizProvider);
    if (state.buscando || raiz == null) return;
    state = _con(state, buscando: true);
    PropuestaRed? propuesta;
    try {
      propuesta = await ref
          .read(servicioRedProvider)
          .buscar(raiz, await _muestras())
          .timeout(limite, onTimeout: () => null);
    } on Object {
      propuesta = null;
    }
    if (!ref.mounted) return;
    state = _con(
      state,
      buscando: false,
      buscada: true,
      propuesta: propuesta,
      sinPropuesta: propuesta == null,
    );
  }

  /// Prueba la ruta [texto] y, si se llega a las películas, la guarda.
  /// Devuelve por qué no se ha guardado, o `null` si se ha guardado. Si
  /// Windows pide contraseña se guarda igual (se arregla entrando una vez
  /// con el Explorador).
  Future<String?> usar(String texto) async {
    final ruta = limpiarRutaRed(texto);
    if (ruta == null) {
      return r'Escribe una carpeta de red (\\PC\Carpeta) o una unidad de red '
          '(Z:).';
    }
    final servicio = ref.read(servicioRedProvider);
    if (esAdministrador && servicio.esDeEstePc(ruta)) {
      return 'Esa carpeta es de este PC y los demás no la ven así: elige la '
          r'carpeta compartida, la que empieza por \\.';
    }
    final r = await _comprobarConLimite(ruta, await _muestras());
    switch (r.estado) {
      case EstadoRed.sinConexion:
        return 'No se llega a ese PC: puede que esté apagado o sin red. '
            'Enciéndelo y vuelve a probar.';
      case EstadoRed.noEncontrada:
        return r.probadas > 0
            ? 'En esa carpeta no está ninguna de las ${r.probadas} películas '
                  'de prueba: no es la carpeta de las películas.'
            : 'No existe esa carpeta.';
      case EstadoRed.contrasena || EstadoRed.disponible:
        break;
    }
    if (!ref.mounted) return null;
    // Primero lo ya comprobado (así no se vuelve a mirar al guardarla).
    state = EstadoRedCasa(
      ruta: ruta,
      fase: _fase(r.estado),
      encontradas: r.encontradas,
      probadas: r.probadas,
      comprobada: DateTime.now(),
    );
    await ref.read(rutaRedProvider.notifier).cambiar(ruta);
    return null;
  }

  /// Administrador: no publicar ninguna ruta. En un PC de consulta: volver a
  /// la del tablón.
  Future<void> quitar() async {
    await ref.read(rutaRedProvider.notifier).cambiar('');
    if (ref.mounted && esAdministrador) state = const EstadoRedCasa();
  }

  Future<ComprobacionRed> _comprobarConLimite(
    String ruta,
    List<String> muestras,
  ) async {
    try {
      return await ref
          .read(servicioRedProvider)
          .comprobar(ruta, muestras)
          .timeout(
            limite,
            onTimeout: () => const ComprobacionRed(EstadoRed.sinConexion),
          );
    } on Object {
      return const ComprobacionRed(EstadoRed.sinConexion);
    }
  }

  /// Rutas (dentro de la colección) de unas cuantas películas del catálogo
  /// para probar la ruta de red.
  Future<List<String>> _muestras() async {
    final List<Pelicula> lista;
    try {
      lista = await ref
          .read(catalogoProvider.future)
          .timeout(const Duration(seconds: 15));
    } on Object {
      return const [];
    }
    // En el PC del administrador las rutas son las del disco; en consulta ya
    // vienen sin la raíz.
    final raiz = ref.read(carpetaRaizProvider) ?? '';
    return muestraPeliculas([
      for (final p in lista)
        if (esAdministrador) ?rutaRelativa(p.ruta, raiz) else p.ruta,
    ]);
  }
}

FaseRed _fase(EstadoRed estado) => switch (estado) {
  EstadoRed.disponible => FaseRed.disponible,
  EstadoRed.sinConexion => FaseRed.sinConexion,
  EstadoRed.contrasena => FaseRed.contrasena,
  EstadoRed.noEncontrada => FaseRed.noEncontrada,
};

/// [e] con algunos datos cambiados (`copyWith`; [sinPropuesta] la quita).
EstadoRedCasa _con(
  EstadoRedCasa e, {
  FaseRed? fase,
  bool? comprobando,
  int? encontradas,
  int? probadas,
  DateTime? comprobada,
  bool? buscando,
  bool? buscada,
  PropuestaRed? propuesta,
  bool sinPropuesta = false,
}) => EstadoRedCasa(
  ruta: e.ruta,
  deTablon: e.deTablon,
  fase: fase ?? e.fase,
  comprobando: comprobando ?? e.comprobando,
  encontradas: encontradas ?? e.encontradas,
  probadas: probadas ?? e.probadas,
  comprobada: comprobada ?? e.comprobada,
  buscando: buscando ?? e.buscando,
  buscada: buscada ?? e.buscada,
  propuesta: sinPropuesta ? null : propuesta ?? e.propuesta,
);

// Lo que se lanza a otro hilo va en funciones sueltas (ver `edicion.dart`).
// Así una carpeta de red que no contesta tampoco frena la pantalla.

Future<ComprobacionRed> _comprobarAparte(String ruta, List<String> muestras) =>
    Isolate.run(() => comprobarRuta(ruta, muestras));

Future<PropuestaRed?> _buscarAparte(String raiz, List<String> muestras) =>
    Isolate.run(() => buscarRutaRed(raiz: raiz, muestras: muestras));

Future<ResultadoCredenciales> _entrarAparte(
  String ruta,
  String usuario,
  String contrasena,
) => Isolate.run(() => entrarConUsuario(ruta, usuario, contrasena)).timeout(
  const Duration(seconds: 40),
  onTimeout: () => ResultadoCredenciales.sinConexion,
);
