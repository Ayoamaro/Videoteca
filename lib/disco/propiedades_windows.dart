// Nombres con mayúsculas como los de Windows (PROPVARIANT, VT_LPWSTR…) para
// que se reconozcan al compararlos con la documentación de Microsoft.
// ignore_for_file: camel_case_types, constant_identifier_names

import 'dart:ffi';

import 'package:ffi/ffi.dart';

/// Lee las propiedades de un archivo igual que "Propiedades → Detalles".
///
/// Usa el *Windows Property System*, el mismo sistema que usa el Explorador:
/// se pide a Windows el "almacén de propiedades" del archivo y se le pregunta
/// por cada propiedad usando su nombre oficial (`System.Title`,
/// `System.Media.Year`…). **Solo lectura**: el archivo se abre sin permiso
/// de escritura.
///
/// Devuelve un mapa nombre → valor, donde el valor es un `String`, una
/// `List<String>` (propiedades con varios valores, como el reparto) o un `int`.
/// Las propiedades vacías no aparecen en el mapa.
///
/// Hay que llamarla de principio a fin en el mismo hilo (es síncrona), porque
/// Windows prepara su sistema COM hilo a hilo.
Map<String, Object> leerPropiedadesWindows(String ruta, List<String> nombres) {
  final hrInicio = _coInitializeEx(nullptr, _COINIT_MULTITHREADED);
  // S_OK o S_FALSE: hay que "cerrar" COM al terminar. Si el hilo ya estaba
  // preparado de otra forma (RPC_E_CHANGED_MODE) se usa tal cual.
  final cerrarCom = hrInicio >= 0;
  final memoria = Arena();
  Pointer<Void> almacen = nullptr;
  try {
    final salida = memoria<Pointer<Void>>();
    final hr = _shGetPropertyStoreFromParsingName(
      ruta.toNativeUtf16(allocator: memoria),
      nullptr,
      _GPS_DEFAULT,
      _iidPropertyStore(memoria),
      salida,
    );
    if (hr < 0) throw PropiedadesException(ruta, hr);
    almacen = salida.value;

    final getValue = _metodo<_GetValueC>(
      almacen,
      5,
    ).asFunction<_GetValueDart>();
    final valores = <String, Object>{};
    final clave = memoria<_PROPERTYKEY>();
    final variante = memoria<_PROPVARIANT>();
    for (final nombre in nombres) {
      if (_psGetPropertyKeyFromName(
            nombre.toNativeUtf16(allocator: memoria),
            clave,
          ) <
          0) {
        continue; // Nombre que esta versión de Windows no conoce.
      }
      if (getValue(almacen, clave, variante) < 0) continue;
      try {
        final valor = _convertir(variante);
        if (valor != null) valores[nombre] = valor;
      } finally {
        _propVariantClear(variante);
      }
    }
    return valores;
  } finally {
    if (almacen != nullptr) {
      _metodo<_ReleaseC>(almacen, 2).asFunction<_ReleaseDart>()(almacen);
    }
    memoria.releaseAll();
    if (cerrarCom) _coUninitialize();
  }
}

class PropiedadesException implements Exception {
  PropiedadesException(this.ruta, this.codigo);

  final String ruta;
  final int codigo;

  @override
  String toString() =>
      'Windows no pudo leer las propiedades de "$ruta" '
      '(código 0x${(codigo & 0xFFFFFFFF).toRadixString(16).toUpperCase()}).';
}

/// Pasa un valor de Windows (PROPVARIANT) a un valor de Dart.
Object? _convertir(Pointer<_PROPVARIANT> v) {
  final tipo = v.ref.vt;
  if (tipo == _VT_EMPTY || tipo == _VT_NULL) return null;

  if (tipo & _VT_VECTOR != 0) {
    final lista = <String>[];
    final n = _propVariantGetElementCount(v);
    final texto = calloc<Pointer<Utf16>>();
    try {
      for (var i = 0; i < n; i++) {
        if (_propVariantGetStringElem(v, i, texto) < 0) break;
        final s = texto.value.toDartString().trim();
        _coTaskMemFree(texto.value.cast());
        if (s.isNotEmpty) lista.add(s);
      }
    } finally {
      calloc.free(texto);
    }
    if (lista.length == n) return lista.isEmpty ? null : lista;
    // Lista de números u otro tipo: se convierte a texto entero.
  } else if (_tiposEnteros.contains(tipo)) {
    final numero = calloc<Uint64>();
    try {
      if (_propVariantToUInt64(v, numero) >= 0) return numero.value;
    } finally {
      calloc.free(numero);
    }
  }

  final texto = calloc<Pointer<Utf16>>();
  try {
    if (_propVariantToStringAlloc(v, texto) < 0) return null;
    final s = texto.value.toDartString().trim();
    _coTaskMemFree(texto.value.cast());
    return s.isEmpty ? null : s;
  } finally {
    calloc.free(texto);
  }
}

