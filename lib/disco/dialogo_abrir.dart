// Nombres con mayúsculas como los de Windows (OPENFILENAMEW, GUID…) para que
// se reconozcan al compararlos con la documentación de Microsoft.
// ignore_for_file: constant_identifier_names, camel_case_types

import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

// Diálogos de Windows llamados directamente (sin plugins de Flutter, que
// exigirían activar el "Modo de desarrollador").

/// Abre el diálogo "Abrir" de Windows para elegir un `.mp4`.
/// Devuelve la ruta elegida o `null` si se cancela.
String? elegirMp4({String? carpetaInicial}) => _elegirArchivo(
  filtro: 'Películas MP4 (*.mp4)\u0000*.mp4\u0000',
  titulo: 'Elige una película',
  carpetaInicial: carpetaInicial,
);

/// Abre el diálogo "Abrir" de Windows para elegir una imagen JPEG o PNG
/// (una carátula). Devuelve la ruta elegida o `null` si se cancela.
String? elegirImagen({String? carpetaInicial}) => _elegirArchivo(
  filtro: 'Imágenes (*.jpg, *.jpeg, *.png)\u0000*.jpg;*.jpeg;*.png\u0000',
  titulo: 'Elige la carátula',
  carpetaInicial: carpetaInicial,
);

/// Abre el diálogo "Abrir" de Windows para elegir una copia de seguridad
/// (`.zip`). Devuelve la ruta elegida o `null` si se cancela.
String? elegirCopia({String? carpetaInicial}) => _elegirArchivo(
  filtro: 'Copias de Videoteca (*.zip)\u0000*.zip\u0000',
  titulo: 'Elige la copia de seguridad',
  carpetaInicial: carpetaInicial,
);

/// Abre el diálogo "Guardar como" de Windows con el nombre [nombre]
/// propuesto (p. ej. `Videoteca.xlsx`). Devuelve la ruta elegida o `null` si
/// se cancela. Si el archivo ya existe, Windows pregunta antes si se cambia.
String? elegirDondeGuardar({
  required String nombre,
  required String filtro,
  required String titulo,
  String? carpetaInicial,
}) => _elegirArchivo(
  filtro: filtro,
  titulo: titulo,
  carpetaInicial: carpetaInicial ?? carpetaDocumentos(),
  guardarComo: nombre,
);

/// La carpeta Documentos del usuario.
String carpetaDocumentos() =>
    '${Platform.environment['USERPROFILE'] ?? 'C:'}\\Documents';

String? _elegirArchivo({
  required String filtro,
  required String titulo,
  String? carpetaInicial,
  String? guardarComo,
}) {
  final memoria = Arena();
  try {
    const largoMaximo = 1024;
    final ruta = memoria<Uint16>(largoMaximo).cast<Utf16>();
    if (guardarComo != null) {
      final unidades = guardarComo.codeUnits;
      final destino = ruta.cast<Uint16>();
      for (var i = 0; i < unidades.length && i < largoMaximo - 1; i++) {
        destino[i] = unidades[i];
      }
      destino[unidades.length.clamp(0, largoMaximo - 1)] = 0;
    }
    final punto = guardarComo?.lastIndexOf('.') ?? -1;
    final datos = memoria<_OPENFILENAMEW>();
    datos.ref
      ..lStructSize = sizeOf<_OPENFILENAMEW>()
      ..hwndOwner = _ventanaApp()
      ..lpstrFilter = '$filtro\u0000'.toNativeUtf16(allocator: memoria)
      ..lpstrFile = ruta
      ..nMaxFile = largoMaximo
      ..lpstrTitle = titulo.toNativeUtf16(allocator: memoria)
      ..lpstrInitialDir = carpetaInicial == null
          ? nullptr
          : carpetaInicial.toNativeUtf16(allocator: memoria)
      // Extensión que se añade si no se escribe ninguna.
      ..lpstrDefExt = punto < 0
          ? nullptr
          : guardarComo!.substring(punto + 1).toNativeUtf16(allocator: memoria)
      ..Flags = guardarComo == null
          ? _OFN_EXPLORER |
                _OFN_FILEMUSTEXIST |
                _OFN_PATHMUSTEXIST |
                _OFN_NOCHANGEDIR
          : _OFN_EXPLORER |
                _OFN_OVERWRITEPROMPT |
                _OFN_PATHMUSTEXIST |
                _OFN_NOCHANGEDIR;
    final elegido = guardarComo == null
        ? _getOpenFileName(datos)
        : _getSaveFileName(datos);
    if (elegido == 0) return null;
    return ruta.toDartString();
  } finally {
    memoria.releaseAll();
  }
}

