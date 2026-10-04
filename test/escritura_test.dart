import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:videoteca/datos/base_datos.dart';
import 'package:videoteca/disco/caratula_mp4.dart';
import 'package:videoteca/disco/escritor.dart';
import 'package:videoteca/disco/etiquetas_mp4.dart';

import 'lectura_test.dart' show caja;

// Pruebas de la escritura con archivos MP4 mínimos fabricados aquí (no hace
// falta Windows ni el disco D:). Con películas reales se prueba con
// `dart run tool/probar_escritura.dart`.

final _video = List.generate(4000, (i) => i * 7 % 251);

/// ftyp + moov (con [udta], si se da) + relleno de [relleno] bytes + mdat.
Uint8List mp4({List<int>? udta, int relleno = 0, bool moovAlFinal = false}) {
  final moov = caja('moov', [
    ...caja('mvhd', List.filled(100, 0)),
    ...caja('trak', List.filled(50, 3)),
    if (udta != null) ...caja('udta', udta),
  ]);
  final free = relleno > 0
      ? caja('free', List.filled(relleno - 8, 0))
      : <int>[];
  final mdat = caja('mdat', _video);
  return Uint8List.fromList([
    ...caja('ftyp', 'isom'.codeUnits),
    if (moovAlFinal) ...[
      ...mdat,
      ...moov,
      ...free,
    ] else ...[
      ...moov,
      ...free,
      ...mdat,
    ],
  ]);
}

/// udta con meta › ilst (un título y una carátula) y una caja Xtra.
List<int> udtaConDatos() => [
  ...caja('meta', [
    0,
    0,
    0,
    0,
    ...caja('hdlr', List.filled(25, 0)),
    ...caja('ilst', [
      ...caja(
        '©nam',
        caja('data', [0, 0, 0, 1, 0, 0, 0, 0, ...utf8.encode('Título')]),
      ),
      ...caja('gnre', caja('data', [0, 0, 0, 0, 0, 0, 0, 0, 0, 8])),
      ...caja('covr', caja('data', [0, 0, 0, 13, 0, 0, 0, 0, ..._jpeg])),
    ]),
  ]),
];

const _jpeg = [0xFF, 0xD8, 0xFF, 0xE0, 1, 2, 3, 0xFF, 0xD9];

// ── Lectura para comprobar (en la app lo lee Windows) ───────────────────

typedef _Caja = (String, int, int); // tipo, inicio del contenido, fin

List<_Caja> _hijas(Uint8List d, int desde, int hasta) {
  final b = ByteData.sublistView(d);
  final lista = <_Caja>[];
  var pos = desde;
  while (pos < hasta) {
    var tam = b.getUint32(pos);
    if (tam == 0) tam = hasta - pos;
    lista.add((latin1.decode(d.sublist(pos + 4, pos + 8)), pos + 8, pos + tam));
    pos += tam;
  }
  return lista;
}

_Caja? _buscar(Uint8List d, List<String> camino) {
  var (desde, hasta) = (0, d.length);
  _Caja? actual;
  for (final tipo in camino) {
    final hijas = _hijas(d, desde, hasta);
    actual = hijas.where((c) => c.$1 == tipo).firstOrNull;
    if (actual == null) return null;
    desde = actual.$2 + (tipo == 'meta' ? 4 : 0);
    hasta = actual.$3;
  }
  return actual;
}

/// Texto de un dato de ilst.
String? textoIlst(Uint8List d, String tipo) {
  final c = _buscar(d, ['moov', 'udta', 'meta', 'ilst', tipo, 'data']);
  return c == null ? null : utf8.decode(d.sublist(c.$2 + 8, c.$3));
}

