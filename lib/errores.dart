import 'dart:async';
import 'dart:io';

// Convierte los fallos inesperados (archivos, red, base de datos) en frases
// que se entienden, en vez de enseñar el mensaje técnico en inglés.
//
// No usa nada de Flutter.

/// Explica [error] en una frase. Los fallos que la app ya prepara con un
/// mensaje propio (`FuenteException`, `TablonException`…) se dejan tal cual.
String explicarError(Object error) {
  switch (error) {
    case FileSystemException(:final osError?, :final path):
      final donde = path == null || path.isEmpty ? '' : ' (${_nombre(path)})';
      return switch (osError.errorCode) {
        2 || 3 => 'No se encuentra el archivo o la carpeta$donde.',
        5 => 'Windows no deja entrar$donde: falta permiso.',
        32 || 33 =>
          'El archivo está abierto en otro programa$donde. Ciérralo y vuelve '
              'a intentarlo.',
        21 || 1006 || 1167 =>
          'El disco no está disponible$donde. Comprueba que está conectado.',
        39 || 112 => 'No queda espacio en el disco$donde.',
        19 => 'El disco está protegido contra escritura$donde.',
        // En Android: 13 = sin permiso, 28 = sin espacio.
        13 => 'No hay permiso para usar el archivo$donde.',
        28 => 'No queda espacio$donde.',
        _ => 'No se ha podido usar el archivo$donde: ${osError.message.trim()}',
      };
    case FileSystemException(:final message, :final path):
      final donde = path == null || path.isEmpty ? '' : ' (${_nombre(path)})';
      return 'No se ha podido usar el archivo$donde: $message';
    case SocketException() || HttpException():
      return 'Sin conexión a internet (o el servicio no contesta).';
    case HandshakeException() || TlsException():
      return 'No se ha podido abrir una conexión segura. Comprueba la fecha '
          'y la hora del equipo.';
    case TimeoutException():
      return 'Ha tardado demasiado en contestar. Vuelve a intentarlo dentro '
          'de un rato.';
    case FormatException():
      return 'Los datos recibidos no tienen el formato esperado.';
    case OutOfMemoryError():
      return 'No queda memoria libre en el equipo.';
  }
  final texto = '$error';
  // Los fallos de la base de datos (SQLite) traen mucho detalle técnico.
  if (texto.startsWith('SqliteException')) {
    return texto.contains('database is locked') || texto.contains('busy')
        ? 'La base de datos está ocupada. Vuelve a intentarlo en unos '
              'segundos.'
        : texto.contains('disk') || texto.contains('full')
        ? 'No se ha podido guardar en la base de datos: ¿queda espacio en el '
              'disco?'
        : 'Ha fallado la base de datos de la app.';
  }
  // Los mensajes propios empiezan muchas veces por «Exception: ».
  return texto.startsWith('Exception: ') ? texto.substring(11) : texto;
}

/// Solo el nombre del archivo o carpeta, sin toda la ruta.
String _nombre(String ruta) {
  final partes = ruta.split(RegExp(r'[\\/]')).where((p) => p.isNotEmpty);
  return partes.isEmpty ? ruta : partes.last;
}
