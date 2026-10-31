import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;

import '../datos/base_datos.dart';
import '../datos/carpetas_app.dart';
import '../disco/caratula_mp4.dart';
import 'cifrado.dart';
import 'formato.dart';
import 'github.dart';

// Publicar el catálogo en el tablón:
//
// 1. Mira qué hay ahora en GitHub (la lista de archivos con su huella).
// 2. Prepara las miniaturas WebP que falten (se guardan en el PC para no
//    rehacerlas cada vez).
// 3. Arma los paquetes de 100 películas, los cifra y calcula su huella.
//    Como el cifrado da siempre los mismos bytes para el mismo contenido,
//    los paquetes que no han cambiado tienen la misma huella que en GitHub y
//    no se suben.
// 4. Si algo ha cambiado: sube lo nuevo y el índice con la versión + 1, y lo
//    cambia todo de golpe con un solo commit.
//
// No usa nada de Flutter (se puede probar desde la terminal).

/// Cómo va la publicación, para la barra de progreso.
typedef ProgresoPublicacion = ({String fase, int hechos, int total});

typedef ResultadoPublicacion = ({
  int version,
  int peliculas,

  /// Archivos subidos y cuánto pesaban.
  int subidos,
  int bytes,

  /// No había nada distinto que publicar.
  bool sinCambios,
});

Future<ResultadoPublicacion> publicarTablon({
  required GitHub github,
  required LlaveTablon llave,
  required ParametrosLlave parametros,
  required List<FilaPelicula> filas,
  required String raiz,
  required CarpetasApp carpetas,
  int versionAnterior = 0,

  /// Ruta de red de las películas para los demás PC de casa (vacía = sin
  /// red). Va dentro del índice.
  String red = '',
  void Function(ProgresoPublicacion progreso)? alAvanzar,
}) async {
  void avanzar(String fase, [int hechos = 0, int total = 0]) =>
      alAvanzar?.call((fase: fase, hechos: hechos, total: total));

  // 1. Lo que hay en GitHub.
  avanzar('Conectando con GitHub');
  final repo = await github.info();
  var commit = await github.ultimoCommit(repo.rama);
  if (commit == null) {
    await github.iniciar(rutaLeeme, leemeTablon);
    commit = await github.ultimoCommit(repo.rama);
  }
  final remoto = commit == null
      ? <String, ArchivoRemoto>{}
      : await github.arbol(commit);

  // 2. Miniaturas WebP.
  await prepararMiniaturasTablon(
    filas,
    carpetas,
    alAvanzar: (hechas, total) =>
        avanzar('Preparando carátulas', hechas, total),
  );

  // 3. Paquetes cifrados (en segundo plano: cifrar decenas de MB lleva unos
  //    segundos).
  avanzar('Cifrando');
  final remotas = {for (final e in remoto.entries) e.key: e.value.huella};
  final armado = await _armarEnSegundoPlano(
    llave.bytes,
    parametros.toJson(),
    filas,
    raiz,
    carpetas.raiz,
    remotas,
  );
  final archivos = armado.huellas;

  // ¿Ha cambiado algo? (Los paquetes o la ruta de red.)
  final indiceRemoto = await _indiceRemoto(github, llave, remoto);
  final mismos =
      indiceRemoto != null &&
      indiceRemoto.red == red &&
      remoto.length == archivos.length + 1 &&
      archivos.entries.every((e) => remotas[e.key] == e.value);
  if (mismos) {
    final version = indiceRemoto.version;
    return (
      version: version,
      peliculas: filas.length,
      subidos: 0,
      bytes: 0,
      sinCambios: true,
    );
  }

  // 4. Índice nuevo y subida.
  final anterior = indiceRemoto?.version ?? 0;
  final version = (anterior > versionAnterior ? anterior : versionAnterior) + 1;
  final indice = IndiceTablon(
    version: version,
    fecha: DateTime.now(),
    peliculas: filas.length,
    catalogo: {
      for (final MapEntry(:key, :value) in archivos.entries)
        if (key.startsWith('catalogo/')) _grupoDeRuta(key): value,
    },
    caratulas: {
      for (final MapEntry(:key, :value) in archivos.entries)
        if (key.startsWith('caratulas/')) _grupoDeRuta(key): value,
    },
    red: red,
  );
  final indiceCifrado = llave.cifrar(rutaIndice, indice.aBytes());
  final nuevos = {...armado.nuevos, rutaIndice: indiceCifrado};
  final huellas = {...archivos, rutaIndice: huellaGit(indiceCifrado)};

  var subidos = 0, bytes = 0;
  for (final MapEntry(key: ruta, value: contenido) in nuevos.entries) {
    avanzar('Subiendo', subidos, nuevos.length);
    final huella = await github.subir(contenido);
    if (huella != huellas[ruta]) {
      throw TablonException(
        'GitHub ha guardado mal «$ruta» (huella distinta).',
      );
    }
    subidos++;
    bytes += contenido.length;
  }
  avanzar('Publicando', subidos, nuevos.length);
  await github.publicar(
    repo.rama,
    huellas,
    'Versión $version · ${filas.length} películas',
    ramaExiste: commit != null,
  );
  return (
    version: version,
    peliculas: filas.length,
    subidos: subidos,
    bytes: bytes,
    sinCambios: false,
  );
}