/// Entradas de Xtra: nombre → valores (textos o números).
Map<String, List<Object>> xtra(Uint8List d) {
  final c = _buscar(d, ['moov', 'udta', 'Xtra']);
  if (c == null) return {};
  final b = ByteData.sublistView(d);
  final salida = <String, List<Object>>{};
  var pos = c.$2;
  while (pos < c.$3) {
    final tam = b.getUint32(pos);
    final largo = b.getUint32(pos + 4);
    final nombre = latin1.decode(d.sublist(pos + 8, pos + 8 + largo));
    var p = pos + 8 + largo;
    final n = b.getUint32(p);
    p += 4;
    final valores = <Object>[];
    for (var i = 0; i < n; i++) {
      final vt = b.getUint32(p);
      final tipo = b.getUint16(p + 4);
      final datos = d.sublist(p + 6, p + vt);
      if (tipo == 8) {
        final u = <int>[
          for (var k = 0; k + 1 < datos.length; k += 2)
            datos[k] | datos[k + 1] << 8,
        ];
        expect(u.last, 0, reason: 'los textos de Xtra terminan en cero');
        valores.add(String.fromCharCodes(u.sublist(0, u.length - 1)));
      } else {
        valores.add(ByteData.sublistView(datos).getUint64(0, Endian.little));
      }
      p += vt;
    }
    salida[nombre] = valores;
    pos += tam;
  }
  return salida;
}

/// Tipos de las cajas de primer nivel, comprobando que llenan el archivo.
List<String> principales(Uint8List d) => [
  for (final c in _hijas(d, 0, d.length)) c.$1,
];

/// Dónde está el contenido del vídeo, y que sigue intacto.
void videoIntacto(Uint8List d, {int? enLaPosicion}) {
  final mdat = _buscar(d, ['mdat'])!;
  if (enLaPosicion != null) expect(mdat.$2, enLaPosicion);
  expect(d.sublist(mdat.$2, mdat.$3), _video);
}

