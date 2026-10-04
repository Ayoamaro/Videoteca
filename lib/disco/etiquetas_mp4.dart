import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

// Escribir los datos (etiquetas) y la carátula dentro de un `.mp4`, en Dart.
//
// Un `.mp4` está hecho de cajas. Los datos de la película están en
// `moov › udta`, en dos «cajones»:
//
// - `meta › ilst`: el estándar de iTunes. Una caja por dato (`©nam` título,
//   `©cmt` comentario, `covr` carátula…), cada una con una caja `data`
//   dentro: 4 bytes de tipo (1 texto UTF-8, 13 JPEG, 14 PNG, 0 números),
//   4 de idioma y el valor.
// - `Xtra`: el de Microsoft, donde el Explorador guarda lo que no cabe en
//   iTunes (`WM/Director`, `WM/SharedUserRating`…). Cada entrada lleva su
//   nombre y una lista de valores; los textos van en UTF-16.
//
// Se escribe con el mismo formato que usa Windows, pero sin su límite de
// 255 letras por texto (con textos más largos, Windows no guarda nada y
// dice que ha ido bien) y sin reescribir el archivo entero: detrás de `moov`
// suele haber una caja `free` de relleno, y la `moov` nueva se escribe en
// ese mismo sitio. El vídeo (`mdat`) **no se mueve ni se toca**.
//
// Si no cabe, la `moov` nueva se pone al final del archivo y la vieja se
// convierte en relleno (`free`). Tampoco así se toca el vídeo.
//
// No usa nada de Flutter ni de Windows: funciona igual en las pruebas.

/// Lo necesario para dejar el archivo exactamente como estaba (byte a byte):
/// su tamaño y los trozos que se han sobrescrito.
class CopiaOriginal {
  CopiaOriginal(this.tamano, this.trozos);

  final int tamano;
  final List<(int, Uint8List)> trozos;

  /// Deshace la escritura: vuelve a poner los trozos y el tamaño.
  void restaurar(String ruta) {
    final archivo = File(ruta).openSync(mode: FileMode.append);
    try {
      archivo.truncateSync(tamano);
      for (final (posicion, bytes) in trozos) {
        archivo
          ..setPositionSync(posicion)
          ..writeFromSync(bytes);
      }
      archivo.flushSync();
    } finally {
      archivo.closeSync();
    }
  }
}

class EtiquetasException implements Exception {
  EtiquetasException(this.mensaje);
  final String mensaje;

  @override
  String toString() => mensaje;
}

