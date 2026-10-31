import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

// La ventana de Windows sin su barra de título (issue #4): la barra la
// dibuja la app (`widgets/barra_ventana.dart`) y el código nativo
// (`windows/runner/marco_ventana.cpp`) hace que se pueda arrastrar, que
// maximizar enseñe el menú «Ajustar» de Windows 11, etc.

/// Si la app dibuja su propia barra de la ventana: en Windows (en las
/// pruebas no, salvo que se pida).
bool get barraPropia =>
    Platform.isWindows && !Platform.environment.containsKey('FLUTTER_TEST');

/// Cómo está el botón de maximizar: sus clics los recibe Windows (para el
/// menú «Ajustar»), y el código nativo avisa de cómo pintarlo.
enum EstadoBoton { normal, encima, pulsado }

@immutable
class EstadoVentana {
  const EstadoVentana({
    this.maximizada = false,
    this.activa = true,
    this.maximizar = EstadoBoton.normal,
  });

  final bool maximizada;

  /// Si es la ventana de delante (si no, la barra se ve más apagada).
  final bool activa;
  final EstadoBoton maximizar;
}

class Ventana {
  Ventana._() {
    _canal.setMethodCallHandler(_recibir);
  }

  static final instancia = Ventana._();

  static const _canal = MethodChannel('videoteca/ventana');

  final estado = ValueNotifier(const EstadoVentana());

  Future<void> _recibir(MethodCall llamada) async {
    if (llamada.method != 'estado') return;
    final datos = llamada.arguments as Map;
    final boton = (datos['maximizar'] as int?) ?? 0;
    estado.value = EstadoVentana(
      maximizada: datos['maximizada'] == true,
      activa: datos['activa'] != false,
      maximizar: EstadoBoton.values[boton.clamp(0, 2)],
    );
  }

  /// Dónde están la barra y sus botones, en píxeles de la pantalla desde
  /// arriba a la izquierda de la app. Lo que no son botones se arrastra.
  Future<void> zonas({
    required double alto,
    required List<Rect> botones,
    required Rect maximizar,
  }) {
    List<double> lista(Rect r) => [r.left, r.top, r.right, r.bottom];
    return _llamar('zonas', {
      'alto': alto,
      'botones': [for (final b in botones) lista(b)],
      'maximizar': lista(maximizar),
    });
  }

  Future<void> minimizar() => _llamar('minimizar');

  /// Maximiza o, si ya lo está, la deja como estaba.
  Future<void> maximizar() => _llamar('maximizar');

  /// Como la X de Windows (la app puede preguntar antes de cerrar).
  Future<void> cerrar() => _llamar('cerrar');

  Future<void> _llamar(String metodo, [Object? datos]) async {
    try {
      await _canal.invokeMethod<void>(metodo, datos);
    } on MissingPluginException {
      // Sin el código nativo (pruebas): no hay ventana que mover.
    }
  }
}