void main() {
  late Directory temporal;
  late String ruta;
  setUp(() {
    temporal = Directory.systemTemp.createTempSync('videoteca');
    ruta = '${temporal.path}${Platform.pathSeparator}peli.mp4';
  });
  tearDown(() => temporal.deleteSync(recursive: true));

  Uint8List leer() => File(ruta).readAsBytesSync();

  group('Escribir etiquetas', () {
    test(
      'cabe en el relleno: el vídeo no se mueve y el archivo mide lo mismo',
      () {
        final original = mp4(udta: udtaConDatos(), relleno: 2000);
        File(ruta).writeAsBytesSync(original);
        final mdatAntes = _buscar(original, ['mdat'])!.$2;
        final largo = 'Una sinopsis muy larga. ' * 30; // más de 255 letras

        escribirEtiquetasMp4(
          ruta,
          ilst: {'©cmt': largo, 'trkn': 3},
          xtra: {
            'WM/Director': ['Directora Uno'],
            'WM/SharedUserRating': 75,
            'WM/Category': ['Tema uno', 'Tema dos'],
          },
        );

        final d = leer();
        expect(d.length, original.length);
        expect(principales(d), ['ftyp', 'moov', 'free', 'mdat']);
        videoIntacto(d, enLaPosicion: mdatAntes);
        expect(textoIlst(d, '©cmt'), largo);
        expect(textoIlst(d, '©nam'), 'Título', reason: 'lo demás no cambia');
        expect(leerCaratulaMp4(ruta), _jpeg);
        expect(xtra(d), {
          'WM/Director': ['Directora Uno'],
          'WM/SharedUserRating': [75],
          'WM/Category': ['Tema uno', 'Tema dos'],
        });
        final trkn = _buscar(d, [
          'moov',
          'udta',
          'meta',
          'ilst',
          'trkn',
          'data',
        ])!;
        expect(d.sublist(trkn.$2, trkn.$3), [
          0,
          0,
          0,
          0,
          0,
          0,
          0,
          0,
          0,
          0,
          0,
          3,
          0,
          0,
          0,
          0,
        ]);
      },
    );

    test('cambiar, quitar y el género en texto sustituye al numérico', () {
      File(ruta).writeAsBytesSync(mp4(udta: udtaConDatos(), relleno: 2000));
      escribirEtiquetasMp4(
        ruta,
        xtra: {
          'WM/Writer': ['A'],
          'WM/Period': ['P'],
        },
      );
      escribirEtiquetasMp4(
        ruta,
        ilst: {'©nam': 'Otro título', '©gen': 'Drama', 'covr': null},
        xtra: {
          'WM/Writer': null,
          'WM/Period': ['Premio'],
        },
      );
      final d = leer();
      expect(textoIlst(d, '©nam'), 'Otro título');
      expect(textoIlst(d, '©gen'), 'Drama');
      expect(_buscar(d, ['moov', 'udta', 'meta', 'ilst', 'gnre']), isNull);
      expect(leerCaratulaMp4(ruta), isNull);
      expect(xtra(d), {
        'WM/Period': ['Premio'],
      });
    });

    test(
      'sin sitio detrás: la moov pasa al final y el vídeo sigue en su sitio',
      () {
        final original = mp4(udta: udtaConDatos()); // sin relleno
        File(ruta).writeAsBytesSync(original);
        final mdatAntes = _buscar(original, ['mdat'])!.$2;

        escribirEtiquetasMp4(ruta, ilst: {'©cmt': 'Algo más largo que antes'});

        final d = leer();
        expect(principales(d), ['ftyp', 'free', 'mdat', 'moov']);
        videoIntacto(d, enLaPosicion: mdatAntes);
        expect(textoIlst(d, '©cmt'), 'Algo más largo que antes');
        expect(leerCaratulaMp4(ruta), _jpeg);

        // Y la siguiente vez se escribe al final, sin crecer de más.
        escribirEtiquetasMp4(ruta, ilst: {'©cmt': 'Corto'});
        expect(principales(leer()), ['ftyp', 'free', 'mdat', 'moov']);
        expect(textoIlst(leer(), '©cmt'), 'Corto');
      },
    );

    test('una caja final «hasta el final del archivo» recibe su tamaño', () {
      final base = mp4(udta: udtaConDatos());
      // Caja mdat vacía con tamaño 0 al final, como en algunos archivos.
      File(ruta).writeAsBytesSync([...base, 0, 0, 0, 0, ...'mdat'.codeUnits]);
      escribirEtiquetasMp4(ruta, ilst: {'©cmt': 'Texto nuevo'});
      final d = leer();
      expect(principales(d), ['ftyp', 'free', 'mdat', 'mdat', 'moov']);
      expect(textoIlst(d, '©cmt'), 'Texto nuevo');
    });

    test('moov al final del archivo: se reescribe allí', () {
      File(ruta).writeAsBytesSync(mp4(udta: udtaConDatos(), moovAlFinal: true));
      escribirEtiquetasMp4(ruta, ilst: {'©cmt': 'x' * 1000});
      var d = leer();
      expect(principales(d), ['ftyp', 'mdat', 'moov']);
      videoIntacto(d);
      escribirEtiquetasMp4(ruta, ilst: {'©cmt': null});
      d = leer();
      expect(textoIlst(d, '©cmt'), isNull);
      expect(principales(d), ['ftyp', 'mdat', 'moov']);
    });

    test('sin datos previos: crea udta, meta (con hdlr) e ilst', () {
      File(ruta).writeAsBytesSync(mp4(relleno: 1000));
      escribirEtiquetasMp4(
        ruta,
        ilst: {'©nam': 'Nueva', 'covr': Uint8List.fromList(_jpeg)},
        xtra: {
          'WM/SubTitle': ['Original'],
        },
      );
      final d = leer();
      expect(textoIlst(d, '©nam'), 'Nueva');
      expect(leerCaratulaMp4(ruta), _jpeg);
      expect(xtra(d), {
        'WM/SubTitle': ['Original'],
      });
      final hdlr = _buscar(d, ['moov', 'udta', 'meta', 'hdlr'])!;
      expect(latin1.decode(d.sublist(hdlr.$2 + 8, hdlr.$2 + 16)), 'mdirappl');
    });

    test('restaurar deja el archivo idéntico, byte a byte', () {
      for (final original in [
        mp4(udta: udtaConDatos(), relleno: 2000), // en su sitio
        mp4(udta: udtaConDatos()), // pasa al final
        mp4(udta: udtaConDatos(), moovAlFinal: true), // ya al final
      ]) {
        File(ruta).writeAsBytesSync(original);
        final copia = escribirEtiquetasMp4(
          ruta,
          ilst: {'©cmt': 'y' * 500},
          xtra: {
            'WM/Director': ['D'],
          },
        );
        expect(leer(), isNot(original));
        copia.restaurar(ruta);
        expect(leer(), original);
      }
    });

    test('un archivo que no es MP4 no se toca', () {
      final basura = Uint8List.fromList(List.generate(300, (i) => i % 256));
      File(ruta).writeAsBytesSync(basura);
      expect(
        () => escribirEtiquetasMp4(ruta, ilst: {'©cmt': 'x'}),
        throwsA(isA<EtiquetasException>()),
      );
      expect(leer(), basura);
    });
  });

  group('Campos', () {
    test('cada campo va a la caja donde lo guarda Windows', () {
      expect(Campo.sinopsis.caja, '©cmt');
      expect(Campo.sinopsis.enXtra, isFalse);
      expect(Campo.direccion.caja, 'WM/Director');
      expect(Campo.direccion.enXtra, isTrue);
    });

    test('valores que se guardan', () {
      expect(valorCaja(Campo.estrellas, '4'), 75);
      expect(valorCaja(Campo.estrellas, '0'), isNull);
      expect(valorCaja(Campo.anio, '1995'), '1995');
      expect(valorCaja(Campo.numeroSaga, '2'), 2);
      expect(valorCaja(Campo.temas, 'Uno; Dos;'), ['Uno', 'Dos']);
      expect(valorCaja(Campo.direccion, 'A, B'), ['A, B']);
      expect(valorCaja(Campo.reparto, 'A, B'), 'A, B');
      expect(valorCaja(Campo.pais, '  '), isNull);
    });

    test('validación', () {
      expect(validarCampo(Campo.titulo, ''), isNotNull);
      expect(validarCampo(Campo.anio, '20222'), isNotNull);
      expect(validarCampo(Campo.anio, '1995'), isNull);
      expect(validarCampo(Campo.reparto, 'A; B'), isNotNull);
      expect(validarCampo(Campo.temas, 'A; B'), isNull);
      expect(validarCampo(Campo.sinopsis, 'Uno; dos'), isNull);
      expect(validarCampo(Campo.enlaceImdb, 'imdb.com'), isNotNull);
      expect(validarCampo(Campo.estrellas, '6'), isNotNull);
    });
  });

  group('Registro de cambios', () {
    test(
      'se anota, se lista del más reciente al más antiguo y se deshace',
      () async {
        final bd = BaseDatos(NativeDatabase.memory());
        addTearDown(bd.close);
        for (final titulo in ['Uno', 'Dos']) {
          await bd.anotarCambio(
            CambiosCompanion.insert(
              pelicula: 1,
              ruta: r'D:\x.mp4',
              titulo: titulo,
              fecha: DateTime(2026, 10, 4),
              origen: 'Editar ficha',
              antes: '{"pais":""}',
              despues: '{"pais":"Francia"}',
            ),
          );
        }
        final lista = await bd.ultimosCambios();
        expect([for (final c in lista) c.titulo], ['Dos', 'Uno']);
        await bd.marcarDeshecho(lista.last.id, DateTime(2026, 10, 5));
        expect(
          (await bd.cambio(lista.last.id))!.deshecho,
          DateTime(2026, 10, 5),
        );
      },
    );
  });
}
