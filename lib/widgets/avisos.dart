import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Avisos flotantes de toda la app (issue #3): pequeños, abajo a la derecha
// en el PC (para no tapar la zona de trabajo), con una X para cerrarlos, y
// también se cierran deslizándolos o con Esc.

/// Ancho máximo de un aviso en el PC (con la letra al 100 %).
const anchoAviso = 420.0;

/// Alto de la barra fija de abajo de Editar ficha (los avisos van encima).
const altoBarraEditar = 80.0;

ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? _abierto;

/// Si hay un aviso en pantalla.
bool get hayAviso => _abierto != null;

/// Cierra el aviso que haya en pantalla.
void cerrarAviso() => _abierto?.close();

/// Enseña un aviso abajo. [accion] es el texto de un botón opcional (p. ej.
/// «Deshacer»); [sobreBarra], para las pantallas con barra fija abajo.
void avisar(
  BuildContext context,
  String texto, {
  String? accion,
  VoidCallback? alPulsar,
  bool sobreBarra = false,
  bool largo = false,
}) => ScaffoldMessenger.of(context).avisar(
  texto,
  accion: accion,
  alPulsar: alPulsar,
  sobreBarra: sobreBarra,
  largo: largo,
);

extension Avisos on ScaffoldMessengerState {
  /// Como [avisar], para cuando el `context` ya no sirve (después de un
  /// `await`): se guarda antes `ScaffoldMessenger.of(context)`.
  void avisar(
    String texto, {
    String? accion,
    VoidCallback? alPulsar,
    bool sobreBarra = false,
    bool largo = false,
  }) {
    final ancho = MediaQuery.sizeOf(context).width;
    // Con la letra más grande, el aviso también (si no, el botón y la X no
    // caben).
    final maximo = MediaQuery.textScalerOf(context).scale(anchoAviso);
    final abajo = sobreBarra ? altoBarraEditar : 16.0;
    hideCurrentSnackBar();
    final aviso = _abierto = showSnackBar(
      SnackBar(
        content: Text(texto),
        // Con botón, el aviso dura más (da tiempo a leerlo y pulsarlo).
        duration: Duration(seconds: accion != null || largo ? 8 : 5),
        // Con botón, Flutter lo dejaría fijo hasta cerrarlo a mano.
        persist: false,
        showCloseIcon: true,
        margin: ancho < 600
            ? EdgeInsets.fromLTRB(12, 0, 12, abajo)
            : EdgeInsets.fromLTRB(max(24, ancho - maximo - 24), 0, 24, abajo),
        action: accion == null
            ? null
            : SnackBarAction(label: accion, onPressed: alPulsar!),
      ),
    );
    aviso.closed.then((_) {
      if (identical(_abierto, aviso)) _abierto = null;
    });
  }
}

/// Esc cierra el aviso que haya en pantalla. Si no hay aviso, o hay un
/// diálogo o un menú abierto, Esc hace lo de siempre (cerrarlos).
class CerrarAvisoConEsc extends StatefulWidget {
  const CerrarAvisoConEsc({super.key, required this.child});

  final Widget child;

  @override
  State<CerrarAvisoConEsc> createState() => _CerrarAvisoConEscState();
}

class _CerrarAvisoConEscState extends State<CerrarAvisoConEsc> {
  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_alPulsar);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_alPulsar);
    super.dispose();
  }

  bool _alPulsar(KeyEvent evento) {
    if (evento is! KeyDownEvent ||
        evento.logicalKey != LogicalKeyboardKey.escape ||
        !hayAviso) {
      return false;
    }
    final foco = FocusManager.instance.primaryFocus?.context;
    if (foco != null && ModalRoute.of(foco) is PopupRoute) return false;
    cerrarAviso();
    return true;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