/// «catalogo/012.bin» → «012».
String _grupoDeRuta(String ruta) =>
    ruta.substring(ruta.indexOf('/') + 1, ruta.lastIndexOf('.'));

/// El índice publicado ahora en GitHub, o `null` si no hay o no se puede
/// leer (p. ej. porque se ha cambiado la contraseña común).
Future<IndiceTablon?> _indiceRemoto(
  GitHub github,
  LlaveTablon llave,
  Map<String, ArchivoRemoto> remoto,
) async {
  final archivo = remoto[rutaIndice];
  if (archivo == null) return null;
  try {
    final datos = llave.descifrar(
      rutaIndice,
      await github.descargar(archivo.huella),
    );
    return IndiceTablon.desdeBytes(datos);
  } on ContrasenaIncorrecta {
    return null;
  } on FormatException {
    return null;
  }
}

// ── Miniaturas ───────────────────────────────────────────────────────────

/// Hace las miniaturas WebP del tablón que falten o estén viejas (4 a la
/// vez) y borra las de películas que ya no están, y las carpetas de
/// miniaturas de otro tamaño o calidad.
Future<void> prepararMiniaturasTablon(
  List<FilaPelicula> filas,
  CarpetasApp carpetas, {
  void Function(int hechas, int total)? alAvanzar,
}) async {
  final carpeta = Directory(carpetas.miniaturasTablon)
    ..createSync(recursive: true);
  for (final otra in carpeta.parent.listSync()) {
    final nombre = otra.uri.pathSegments.where((s) => s.isNotEmpty).last;
    if (otra is Directory &&
        nombre.startsWith('caratulas') &&
        otra.path != carpeta.path) {
      otra.deleteSync(recursive: true);
    }
  }
  final pendientes = <(int, String)>[];
  for (final f in filas) {
    if (!f.tieneMiniatura) continue;
    final jpeg = File(carpetas.miniatura(f.id));
    final webp = File(carpetas.miniaturaTablon(f.id));
    if (!jpeg.existsSync()) continue;
    if (!webp.existsSync() ||
        webp.lastModifiedSync().isBefore(jpeg.lastModifiedSync())) {
      pendientes.add((f.id, f.ruta));
    }
  }
  final validas = {for (final f in filas) f.id};
  for (final archivo in Directory(carpetas.miniaturasTablon).listSync()) {
    final id = int.tryParse(archivo.uri.pathSegments.last.split('.').first);
    if (id != null && !validas.contains(id)) archivo.deleteSync();
  }
  if (pendientes.isEmpty) return;

  final raiz = carpetas.raiz;
  var hechas = 0;
  alAvanzar?.call(0, pendientes.length);
  const porTanda = 40;
  final tandas = [
    for (var i = 0; i < pendientes.length; i += porTanda)
      pendientes.sublist(
        i,
        i + porTanda > pendientes.length ? pendientes.length : i + porTanda,
      ),
  ];
  var siguiente = 0;
  Future<void> trabajador() async {
    while (siguiente < tandas.length) {
      final tanda = tandas[siguiente++];
      await _miniaturasEnSegundoPlano(raiz, tanda);
      hechas += tanda.length;
      alAvanzar?.call(hechas, pendientes.length);
    }
  }

  await Future.wait([for (var i = 0; i < 4; i++) trabajador()]);
}

// Lo que se lanza a otro hilo va en funciones sueltas: una función creada
// dentro de otra se llevaría sin querer todo lo de alrededor (como el aviso
// de progreso de la app), y eso no se puede mandar a otro hilo.

Future<void> _miniaturasEnSegundoPlano(
  String raiz,
  List<(int, String)> peliculas,
) => Isolate.run(() => _hacerMiniaturas(raiz, peliculas));

Future<_Armado> _armarEnSegundoPlano(
  Uint8List bytesLlave,
  Map<String, Object> parametros,
  List<FilaPelicula> filas,
  String raizColeccion,
  String raizApp,
  Map<String, String> remotas,
) => Isolate.run(
  () => _armar(bytesLlave, parametros, filas, raizColeccion, raizApp, remotas),
);

