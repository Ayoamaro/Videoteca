import 'dart:async';
import 'dart:io';

import 'red_windows.dart';

// La red de casa: los demás PC ven las películas por una carpeta compartida
// del PC que tiene el disco (p. ej. `\\AYO-PC\Multimedia\Películas`). El
// final de la ruta de cada película es el mismo que en el disco
// (`Drama y Musical\Drama\Factory Girl (2006).mp4`); solo cambia el
// principio.
//
// Mirar una carpeta de red puede tardar medio minuto o más si el otro PC
// está apagado (Windows espera antes de rendirse). Por eso primero se
// «llama» al PC (al puerto de compartir archivos) con un límite de 3 s, y
// cada paso lleva su propio límite: la app nunca se queda esperando.
//
// No usa nada de Flutter.

/// Lo que se sabe de una ruta de red.
enum EstadoRed {
  /// Se llega y están las películas.
  disponible,

  /// El PC no contesta: apagado, sin red o este PC está fuera de casa.
  sinConexion,

  /// Windows pide usuario y contraseña para entrar.
  contrasena,

  /// Se llega al PC, pero esa carpeta no existe o no tiene las películas.
  noEncontrada,
}

/// Resultado de mirar una ruta de red.
class ComprobacionRed {
  const ComprobacionRed(
    this.estado, {
    this.encontradas = 0,
    this.probadas = 0,
    this.codigo,
  });

  final EstadoRed estado;

  /// Películas de prueba que se han encontrado por esa ruta, de [probadas].
  final int encontradas;
  final int probadas;

  /// Código de error de Windows, si lo hubo.
  final int? codigo;
}

/// La ruta que propone la app y cuántas películas de prueba encuentra.
typedef PropuestaRed = ({String ruta, int encontradas, int probadas});

/// Películas que se prueban para saber si una ruta es la buena.
const peliculasDePrueba = 20;

// ── Rutas ────────────────────────────────────────────────────────────────