/// Abre el diálogo de Windows para elegir una **carpeta** (el mismo que usa
/// el Explorador). Devuelve la ruta elegida o `null` si se cancela.
///
/// Usa el objeto COM `IFileOpenDialog` en modo "elegir carpetas". Los objetos
/// COM se manejan a través de su tabla de funciones: cada número (3, 9, 20…)
/// es la posición de una función en esa tabla, según la documentación.
String? elegirCarpeta({
  String? carpetaInicial,
  String titulo = 'Elige la carpeta de tus películas',
}) {
  final hrInicio = _coInitializeEx(
    nullptr,
    _COINIT_APARTMENTTHREADED | _COINIT_DISABLE_OLE1DDE,
  );
  final memoria = Arena();
  Pointer<Void> dialogo = nullptr;
  Pointer<Void> elegida = nullptr;
  try {
    final salida = memoria<Pointer<Void>>();
    var hr = _coCreateInstance(
      _guid(memoria, 'DC1C5A9C-E88A-4DDE-A5A1-60F82A20AEF7'), // FileOpenDialog
      nullptr,
      _CLSCTX_INPROC_SERVER,
      _guid(memoria, 'D57C7288-D4AD-4768-BE02-9D969532D960'), // IFileOpenDialog
      salida,
    );
    if (hr < 0) return null;
    dialogo = salida.value;

    // GetOptions (10) y SetOptions (9): modo carpetas.
    final opciones = memoria<Uint32>();
    _funcion<_Con32C>(dialogo, 10).asFunction<_Con32Dart>()(dialogo, opciones);
    _funcion<_ConEnteroC>(dialogo, 9).asFunction<_ConEnteroDart>()(
      dialogo,
      opciones.value |
          _FOS_PICKFOLDERS |
          _FOS_FORCEFILESYSTEM |
          _FOS_PATHMUSTEXIST,
    );
    // SetTitle (17).
    _funcion<_ConPunteroC>(dialogo, 17).asFunction<_ConPunteroDart>()(
      dialogo,
      titulo.toNativeUtf16(allocator: memoria).cast(),
    );
    // SetFolder (12): dónde se abre.
    if (carpetaInicial != null) {
      final item = memoria<Pointer<Void>>();
      final hrItem = _shCreateItemFromParsingName(
        carpetaInicial.toNativeUtf16(allocator: memoria),
        nullptr,
        _guid(memoria, '43826D1E-E718-42EE-BC55-A1E261C37BFE'), // IShellItem
        item,
      );
      if (hrItem >= 0) {
        _funcion<_ConPunteroC>(dialogo, 12).asFunction<_ConPunteroDart>()(
          dialogo,
          item.value,
        );
        _liberar(item.value);
      }
    }

    // Show (3): espera hasta que se elige o se cancela.
    hr = _funcion<_ConPunteroC>(dialogo, 3).asFunction<_ConPunteroDart>()(
      dialogo,
      _ventanaApp(),
    );
    if (hr < 0) return null;

    // GetResult (20) y GetDisplayName (5) de la carpeta elegida.
    hr = _funcion<_ConSalidaC>(dialogo, 20).asFunction<_ConSalidaDart>()(
      dialogo,
      salida,
    );
    if (hr < 0) return null;
    elegida = salida.value;
    final texto = memoria<Pointer<Utf16>>();
    hr = _funcion<_NombreC>(elegida, 5).asFunction<_NombreDart>()(
      elegida,
      _SIGDN_FILESYSPATH,
      texto,
    );
    if (hr < 0) return null;
    final ruta = texto.value.toDartString();
    _coTaskMemFree(texto.value.cast());
    return ruta;
  } finally {
    if (elegida != nullptr) _liberar(elegida);
    if (dialogo != nullptr) _liberar(dialogo);
    memoria.releaseAll();
    if (hrInicio >= 0) _coUninitialize();
  }
}

/// Ventana de la app, para que el diálogo quede delante de ella.
Pointer<Void> _ventanaApp() {
  final activa = _getActiveWindow();
  if (activa != nullptr) return activa;
  final clase = 'FLUTTER_RUNNER_WIN32_WINDOW'.toNativeUtf16();
  try {
    return _findWindow(clase, nullptr);
  } finally {
    calloc.free(clase);
  }
}

const _OFN_OVERWRITEPROMPT = 0x2;
const _OFN_NOCHANGEDIR = 0x8;
const _OFN_PATHMUSTEXIST = 0x800;
const _OFN_FILEMUSTEXIST = 0x1000;
const _OFN_EXPLORER = 0x80000;
const _COINIT_APARTMENTTHREADED = 0x2;
const _COINIT_DISABLE_OLE1DDE = 0x4;
const _CLSCTX_INPROC_SERVER = 0x1;
const _FOS_PICKFOLDERS = 0x20;
const _FOS_FORCEFILESYSTEM = 0x40;
const _FOS_PATHMUSTEXIST = 0x800;
const _SIGDN_FILESYSPATH = 0x80058000;

/// Estructura OPENFILENAMEW de Windows (los nombres son los oficiales).
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

final class _GUID extends Struct {
  @Uint32()
  external int data1;
  @Uint16()
  external int data2;
  @Uint16()
  external int data3;
  @Array(8)
  external Array<Uint8> data4;
}

