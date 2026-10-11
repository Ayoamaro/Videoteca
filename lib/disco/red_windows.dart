// Nombres con mayúsculas como los de Windows (SHARE_INFO_1…) para que se
// reconozcan al compararlos con la documentación de Microsoft.
// ignore_for_file: constant_identifier_names, camel_case_types, non_constant_identifier_names

import 'dart:ffi';

import 'package:ffi/ffi.dart';

// Lo que hace falta de Windows para la red de casa, llamado directamente
// (sin plugins): las carpetas que este PC comparte en la red, a qué
// carpeta de red lleva una unidad como `Z:` y entrar en otro PC con usuario
// y contraseña (guardándolos como hace «Recordar mis credenciales»).

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

/// Entra en la carpeta compartida [recurso] (`\\PC\Compartida`) con
/// [usuario] y [contrasena], sin letra de unidad. Devuelve 0 si ha ido bien
/// o el código de error de Windows (1326 = usuario o contraseña
/// incorrectos…). Puede tardar: llamarla aparte.
int conectarConUsuario(String recurso, String usuario, String contrasena) {
  final memoria = Arena();
  try {
    final datos = memoria<_NETRESOURCE>()
      ..ref.dwScope = 0
      ..ref.dwType = _RESOURCETYPE_DISK
      ..ref.dwDisplayType = 0
      ..ref.dwUsage = 0
      ..ref.lpLocalName = nullptr
      ..ref.lpRemoteName = recurso.toNativeUtf16(allocator: memoria)
      ..ref.lpComment = nullptr
      ..ref.lpProvider = nullptr;
    return _wNetAddConnection2(
      datos,
      contrasena.toNativeUtf16(allocator: memoria),
      usuario.toNativeUtf16(allocator: memoria),
      0,
    );
  } finally {
    memoria.releaseAll();
  }
}

/// Cierra la conexión de este PC con la carpeta compartida [recurso] (si la
/// hay), aunque tenga archivos abiertos.
void desconectar(String recurso) {
  final memoria = Arena();
  try {
    _wNetCancelConnection2(recurso.toNativeUtf16(allocator: memoria), 0, 1);
  } finally {
    memoria.releaseAll();
  }
}

/// Guarda en el Administrador de credenciales de Windows (en «Credenciales
/// de Windows») el [usuario] y la [contrasena] para entrar en el PC
/// [equipo], como «Recordar mis credenciales» del Explorador: Windows los usa
/// sin preguntar cada vez que se entra en ese PC, también al reiniciar.
/// `true` si se han guardado.
bool guardarCredencial(String equipo, String usuario, String contrasena) {
  final memoria = Arena();
  try {
    final secreto = contrasena.toNativeUtf16(allocator: memoria);
    final credencial = memoria<_CREDENTIAL>()
      ..ref.Flags = 0
      ..ref.Type = _CRED_TYPE_DOMAIN_PASSWORD
      ..ref.TargetName = equipo.toNativeUtf16(allocator: memoria)
      ..ref.Comment = nullptr
      ..ref.LastWrittenBajo = 0
      ..ref.LastWrittenAlto = 0
      // La contraseña va sin el cero del final (2 bytes por letra).
      ..ref.CredentialBlobSize = contrasena.length * 2
      ..ref.CredentialBlob = secreto.cast()
      ..ref.Persist = _CRED_PERSIST_ENTERPRISE
      ..ref.AttributeCount = 0
      ..ref.Attributes = nullptr
      ..ref.TargetAlias = nullptr
      ..ref.UserName = usuario.toNativeUtf16(allocator: memoria);
    return _credWrite(credencial, 0) != 0;
  } finally {
    memoria.releaseAll();
  }
}

/// El usuario guardado para entrar en el PC [equipo], o `null` si no hay.
String? usuarioGuardado(String equipo) {
  final memoria = Arena();
  final leida = memoria<Pointer<_CREDENTIAL>>();
  try {
    final hay = _credRead(
      equipo.toNativeUtf16(allocator: memoria),
      _CRED_TYPE_DOMAIN_PASSWORD,
      0,
      leida,
    );
    if (hay == 0 || leida.value == nullptr) return null;
    final usuario = leida.value.ref.UserName;
    return usuario == nullptr ? '' : usuario.toDartString();
  } finally {
    if (leida.value != nullptr) _credFree(leida.value.cast());
    memoria.releaseAll();
  }
}