/// Cambia etiquetas del `.mp4` de [ruta].
///
/// [ilst]: nombre de la caja → valor: `String` (texto), `int` (nº de pista,
/// para `trkn`), `Uint8List` (imagen, para `covr`) o `null` (quitarla).
/// [xtra]: nombre → `List<String>` (textos), `int` (número de 64 bits, como
/// las estrellas) o `null` (quitarla).
///
/// Devuelve lo necesario para deshacerlo byte a byte.
CopiaOriginal escribirEtiquetasMp4(
  String ruta, {
  Map<String, Object?> ilst = const {},
  Map<String, Object?> xtra = const {},
}) {
  final archivo = File(ruta).openSync(mode: FileMode.append);
  try {
    final total = archivo.lengthSync();
    final cajas = _cajasPrincipales(archivo, total);
    final moovs = [
      for (var i = 0; i < cajas.length; i++)
        if (cajas[i].tipo == 'moov') i,
    ];
    if (moovs.length != 1) {
      throw EtiquetasException(
        'El archivo tiene ${moovs.length} cajas moov (se esperaba una).',
      );
    }
    final iMoov = moovs.single;
    final moov = cajas[iMoov];
    if (moov.cabecera != 8) {
      throw EtiquetasException('Caja moov con un formato poco habitual.');
    }
    archivo.setPositionSync(moov.inicio + 8);
    final contenido = archivo.readSync(moov.tamano - 8);
    final nueva = _juntar(
      'moov',
      _nuevoContenidoMoov(contenido, ilst: ilst, xtra: xtra),
    );

    // Hueco disponible: la moov y las cajas de relleno que la siguen.
    var finHueco = moov.inicio + moov.tamano;
    var j = iMoov + 1;
    while (j < cajas.length &&
        const {'free', 'skip'}.contains(cajas[j].tipo) &&
        cajas[j].cabecera == 8) {
      finHueco = cajas[j].inicio + cajas[j].tamano;
      j++;
    }
    final alFinal = j == cajas.length;
    final hueco = finHueco - moov.inicio;
    final sobra = hueco - nueva.length;

    archivo.setPositionSync(moov.inicio);
    final original = archivo.readSync(hueco);
    final copia = CopiaOriginal(total, [(moov.inicio, original)]);

    if (alFinal) {
      // La moov es lo último del archivo: se escribe y el archivo se alarga
      // o se acorta lo necesario.
      archivo
        ..setPositionSync(moov.inicio)
        ..writeFromSync(nueva)
        ..truncateSync(moov.inicio + nueva.length);
    } else if (sobra == 0 || sobra >= 8) {
      // Cabe en su sitio; lo que sobra queda como relleno.
      archivo
        ..setPositionSync(moov.inicio)
        ..writeFromSync(nueva);
      if (sobra > 0) archivo.writeFromSync(_relleno(sobra));
    } else {
      _moverAlFinal(archivo, cajas, moov, nueva, copia);
    }
    archivo.flushSync();
    return copia;
  } on FileSystemException catch (e) {
    throw EtiquetasException('No se pudo escribir en el archivo: ${e.message}');
  } finally {
    archivo.closeSync();
  }
}

/// No cabe en su sitio: la moov nueva va al final del archivo y la vieja
/// pasa a ser relleno. El orden de los pasos hace que en todo momento haya
/// una sola moov válida (salvo un instante entre dos escrituras de 4 bytes).
void _moverAlFinal(
  RandomAccessFile archivo,
  List<_CajaArchivo> cajas,
  _CajaArchivo moov,
  Uint8List nueva,
  CopiaOriginal copia,
) {
  final total = archivo.lengthSync();
  // Una última caja «hasta el final» (tamaño 0) dejaría de serlo: se le pone
  // su tamaño real.
  final ultima = cajas.last;
  if (ultima.cabecera == 8 && ultima.tamanoCero) {
    if (ultima.tamano > 0xFFFFFFFF) {
      throw EtiquetasException('No hay sitio para los datos nuevos.');
    }
    archivo.setPositionSync(ultima.inicio);
    copia.trozos.add((ultima.inicio, archivo.readSync(4)));
    archivo
      ..setPositionSync(ultima.inicio)
      ..writeFromSync(_entero32(ultima.tamano));
  }
  // 1. La moov nueva, escrita al final como relleno.
  archivo
    ..setPositionSync(total)
    ..writeFromSync(_juntar('free', Uint8List.sublistView(nueva, 8)))
    ..flushSync();
  // 2. La vieja pasa a ser relleno y 3. la nueva pasa a ser la moov.
  archivo
    ..setPositionSync(moov.inicio + 4)
    ..writeFromSync(ascii.encode('free'))
    ..setPositionSync(total + 4)
    ..writeFromSync(ascii.encode('moov'));
}

/// Contenido nuevo de la moov: igual que el viejo, salvo `udta`.
List<int> _nuevoContenidoMoov(
  Uint8List contenido, {
  required Map<String, Object?> ilst,
  required Map<String, Object?> xtra,
}) {
  final hijos = _cajas(contenido, 'moov');
  final iUdta = hijos.indexWhere((c) => c.tipo == 'udta');
  final udta = iUdta < 0 ? Uint8List(0) : _contenido(contenido, hijos[iUdta]);
  final nuevaUdta = _juntar(
    'udta',
    _nuevoContenidoUdta(udta, ilst: ilst, xtra: xtra),
  );
  return [
    for (var i = 0; i < hijos.length; i++)
      ...(i == iUdta ? nuevaUdta : _completa(contenido, hijos[i])),
    if (iUdta < 0) ...nuevaUdta,
  ];
}

