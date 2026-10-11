// Nombres con mayúsculas como los de Windows (SHARE_INFO_1…) para que se
// reconozcan al compararlos con la documentación de Microsoft.
// ignore_for_file: constant_identifier_names, camel_case_types, non_constant_identifier_names

import 'dart:ffi';

import 'package:ffi/ffi.dart';

// Lo que hace falta de Windows para la red de casa, llamado directamente
// (sin plugins): las carpetas que este PC comparte en la red y a qué
// carpeta de red lleva una unidad como `Z:`.

/// Nombres de las carpetas que este PC comparte en la red: solo las de
/// archivos, sin las que Windows comparte por su cuenta para los
/// administradores (`C$`, `ADMIN$`, `IPC$`…). Vacía si Windows no las da.
List<String> carpetasCompartidas() {
  final memoria = Arena();
  final datos = memoria<Pointer<_SHARE_INFO_1>>();
  try {
    final leidas = memoria<Uint32>();
    final total = memoria<Uint32>();
    final resultado = _netShareEnum(
      nullptr, // este PC
      1, // SHARE_INFO_1: nombre, tipo y descripción
      datos,
      _MAX_PREFERRED_LENGTH,
      leidas,
      total,
      nullptr,
    );
    if (resultado != 0 && resultado != _ERROR_MORE_DATA) return const [];
    if (datos.value == nullptr) return const [];
    return [
      for (var i = 0; i < leidas.value; i++)
        // Tipo 0 = carpeta de archivos (las especiales llevan un bit más).
        if (datos.value[i].shi1_type & ~_STYPE_TEMPORARY == _STYPE_DISKTREE)
          datos.value[i].shi1_netname.toDartString(),
    ];
  } finally {
    if (datos.value != nullptr) _netApiBufferFree(datos.value.cast());
    memoria.releaseAll();
  }
}

/// La carpeta de red a la que lleva la unidad [letra] (`Z:` →
/// `\\PC\Compartida`), o `null` si no es una unidad de red.
String? conexionDeUnidad(String letra) {
  final memoria = Arena();
  try {
    const largoMaximo = 1024;
    final largo = memoria<Uint32>()..value = largoMaximo;
    final remota = memoria<Uint16>(largoMaximo).cast<Utf16>();
    final resultado = _wNetGetConnection(
      letra.toNativeUtf16(allocator: memoria),
      remota,
      largo,
    );
    // También vale una unidad recordada pero desconectada ahora.
    if (resultado != 0 && resultado != _ERROR_CONNECTION_UNAVAIL) return null;
    final texto = remota.toDartString();
    return texto.isEmpty ? null : texto;
  } finally {
    memoria.releaseAll();
  }
}

// ── Funciones de Windows ─────────────────────────────────────────────────

const _MAX_PREFERRED_LENGTH = 0xFFFFFFFF;
const _ERROR_MORE_DATA = 234;
const _ERROR_CONNECTION_UNAVAIL = 1201;
const _STYPE_DISKTREE = 0;
const _STYPE_TEMPORARY = 0x40000000;

/// Estructura SHARE_INFO_1 de Windows (los nombres son los oficiales).
final class _SHARE_INFO_1 extends Struct {
  external Pointer<Utf16> shi1_netname;
  @Uint32()
  external int shi1_type;
  external Pointer<Utf16> shi1_remark;
}

final _netapi32 = DynamicLibrary.open('netapi32.dll');

final _netShareEnum = _netapi32
    .lookupFunction<
      Uint32 Function(
        Pointer<Utf16>,
        Uint32,
        Pointer<Pointer<_SHARE_INFO_1>>,
        Uint32,
        Pointer<Uint32>,
        Pointer<Uint32>,
        Pointer<Uint32>,
      ),
      int Function(
        Pointer<Utf16>,
        int,
        Pointer<Pointer<_SHARE_INFO_1>>,
        int,
        Pointer<Uint32>,
        Pointer<Uint32>,
        Pointer<Uint32>,
      )
    >('NetShareEnum');
final _netApiBufferFree = _netapi32
    .lookupFunction<
      Uint32 Function(Pointer<Void>),
      int Function(Pointer<Void>)
    >('NetApiBufferFree');
final _wNetGetConnection = DynamicLibrary.open('mpr.dll')
    .lookupFunction<
      Uint32 Function(Pointer<Utf16>, Pointer<Utf16>, Pointer<Uint32>),
      int Function(Pointer<Utf16>, Pointer<Utf16>, Pointer<Uint32>)
    >('WNetGetConnectionW');