/// Borra el usuario y la contraseña guardados para el PC [equipo].
bool borrarCredencial(String equipo) {
  final memoria = Arena();
  try {
    return _credDelete(
          equipo.toNativeUtf16(allocator: memoria),
          _CRED_TYPE_DOMAIN_PASSWORD,
          0,
        ) !=
        0;
  } finally {
    memoria.releaseAll();
  }
}

// ── Funciones de Windows ─────────────────────────────────────────────────

const _RESOURCETYPE_DISK = 1;
const _CRED_TYPE_DOMAIN_PASSWORD = 2;
const _CRED_PERSIST_ENTERPRISE = 3;
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

/// Estructura NETRESOURCEW de Windows.
final class _NETRESOURCE extends Struct {
  @Uint32()
  external int dwScope;
  @Uint32()
  external int dwType;
  @Uint32()
  external int dwDisplayType;
  @Uint32()
  external int dwUsage;
  external Pointer<Utf16> lpLocalName;
  external Pointer<Utf16> lpRemoteName;
  external Pointer<Utf16> lpComment;
  external Pointer<Utf16> lpProvider;
}

/// Estructura CREDENTIALW de Windows (`LastWritten`, un FILETIME, va en sus
/// dos mitades).
final class _CREDENTIAL extends Struct {
  @Uint32()
  external int Flags;
  @Uint32()
  external int Type;
  external Pointer<Utf16> TargetName;
  external Pointer<Utf16> Comment;
  @Uint32()
  external int LastWrittenBajo;
  @Uint32()
  external int LastWrittenAlto;
  @Uint32()
  external int CredentialBlobSize;
  external Pointer<Uint8> CredentialBlob;
  @Uint32()
  external int Persist;
  @Uint32()
  external int AttributeCount;
  external Pointer<Void> Attributes;
  external Pointer<Utf16> TargetAlias;
  external Pointer<Utf16> UserName;
}

final _netapi32 = DynamicLibrary.open('netapi32.dll');
final _mpr = DynamicLibrary.open('mpr.dll');
final _advapi32 = DynamicLibrary.open('advapi32.dll');

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
final _wNetGetConnection = _mpr
    .lookupFunction<
      Uint32 Function(Pointer<Utf16>, Pointer<Utf16>, Pointer<Uint32>),
      int Function(Pointer<Utf16>, Pointer<Utf16>, Pointer<Uint32>)
    >('WNetGetConnectionW');
final _wNetAddConnection2 = _mpr
    .lookupFunction<
      Uint32 Function(
        Pointer<_NETRESOURCE>,
        Pointer<Utf16>,
        Pointer<Utf16>,
        Uint32,
      ),
      int Function(Pointer<_NETRESOURCE>, Pointer<Utf16>, Pointer<Utf16>, int)
    >('WNetAddConnection2W');
final _wNetCancelConnection2 = _mpr
    .lookupFunction<
      Uint32 Function(Pointer<Utf16>, Uint32, Int32),
      int Function(Pointer<Utf16>, int, int)
    >('WNetCancelConnection2W');
final _credWrite = _advapi32
    .lookupFunction<
      Int32 Function(Pointer<_CREDENTIAL>, Uint32),
      int Function(Pointer<_CREDENTIAL>, int)
    >('CredWriteW');
final _credRead = _advapi32
    .lookupFunction<
      Int32 Function(
        Pointer<Utf16>,
        Uint32,
        Uint32,
        Pointer<Pointer<_CREDENTIAL>>,
      ),
      int Function(Pointer<Utf16>, int, int, Pointer<Pointer<_CREDENTIAL>>)
    >('CredReadW');
final _credFree = _advapi32
    .lookupFunction<Void Function(Pointer<Void>), void Function(Pointer<Void>)>(
      'CredFree',
    );
final _credDelete = _advapi32
    .lookupFunction<
      Int32 Function(Pointer<Utf16>, Uint32, Uint32),
      int Function(Pointer<Utf16>, int, int)
    >('CredDeleteW');