List<int> _nuevoContenidoUdta(
  Uint8List contenido, {
  required Map<String, Object?> ilst,
  required Map<String, Object?> xtra,
}) {
  final hijos = _cajas(contenido, 'udta');
  final iMeta = hijos.indexWhere((c) => c.tipo == 'meta');
  final iXtra = hijos.indexWhere((c) => c.tipo == 'Xtra');

  List<int>? nuevaMeta;
  if (ilst.isNotEmpty) {
    nuevaMeta = _juntar(
      'meta',
      _nuevoContenidoMeta(
        iMeta < 0 ? null : _contenido(contenido, hijos[iMeta]),
        ilst,
      ),
    );
  }
  List<int>? nuevaXtra;
  if (xtra.isNotEmpty) {
    final entradas = _nuevasEntradasXtra(
      iXtra < 0 ? Uint8List(0) : _contenido(contenido, hijos[iXtra]),
      xtra,
    );
    nuevaXtra = entradas.isEmpty ? const [] : _juntar('Xtra', entradas);
  }
  return [
    for (var i = 0; i < hijos.length; i++)
      if (i == iMeta && nuevaMeta != null)
        ...nuevaMeta
      else if (i == iXtra && nuevaXtra != null)
        ...nuevaXtra
      else
        ..._completa(contenido, hijos[i]),
    if (iMeta < 0 && nuevaMeta != null) ...nuevaMeta,
    if (iXtra < 0 && nuevaXtra != null) ...nuevaXtra,
  ];
}

/// `meta` lleva normalmente 4 bytes de versión antes de sus cajas (estilo
/// iTunes); en el estilo QuickTime no. Si no existía, se crea con su `hdlr`.
List<int> _nuevoContenidoMeta(Uint8List? contenido, Map<String, Object?> ilst) {
  if (contenido == null) {
    return [
      0, 0, 0, 0, // versión y flags
      ..._juntar('hdlr', [
        0, 0, 0, 0, 0, 0, 0, 0, // versión, flags y pre_defined
        ...ascii.encode('mdirappl'),
        0, 0, 0, 0, 0, 0, 0, 0, 0, // reservado y nombre vacío
      ]),
      ..._juntar('ilst', _nuevoContenidoIlst(Uint8List(0), ilst)),
    ];
  }
  final nombre = contenido.length >= 8
      ? latin1.decode(contenido.sublist(4, 8))
      : '';
  final version = nombre != 'hdlr' && nombre != 'ilst' ? 4 : 0;
  final hijos = _cajas(Uint8List.sublistView(contenido, version), 'meta');
  final cuerpo = Uint8List.sublistView(contenido, version);
  final iIlst = hijos.indexWhere((c) => c.tipo == 'ilst');
  final nuevaIlst = _juntar(
    'ilst',
    _nuevoContenidoIlst(
      iIlst < 0 ? Uint8List(0) : _contenido(cuerpo, hijos[iIlst]),
      ilst,
    ),
  );
  return [
    ...contenido.sublist(0, version),
    for (var i = 0; i < hijos.length; i++)
      ...(i == iIlst ? nuevaIlst : _completa(cuerpo, hijos[i])),
    if (iIlst < 0) ...nuevaIlst,
  ];
}

