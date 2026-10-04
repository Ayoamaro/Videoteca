import 'dart:io';
import 'dart:typed_data';

import 'escaner.dart' show archivoEnUso;
import 'etiquetas_mp4.dart';
import 'lector_archivo.dart';

// Escribir los datos de una ficha dentro de su `.mp4`.
//
// Se escriben las mismas cajas y con el mismo formato que usa Windows al
// editar "Propiedades → Detalles" (ver `etiquetas_mp4.dart`), y después es
// el propio Windows quien vuelve a leer el archivo para comprobar que:
// - los campos cambiados tienen el valor nuevo;
// - todos los demás campos y la carátula siguen exactamente igual;
// - el vídeo no ha cambiado (mismo tamaño y mismas muestras de contenido).
// Si algo no cuadra, el archivo se deja byte a byte como estaba.
//
// No usa nada de Flutter.

/// Un dato de la ficha que se puede editar: su propiedad de Windows (ver la
/// tabla de CLAUDE.md) y la caja del `.mp4` donde Windows la guarda (las que
/// empiezan por `WM/` van en la caja `Xtra`; el resto, en `ilst`).
enum Campo {
  titulo('System.Title', '©nam', 'Título'),
  tituloOriginal('System.Media.SubTitle', 'WM/SubTitle', 'Título original'),
  anio('System.Media.Year', '©day', 'Año', numero: true),
  generos('System.Music.Genre', '©gen', 'Géneros', varios: true),
  sinopsis('System.Comment', '©cmt', 'Sinopsis'),
  direccion('System.Video.Director', 'WM/Director', 'Dirección', varios: true),
  reparto('System.Music.Artist', '©ART', 'Reparto', varios: true),
  guion('System.Media.Writer', 'WM/Writer', 'Guion', varios: true),
  musica('System.Music.Composer', '©wrt', 'Música', varios: true),
  fotografia(
    'System.Music.Conductor',
    'WM/Conductor',
    'Fotografía',
    varios: true,
  ),
  productora(
    'System.Media.Producer',
    'WM/Producer',
    'Productora',
    varios: true,
  ),
  pais('System.Media.Publisher', 'WM/Publisher', 'País'),
  clasificacion('System.ParentalRating', 'WM/ParentalRating', 'Clasificación'),
  estrellas('System.Rating', 'WM/SharedUserRating', 'Estrellas', numero: true),
  temas('System.Keywords', 'WM/Category', 'Temas', varios: true),
  premios('System.Music.Period', 'WM/Period', 'Premios'),
  saga('System.Music.AlbumTitle', '©alb', 'Saga'),
  numeroSaga('System.Music.TrackNumber', 'trkn', 'Nº en la saga', numero: true),
  enlaceFilmaffinity(
    'System.Media.AuthorUrl',
    'WM/AuthorURL',
    'Enlace a FilmAffinity',
  ),
  enlaceImdb('System.Media.PromotionUrl', 'WM/PromotionURL', 'Enlace a IMDb');

  const Campo(
    this.propiedad,
    this.caja,
    this.nombre, {
    this.numero = false,
    this.varios = false,
  });

  /// Nombre oficial de la propiedad de Windows.
  final String propiedad;

  /// Caja del `.mp4` donde se guarda.
  final String caja;

  /// Cómo se llama en la app.
  final String nombre;
  final bool numero;

  /// Windows la trata como lista de valores (y separa los valores por «;»).
  /// En tu colección es un solo texto («A, B, C»), salvo los temas, que van
  /// uno por uno.
  final bool varios;

  bool get enXtra => caja.startsWith('WM/');

  static Campo? porNombre(String nombre) {
    for (final c in values) {
      if (c.name == nombre) return c;
    }
    return null;
  }
}

/// Los datos editables de un archivo, como textos (vacío = sin dato).
///
/// Los números van como cifras («2015»), las estrellas de «1» a «5» y los
/// temas separados por «; ».
Map<Campo, String> valoresFicha(DatosArchivo d) => {
  for (final c in Campo.values) c: _valor(d, c),
};