/// La ruta tal como se escribe o se pega, limpia: sin comillas ni espacios
/// alrededor, con `\` y sin `\` al final (`z:` → `Z:\`). `null` si no es
/// una carpeta de red (`\\PC\Carpeta…`) ni una unidad (`Z:…`).
String? limpiarRutaRed(String texto) {
  var ruta = texto.trim();
  if (ruta.length >= 2 && ruta.startsWith('"') && ruta.endsWith('"')) {
    ruta = ruta.substring(1, ruta.length - 1).trim();
  }
  ruta = ruta.replaceAll('/', r'\');
  List<String> partes(String resto) => resto
      .split(r'\')
      .map((p) => p.trim())
      .where((p) => p.isNotEmpty)
      .toList();
  if (ruta.startsWith(r'\\')) {
    final trozos = partes(ruta.substring(2));
    // Hace falta al menos el PC y la carpeta compartida.
    if (trozos.length < 2) return null;
    return '\\\\${trozos.join(r'\')}';
  }
  if (RegExp(r'^[A-Za-z]:').hasMatch(ruta)) {
    return '${ruta[0].toUpperCase()}:\\${partes(ruta.substring(2)).join(r'\')}';
  }
  return null;
}

/// La ruta de una película por la red: [base] más su ruta dentro de la
/// colección ([relativa], p. ej. `Comedias\Comedia\Título (2000).mp4`).
String unirRuta(String base, String relativa) {
  var resto = relativa.replaceAll('/', r'\');
  if (resto.startsWith(r'\')) resto = resto.substring(1);
  return base.endsWith(r'\') ? '$base$resto' : '$base\\$resto';
}

/// [ruta] sin la carpeta raíz de la colección: `D:\Comedias\X.mp4` con la
/// raíz `D:\` → `Comedias\X.mp4`. Si no está dentro de la raíz, `null`.
String? rutaRelativa(String ruta, String raiz) {
  if (raiz.isEmpty || !ruta.toLowerCase().startsWith(raiz.toLowerCase())) {
    return null;
  }
  final resto = ruta.substring(raiz.length);
  return resto.startsWith(r'\') || resto.startsWith('/')
      ? resto.substring(1)
      : resto;
}

/// Unas cuantas películas repartidas por toda la colección (por orden
/// alfabético de su ruta, así salen de todas las carpetas) para probar una
/// ruta de red.
List<String> muestraPeliculas(
  Iterable<String> relativas, {
  int cuantas = peliculasDePrueba,
}) {
  final orden = relativas.toList()..sort();
  if (orden.length <= cuantas) return orden;
  final paso = orden.length / cuantas;
  return [for (var i = 0; i < cuantas; i++) orden[(i * paso).floor()]];
}

/// El PC al que lleva [ruta]: `\\AYO-PC\Multimedia` → `AYO-PC`; una unidad
/// de red (`Z:`), el de su conexión. `null` si es una carpeta de este PC.
String? equipoDeRuta(String ruta) {
  if (ruta.startsWith(r'\\')) {
    final fin = ruta.indexOf(r'\', 2);
    final equipo = ruta.substring(2, fin < 0 ? ruta.length : fin);
    return equipo.isEmpty ? null : equipo;
  }
  if (Platform.isWindows && RegExp(r'^[A-Za-z]:').hasMatch(ruta)) {
    final remota = conexionDeUnidad(ruta.substring(0, 2));
    if (remota != null && remota.startsWith(r'\\')) return equipoDeRuta(remota);
  }
  return null;
}

/// La carpeta compartida de [ruta] (`\\PC\Compartida\Películas` →
/// `\\PC\Compartida`), o `null` si no es una ruta de red.
String? carpetaCompartidaDe(String ruta) {
  if (!ruta.startsWith(r'\\')) return null;
  final partes = ruta.substring(2).split(r'\').where((p) => p.isNotEmpty);
  if (partes.length < 2) return null;
  return '\\\\${partes.take(2).join(r'\')}';
}

/// El usuario tal como lo quiere Windows para entrar en el PC [equipo]:
/// «Ayoze» → «AYO-PC\Ayoze». Si ya lleva el PC delante (`PC\usuario`) o es
/// una cuenta de Microsoft (su correo), tal cual.
String usuarioDeRed(String usuario, String equipo) {
  final limpio = usuario.trim();
  if (limpio.contains(r'\') || limpio.contains('@')) return limpio;
  return '$equipo\\$limpio';
}

/// Cómo ha ido entrar en el PC de las películas con usuario y contraseña.
enum ResultadoCredenciales {
  /// Se ha entrado y Windows los recuerda para las veces siguientes.
  hecho,

  /// Se ha entrado, pero Windows no ha dejado guardarlos: al reiniciar
  /// habrá que volver a escribirlos.
  sinGuardar,

  /// Usuario o contraseña incorrectos.
  incorrectos,

  /// Esa cuenta no tiene contraseña (Windows no deja entrar por la red sin
  /// ella).
  cuentaSinContrasena,

  /// La cuenta está desactivada, bloqueada o con la contraseña caducada.
  cuentaNoValida,

  /// Ese usuario no existe en el PC de las películas: Windows lo trata como
  /// invitado y este PC no deja entrar como invitado.
  noExiste,

  /// La cuenta existe, pero no tiene permiso para entrar en esa carpeta.
  sinPermiso,

  /// Este PC ya está conectado a ese PC con otro usuario.
  otroUsuario,

  /// El PC de las películas no contesta.
  sinConexion,

  /// No es una carpeta de red (o ya no existe la carpeta compartida).
  noEsRed,

  /// Otro error de Windows.
  error,
}

/// Qué quiere decir el código de error de Windows al entrar con usuario y
/// contraseña (ver [conectarConUsuario]).
ResultadoCredenciales resultadoDeConectar(int codigo) => switch (codigo) {
  0 => ResultadoCredenciales.hecho,
  86 || 1244 || 1326 || 2202 => ResultadoCredenciales.incorrectos,
  1327 => ResultadoCredenciales.cuentaSinContrasena,
  1330 || 1331 || 1385 || 1907 || 1909 => ResultadoCredenciales.cuentaNoValida,
  1272 => ResultadoCredenciales.noExiste,
  5 => ResultadoCredenciales.sinPermiso,
  1219 => ResultadoCredenciales.otroUsuario,
  67 || 1200 => ResultadoCredenciales.noEsRed,
  // No se encuentra el PC, se ha cortado la red…
  51 ||
  53 ||
  64 ||
  1222 ||
  1231 ||
  1232 ||
  1311 => ResultadoCredenciales.sinConexion,
  _ => ResultadoCredenciales.error,
};

/// Entra en el PC de [ruta] con [usuario] y [contrasena] y, si van bien,
/// los deja guardados en Windows (como «Recordar mis credenciales»): así la
/// app, el Explorador y el reproductor entran sin preguntar. La contraseña
/// no se guarda en la app. Solo en Windows; puede tardar: llamarla aparte.
Future<ResultadoCredenciales> entrarConUsuario(
  String ruta,
  String usuario,
  String contrasena,
) async {
  var red = ruta;
  if (RegExp(r'^[A-Za-z]:').hasMatch(ruta)) {
    red = conexionDeUnidad(ruta.substring(0, 2)) ?? ruta;
  }
  final recurso = carpetaCompartidaDe(red);
  final equipo = recurso == null ? null : equipoDeRuta(recurso);
  if (recurso == null || equipo == null) return ResultadoCredenciales.noEsRed;
  if (!await equipoResponde(equipo)) return ResultadoCredenciales.sinConexion;

  final nombre = usuarioDeRed(usuario, equipo);
  var codigo = conectarConUsuario(recurso, nombre, contrasena);
  if (codigo == 1219) {
    // Ya había una conexión con ese PC (p. ej. con otro usuario): se cierra
    // y se prueba otra vez.
    desconectar(recurso);
    desconectar('\\\\$equipo\\IPC\$');
    codigo = conectarConUsuario(recurso, nombre, contrasena);
  }
  final resultado = resultadoDeConectar(codigo);
  if (resultado != ResultadoCredenciales.hecho) return resultado;
  return guardarCredencial(equipo, nombre, contrasena)
      ? ResultadoCredenciales.hecho
      : ResultadoCredenciales.sinGuardar;
}

/// Las carpetas compartidas de este PC tal como las ven los demás:
/// `\\AYO-PC\Multimedia`…
List<String> carpetasCompartidasDeEstePc() {
  final equipo = Platform.environment['COMPUTERNAME'] ?? Platform.localHostname;
  return [for (final nombre in carpetasCompartidas()) '\\\\$equipo\\$nombre'];
}

// ── Comprobar ────────────────────────────────────────────────────────────

/// ¿Contesta el PC [equipo]? Prueba los puertos de compartir archivos (445
/// y, en equipos antiguos, 139), como mucho durante [limite].
Future<bool> equipoResponde(
  String equipo, {
  Duration limite = const Duration(seconds: 3),
}) {
  final respuesta = Completer<bool>();
  var pendientes = 2;
  for (final puerto in [445, 139]) {
    Socket.connect(equipo, puerto, timeout: limite).then(
      (conexion) {
        conexion.destroy();
        if (!respuesta.isCompleted) respuesta.complete(true);
      },
      onError: (Object _) {
        if (--pendientes == 0 && !respuesta.isCompleted) {
          respuesta.complete(false);
        }
      },
    );
  }
  return respuesta.future.timeout(
    limite + const Duration(seconds: 1),
    onTimeout: () => false,
  );
}

/// Qué quiere decir un error de Windows al entrar en una carpeta de red.
EstadoRed estadoDeError(int? codigo) => switch (codigo) {
  // Acceso denegado, contraseña incorrecta, cuenta desactivada o sin
  // permiso para entrar, invitado bloqueado (Windows 11), otras
  // credenciales ya en uso con ese PC…
  5 ||
  86 ||
  1219 ||
  1244 ||
  1272 ||
  1326 ||
  1327 ||
  1330 ||
  1331 ||
  1385 ||
  1907 ||
  1909 => EstadoRed.contrasena,
  // No existe esa carpeta compartida, la ruta o la unidad.
  2 || 3 || 15 || 67 || 123 || 267 => EstadoRed.noEncontrada,
  // Lo demás (no se encuentra el PC, se cortó la red…).
  _ => EstadoRed.sinConexion,
};

/// Mira si se llega a la carpeta [ruta] (sin mirar las películas).
Future<ComprobacionRed> estadoRuta(
  String ruta, {
  Duration limite = const Duration(seconds: 8),
}) async {
  final equipo = equipoDeRuta(ruta);
  if (equipo != null && !await equipoResponde(equipo)) {
    return const ComprobacionRed(EstadoRed.sinConexion);
  }
  try {
    await Directory(ruta)
        .list(followLinks: false)
        .take(1)
        .toList()
        .timeout(limite);
    return const ComprobacionRed(EstadoRed.disponible);
  } on FileSystemException catch (e) {
    final codigo = e.osError?.errorCode;
    return ComprobacionRed(estadoDeError(codigo), codigo: codigo);
  } on TimeoutException {
    return const ComprobacionRed(EstadoRed.sinConexion);
  }
}

/// ¿Está el archivo [ruta]? Si es de otro PC, antes se «llama» a ese PC; si
/// no contesta (o tarda más de [limite]), `null`.
Future<bool?> archivoEsta(
  String ruta, {
  Duration limite = const Duration(seconds: 8),
}) async {
  final equipo = equipoDeRuta(ruta);
  if (equipo != null && !await equipoResponde(equipo)) return null;
  try {
    return await File(ruta).exists().timeout(limite);
  } on TimeoutException {
    return null;
  }
}

/// Cuántas de las películas [relativas] están por la ruta [base] (4 a la
/// vez, como mucho durante [limite]).
Future<int> contarPeliculas(
  String base,
  List<String> relativas, {
  Duration limite = const Duration(seconds: 20),
}) async {
  var encontradas = 0;
  var siguiente = 0;
  Future<void> trabajador() async {
    while (siguiente < relativas.length) {
      final relativa = relativas[siguiente++];
      if (await File(unirRuta(base, relativa)).exists()) encontradas++;
    }
  }

  try {
    await Future.wait([for (var i = 0; i < 4; i++) trabajador()])
        .timeout(limite);
  } on TimeoutException {
    // Las que no ha dado tiempo a mirar no cuentan.
  }
  return encontradas;
}

/// Mira si se llega a [ruta] y cuántas de las películas [muestras] están.
/// Si se llega pero no está ninguna, es que la carpeta no es la buena.
Future<ComprobacionRed> comprobarRuta(
  String ruta,
  List<String> muestras,
) async {
  final estado = await estadoRuta(ruta);
  if (estado.estado != EstadoRed.disponible || muestras.isEmpty) return estado;
  final encontradas = await contarPeliculas(ruta, muestras);
  return ComprobacionRed(
    encontradas == 0 ? EstadoRed.noEncontrada : EstadoRed.disponible,
    encontradas: encontradas,
    probadas: muestras.length,
  );
}

// ── Buscar ───────────────────────────────────────────────────────────────

/// Busca la ruta de red de la colección: entre las carpetas compartidas
/// [compartidas] (las de este PC si no se dan), la carpeta que contiene las
/// de la colección (las primeras de cada ruta de [muestras]) y en la que
/// más películas de prueba se encuentran. Mira hasta dos niveles por debajo
/// de cada carpeta compartida. Si la raíz de la colección ya es una carpeta
/// de red (`\\NAS\Películas`), también la prueba. `null` si no encuentra
/// ninguna.
Future<PropuestaRed?> buscarRutaRed({
  required String raiz,
  required List<String> muestras,
  List<String>? compartidas,
}) async {
  if (muestras.isEmpty) return null;
  final grupos = {
    for (final m in muestras)
      if (m.contains(r'\')) m.substring(0, m.indexOf(r'\')).toLowerCase(),
  };
  final candidatas = [if (raiz.startsWith(r'\\')) ?limpiarRutaRed(raiz)];
  for (final base in compartidas ?? carpetasCompartidasDeEstePc()) {
    candidatas.addAll(await _buscarEn(base, grupos));
  }

  PropuestaRed? mejor;
  for (final candidata in candidatas) {
    final encontradas = await contarPeliculas(candidata, muestras);
    if (encontradas > (mejor?.encontradas ?? 0)) {
      mejor = (
        ruta: candidata,
        encontradas: encontradas,
        probadas: muestras.length,
      );
    }
    if (encontradas == muestras.length) break;
  }
  return mejor;
}

/// Carpetas dentro de [base] (ella incluida, hasta dos niveles más abajo)
/// que contienen alguna de las carpetas [grupos].
Future<List<String>> _buscarEn(String base, Set<String> grupos) async {
  final encontradas = <String>[];
  final cola = [(base, 0)];
  var miradas = 0;
  // Un límite por si se comparte una carpeta enorme (como todo un disco).
  while (cola.isNotEmpty && miradas < 80) {
    final (carpeta, nivel) = cola.removeAt(0);
    miradas++;
    final List<String> hijas;
    try {
      hijas = await _subcarpetas(carpeta).timeout(const Duration(seconds: 5));
    } on Object {
      continue;
    }
    if (hijas.any((h) => grupos.contains(h.toLowerCase()))) {
      encontradas.add(carpeta);
      continue;
    }
    if (nivel < 2) {
      for (final hija in hijas) {
        cola.add((unirRuta(carpeta, hija), nivel + 1));
      }
    }
  }
  return encontradas;
}

/// Nombres de las carpetas que hay dentro de [carpeta] (también los atajos
/// de Windows, como las uniones).
Future<List<String>> _subcarpetas(String carpeta) async {
  final nombres = <String>[];
  await for (final e in Directory(carpeta).list(followLinks: false)) {
    if (e is Directory || e is Link) {
      nombres.add(e.path.substring(e.path.lastIndexOf(r'\') + 1));
    }
  }
  return nombres;
}