List<int> _nuevoContenidoIlst(
  Uint8List contenido,
  Map<String, Object?> cambios,
) {
  final hijos = _cajas(contenido, 'ilst');
  // Con el género en texto (©gen) sobra el antiguo género numérico (gnre).
  final quitar = {...cambios.keys, if (cambios.containsKey('©gen')) 'gnre'};
  final puestas = <String>{};
  final salida = <int>[];
  for (final h in hijos) {
    if (!quitar.contains(h.tipo)) {
      salida.addAll(_completa(contenido, h));
    } else if (cambios[h.tipo] != null && puestas.add(h.tipo)) {
      // Se cambia en el mismo sitio donde estaba (y se quitan repetidas).
      salida.addAll(_itemIlst(h.tipo, cambios[h.tipo]!));
    }
  }
  for (final MapEntry(key: tipo, :value) in cambios.entries) {
    if (value != null && !puestas.contains(tipo)) {
      salida.addAll(_itemIlst(tipo, value));
    }
  }
  return salida;
}

/// Un dato de `ilst`: caja [tipo] con una caja `data` dentro.
List<int> _itemIlst(String tipo, Object valor) {
  final (clase, bytes) = switch (valor) {
    final String texto => (1, utf8.encode(texto)),
    // trkn: 2 bytes vacíos, nº de pista, total (0) y 2 bytes vacíos.
    final int pista => (0, [0, 0, pista >> 8 & 0xFF, pista & 0xFF, 0, 0, 0, 0]),
    final Uint8List imagen => (imagen.first == 0x89 ? 14 : 13, imagen),
    _ => throw ArgumentError('Valor no admitido para $tipo: $valor'),
  };
  return _juntar(
    tipo,
    _juntar('data', [..._entero32(clase), 0, 0, 0, 0, ...bytes]),
  );
}

/// Entradas de la caja `Xtra` con los cambios hechos (en el mismo orden;
/// las nuevas, al final).
List<int> _nuevasEntradasXtra(
  Uint8List contenido,
  Map<String, Object?> cambios,
) {
  final datos = ByteData.sublistView(contenido);
  final salida = <int>[];
  final puestas = <String>{};
  var pos = 0;
  while (pos + 8 <= contenido.length) {
    final tamano = datos.getUint32(pos);
    final largoNombre = datos.getUint32(pos + 4);
    if (tamano < 12 + largoNombre || pos + tamano > contenido.length) {
      throw EtiquetasException('La caja Xtra está dañada.');
    }
    final nombre = latin1.decode(
      contenido.sublist(pos + 8, pos + 8 + largoNombre),
    );
    if (!cambios.containsKey(nombre)) {
      salida.addAll(contenido.sublist(pos, pos + tamano));
    } else if (cambios[nombre] != null && puestas.add(nombre)) {
      salida.addAll(_entradaXtra(nombre, cambios[nombre]!));
    }
    pos += tamano;
  }
  if (pos != contenido.length) {
    throw EtiquetasException('La caja Xtra está dañada.');
  }
  for (final MapEntry(key: nombre, :value) in cambios.entries) {
    if (value != null && !puestas.contains(nombre)) {
      salida.addAll(_entradaXtra(nombre, value));
    }
  }
  return salida;
}

/// Una entrada de `Xtra`: tamaño, largo del nombre, nombre, nº de valores y
/// cada valor (tamaño, tipo y datos). Los textos son de tipo 8 (UTF-16 con
/// un cero al final) y los números de tipo 19 (8 bytes).
List<int> _entradaXtra(String nombre, Object valor) {
  final valores = switch (valor) {
    final List<String> textos => [
      for (final t in textos)
        (
          8,
          [
            for (final u in t.codeUnits) ...[u & 0xFF, u >> 8],
            0,
            0,
          ],
        ),
    ],
    final int numero => [
      (
        19,
        (ByteData(8)..setUint64(0, numero, Endian.little)).buffer.asUint8List(),
      ),
    ],
    _ => throw ArgumentError('Valor no admitido para $nombre: $valor'),
  };
  final nombreBytes = latin1.encode(nombre);
  final cuerpo = [
    ..._entero32(nombreBytes.length),
    ...nombreBytes,
    ..._entero32(valores.length),
    for (final (tipo, bytes) in valores) ...[
      ..._entero32(6 + bytes.length),
      tipo >> 8,
      tipo & 0xFF,
      ...bytes,
    ],
  ];
  return [..._entero32(4 + cuerpo.length), ...cuerpo];
}