/// Las miniaturas del tablón salen de la carátula original del `.mp4` (más
/// nítidas que desde la miniatura JPEG del PC, que ya está comprimida). Si el
/// archivo no se puede leer (disco desconectado…), de la miniatura del PC, y
/// se deja con fecha de antes para rehacerla desde el original la próxima
/// vez.
void _hacerMiniaturas(String raiz, List<(int, String)> peliculas) {
  final carpetas = CarpetasApp(raiz);
  for (final (id, ruta) in peliculas) {
    try {
      final jpeg = File(carpetas.miniatura(id));
      Uint8List? original;
      try {
        original = leerCaratulaMp4(ruta);
      } catch (_) {
        // Sin disco, archivo movido o carátula rara: la del PC.
        original = null;
      }
      final webp = miniaturaTablon(original ?? jpeg.readAsBytesSync());
      if (webp == null) continue;
      final destino = File(carpetas.miniaturaTablon(id))
        ..writeAsBytesSync(webp);
      if (original == null) {
        destino.setLastModifiedSync(
          jpeg.lastModifiedSync().subtract(const Duration(seconds: 1)),
        );
      }
    } on Exception {
      // Una miniatura estropeada: esa película va sin carátula.
    }
  }
}

// ── Paquetes ─────────────────────────────────────────────────────────────

typedef _Armado = ({
  /// Ruta → huella Git de todos los archivos (menos el índice).
  Map<String, String> huellas,

  /// Los que no están en GitHub, ya cifrados.
  Map<String, Uint8List> nuevos,
});

/// Arma y cifra todos los paquetes. Para no cifrarlo todo cada vez, guarda
/// en `estado.json` la huella del contenido sin cifrar y la del cifrado: si
/// el contenido es el mismo y GitHub ya lo tiene, no hace falta cifrar.
_Armado _armar(
  Uint8List bytesLlave,
  Map<String, Object> parametros,
  List<FilaPelicula> filas,
  String raizColeccion,
  String raizApp,
  Map<String, String> remotas,
) {
  final llave = LlaveTablon(bytesLlave);
  final carpetas = CarpetasApp(raizApp);
  final archivoEstado = File(carpetas.estadoTablon);
  var cache = <String, dynamic>{};
  try {
    final json = jsonDecode(archivoEstado.readAsStringSync());
    if (json['llave'] == llave.huella) {
      cache = json['archivos'] as Map<String, dynamic>;
    }
  } on Object {
    // Sin estado guardado: se cifra todo.
  }
  final nuevaCache = <String, Object>{};
  final huellas = <String, String>{};
  final nuevos = <String, Uint8List>{};

  void anadir(String ruta, Uint8List plano, {bool cifrar = true}) {
    final huellaPlano = crypto.sha256.convert(plano).toString();
    final guardado = cache[ruta] as Map<String, dynamic>?;
    String huella;
    if (guardado != null &&
        guardado['plano'] == huellaPlano &&
        remotas[ruta] == guardado['git']) {
      huella = guardado['git'] as String;
    } else {
      final contenido = cifrar ? llave.cifrar(ruta, plano) : plano;
      huella = huellaGit(contenido);
      if (remotas[ruta] != huella) nuevos[ruta] = contenido;
    }
    huellas[ruta] = huella;
    nuevaCache[ruta] = {'plano': huellaPlano, 'git': huella};
  }

  anadir(rutaLeeme, leemeTablon, cifrar: false);
  anadir(rutaDescripcion, descripcionTablon(parametros), cifrar: false);

  final grupos = <String, List<FilaPelicula>>{};
  for (final f in [...filas]..sort((a, b) => a.id.compareTo(b.id))) {
    grupos.putIfAbsent(grupoDe(f.id), () => []).add(f);
  }
  for (final MapEntry(key: grupo, value: suyas) in grupos.entries) {
    final imagenes = <int, Uint8List>{};
    for (final f in suyas) {
      final webp = File(carpetas.miniaturaTablon(f.id));
      if (f.tieneMiniatura && webp.existsSync()) {
        imagenes[f.id] = webp.readAsBytesSync();
      }
    }
    anadir(
      rutaCatalogo(grupo),
      paqueteCatalogo([
        for (final f in suyas)
          fichaTablon(
            f,
            raiz: raizColeccion,
            caratula: imagenes.containsKey(f.id),
          ),
      ]),
    );
    if (imagenes.isNotEmpty) {
      anadir(rutaCaratulas(grupo), paqueteCaratulas(imagenes));
    }
  }

  archivoEstado.writeAsStringSync(
    jsonEncode({'llave': llave.huella, 'archivos': nuevaCache}),
  );
  return (huellas: huellas, nuevos: nuevos);
}
