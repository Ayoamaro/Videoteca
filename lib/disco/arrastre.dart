import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

// Archivos arrastrados desde el Explorador de Windows a la ventana de la app
// (p. ej. una carátula). Lo recibe el código nativo de la ventana
// (`windows/runner/receptor_arrastre.cpp`) y lo manda aquí por el canal
// «videoteca/arrastre».
//
// Solo se aceptan archivos mientras alguna pantalla está escuchando (si no,
// Windows enseña el cursor de «no se puede soltar»). En Android no hace nada.

typedef AlSoltar = void Function(List<String> rutas);

class ArrastreArchivos {
  ArrastreArchivos._();

  static final instancia = ArrastreArchivos._();

  static const _canal = MethodChannel('videoteca/arrastre');

  /// Hay archivos encima de la ventana (para resaltar la zona de soltar).
  final encima = ValueNotifier(false);

  final _receptores = <AlSoltar>[];
  var _conectado = false;

  /// Empieza a recibir lo que se suelte. Si hay varias pantallas
  /// escuchando, lo recibe la última.
  void escuchar(AlSoltar receptor) {
    _receptores.add(receptor);
    if (!_conectado) {
      _conectado = true;
      _canal.setMethodCallHandler(_mensaje);
    }
    if (_receptores.length == 1) _activar(true);
  }

  void dejar(AlSoltar receptor) {
    _receptores.remove(receptor);
    if (_receptores.isEmpty) {
      encima.value = false;
      _activar(false);
    }
  }

  Future<void> _activar(bool activo) async {
    try {
      await _canal.invokeMethod<void>('activar', activo);
    } on MissingPluginException {
      // Fuera de Windows (o en las pruebas) no hay nadie al otro lado.
    } on PlatformException {
      // Igual.
    }
  }

  Future<void> _mensaje(MethodCall llamada) async {
    switch (llamada.method) {
      case 'entrar':
        encima.value = true;
      case 'salir':
        encima.value = false;
      case 'soltar':
        encima.value = false;
        final rutas = [
          for (final r in (llamada.arguments as List? ?? const []))
            if (r is String) r,
        ];
        if (rutas.isNotEmpty && _receptores.isNotEmpty) {
          _receptores.last(rutas);
        }
    }
  }
}

/// Para las pruebas: simula que se sueltan [rutas] en la ventana.
@visibleForTesting
Future<void> simularSoltar(List<String> rutas) =>
    ArrastreArchivos.instancia._mensaje(MethodCall('soltar', rutas));
