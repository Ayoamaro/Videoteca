import 'dart:typed_data';
import 'dart:ui' show Color;

/// Una película de la colección.
///
/// De momento es una clase sencilla para los datos de ejemplo. El día 4 se
/// convertirá en una tabla de la base de datos (Drift) con estos mismos campos.
class Pelicula {
  const Pelicula({
    required this.id,
    required this.titulo,
    required this.anio,
    required this.ruta,
    this.tituloOriginal = '',
    this.generos = const [],
    this.temas = const [],
    this.sinopsis = '',
    this.direccion = '',
    this.guion = '',
    this.reparto = '',
    this.musica = '',
    this.fotografia = '',
    this.productora = '',
    this.pais = '',
    this.premios = '',
    this.clasificacion = '',
    this.estrellas = 0,
    this.rottenTomatoes,
    this.duracionMin = 0,
    this.resolucion = '',
    this.tamanoBytes = 0,
    this.saga = '',
    this.numeroSaga = 0,
    this.anadida,
    this.nueva = false,
    this.tono = const Color(0xFF2E4034),
    this.caratula,
  });

  final int id;

  /// Título en España (el del nombre de archivo).
  final String titulo;
  final String tituloOriginal;
  final int anio;

  /// Ruta completa del `.mp4`, p. ej. `D:\Drama\Drama\Joy (2015).mp4`.
  final String ruta;

  final List<String> generos;
  final List<String> temas;
  final String sinopsis;
  final String direccion;
  final String guion;
  final String reparto;
  final String musica;
  final String fotografia;
  final String productora;
  final String pais;
  final String premios;

  /// Frase de edad, p. ej. "No recomendado para menores de 12 años".
  final String clasificacion;

  /// Estrellas de 0 a 5 (equivalen a la nota de Rotten Tomatoes).
  final int estrellas;
  final int? rottenTomatoes;

  final int duracionMin;
  final String resolucion;
  final int tamanoBytes;
  final String saga;
  final int numeroSaga;
  final DateTime? anadida;

  /// Recién detectada en el disco (muestra la insignia "NUEVA").
  final bool nueva;

  /// Color de la carátula provisional mientras no hay imagen.
  final Color tono;

  /// Carátula incrustada en el `.mp4` (llegará el día 3).
  final Uint8List? caratula;

  /// Carpeta donde está el archivo (sin el nombre).
  String get carpeta {
    final i = ruta.lastIndexOf(r'\');
    return i < 0 ? '' : ruta.substring(0, i + 1);
  }

  /// Nombre del archivo, p. ej. `Joy (2015).mp4`.
  String get archivo {
    final i = ruta.lastIndexOf(r'\');
    return i < 0 ? ruta : ruta.substring(i + 1);
  }

  /// Género según la carpeta (último nivel), p. ej. "Thriller".
  String get generoCarpeta {
    final partes = carpeta.split(r'\').where((p) => p.isNotEmpty).toList();
    return partes.isEmpty ? '' : partes.last;
  }

  /// "2 h 29 min"
  String get duracionTexto {
    if (duracionMin <= 0) return '';
    final h = duracionMin ~/ 60;
    final m = duracionMin % 60;
    return h == 0 ? '$m min' : '$h h $m min';
  }

  /// "4,1 GB"
  String get tamanoTexto {
    if (tamanoBytes <= 0) return '';
    final gb = tamanoBytes / (1024 * 1024 * 1024);
    return '${gb.toStringAsFixed(1).replaceAll('.', ',')} GB';
  }

  /// Etiqueta corta de edad a partir de la frase: "TP", "7", "12", "16", "18".
  String get edadCorta {
    if (clasificacion.isEmpty) return '';
    if (clasificacion.toLowerCase().contains('todos')) return 'TP';
    final numero = RegExp(r'\d+').firstMatch(clasificacion);
    return numero?.group(0) ?? '';
  }
}
