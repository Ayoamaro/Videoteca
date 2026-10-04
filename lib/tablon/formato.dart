import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:image/image.dart' as img;

import '../datos/base_datos.dart';

// Qué hay en el tablón y cómo se guarda. Lo usan el PC (al publicar) y el
// móvil (al descargar).
//
//   tablon.json            sin cifrar: formato y parámetros de la llave
//   README.md              sin cifrar: qué es este repositorio
//   indice.bin             cifrado: versión, fecha y huella de cada paquete
//   catalogo/000.bin …     cifrados: fichas de las películas 0–99, 100–199…
//   caratulas/000.bin …    cifrados: miniaturas WebP de esas mismas películas
//
// Las películas van en grupos de 100 según su número (id): al guardar una
// ficha solo cambia (y se vuelve a subir y descargar) su grupo, no todo.
//
// No usa nada de Flutter.

const formatoTablon = 1;
const peliculasPorGrupo = 100;

const rutaDescripcion = 'tablon.json';
const rutaLeeme = 'README.md';
const rutaIndice = 'indice.bin';
String rutaCatalogo(String grupo) => 'catalogo/$grupo.bin';
String rutaCaratulas(String grupo) => 'caratulas/$grupo.bin';

/// Grupo de la película [id]: «000», «001»…, «055».
String grupoDe(int id) => (id ~/ peliculasPorGrupo).toString().padLeft(3, '0');

/// Huella con la que Git identifica un archivo (SHA-1 de «blob N\0» + datos).
/// Si coincide con la del repositorio, ese archivo ya está subido.
String huellaGit(List<int> datos) {
  final salida = _Digest();
  crypto.sha1.startChunkedConversion(salida)
    ..add(utf8.encode('blob ${datos.length}\u0000'))
    ..add(datos)
    ..close();
  return salida.valor.toString();
}

class _Digest implements Sink<crypto.Digest> {
  late crypto.Digest valor;

  @override
  void add(crypto.Digest data) => valor = data;

  @override
  void close() {}
}

// ── Descripción pública ──────────────────────────────────────────────────

/// `tablon.json`: lo único sin cifrar (además del README).
Uint8List descripcionTablon(Map<String, Object> llave) => utf8.encode(
  const JsonEncoder.withIndent('  ').convert({
    'app': 'Videoteca',
    'formato': formatoTablon,
    'cifrado': 'AES-256-GCM',
    'llave': llave,
  }),
);

final Uint8List leemeTablon = utf8.encode('''
# Tablón de Videoteca

Catálogo de películas publicado por la app
[Videoteca](https://github.com/Ayoamaro/Videoteca).

Todo el contenido está **cifrado** (AES-256-GCM, llave sacada de una
contraseña con Argon2id): solo se puede ver desde la app, con la contraseña.
Este repositorio lo actualiza la app sola; no hace falta tocar nada aquí.
''');

// ── Índice ───────────────────────────────────────────────────────────────

/// `indice.bin`: qué versión es y la huella de cada paquete (el móvil
/// descarga solo los paquetes cuya huella ha cambiado).
class IndiceTablon {
  const IndiceTablon({
    required this.version,
    required this.fecha,
    required this.peliculas,
    required this.catalogo,
    required this.caratulas,
  });

  factory IndiceTablon.desdeBytes(Uint8List datos) {
    final json = _descomprimirJson(datos);
    if ((json['formato'] as int) > formatoTablon) {
      throw const FormatException(
        'El tablón es de una versión más nueva de la app',
      );
    }
    Map<String, String> mapa(Object? m) =>
        (m as Map<String, dynamic>).cast<String, String>();
    return IndiceTablon(
      version: json['version'] as int,
      fecha: DateTime.parse(json['fecha'] as String),
      peliculas: json['peliculas'] as int,
      catalogo: mapa(json['catalogo']),
      caratulas: mapa(json['caratulas']),
    );
  }

  /// Sube 1 cada vez que se publica algo distinto.
  final int version;
  final DateTime fecha;
  final int peliculas;

  /// Grupo («000») → huella Git del paquete cifrado.
  final Map<String, String> catalogo;
  final Map<String, String> caratulas;

  Uint8List aBytes() => _comprimirJson({
    'formato': formatoTablon,
    'version': version,
    'fecha': fecha.toUtc().toIso8601String(),
    'peliculas': peliculas,
    'catalogo': catalogo,
    'caratulas': caratulas,
  });
}

// ── Catálogo ─────────────────────────────────────────────────────────────