// ---------------------------------------------------------------------------
// Conexión con las bibliotecas de Windows (FFI).
// ---------------------------------------------------------------------------

const _COINIT_MULTITHREADED = 0x0;
const _GPS_DEFAULT = 0;
const _VT_EMPTY = 0;
const _VT_NULL = 1;
const _VT_VECTOR = 0x1000;

/// I2, I4, I1, UI1, UI2, UI4, I8, UI8, INT, UINT.
const _tiposEnteros = {2, 3, 16, 17, 18, 19, 20, 21, 22, 23};

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

final class _PROPERTYKEY extends Struct {
  external _GUID fmtid;
  @Uint32()
  external int pid;
}

/// Valor "comodín" de Windows: un tipo (`vt`) y 16 bytes de datos (24 en
/// total en 64 bits). Solo se lee `vt`; el resto lo interpreta Windows.
final class _PROPVARIANT extends Struct {
  @Uint16()
  external int vt;
  @Uint16()
  external int reservado1;
  @Uint16()
  external int reservado2;
  @Uint16()
  external int reservado3;
  @Uint64()
  external int datos1;
  @Uint64()
  external int datos2;
}

/// `{886d8eeb-8cf2-4446-8d02-cdba1dbdcf99}`: identificador de IPropertyStore.
Pointer<_GUID> _iidPropertyStore(Allocator memoria) {
  final g = memoria<_GUID>();
  g.ref
    ..data1 = 0x886d8eeb
    ..data2 = 0x8cf2
    ..data3 = 0x4446;
  const resto = [0x8d, 0x02, 0xcd, 0xba, 0x1d, 0xbd, 0xcf, 0x99];
  for (var i = 0; i < 8; i++) {
    g.ref.data4[i] = resto[i];
  }
  return g;
}

/// Un objeto COM es un puntero a una tabla de funciones; [indice] es la
/// posición del método en esa tabla (IPropertyStore: 2 Release, 5 GetValue).
Pointer<NativeFunction<T>> _metodo<T extends Function>(
  Pointer<Void> objeto,
  int indice,
) {
  final tabla = objeto.cast<Pointer<Pointer<NativeFunction<T>>>>().value;
  return (tabla + indice).value;
}

typedef _ReleaseC = Uint32 Function(Pointer<Void>);
typedef _ReleaseDart = int Function(Pointer<Void>);
typedef _GetValueC = Int32 Function(
  Pointer<Void>,
  Pointer<_PROPERTYKEY>,
  Pointer<_PROPVARIANT>,
);
typedef _GetValueDart = int Function(
  Pointer<Void>,
  Pointer<_PROPERTYKEY>,
  Pointer<_PROPVARIANT>,
);

final _ole32 = DynamicLibrary.open('ole32.dll');
final _shell32 = DynamicLibrary.open('shell32.dll');
final _propsys = DynamicLibrary.open('propsys.dll');

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
final _propVariantClear = _ole32
    .lookupFunction<
      Int32 Function(Pointer<_PROPVARIANT>),
      int Function(Pointer<_PROPVARIANT>)
    >('PropVariantClear');

final _shGetPropertyStoreFromParsingName = _shell32
    .lookupFunction<
      Int32 Function(
        Pointer<Utf16>,
        Pointer<Void>,
        Int32,
        Pointer<_GUID>,
        Pointer<Pointer<Void>>,
      ),
      int Function(
        Pointer<Utf16>,
        Pointer<Void>,
        int,
        Pointer<_GUID>,
        Pointer<Pointer<Void>>,
      )
    >('SHGetPropertyStoreFromParsingName');

final _psGetPropertyKeyFromName = _propsys
    .lookupFunction<
      Int32 Function(Pointer<Utf16>, Pointer<_PROPERTYKEY>),
      int Function(Pointer<Utf16>, Pointer<_PROPERTYKEY>)
    >('PSGetPropertyKeyFromName');
final _propVariantToStringAlloc = _propsys
    .lookupFunction<
      Int32 Function(Pointer<_PROPVARIANT>, Pointer<Pointer<Utf16>>),
      int Function(Pointer<_PROPVARIANT>, Pointer<Pointer<Utf16>>)
    >('PropVariantToStringAlloc');
final _propVariantToUInt64 = _propsys
    .lookupFunction<
      Int32 Function(Pointer<_PROPVARIANT>, Pointer<Uint64>),
      int Function(Pointer<_PROPVARIANT>, Pointer<Uint64>)
    >('PropVariantToUInt64');
final _propVariantGetElementCount = _propsys
    .lookupFunction<
      Uint32 Function(Pointer<_PROPVARIANT>),
      int Function(Pointer<_PROPVARIANT>)
    >('PropVariantGetElementCount');
final _propVariantGetStringElem = _propsys
    .lookupFunction<
      Int32 Function(Pointer<_PROPVARIANT>, Uint32, Pointer<Pointer<Utf16>>),
      int Function(Pointer<_PROPVARIANT>, int, Pointer<Pointer<Utf16>>)
    >('PropVariantGetStringElem');