String _valor(DatosArchivo d, Campo c) {
  switch (c) {
    case Campo.estrellas:
      return d.estrellas == 0 ? '' : '${d.estrellas}';
    case Campo.anio || Campo.numeroSaga:
      final n = d.numero(c.propiedad);
      return n == 0 ? '' : '$n';
    case Campo.temas:
      return d.lista(c.propiedad).join('; ');
    default:
      return d.texto(c.propiedad).trim();
  }
}

/// Estrellas (1–5) → valor de Windows (0–99), como las pone el Explorador.
const estrellasWindows = [0, 1, 25, 50, 75, 99];

/// Pasa el texto de un campo al valor que se guarda en su caja (ver
/// `escribirEtiquetasMp4`); `null` = quitar el dato.
Object? valorCaja(Campo c, String texto) {
  texto = texto.trim();
  if (texto.isEmpty) return null;
  switch (c) {
    case Campo.estrellas:
      final n = int.parse(texto);
      if (n < 0 || n > 5) throw ArgumentError('Estrellas fuera de rango: $n');
      return n == 0 ? null : estrellasWindows[n];
    case Campo.numeroSaga:
      final n = int.parse(texto);
      return n == 0 ? null : n;
    case Campo.temas:
      final temas = [
        for (final t in texto.split(';'))
          if (t.trim().isNotEmpty) t.trim(),
      ];
      return temas.isEmpty ? null : temas;
    default:
      // El año también va como texto («1995»), igual que lo guarda Windows.
      return c.enXtra ? [texto] : texto;
  }
}

/// Comprueba un texto antes de escribirlo. Devuelve el problema o `null`.
String? validarCampo(Campo c, String texto) {
  texto = texto.trim();
  if (texto.isEmpty) {
    return c == Campo.titulo ? 'El título no puede quedar vacío.' : null;
  }
  switch (c) {
    case Campo.anio:
      final n = int.tryParse(texto);
      if (n == null || n < 1870 || n > 2100) {
        return 'Escribe un año de 4 cifras, p. ej. 1995.';
      }
    case Campo.numeroSaga:
      final n = int.tryParse(texto);
      if (n == null || n < 0 || n > 999) return 'Escribe un número.';
    case Campo.estrellas:
      final n = int.tryParse(texto);
      if (n == null || n < 0 || n > 5) return 'De 0 a 5 estrellas.';
    case Campo.enlaceFilmaffinity || Campo.enlaceImdb:
      if (!texto.startsWith('http://') && !texto.startsWith('https://')) {
        return 'Tiene que empezar por https://';
      }
    case Campo.temas:
      break;
    default:
      // Windows partiría el texto en varios valores por el «;».
      if (c.varios && texto.contains(';')) {
        return 'No uses «;» (Windows lo toma como separador): usa comas.';
      }
  }
  return null;
}

/// Cambio de carátula: [imagen] nueva (JPEG o PNG) o `null` para quitarla.
class CaratulaNueva {
  const CaratulaNueva(this.imagen);
  final Uint8List? imagen;
}

/// Lo que ha pasado al escribir: el valor que había y el nuevo de cada campo
/// cambiado (los demás no se han tocado) y la carátula de antes y de después.
class ResultadoEscritura {
  ResultadoEscritura({
    required this.antes,
    required this.despues,
    required this.caratulaCambiada,
    required this.caratulaAntes,
    required this.caratulaDespues,
    required this.datos,
  });

  final Map<Campo, String> antes;
  final Map<Campo, String> despues;
  final bool caratulaCambiada;
  final Uint8List? caratulaAntes;
  final Uint8List? caratulaDespues;

  /// El archivo tal como ha quedado.
  final DatosArchivo datos;

  /// No había nada distinto que escribir.
  bool get sinCambios => despues.isEmpty && !caratulaCambiada;
}

class EscrituraException implements Exception {
  EscrituraException(this.mensaje, {this.restaurado = true});

  final String mensaje;

  /// El archivo está como antes de intentarlo.
  final bool restaurado;

  @override
  String toString() => mensaje;
}

