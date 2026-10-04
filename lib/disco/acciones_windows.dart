// Nombres con mayúsculas como los de Windows para que se reconozcan al
// compararlos con la documentación de Microsoft.
// ignore_for_file: constant_identifier_names

import 'dart:ffi';

import 'package:ffi/ffi.dart';

// Acciones del Explorador de Windows llamadas directamente (sin plugins):
// abrir un archivo con su programa, abrir una web y enseñar un archivo en su
// carpeta.

/// Abre [ruta] (un archivo o una dirección web) con el programa que Windows
/// tenga asignado: el reproductor para un `.mp4`, el navegador para una web.
/// Devuelve `false` si Windows no ha podido abrirlo.
bool abrirConWindows(String ruta) {
  final memoria = Arena();
  try {
    final resultado = _shellExecute(
      nullptr,
      'open'.toNativeUtf16(allocator: memoria),
      ruta.toNativeUtf16(allocator: memoria),
      nullptr,
      nullptr,
      _SW_SHOWNORMAL,
    );
    // ShellExecute devuelve un número mayor que 32 si todo va bien.
    return resultado.address > 32;
  } finally {
    memoria.releaseAll();
  }
}

/// Abre en el Explorador la carpeta de [ruta] con el archivo ya seleccionado.
/// Devuelve `false` si no se ha podido (p. ej. el archivo no existe).
bool mostrarEnCarpeta(String ruta) {
  final hrInicio = _coInitializeEx(nullptr, _COINIT_APARTMENTTHREADED);
  final memoria = Arena();
  final elemento = memoria<Pointer<Void>>();
  try {
    final hr = _shParseDisplayName(
      ruta.toNativeUtf16(allocator: memoria),
      nullptr,
      elemento,
      0,
      nullptr,
    );
    if (hr < 0 || elemento.value == nullptr) return false;
    return _shOpenFolderAndSelectItems(elemento.value, 0, nullptr, 0) >= 0;
  } finally {
    if (elemento.value != nullptr) _coTaskMemFree(elemento.value);
    memoria.releaseAll();
    if (hrInicio >= 0) _coUninitialize();
  }
}

// ── Funciones de Windows ─────────────────────────────────────────────────

const _SW_SHOWNORMAL = 1;
const _COINIT_APARTMENTTHREADED = 0x2;

final _shell32 = DynamicLibrary.open('shell32.dll');
final _ole32 = DynamicLibrary.open('ole32.dll');

final _shellExecute = _shell32
    .lookupFunction<
      Pointer<Void> Function(
        Pointer<Void>,
        Pointer<Utf16>,
        Pointer<Utf16>,
        Pointer<Utf16>,
        Pointer<Utf16>,
        Int32,
      ),
      Pointer<Void> Function(
        Pointer<Void>,
        Pointer<Utf16>,
        Pointer<Utf16>,
        Pointer<Utf16>,
        Pointer<Utf16>,
        int,
      )
    >('ShellExecuteW');
final _shParseDisplayName = _shell32
    .lookupFunction<
      Int32 Function(
        Pointer<Utf16>,
        Pointer<Void>,
        Pointer<Pointer<Void>>,
        Uint32,
        Pointer<Uint32>,
      ),
      int Function(
        Pointer<Utf16>,
        Pointer<Void>,
        Pointer<Pointer<Void>>,
        int,
        Pointer<Uint32>,
      )
    >('SHParseDisplayName');
final _shOpenFolderAndSelectItems = _shell32
    .lookupFunction<
      Int32 Function(Pointer<Void>, Uint32, Pointer<Pointer<Void>>, Uint32),
      int Function(Pointer<Void>, int, Pointer<Pointer<Void>>, int)
    >('SHOpenFolderAndSelectItems');
final _coInitializeEx = _ole32
    .lookupFunction<
      Int32 Function(Pointer<Void>, Uint32),
      int Function(Pointer<Void>, int)
    >('CoInitializeEx');
final _coUninitialize = _ole32.lookupFunction<Void Function(), void Function()>(
  'CoUninitialize',
);
final _coTaskMemFree = _ole32
    .lookupFunction<Void Function(Pointer<Void>), void Function(Pointer<Void>)>(
      'CoTaskMemFree',
    );
