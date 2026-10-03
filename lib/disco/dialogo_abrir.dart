// ignore_for_file: constant_identifier_names

import 'dart:ffi';

import 'package:ffi/ffi.dart';

/// Abre el diálogo "Abrir" de Windows para elegir un `.mp4`.
///
/// Se llama directamente a Windows (sin plugins de Flutter, que exigirían
/// activar el "Modo de desarrollador"). Devuelve la ruta elegida o `null` si
/// se cancela.
String? elegirMp4({String? carpetaInicial}) {
  final memoria = Arena();
  try {
    const largoMaximo = 1024;
    final ruta = memoria<Uint16>(largoMaximo).cast<Utf16>();
    final datos = memoria<_OPENFILENAMEW>();
    datos.ref
      ..lStructSize = sizeOf<_OPENFILENAMEW>()
      ..lpstrFilter = 'Películas MP4 (*.mp4)\u0000*.mp4\u0000\u0000'
          .toNativeUtf16(allocator: memoria)
      ..lpstrFile = ruta
      ..nMaxFile = largoMaximo
      ..lpstrTitle = 'Elige una película'.toNativeUtf16(allocator: memoria)
      ..lpstrInitialDir = carpetaInicial == null
          ? nullptr
          : carpetaInicial.toNativeUtf16(allocator: memoria)
      ..Flags =
          _OFN_EXPLORER |
          _OFN_FILEMUSTEXIST |
          _OFN_PATHMUSTEXIST |
          _OFN_NOCHANGEDIR;
    if (_getOpenFileName(datos) == 0) return null;
    return ruta.toDartString();
  } finally {
    memoria.releaseAll();
  }
}

const _OFN_NOCHANGEDIR = 0x8;
const _OFN_PATHMUSTEXIST = 0x800;
const _OFN_FILEMUSTEXIST = 0x1000;
const _OFN_EXPLORER = 0x80000;

/// Estructura OPENFILENAMEW de Windows (los nombres son los oficiales).
// ignore: camel_case_types
final class _OPENFILENAMEW extends Struct {
  @Uint32()
  external int lStructSize;
  external Pointer<Void> hwndOwner;
  external Pointer<Void> hInstance;
  external Pointer<Utf16> lpstrFilter;
  external Pointer<Utf16> lpstrCustomFilter;
  @Uint32()
  external int nMaxCustFilter;
  @Uint32()
  external int nFilterIndex;
  external Pointer<Utf16> lpstrFile;
  @Uint32()
  external int nMaxFile;
  external Pointer<Utf16> lpstrFileTitle;
  @Uint32()
  external int nMaxFileTitle;
  external Pointer<Utf16> lpstrInitialDir;
  external Pointer<Utf16> lpstrTitle;
  @Uint32()
  // ignore: non_constant_identifier_names
  external int Flags;
  @Uint16()
  external int nFileOffset;
  @Uint16()
  external int nFileExtension;
  external Pointer<Utf16> lpstrDefExt;
  @IntPtr()
  external int lCustData;
  external Pointer<Void> lpfnHook;
  external Pointer<Utf16> lpTemplateName;
  external Pointer<Void> pvReserved;
  @Uint32()
  external int dwReserved;
  @Uint32()
  external int flagsEx;
}

final _getOpenFileName = DynamicLibrary.open('comdlg32.dll')
    .lookupFunction<
      Int32 Function(Pointer<_OPENFILENAMEW>),
      int Function(Pointer<_OPENFILENAMEW>)
    >('GetOpenFileNameW');