/// Escribe en el `.mp4` de [ruta] los [cambios] (campo → texto nuevo) y, si
/// se da, la [caratula] nueva. Los campos que ya tienen ese valor no se
/// tocan; si no queda nada que cambiar, no se escribe nada. Con
/// [soloVacios] solo se escriben los campos que están vacíos en el archivo
/// (los que ya tienen algo se dejan como están, aunque [cambios] diga otra
/// cosa): es lo que usa «Completar mi colección».
///
/// Después lo comprueba todo (ver el principio de este archivo). Si falla,
/// deja el archivo como estaba y lanza [EscrituraException]. Es síncrona:
/// hay que llamarla en segundo plano (`Isolate.run`).
ResultadoEscritura escribirFicha(
  String ruta,
  Map<Campo, String> cambios, {
  CaratulaNueva? caratula,
  bool soloVacios = false,
}) {
  for (final MapEntry(key: c, value: texto) in cambios.entries) {
    final problema = validarCampo(c, texto);
    if (problema != null) {
      throw EscrituraException('${c.nombre}: $problema');
    }
  }
  if (archivoEnUso(ruta)) {
    throw EscrituraException(
      'Otro programa está escribiendo en el archivo (¿se está copiando?). '
      'Espera a que termine y vuelve a intentarlo.',
    );
  }

  final DatosArchivo antes;
  try {
    antes = leerArchivo(ruta);
  } catch (e) {
    throw EscrituraException('No se puede leer el archivo: $e');
  }
  final valoresAntes = valoresFicha(antes);
  final pendientes = {
    for (final MapEntry(key: c, value: texto) in cambios.entries)
      if (texto.trim() != valoresAntes[c] &&
          (!soloVacios || valoresAntes[c]!.isEmpty))
        c: texto.trim(),
  };
  final cambiaCaratula =
      caratula != null && !mismaImagen(caratula.imagen, antes.caratula);
  if (pendientes.isEmpty && !cambiaCaratula) {
    return ResultadoEscritura(
      antes: const {},
      despues: const {},
      caratulaCambiada: false,
      caratulaAntes: antes.caratula,
      caratulaDespues: antes.caratula,
      datos: antes,
    );
  }

  final huella = HuellaVideo.de(ruta);
  final caratulaFinal = cambiaCaratula ? caratula.imagen : antes.caratula;
  final CopiaOriginal copia;
  try {
    copia = escribirEtiquetasMp4(
      ruta,
      ilst: {
        for (final MapEntry(key: c, value: texto) in pendientes.entries)
          if (!c.enXtra) c.caja: valorCaja(c, texto),
        if (cambiaCaratula) 'covr': caratula.imagen,
      },
      xtra: {
        for (final MapEntry(key: c, value: texto) in pendientes.entries)
          if (c.enXtra) c.caja: valorCaja(c, texto),
      },
    );
  } on EtiquetasException catch (e) {
    throw EscrituraException('No se ha escrito nada: $e');
  }

  final problemas = _comprobar(
    ruta,
    esperado: {...valoresAntes, ...pendientes},
    antes: antes,
    caratula: caratulaFinal,
    huella: huella,
  );
  if (problemas.isNotEmpty) {
    // Se deja todo exactamente como estaba.
    String? motivo;
    try {
      copia.restaurar(ruta);
      final quedan = _comprobar(
        ruta,
        esperado: valoresAntes,
        antes: antes,
        caratula: antes.caratula,
        huella: huella,
      );
      if (quedan.isNotEmpty) motivo = quedan.join('; ');
    } catch (e) {
      motivo = '$e';
    }
    throw EscrituraException(
      'La comprobación después de guardar no ha salido bien '
      '(${problemas.join('; ')}). '
      '${motivo == null ? 'El archivo se ha dejado como estaba.' : 'No se ha podido dejar como estaba ($motivo): revísalo.'}',
      restaurado: motivo == null,
    );
  }

  return ResultadoEscritura(
    antes: {for (final c in pendientes.keys) c: valoresAntes[c]!},
    despues: pendientes,
    caratulaCambiada: cambiaCaratula,
    caratulaAntes: antes.caratula,
    caratulaDespues: caratulaFinal,
    datos: leerArchivo(ruta),
  );
}

