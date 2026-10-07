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
///
/// El modo consulta tiene su propia carpeta dentro (`consulta`), con su base
/// de datos y las carátulas descargadas del tablón (WebP).
class CarpetasApp {
  CarpetasApp(this.raiz, {this.extensionMiniaturas = 'jpg'});

  /// Prepara las carpetas (las crea si no existen).
  factory CarpetasApp.preparar([String? raiz]) =>
      CarpetasApp(raiz ?? carpetaDatosApp()).._crear();

  /// Las del modo consulta, dentro de [raiz] (o de la carpeta de la app).
  factory CarpetasApp.consulta([String? raiz]) => CarpetasApp(
    '${raiz ?? carpetaDatosApp()}${Platform.pathSeparator}consulta',
    extensionMiniaturas: 'webp',
  ).._crear();

  void _crear() {
    Directory(miniaturas).createSync(recursive: true);
    Directory(copias).createSync(recursive: true);
  }

  final String raiz;

  /// `jpg` en el PC del administrador (sacadas de los `.mp4`) y `webp` en el
  /// modo consulta (las del tablón).
  final String extensionMiniaturas;

  String get _sep => Platform.pathSeparator;
  String get baseDatos => '$raiz${_sep}videoteca.sqlite';
  String get miniaturas => '$raiz${_sep}miniaturas';

  /// Carátulas de antes y de después de cada cambio del registro (para
  /// poder deshacerlo).
  String get copias => '$raiz${_sep}copias';

  /// Perfil propio de la ventana de Edge con la que se lee FilmAffinity.
  String get navegador => '$raiz${_sep}navegador';

  /// Lo que se prepara para publicar en el tablón: miniaturas WebP y qué
  /// se publicó la última vez.
  String get tablon => '$raiz${_sep}tablon';
  String get miniaturasTablon => '$tablon${_sep}caratulas';
  String miniaturaTablon(int id) => '$miniaturasTablon$_sep$id.webp';
  String get estadoTablon => '$tablon${_sep}estado.json';

  /// Lo comprobado en TMDB sobre las sagas (ver `fuentes/sagas.dart`).
  String get sagas => '$raiz${_sep}sagas.json';

  /// Miniatura de la carátula de la película con número [id].
  String miniatura(int id) => '$miniaturas$_sep$id.$extensionMiniaturas';

  /// Carátula guardada del cambio [cambio] del registro: la que había
  /// ([antes]) o la que se puso.
  String copiaCaratula(int cambio, {required bool antes}) =>
      '$copias$_sep$cambio-${antes ? 'antes' : 'despues'}.img';
}
