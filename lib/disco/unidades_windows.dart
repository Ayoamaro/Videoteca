// Nombres con mayúsculas como los de Windows (DRIVE_FIXED…) para que se
// reconozcan al compararlos con la documentación de Microsoft.
// ignore_for_file: constant_identifier_names

import 'dart:ffi';

import 'package:ffi/ffi.dart';

// Las unidades de este PC (discos, pendrives, tarjetas de memoria) y el
// espacio libre de una carpeta, preguntados directamente a Windows (sin
// plugins). Lo usa `copiador.dart`.

/// Qué es una unidad para Windows (`GetDriveType`).
enum TipoUnidad { extraible, fija, red, cd, otra }

/// Letras de las unidades que hay en este PC: `['C:', 'D:', 'E:']`.
List<String> letrasDeUnidades() {
  final mascara = _getLogicalDrives();
  return [
    for (var i = 0; i < 26; i++)
      if (mascara & (1 << i) != 0) '${String.fromCharCode(65 + i)}:',
  ];
}

TipoUnidad tipoDeUnidad(String letra) {
  final memoria = Arena();
  try {
    return switch (_getDriveType(
      '$letra\\'.toNativeUtf16(allocator: memoria),
    )) {
      _DRIVE_REMOVABLE => TipoUnidad.extraible,
      _DRIVE_FIXED => TipoUnidad.fija,
      _DRIVE_REMOTE => TipoUnidad.red,
      _DRIVE_CDROM => TipoUnidad.cd,
      _ => TipoUnidad.otra,
    };
  } finally {
    memoria.releaseAll();
  }
}

/// Nombre y formato del disco cuya raíz es [raiz] (`E:\`, `\\PC\Carpeta\`).
/// `null` si no tiene nada dentro (un lector de tarjetas vacío) o no se puede
/// leer.
({String etiqueta, String sistema, bool soloLectura})? datosDeVolumen(
  String raiz,
) {
  final memoria = Arena();
  try {
    const largo = 261;
    final etiqueta = memoria<Uint16>(largo).cast<Utf16>();
    final sistema = memoria<Uint16>(largo).cast<Utf16>();
    final marcas = memoria<Uint32>();
    final bien = _getVolumeInformation(
      raiz.toNativeUtf16(allocator: memoria),
      etiqueta,
      largo,
      nullptr,
      nullptr,
      marcas,
      sistema,
      largo,
    );
    if (bien == 0) return null;
    return (
      etiqueta: etiqueta.toDartString().trim(),
      sistema: sistema.toDartString(),
      soloLectura: marcas.value & _FILE_READ_ONLY_VOLUME != 0,
    );
  } finally {
    memoria.releaseAll();
  }
}

