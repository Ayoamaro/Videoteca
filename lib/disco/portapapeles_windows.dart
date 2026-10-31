import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

// El portapapeles de Windows en formato HTML (lo que guarda el navegador al
// copiar una página: Flutter solo deja leer el texto). Lo usa «Pegar ficha
// de FilmAffinity» (`fuentes/filmaffinity.dart`).

/// El portapapeles (en las pruebas se cambia por uno falso).
class Portapapeles {
  const Portapapeles();

  /// Un número que cambia cada vez que se copia algo (para leer solo lo
  /// copiado después de abrir la ventana).
  int cambios() => Platform.isWindows ? _getClipboardSequenceNumber() : 0;

  /// Lo copiado en «HTML Format» (cabecera + HTML, en UTF-8), o `null` si lo
  /// copiado no es de una página web.
  Uint8List? html() {
    if (!Platform.isWindows) return null;
    final nombre = 'HTML Format'.toNativeUtf16();
    final formato = _registerClipboardFormat(nombre);
    calloc.free(nombre);
    if (formato == 0 || _openClipboard(0) == 0) return null;
    try {
      final memoria = _getClipboardData(formato);
      if (memoria == 0) return null;
      final datos = _globalLock(memoria);
      if (datos == nullptr) return null;
      try {
        final bytes = datos.cast<Uint8>().asTypedList(_globalSize(memoria));
        return Uint8List.fromList(bytes);
      } finally {
        _globalUnlock(memoria);
      }
    } finally {
      _closeClipboard();
    }
  }
}

final _user32 = DynamicLibrary.open('user32.dll');
final _kernel32 = DynamicLibrary.open('kernel32.dll');

final _registerClipboardFormat = _user32
    .lookupFunction<
      Uint32 Function(Pointer<Utf16>),
      int Function(Pointer<Utf16>)
    >('RegisterClipboardFormatW');
final _getClipboardSequenceNumber = _user32
    .lookupFunction<Uint32 Function(), int Function()>(
      'GetClipboardSequenceNumber',
    );
final _openClipboard = _user32
    .lookupFunction<Int32 Function(IntPtr), int Function(int)>('OpenClipboard');
final _closeClipboard = _user32
    .lookupFunction<Int32 Function(), int Function()>('CloseClipboard');
final _getClipboardData = _user32
    .lookupFunction<IntPtr Function(Uint32), int Function(int)>(
      'GetClipboardData',
    );
final _globalLock = _kernel32
    .lookupFunction<
      Pointer<Void> Function(IntPtr),
      Pointer<Void> Function(int)
    >('GlobalLock');
final _globalUnlock = _kernel32
    .lookupFunction<Int32 Function(IntPtr), int Function(int)>('GlobalUnlock');
final _globalSize = _kernel32
    .lookupFunction<IntPtr Function(IntPtr), int Function(int)>('GlobalSize');
