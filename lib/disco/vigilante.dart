import 'dart:async';
import 'dart:io';

// El vigilante pide a Windows que le avise de cualquier cambio dentro de la
// carpeta raíz (archivos nuevos, borrados, movidos o renombrados, en todas
// las subcarpetas). No lee nada: solo dice «algo ha cambiado» y la app hace
// entonces una revisión rápida (el escaneo incremental).
//
// Los avisos llegan a ráfagas (copiar una película son cientos de avisos),
// así que se espera a que haya unos segundos de calma antes de avisar.
//
// No usa nada de Flutter.

class VigilanteCarpeta {
  VigilanteCarpeta(this.raiz, {this.calma = const Duration(seconds: 3)});

  final String raiz;

  /// Tiempo sin avisos nuevos antes de dar el cambio por terminado.
  final Duration calma;

  final _cambios = StreamController<void>.broadcast();
  StreamSubscription<FileSystemEvent>? _suscripcion;
  Timer? _espera;
  Timer? _reintento;
  bool _parado = false;

  /// Emite cada vez que hay cambios (ya agrupados).
  Stream<void> get cambios => _cambios.stream;

  bool get activo => _suscripcion != null;

  void iniciar() {
    _parado = false;
    _escuchar();
  }

  void _escuchar() {
    if (_parado || _suscripcion != null) return;
    try {
      _suscripcion = Directory(raiz)
          .watch(recursive: true)
          .listen(_alCambiar, onError: _alFallar, onDone: _alFallar);
    } catch (_) {
      _alFallar(null);
    }
  }

  void _alCambiar(FileSystemEvent evento) {
    if (!esCambioInteresante(evento.path, esCarpeta: evento.isDirectory)) {
      return;
    }
    _espera?.cancel();
    _espera = Timer(calma, () => _cambios.add(null));
  }

  /// Si Windows deja de avisar (p. ej. se desconecta el disco o hay
  /// demasiados cambios de golpe), se vuelve a intentar en unos segundos y se
  /// pide una revisión por si se ha perdido algo.
  void _alFallar([Object? _, Object? _]) {
    _suscripcion?.cancel();
    _suscripcion = null;
    if (_parado) return;
    _reintento?.cancel();
    _reintento = Timer(const Duration(seconds: 10), () {
      if (_parado || !Directory(raiz).existsSync()) return _alFallar();
      _escuchar();
      _cambios.add(null);
    });
  }

  void parar() {
    _parado = true;
    _espera?.cancel();
    _reintento?.cancel();
    _suscripcion?.cancel();
    _suscripcion = null;
  }

  void cerrar() {
    parar();
    _cambios.close();
  }
}

/// ¿Merece la pena revisar el disco por un cambio en [ruta]?
///
/// Sí para los vídeos y las carpetas (al mover o renombrar una carpeta,
/// Windows solo avisa de la carpeta). No para otros archivos (`.srt`,
/// `.jpg`…) ni para lo que pasa en la papelera o en carpetas de sistema.
bool esCambioInteresante(String ruta, {bool esCarpeta = false}) {
  final r = ruta.toLowerCase();
  if (r.contains(r'\$recycle.bin') ||
      r.contains(r'\system volume information')) {
    return false;
  }
  if (r.endsWith('.mp4') || r.endsWith('.m4v') || esCarpeta) return true;
  // De lo borrado no se puede saber si era carpeta: si el nombre no tiene
  // extensión, podría serlo.
  final nombre = r.substring(r.lastIndexOf(Platform.pathSeparator) + 1);
  return !nombre.contains('.');
}
