// Nombres con mayúsculas como los de Windows para que se reconozcan al
// compararlos con la documentación de Microsoft.
// ignore_for_file: constant_identifier_names

import 'dart:ffi';
import 'dart:isolate';

import 'package:ffi/ffi.dart';

import 'red.dart';

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

/// Lo que ha pasado al abrir una película.
enum ResultadoAbrir {
  hecho,

  /// El PC de las películas no contesta (apagado o sin red).
  sinConexion,

  /// El archivo ya no está en esa ruta.
  noEsta,

  /// Windows no ha podido abrirlo.
  error,
}

/// Reproduce [ruta] con el programa que Windows tenga para ella (como un
/// doble clic en el Explorador) o, con [enCarpeta], abre su carpeta con el
/// archivo ya seleccionado. Va en otro hilo y antes mira, con tiempo límite,
/// que el archivo sigue ahí: con un PC de la red apagado, Windows dejaría la
/// app esperando medio minuto.
Future<ResultadoAbrir> abrirArchivo(String ruta, {bool enCarpeta = false}) =>
    Isolate.run(() => _abrirArchivo(ruta, enCarpeta));

Future<ResultadoAbrir> _abrirArchivo(String ruta, bool enCarpeta) async {
  final esta = await archivoEsta(ruta);
  if (esta == null) return ResultadoAbrir.sinConexion;
  if (!esta) return ResultadoAbrir.noEsta;
  final hecho = enCarpeta ? mostrarEnCarpeta(ruta) : _ejecutar(ruta);
  return hecho ? ResultadoAbrir.hecho : ResultadoAbrir.error;
}

/// Abre el Explorador en [carpeta] (p. ej. `\\PC\Carpeta`). Si ese PC pide
/// usuario y contraseña, el Explorador los pide y, con «Recordar mis
/// credenciales», Windows los guarda para la próxima vez (también para la
/// app). Va en otro hilo, así la app no espera.
Future<bool> explorarCarpeta(String carpeta) => Isolate.run(
  () => _ejecutar(
    'explorer.exe',
    // Entre comillas por los espacios; una `\` justo antes de las comillas
    // las anularía (`Z:\`), pero esas rutas no llevan espacios.
    parametros: carpeta.endsWith(r'\') ? carpeta : '"$carpeta"',
  ),
);

/// Como [abrirConWindows], pero espera a que Windows termine de lanzarlo
/// (`SEE_MASK_NOASYNC`) y prepara COM: así funciona desde otro hilo.
bool _ejecutar(String archivo, {String? parametros}) {
  final hrInicio = _coInitializeEx(
    nullptr,
    _COINIT_APARTMENTTHREADED | _COINIT_DISABLE_OLE1DDE,
  );
  final memoria = Arena();
  try {
    final info = memoria<_ShellExecuteInfo>();
    info.ref
      ..cbSize = sizeOf<_ShellExecuteInfo>()
      ..fMask = _SEE_MASK_NOASYNC | _SEE_MASK_FLAG_NO_UI
      ..lpFile = archivo.toNativeUtf16(allocator: memoria)
      ..lpParameters = parametros == null
          ? nullptr
          : parametros.toNativeUtf16(allocator: memoria)
      ..nShow = _SW_SHOWNORMAL;
    // Sin verbo: el de un doble clic (normalmente «Abrir»).
    return _shellExecuteEx(info) != 0;
  } finally {
    memoria.releaseAll();
    if (hrInicio >= 0) _coUninitialize();
  }
}

// ── Funciones de Windows ─────────────────────────────────────────────────

const _SW_SHOWNORMAL = 1;
const _COINIT_APARTMENTTHREADED = 0x2;
const _COINIT_DISABLE_OLE1DDE = 0x4;
const _SEE_MASK_NOASYNC = 0x100;
const _SEE_MASK_FLAG_NO_UI = 0x400;

/// `SHELLEXECUTEINFOW`.
final class _ShellExecuteInfo extends Struct {
  @Uint32()
  external int cbSize;
  @Uint32()
  external int fMask;
  external Pointer<Void> hwnd;
  external Pointer<Utf16> lpVerb;
  external Pointer<Utf16> lpFile;
  external Pointer<Utf16> lpParameters;
  external Pointer<Utf16> lpDirectory;
  @Int32()
  external int nShow;
  external Pointer<Void> hInstApp;
  external Pointer<Void> lpIDList;
  external Pointer<Utf16> lpClass;
  external Pointer<Void> hkeyClass;
  @Uint32()
  external int dwHotKey;
  external Pointer<Void> hIcon;
  external Pointer<Void> hProcess;
}

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
final _shellExecuteEx = _shell32
    .lookupFunction<
      Int32 Function(Pointer<_ShellExecuteInfo>),
      int Function(Pointer<_ShellExecuteInfo>)
    >('ShellExecuteExW');
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