// ── Cajas ────────────────────────────────────────────────────────────────

/// Una caja de primer nivel del archivo.
class _CajaArchivo {
  _CajaArchivo(
    this.tipo,
    this.inicio,
    this.tamano,
    this.cabecera,
    this.tamanoCero,
  );

  final String tipo;
  final int inicio;
  final int tamano;
  final int cabecera;

  /// Tenía tamaño 0 («hasta el final del archivo»).
  final bool tamanoCero;
}

List<_CajaArchivo> _cajasPrincipales(RandomAccessFile archivo, int total) {
  final cajas = <_CajaArchivo>[];
  var pos = 0;
  while (pos < total) {
    if (pos + 8 > total) {
      throw EtiquetasException('El archivo termina a mitad de una caja.');
    }
    archivo.setPositionSync(pos);
    final cabecera = archivo.readSync(16);
    final datos = ByteData.sublistView(cabecera);
    var tamano = datos.getUint32(0);
    var largo = 8;
    final cero = tamano == 0;
    if (tamano == 1) {
      if (cabecera.length < 16) {
        throw EtiquetasException('El archivo termina a mitad de una caja.');
      }
      tamano = datos.getUint64(8);
      largo = 16;
    } else if (cero) {
      tamano = total - pos;
    }
    if (tamano < largo || pos + tamano > total) {
      throw EtiquetasException('El archivo no tiene el formato MP4 esperado.');
    }
    cajas.add(
      _CajaArchivo(
        latin1.decode(cabecera.sublist(4, 8)),
        pos,
        tamano,
        largo,
        cero,
      ),
    );
    pos += tamano;
  }
  return cajas;
}

/// Una caja dentro de otra: tipo, dónde empieza y su tamaño total.
typedef _Caja = ({String tipo, int inicio, int tamano});

/// Las cajas hijas que llenan [datos] por completo. Dentro de `moov` no se
/// esperan cajas de más de 4 GB ni «hasta el final»: si las hay, no se toca.
List<_Caja> _cajas(Uint8List datos, String padre) {
  final b = ByteData.sublistView(datos);
  final cajas = <_Caja>[];
  var pos = 0;
  while (pos < datos.length) {
    if (pos + 8 > datos.length) {
      throw EtiquetasException('La caja $padre está dañada.');
    }
    final tamano = b.getUint32(pos);
    if (tamano < 8 || pos + tamano > datos.length) {
      throw EtiquetasException(
        'La caja $padre está dañada o es poco habitual.',
      );
    }
    cajas.add((
      tipo: latin1.decode(datos.sublist(pos + 4, pos + 8)),
      inicio: pos,
      tamano: tamano,
    ));
    pos += tamano;
  }
  return cajas;
}

Uint8List _completa(Uint8List datos, _Caja c) =>
    Uint8List.sublistView(datos, c.inicio, c.inicio + c.tamano);

Uint8List _contenido(Uint8List datos, _Caja c) =>
    Uint8List.sublistView(datos, c.inicio + 8, c.inicio + c.tamano);

Uint8List _juntar(String tipo, List<int> contenido) {
  final tamano = 8 + contenido.length;
  if (tamano > 0xFFFFFFFF) {
    throw EtiquetasException('Caja $tipo demasiado grande.');
  }
  return Uint8List(tamano)
    ..setAll(0, _entero32(tamano))
    ..setAll(4, latin1.encode(tipo))
    ..setAll(8, contenido);
}

/// Caja de relleno de [tamano] bytes (todo ceros).
Uint8List _relleno(int tamano) => Uint8List(tamano)
  ..setAll(0, _entero32(tamano))
  ..setAll(4, ascii.encode('free'));

List<int> _entero32(int n) => [
  n >> 24 & 0xFF,
  n >> 16 & 0xFF,
  n >> 8 & 0xFF,
  n & 0xFF,
];