/// Lee de nuevo el archivo (con Windows) y dice qué no coincide con lo
/// esperado.
List<String> _comprobar(
  String ruta, {
  required Map<Campo, String> esperado,
  required DatosArchivo antes,
  required Uint8List? caratula,
  required HuellaVideo huella,
}) {
  final DatosArchivo ahora;
  try {
    ahora = leerArchivo(ruta);
  } catch (e) {
    return ['no se puede leer el archivo: $e'];
  }
  final problemas = <String>[];
  final valores = valoresFicha(ahora);
  for (final c in Campo.values) {
    if (valores[c] != esperado[c]) problemas.add('${c.nombre} distinto');
  }
  // Datos del vídeo que Windows calcula del propio archivo.
  for (final p in const [
    'System.Media.Duration',
    'System.Video.FrameWidth',
    'System.Video.FrameHeight',
  ]) {
    if (ahora.texto(p) != antes.texto(p)) problemas.add('$p distinto');
  }
  if (!mismaImagen(ahora.caratula, caratula)) {
    problemas.add('carátula distinta');
  }
  if (HuellaVideo.de(ruta) != huella) problemas.add('el vídeo ha cambiado');
  return problemas;
}

/// ¿Son la misma imagen, byte a byte? (Dos `null` también cuentan.)
bool mismaImagen(Uint8List? a, Uint8List? b) {
  if (a == null || b == null) return a == b;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// "Huella" del vídeo: el tamaño de la caja `mdat` (donde está el vídeo) y
/// tres muestras de 1 MB de su contenido (principio, mitad y final). Leer el
/// vídeo entero tardaría demasiado en el disco duro; con las muestras se
/// detecta igualmente si algo se hubiera movido o estropeado.
class HuellaVideo {
  HuellaVideo(this.tamano, this.muestras);

  /// Huella del vídeo de [ruta] (o una vacía si no tiene caja `mdat`).
  factory HuellaVideo.de(String ruta) {
    final archivo = File(ruta).openSync();
    try {
      final mdat = _mayorMdat(archivo);
      if (mdat == null) return HuellaVideo(0, const []);
      final (inicio, fin) = mdat;
      const trozo = 1 << 20;
      final largo = fin - inicio;
      final posiciones = largo <= 3 * trozo
          ? [inicio]
          : [inicio, inicio + largo ~/ 2, fin - trozo];
      return HuellaVideo(largo, [
        for (final p in posiciones)
          (archivo..setPositionSync(p)).readSync(trozo),
      ]);
    } finally {
      archivo.closeSync();
    }
  }

  final int tamano;
  final List<Uint8List> muestras;

  @override
  bool operator ==(Object other) {
    if (other is! HuellaVideo ||
        other.tamano != tamano ||
        other.muestras.length != muestras.length) {
      return false;
    }
    for (var i = 0; i < muestras.length; i++) {
      if (!mismaImagen(muestras[i], other.muestras[i])) return false;
    }
    return true;
  }

  @override
  int get hashCode => tamano.hashCode;
}

/// Inicio y fin del contenido de la caja `mdat` más grande.
(int, int)? _mayorMdat(RandomAccessFile archivo) {
  final total = archivo.lengthSync();
  (int, int)? mayor;
  var pos = 0;
  while (pos + 8 <= total) {
    archivo.setPositionSync(pos);
    final cabecera = archivo.readSync(16);
    if (cabecera.length < 8) break;
    final datos = ByteData.sublistView(cabecera);
    var tamano = datos.getUint32(0);
    var largoCabecera = 8;
    if (tamano == 1 && cabecera.length == 16) {
      tamano = datos.getUint64(8);
      largoCabecera = 16;
    } else if (tamano == 0) {
      tamano = total - pos;
    }
    if (tamano < largoCabecera) break;
    if (String.fromCharCodes(cabecera, 4, 8) == 'mdat') {
      final contenido = (pos + largoCabecera, pos + tamano);
      if (mayor == null || contenido.$2 - contenido.$1 > mayor.$2 - mayor.$1) {
        mayor = contenido;
      }
    }
    pos += tamano;
  }
  return mayor;
}
