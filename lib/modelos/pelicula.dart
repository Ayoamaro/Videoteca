import 'dart:typed_data';
import 'dart:ui' show Color;

import '../disco/lector_archivo.dart';

/// Una película de la colección.
///
/// Se crea a partir de una fila de la base de datos (ver `datos/catalogo.dart`),
/// de lo leído en un `.mp4` o de los datos de ejemplo.
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
    this.completada,
    this.tono = const Color(0xFF2E4034),
    this.caratula,
    this.miniatura,
    this.tieneCaratula = false,
    this.grupo = '',
    this.enlaceFilmaffinity = '',
    this.enlaceImdb = '',
    this.errorLectura,
    this.desaparecida,
  });

  /// Película a partir de lo leído en su `.mp4`.
  factory Pelicula.desdeArchivo(DatosArchivo d, {int id = 0}) => Pelicula(
    id: id,
    titulo: d.titulo,
    tituloOriginal: d.texto('System.Media.SubTitle'),
    anio: d.anio,
    ruta: d.ruta,
    generos: d.generos,
    temas: separarTemas(d.lista('System.Keywords').join(';')),
    sinopsis: d.texto('System.Comment'),
    direccion: d.texto('System.Video.Director'),
    guion: d.texto('System.Media.Writer'),
    reparto: d.texto('System.Music.Artist'),
    musica: d.texto('System.Music.Composer'),
    fotografia: d.texto('System.Music.Conductor'),
    productora: d.texto('System.Media.Producer'),
    pais: d.texto('System.Media.Publisher'),
    premios: d.texto('System.Music.Period'),
    clasificacion: d.texto('System.ParentalRating'),
    estrellas: d.estrellas,
    duracionMin: d.duracionMin,
    resolucion: d.resolucion,
    tamanoBytes: d.tamanoBytes,
    saga: d.texto('System.Music.AlbumTitle'),
    numeroSaga: d.numero('System.Music.TrackNumber'),
    caratula: d.caratula,
    tieneCaratula: d.caratula != null,
    enlaceFilmaffinity: d.texto('System.Media.AuthorUrl'),
    enlaceImdb: d.texto('System.Media.PromotionUrl'),
  );

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

  /// Cuándo se guardó su ficha desde «Completar ficha» (en la bandeja de
  /// nuevas sale como «Guardada»).
  final DateTime? completada;

  /// Color de la carátula provisional mientras no hay imagen.
  final Color tono;

  /// Carátula incrustada en el `.mp4`.
  final Uint8List? caratula;

  /// Ruta de la miniatura de la carátula que guarda la app (para listas y
  /// cuadrículas: pesa mucho menos que la carátula completa).
  final String? miniatura;

  /// El `.mp4` lleva carátula incrustada.
  final bool tieneCaratula;

  /// Carpeta de primer nivel, p. ej. "Comedias".
  final String grupo;

  final String enlaceFilmaffinity;
  final String enlaceImdb;

  /// Si Windows no pudo leer el archivo, el motivo.
  final String? errorLectura;

  /// Cuándo se vio que el archivo ya no estaba en el disco.
  final DateTime? desaparecida;

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

  /// Las carpetas de la ruta, de fuera adentro, p. ej. `[Dramas, Drama]`.
  List<String> get carpetas =>
      carpeta.split(r'\').where((p) => p.isNotEmpty).toList();

  /// Género según la carpeta (último nivel), p. ej. "Thriller".
  String get generoCarpeta {
    final partes = carpetas;
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

/// Los temas de [texto], uno por uno. La app los guarda separados por «;»
/// (un valor por tema, como Windows), pero también se aceptan escritos como
/// los géneros: «Biográfico. Años 60. Años 70». No se corta tras «Dr.»,
/// «Mr.» y parecidos.
List<String> separarTemas(String texto) => [
  for (final t in texto.split(_separadorTemas).map(_limpiarTema))
    if (t.isNotEmpty) t,
];

final _separadorTemas = RegExp(
  r';|(?<!\b(?:Dr|Dra|Mr|Mrs|Ms|Sr|Sra|Srta|Jr|St))\.\s+',
);

/// Sin espacios alrededor ni punto final («Crimen.» → «Crimen»; «EE.UU.» se
/// queda igual).
String _limpiarTema(String t) {
  t = t.trim();
  return t.endsWith('.') && t.indexOf('.') == t.length - 1
      ? t.substring(0, t.length - 1).trim()
      : t;
}