/// Espacio libre (el que puede usar este usuario) y total del disco donde
/// está [carpeta]. `null` si no se puede saber.
({int libre, int total})? espacioDe(String carpeta) {
  final memoria = Arena();
  try {
    final libre = memoria<Uint64>();
    final total = memoria<Uint64>();
    final ruta = carpeta.endsWith(r'\') ? carpeta : '$carpeta\\';
    final bien = _getDiskFreeSpaceEx(
      ruta.toNativeUtf16(allocator: memoria),
      libre,
      total,
      nullptr,
    );
    if (bien == 0) return null;
    return (libre: libre.value, total: total.value);
  } finally {
    memoria.releaseAll();
  }
}

/// Raíz del disco donde está [carpeta]: `E:\Películas` → `E:\`,
/// `\\PC\Carpeta\Otra` → `\\PC\Carpeta\`. `null` si no se puede saber.
String? raizDeVolumen(String carpeta) {
  final memoria = Arena();
  try {
    const largo = 1024;
    final raiz = memoria<Uint16>(largo).cast<Utf16>();
    final bien = _getVolumePathName(
      carpeta.toNativeUtf16(allocator: memoria),
      raiz,
      largo,
    );
    return bien == 0 ? null : raiz.toDartString();
  } finally {
    memoria.releaseAll();
  }
}

/// Por dónde va conectado el disco de la unidad [letra] (`E:`): el
/// `STORAGE_BUS_TYPE` de Windows (7 = USB, 12 = tarjeta SD…). `null` si
/// Windows no lo dice. No hace falta ser administrador: se abre la unidad
/// sin pedir permiso de lectura ni de escritura, solo para preguntar.
int? busDeUnidad(String letra) {
  final memoria = Arena();
  final manija = _createFile(
    '\\\\.\\$letra'.toNativeUtf16(allocator: memoria),
    0,
    _FILE_SHARE_READ | _FILE_SHARE_WRITE,
    nullptr,
    _OPEN_EXISTING,
    0,
    nullptr,
  );
  try {
    if (manija.address == _INVALID_HANDLE_VALUE) return null;
    // STORAGE_PROPERTY_QUERY: StorageDeviceProperty (0), PropertyStandardQuery
    // (0) y un byte más (12 con el relleno).
    final pregunta = memoria<Uint8>(12);
    for (var i = 0; i < 12; i++) {
      pregunta[i] = 0;
    }
    const largo = 1024;
    final respuesta = memoria<Uint8>(largo);
    final devueltos = memoria<Uint32>();
    final bien = _deviceIoControl(
      manija,
      _IOCTL_STORAGE_QUERY_PROPERTY,
      pregunta.cast(),
      12,
      respuesta.cast(),
      largo,
      devueltos,
      nullptr,
    );
    // STORAGE_DEVICE_DESCRIPTOR: BusType va en el byte 28.
    if (bien == 0 || devueltos.value < 32) return null;
    return (respuesta + 28).cast<Uint32>().value;
  } finally {
    if (manija.address != _INVALID_HANDLE_VALUE) _closeHandle(manija);
    memoria.releaseAll();
  }
}

/// Hace [trabajo] sin que Windows enseñe ventanas como «No hay ningún disco
/// en la unidad» (al preguntar por un lector de tarjetas vacío). Todo lo de
/// [trabajo] tiene que ir seguido, sin esperas (`await`): así se queda en el
/// mismo hilo.
T sinVentanasDeWindows<T>(T Function() trabajo) {
  final memoria = Arena();
  try {
    final antes = memoria<Uint32>();
    final cambiado =
        _setThreadErrorMode(
          _SEM_FAILCRITICALERRORS | _SEM_NOOPENFILEERRORBOX,
          antes,
        ) !=
        0;
    try {
      return trabajo();
    } finally {
      if (cambiado) _setThreadErrorMode(antes.value, nullptr);
    }
  } finally {
    memoria.releaseAll();
  }
}

// ── Funciones de Windows ─────────────────────────────────────────────────

const _DRIVE_REMOVABLE = 2;
const _DRIVE_FIXED = 3;
const _DRIVE_REMOTE = 4;
const _DRIVE_CDROM = 5;
const _FILE_READ_ONLY_VOLUME = 0x00080000;
const _FILE_SHARE_READ = 0x1;
const _FILE_SHARE_WRITE = 0x2;
const _OPEN_EXISTING = 3;
const _INVALID_HANDLE_VALUE = -1;
const _IOCTL_STORAGE_QUERY_PROPERTY = 0x002D1400;
const _SEM_FAILCRITICALERRORS = 0x0001;
const _SEM_NOOPENFILEERRORBOX = 0x8000;

final _kernel32 = DynamicLibrary.open('kernel32.dll');

final _getLogicalDrives = _kernel32
    .lookupFunction<Uint32 Function(), int Function()>('GetLogicalDrives');
final _getDriveType = _kernel32
    .lookupFunction<
      Uint32 Function(Pointer<Utf16>),
      int Function(Pointer<Utf16>)
    >('GetDriveTypeW');
final _getVolumeInformation = _kernel32
    .lookupFunction<
      Int32 Function(
        Pointer<Utf16>,
        Pointer<Utf16>,
        Uint32,
        Pointer<Uint32>,
        Pointer<Uint32>,
        Pointer<Uint32>,
        Pointer<Utf16>,
        Uint32,
      ),
      int Function(
        Pointer<Utf16>,
        Pointer<Utf16>,
        int,
        Pointer<Uint32>,
        Pointer<Uint32>,
        Pointer<Uint32>,
        Pointer<Utf16>,
        int,
      )
    >('GetVolumeInformationW');
final _getDiskFreeSpaceEx = _kernel32
    .lookupFunction<
      Int32 Function(
        Pointer<Utf16>,
        Pointer<Uint64>,
        Pointer<Uint64>,
        Pointer<Uint64>,
      ),
      int Function(
        Pointer<Utf16>,
        Pointer<Uint64>,
        Pointer<Uint64>,
        Pointer<Uint64>,
      )
    >('GetDiskFreeSpaceExW');
final _getVolumePathName = _kernel32
    .lookupFunction<
      Int32 Function(Pointer<Utf16>, Pointer<Utf16>, Uint32),
      int Function(Pointer<Utf16>, Pointer<Utf16>, int)
    >('GetVolumePathNameW');
final _createFile = _kernel32
    .lookupFunction<
      Pointer<Void> Function(
        Pointer<Utf16>,
        Uint32,
        Uint32,
        Pointer<Void>,
        Uint32,
        Uint32,
        Pointer<Void>,
      ),
      Pointer<Void> Function(
        Pointer<Utf16>,
        int,
        int,
        Pointer<Void>,
        int,
        int,
        Pointer<Void>,
      )
    >('CreateFileW');
final _deviceIoControl = _kernel32
    .lookupFunction<
      Int32 Function(
        Pointer<Void>,
        Uint32,
        Pointer<Void>,
        Uint32,
        Pointer<Void>,
        Uint32,
        Pointer<Uint32>,
        Pointer<Void>,
      ),
      int Function(
        Pointer<Void>,
        int,
        Pointer<Void>,
        int,
        Pointer<Void>,
        int,
        Pointer<Uint32>,
        Pointer<Void>,
      )
    >('DeviceIoControl');
final _closeHandle = _kernel32
    .lookupFunction<Int32 Function(Pointer<Void>), int Function(Pointer<Void>)>(
      'CloseHandle',
    );
final _setThreadErrorMode = _kernel32
    .lookupFunction<
      Int32 Function(Uint32, Pointer<Uint32>),
      int Function(int, Pointer<Uint32>)
    >('SetThreadErrorMode');
