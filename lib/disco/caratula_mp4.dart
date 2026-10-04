import 'dart:io';
import 'dart:typed_data';

/// Lee la carátula incrustada en un `.mp4` (el átomo `covr`).
///
/// Un `.mp4` está hecho de "cajas" (átomos) metidas unas dentro de otras, cada
/// una con su tamaño y un nombre de 4 letras. La carátula está en:
///
///     moov › udta › meta › ilst › covr › data
///
/// Aquí solo se leen las cabeceras de las cajas para saltar de una a otra, así
/// que no hace falta cargar el vídeo entero: basta con unos pocos KB. El
/// archivo se abre **solo para leer**.
///
/// Devuelve los bytes de la imagen (JPEG o PNG) o `null` si no tiene carátula.
Uint8List? leerCaratulaMp4(String ruta) {
  final archivo = File(ruta).openSync();
  try {
    final total = archivo.lengthSync();
    var caja = _buscar(archivo, 0, total, 'moov');
    if (caja == null) return null;
    caja = _buscar(archivo, caja.$1, caja.$2, 'udta');
    if (caja == null) return null;
    caja = _buscar(archivo, caja.$1, caja.$2, 'meta');
    if (caja == null) return null;
    // "meta" suele llevar 4 bytes de versión antes de sus cajas hijas (estilo
    // iTunes); en el estilo QuickTime no. Se distingue mirando si ya empieza
    // por una caja con nombre conocido.
    var inicioMeta = caja.$1;
    archivo.setPositionSync(inicioMeta + 4);
    final nombre = String.fromCharCodes(archivo.readSync(4));
    if (nombre != 'hdlr' && nombre != 'ilst') inicioMeta += 4;
    caja = _buscar(archivo, inicioMeta, caja.$2, 'ilst');
    if (caja == null) return null;
    caja = _buscar(archivo, caja.$1, caja.$2, 'covr');
    if (caja == null) return null;
    caja = _buscar(archivo, caja.$1, caja.$2, 'data');
    if (caja == null) return null;
    // "data" = 4 bytes de tipo (13 JPEG, 14 PNG) + 4 de idioma + la imagen.
    final inicio = caja.$1 + 8;
    final largo = caja.$2 - inicio;
    if (largo <= 0 || largo > 20 * 1024 * 1024) return null;
    archivo.setPositionSync(inicio);
    final bytes = archivo.readSync(largo);
    return bytes.length == largo ? sinRelleno(bytes) : null;
  } finally {
    archivo.closeSync();
  }
}

/// Cuando Windows guarda una carátula añade unos ceros de relleno detrás de
/// la imagen. Se quitan para obtener la imagen exacta, pero solo si lo que
/// queda termina como un JPEG (`FF D9`): un PNG sí puede acabar en cero.
Uint8List sinRelleno(Uint8List imagen) {
  var fin = imagen.length;
  while (fin > 0 && imagen[fin - 1] == 0) {
    fin--;
  }
  final esJpeg = fin >= 2 && imagen[fin - 2] == 0xFF && imagen[fin - 1] == 0xD9;
  return fin == imagen.length || !esJpeg
      ? imagen
      : Uint8List.sublistView(imagen, 0, fin);
}

/// Busca la caja [tipo] entre [desde] y [hasta]. Devuelve dónde empieza y
/// termina su contenido (sin la cabecera), o `null` si no está.
(int, int)? _buscar(
  RandomAccessFile archivo,
  int desde,
  int hasta,
  String tipo,
) {
  var pos = desde;
  while (pos + 8 <= hasta) {
    archivo.setPositionSync(pos);
    final cabecera = archivo.readSync(16);
    if (cabecera.length < 8) return null;
    final datos = ByteData.sublistView(cabecera);
    var tamano = datos.getUint32(0);
    final nombre = String.fromCharCodes(cabecera, 4, 8);
    var cabeceraLargo = 8;
    if (tamano == 1) {
      // Caja de más de 4 GB: el tamaño real va en los 8 bytes siguientes.
      if (cabecera.length < 16) return null;
      tamano = datos.getUint64(8);
      cabeceraLargo = 16;
    } else if (tamano == 0) {
      tamano = hasta - pos; // "hasta el final"
    }
    if (tamano < cabeceraLargo || pos + tamano > hasta) return null;
    if (nombre == tipo) return (pos + cabeceraLargo, pos + tamano);
    pos += tamano;
  }
  return null;
}