/// Identificador COM a partir de su forma escrita "XXXXXXXX-XXXX-…".
Pointer<_GUID> _guid(Allocator memoria, String texto) {
  final h = texto.replaceAll('-', '');
  final g = memoria<_GUID>();
  g.ref
    ..data1 = int.parse(h.substring(0, 8), radix: 16)
    ..data2 = int.parse(h.substring(8, 12), radix: 16)
    ..data3 = int.parse(h.substring(12, 16), radix: 16);
  for (var i = 0; i < 8; i++) {
    g.ref.data4[i] = int.parse(h.substring(16 + i * 2, 18 + i * 2), radix: 16);
  }
  return g;
}

/// Función número [indice] de la tabla de funciones de un objeto COM.
Pointer<NativeFunction<C>> _funcion<C extends Function>(
  Pointer<Void> objeto,
  int indice,
) {
  final tabla = objeto.cast<Pointer<Pointer<NativeFunction<C>>>>().value;
  return (tabla + indice).value;
}

/// Release (2): avisa a Windows de que ya no se usa el objeto.
void _liberar(Pointer<Void> objeto) =>
    _funcion<_LiberarC>(objeto, 2).asFunction<_LiberarDart>()(objeto);

typedef _LiberarC = Uint32 Function(Pointer<Void>);
typedef _LiberarDart = int Function(Pointer<Void>);
typedef _ConPunteroC = Int32 Function(Pointer<Void>, Pointer<Void>);
typedef _ConPunteroDart = int Function(Pointer<Void>, Pointer<Void>);
typedef _Con32C = Int32 Function(Pointer<Void>, Pointer<Uint32>);
typedef _Con32Dart = int Function(Pointer<Void>, Pointer<Uint32>);
typedef _ConEnteroC = Int32 Function(Pointer<Void>, Uint32);
typedef _ConEnteroDart = int Function(Pointer<Void>, int);
typedef _ConSalidaC = Int32 Function(Pointer<Void>, Pointer<Pointer<Void>>);
typedef _ConSalidaDart = int Function(Pointer<Void>, Pointer<Pointer<Void>>);
typedef _NombreC = Int32 Function(
  Pointer<Void>,
  Uint32,
  Pointer<Pointer<Utf16>>,
);
typedef _NombreDart = int Function(Pointer<Void>, int, Pointer<Pointer<Utf16>>);

final _ole32 = DynamicLibrary.open('ole32.dll');
final _user32 = DynamicLibrary.open('user32.dll');

final _getOpenFileName = DynamicLibrary.open('comdlg32.dll')
    .lookupFunction<
      Int32 Function(Pointer<_OPENFILENAMEW>),
      int Function(Pointer<_OPENFILENAMEW>)
    >('GetOpenFileNameW');
final _getSaveFileName = DynamicLibrary.open('comdlg32.dll')
    .lookupFunction<
      Int32 Function(Pointer<_OPENFILENAMEW>),
      int Function(Pointer<_OPENFILENAMEW>)
    >('GetSaveFileNameW');
final _coInitializeEx = _ole32
    .lookupFunction<
      Int32 Function(Pointer<Void>, Uint32),
      int Function(Pointer<Void>, int)
    >('CoInitializeEx');
final _coUninitialize = _ole32.lookupFunction<Void Function(), void Function()>(
  'CoUninitialize',
);
final _coCreateInstance = _ole32
    .lookupFunction<
      Int32 Function(
        Pointer<_GUID>,
        Pointer<Void>,
        Uint32,
        Pointer<_GUID>,
        Pointer<Pointer<Void>>,
      ),
      int Function(
        Pointer<_GUID>,
        Pointer<Void>,
        int,
        Pointer<_GUID>,
        Pointer<Pointer<Void>>,
      )
    >('CoCreateInstance');
final _coTaskMemFree = _ole32
    .lookupFunction<Void Function(Pointer<Void>), void Function(Pointer<Void>)>(
      'CoTaskMemFree',
    );
final _shCreateItemFromParsingName = DynamicLibrary.open('shell32.dll')
    .lookupFunction<
      Int32 Function(
        Pointer<Utf16>,
        Pointer<Void>,
        Pointer<_GUID>,
        Pointer<Pointer<Void>>,
      ),
      int Function(
        Pointer<Utf16>,
        Pointer<Void>,
        Pointer<_GUID>,
        Pointer<Pointer<Void>>,
      )
    >('SHCreateItemFromParsingName');
final _getActiveWindow = _user32
    .lookupFunction<Pointer<Void> Function(), Pointer<Void> Function()>(
      'GetActiveWindow',
    );
final _findWindow = _user32
    .lookupFunction<
      Pointer<Void> Function(Pointer<Utf16>, Pointer<Utf16>),
      Pointer<Void> Function(Pointer<Utf16>, Pointer<Utf16>)
    >('FindWindowW');
