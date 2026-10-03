import 'dart:io';
import 'dart:typed_data';

import 'caratula_mp4.dart';
import 'propiedades_windows.dart';

/// Propiedades de Windows que lee la app, con lo que significa cada una en tu
/// colección (ver la tabla de CLAUDE.md).
const propiedadesLeidas = <String, String>{
  'System.Title': 'Título',
  'System.Media.SubTitle': 'Título original',
  'System.Comment': 'Sinopsis',
  'System.Music.Artist': 'Reparto',
  'System.Media.Year': 'Año',
  'System.Music.Genre': 'Géneros',
  'System.Rating': 'Estrellas',
  'System.Video.Director': 'Dirección',
  'System.Media.Producer': 'Productora',
  'System.Music.Composer': 'Música',
  'System.ParentalRating': 'Clasificación',
  'System.Media.Writer': 'Guion',
  'System.Media.Publisher': 'País',
  'System.Music.Conductor': 'Fotografía',
  'System.Keywords': 'Temas',
  'System.Media.AuthorUrl': 'Enlace FilmAffinity',
  'System.Media.PromotionUrl': 'Enlace IMDb',
  'System.Music.Period': 'Premios',
  'System.Music.AlbumTitle': 'Saga',
  'System.Music.TrackNumber': 'Nº en la saga',
  'System.Media.Duration': 'Duración',
  'System.Video.FrameWidth': 'Ancho',
  'System.Video.FrameHeight': 'Alto',
};

/// Todo lo que se sabe de un `.mp4` leyendo el propio archivo.
class DatosArchivo {
  DatosArchivo({
    required this.ruta,
    required this.propiedades,
    required this.caratula,
    required this.tamanoBytes,
  });

  final String ruta;

  /// Valores tal cual los da Windows (nombre oficial → valor).
  final Map<String, Object> propiedades;

  /// Imagen incrustada (JPEG/PNG) o `null`.
  final Uint8List? caratula;
  final int tamanoBytes;

  /// Nombre del archivo sin `.mp4`, con `꞉` cambiado por `:`.
  String get nombreLimpio {
    var nombre = ruta.substring(ruta.lastIndexOf(r'\') + 1);
    final punto = nombre.lastIndexOf('.');
    if (punto > 0) nombre = nombre.substring(0, punto);
    return nombre.replaceAll('꞉', ':');
  }

  /// Texto de una propiedad; si tiene varios valores, separados por comas.
  String texto(String nombre) => switch (propiedades[nombre]) {
    final List<String> lista => lista.join(', '),
    final Object valor => '$valor',
    null => '',
  };

  /// Lista de valores de una propiedad.
  List<String> lista(String nombre) => switch (propiedades[nombre]) {
    final List<String> lista => lista,
    final Object valor => ['$valor'],
    null => const [],
  };

  int numero(String nombre) => switch (propiedades[nombre]) {
    final int n => n,
    final Object valor => int.tryParse('$valor') ?? 0,
    null => 0,
  };

  /// Título en España: el de las propiedades o, si falta, el del archivo.
  String get titulo {
    final t = texto('System.Title');
    if (t.isNotEmpty) return t;
    return nombreLimpio.replaceFirst(RegExp(r'\s*\(\d{4}\).*$'), '');
  }

  /// Año de las propiedades o, si falta, el que aparece entre paréntesis.
  int get anio {
    final a = numero('System.Media.Year');
    if (a > 0) return a;
    final m = RegExp(r'\((\d{4})\)').firstMatch(nombreLimpio);
    return m == null ? 0 : int.parse(m.group(1)!);
  }

  /// "Drama. Comedia. Romance" → ["Drama", "Comedia", "Romance"].
  List<String> get generos => [
    for (final g in lista('System.Music.Genre'))
      ...g
          .split(RegExp(r'[.;]'))
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty),
  ];

  /// Windows guarda la nota de 0 a 99; el Explorador la enseña como estrellas:
  /// 1 → ★, 25 → ★★, 50 → ★★★, 75 → ★★★★, 99 → ★★★★★.
  int get estrellas {
    final r = numero('System.Rating');
    if (r <= 0) return 0;
    if (r < 13) return 1;
    if (r < 38) return 2;
    if (r < 63) return 3;
    if (r < 88) return 4;
    return 5;
  }

  /// Windows da la duración en unidades de 100 nanosegundos.
  int get duracionMin => (numero('System.Media.Duration') / 600000000).round();

  int get ancho => numero('System.Video.FrameWidth');
  int get alto => numero('System.Video.FrameHeight');

  /// "1080p · 1918 × 816"
  String get resolucion {
    if (ancho <= 0 || alto <= 0) return '';
    final calidad = switch (ancho) {
      >= 3800 => '4K',
      >= 1900 => '1080p',
      >= 1260 => '720p',
      _ => 'SD',
    };
    return '$calidad · $ancho × $alto';
  }
}

/// Lee un `.mp4` completo: propiedades de Windows, carátula y tamaño.
/// Solo lectura: no modifica nada del archivo.
DatosArchivo leerArchivo(String ruta) {
  return DatosArchivo(
    ruta: ruta,
    propiedades: leerPropiedadesWindows(ruta, propiedadesLeidas.keys.toList()),
    caratula: leerCaratulaMp4(ruta),
    tamanoBytes: File(ruta).lengthSync(),
  );
}
