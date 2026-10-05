import 'dart:io';

import 'package:flutter/services.dart';

import 'acciones_windows.dart';

// Abrir una web (FilmAffinity, IMDb…) con el navegador, en el PC y en el
// móvil, sin plugins: en Windows con el Explorador (`acciones_windows.dart`)
// y en Android con el canal «videoteca/sistema» de `MainActivity.kt`.

const _canal = MethodChannel('videoteca/sistema');

/// Abre [direccion] en el navegador. Devuelve `false` si no se ha podido.
Future<bool> abrirEnlace(String direccion) async {
  if (Platform.isAndroid) {
    try {
      return await _canal.invokeMethod<bool>('abrir', direccion) ?? false;
    } on PlatformException {
      return false;
    }
  }
  if (Platform.isWindows) return abrirConWindows(direccion);
  return false;
}