/// La ficha de una película tal como va al tablón. Los campos vacíos no se
/// ponen (el paquete ocupa menos). [raiz] se quita de la ruta: en el móvil
/// se ve «Comedias\Romance\Título (Año).mp4».
Map<String, Object> fichaTablon(
  FilaPelicula f, {
  required String raiz,
  required bool caratula,
}) {
  var ruta = f.ruta;
  if (raiz.isNotEmpty && ruta.toLowerCase().startsWith(raiz.toLowerCase())) {
    ruta = ruta.substring(raiz.length);
    if (ruta.startsWith(r'\') || ruta.startsWith('/')) ruta = ruta.substring(1);
  }
  final ficha = <String, Object>{
    'id': f.id,
    'titulo': f.titulo,
    'tituloOriginal': f.tituloOriginal,
    'anio': f.anio,
    'generos': f.generos,
    'temas': f.temas,
    'sinopsis': f.sinopsis,
    'direccion': f.direccion,
    'guion': f.guion,
    'reparto': f.reparto,
    'musica': f.musica,
    'fotografia': f.fotografia,
    'productora': f.productora,
    'pais': f.pais,
    'premios': f.premios,
    'clasificacion': f.clasificacion,
    'estrellas': f.estrellas,
    'saga': f.saga,
    'numeroSaga': f.numeroSaga,
    'enlaceFilmaffinity': f.enlaceFilmaffinity,
    'enlaceImdb': f.enlaceImdb,
    'duracionMin': f.duracionMin,
    'resolucion': f.resolucion,
    'tamanoBytes': f.tamanoBytes,
    'grupo': f.grupo,
    'generoCarpeta': f.generoCarpeta,
    'ruta': ruta,
    'anadida': f.anadida.toUtc().toIso8601String(),
    'caratula': caratula,
  };
  ficha.removeWhere(
    (clave, valor) =>
        clave != 'id' && (valor == '' || valor == 0 || valor == false),
  );
  return ficha;
}

/// Paquete del catálogo (sin cifrar): las fichas de un grupo en JSON
/// comprimido. Siempre igual para las mismas fichas.
Uint8List paqueteCatalogo(List<Map<String, Object>> fichas) =>
    _comprimirJson({'formato': formatoTablon, 'peliculas': fichas});

/// Las fichas de un paquete del catálogo.
List<Map<String, dynamic>> leerPaqueteCatalogo(Uint8List datos) => [
  for (final f in _descomprimirJson(datos)['peliculas'] as List)
    f as Map<String, dynamic>,
];

// ── Carátulas ────────────────────────────────────────────────────────────

/// Ancho de las miniaturas del tablón (las del PC son de 240 px; estas pesan
/// la mitad: ~13 KB).
const anchoMiniaturaTablon = 180;

/// Miniatura del tablón (WebP) a partir de la miniatura JPEG del PC.
Uint8List? miniaturaTablon(Uint8List jpeg) {
  final imagen = img.decodeImage(jpeg);
  if (imagen == null) return null;
  final pequena = imagen.width > anchoMiniaturaTablon
      ? img.copyResize(
          imagen,
          width: anchoMiniaturaTablon,
          interpolation: img.Interpolation.average,
        )
      : imagen;
  return img.WebPEncoder(lossless: false, quality: 65).encode(pequena);
}

const _cabeceraCaratulas = [0x56, 0x54, 0x43, 0x31]; // «VTC1»

/// Paquete de carátulas (sin cifrar): «VTC1», cuántas hay, una tabla con
/// número de película y tamaño de cada imagen, y después las imágenes.
Uint8List paqueteCaratulas(Map<int, Uint8List> imagenes) {
  final ids = imagenes.keys.toList()..sort();
  final tabla = ByteData(4 + ids.length * 8)..setUint32(0, ids.length);
  for (final (i, id) in ids.indexed) {
    tabla
      ..setUint32(4 + i * 8, id)
      ..setUint32(8 + i * 8, imagenes[id]!.length);
  }
  final b = BytesBuilder(copy: false)
    ..add(_cabeceraCaratulas)
    ..add(tabla.buffer.asUint8List());
  for (final id in ids) {
    b.add(imagenes[id]!);
  }
  return b.takeBytes();
}

/// Las imágenes de un paquete de carátulas (número de película → WebP).
Map<int, Uint8List> leerPaqueteCaratulas(Uint8List datos) {
  for (var i = 0; i < 4; i++) {
    if (datos[i] != _cabeceraCaratulas[i]) {
      throw const FormatException('No es un paquete de carátulas');
    }
  }
  final vista = ByteData.sublistView(datos);
  final n = vista.getUint32(4);
  var posicion = 8 + n * 8;
  return {
    for (var i = 0; i < n; i++)
      vista.getUint32(8 + i * 8): Uint8List.sublistView(
        datos,
        posicion,
        posicion += vista.getUint32(12 + i * 8),
      ),
  };
}

// ── Utilidades ───────────────────────────────────────────────────────────

Uint8List _comprimirJson(Object json) =>
    Uint8List.fromList(gzip.encode(utf8.encode(jsonEncode(json))));

Map<String, dynamic> _descomprimirJson(Uint8List datos) =>
    jsonDecode(utf8.decode(gzip.decode(datos))) as Map<String, dynamic>;
