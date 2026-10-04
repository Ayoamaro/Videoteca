import 'dart:io';

/// Carpeta donde la app guarda sus cosas: la base de datos y las miniaturas.
///
/// En Windows es `%LOCALAPPDATA%\Videoteca` (p. ej.
/// `C:\Users\Ayo\AppData\Local\Videoteca`). En Android, la carpeta privada
/// de la app. No se usa ningún plugin de Flutter para averiguarla.
String carpetaDatosApp() {
  if (Platform.isWindows) {
    final base =
        Platform.environment['LOCALAPPDATA'] ??
        '${Platform.environment['USERPROFILE']}\\AppData\\Local';
    return '$base\\Videoteca';
  }
  if (Platform.isAndroid) {
    // El nombre del proceso es el identificador de la app.
    final nombre = File('/proc/self/cmdline')
        .readAsStringSync()
        .split('\u0000')
        .first
        .split(':')
        .first;
    return '/data/data/$nombre/files';
  }
  return '${Platform.environment['HOME']}/.videoteca';
}

/// Rutas concretas dentro de [carpetaDatosApp].
class CarpetasApp {
  CarpetasApp(this.raiz);

  /// Prepara las carpetas (las crea si no existen).
  factory CarpetasApp.preparar([String? raiz]) {
    final carpetas = CarpetasApp(raiz ?? carpetaDatosApp());
    Directory(carpetas.miniaturas).createSync(recursive: true);
    Directory(carpetas.copias).createSync(recursive: true);
    return carpetas;
  }

  final String raiz;

  String get _sep => Platform.pathSeparator;
  String get baseDatos => '$raiz${_sep}videoteca.sqlite';
  String get miniaturas => '$raiz${_sep}miniaturas';

  /// Carátulas de antes y de después de cada cambio del registro (para
  /// poder deshacerlo).
  String get copias => '$raiz${_sep}copias';

  /// Perfil propio de la ventana de Edge con la que se lee FilmAffinity.
  String get navegador => '$raiz${_sep}navegador';

  /// Miniatura de la carátula de la película con número [id].
  String miniatura(int id) => '$miniaturas$_sep$id.jpg';

  /// Carátula guardada del cambio [cambio] del registro: la que había
  /// ([antes]) o la que se puso.
  String copiaCaratula(int cambio, {required bool antes}) =>
      '$copias$_sep$cambio-${antes ? 'antes' : 'despues'}.img';
}
