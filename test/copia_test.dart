import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:videoteca/disco/copiador.dart';

const _mb = 1024 * 1024;
const _gb = 1024 * _mb;

/// Una letra de unidad que no existe en este PC (`Q:`…).
String _letraLibre() =>
    [for (final l in 'QRSTUVWKLMNOP'.split('')) '$l:']
        .firstWhere((u) => !Directory('$u\\').existsSync());

void main() {
  late Directory temporal;
  late String origen;

  setUp(() async {
    temporal = await Directory.systemTemp.createTemp('videoteca_copia_');
    // 20 MB al azar: varios trozos de 8 MB.
    final azar = Random(23);
    final datos = Uint8List(20 * _mb + 12345);
    for (var i = 0; i < datos.length; i++) {
      datos[i] = azar.nextInt(256);
    }
    origen = '${temporal.path}\\Factory Girl (2006).mp4';
    await File(origen).writeAsBytes(datos);
    await File(origen).setLastModified(DateTime(2020, 5, 17, 10, 30));
  });

  tearDown(() => temporal.delete(recursive: true));

  String destinoEn(String carpeta) =>
      '${temporal.path}\\$carpeta\\Factory Girl (2006).mp4';

  group('Copiar', () {
    test('copia entera, igual y con la fecha de la original', () async {
      final destino = destinoEn(r'E\Películas');
      final avances = <AvanceCopia>[];
      final r = await copiarArchivo(origen, destino, alAvanzar: avances.add);
      expect(r.fin, FinCopia.hecha);
      expect(
        await File(destino).readAsBytes(),
        await File(origen).readAsBytes(),
      );
      expect(File('$destino$finalParcial').existsSync(), isFalse);
      expect(File(destino).lastModifiedSync(), File(origen).lastModifiedSync());
      // Avanza de 0 al total y termina comprobando.
      expect(avances.first.copiados, 0);
      expect(
        avances.where((a) => !a.comprobando).last.copiados,
        20 * _mb + 12345,
      );
      expect(avances.last.comprobando, isTrue);
      expect(avances.length, greaterThan(3));
    });

    test('cancelar a mitad no deja nada', () async {
      final destino = destinoEn('E');
      var cancelada = false;
      final r = await copiarArchivo(
        origen,
        destino,
        cancelada: () => cancelada,
        alAvanzar: (a) {
          if (a.copiados > 0) cancelada = true;
        },
      );
      expect(r.fin, FinCopia.cancelada);
      expect(r.restos, isNull);
      expect(File(destino).existsSync(), isFalse);
      expect(File('$destino$finalParcial').existsSync(), isFalse);
    });

    test('si ya existe, solo se reemplaza si se pide', () async {
      final destino = destinoEn('E');
      await Directory(File(destino).parent.path).create();
      await File(destino).writeAsString('la vieja');
      var r = await copiarArchivo(origen, destino);
      expect(r.fin, FinCopia.yaExiste);
      expect(await File(destino).readAsString(), 'la vieja');

      r = await copiarArchivo(origen, destino, reemplazar: true);
      expect(r.fin, FinCopia.hecha);
      expect(File(destino).lengthSync(), File(origen).lengthSync());
    });

    test('se borran los trozos a medias de copias anteriores', () async {
      final carpeta = Directory('${temporal.path}\\E')..createSync();
      final resto = File('${carpeta.path}\\Otra (1999).mp4$finalParcial')
        ..writeAsStringSync('a medias');
      final ajeno = File('${carpeta.path}\\notas.txt$finalParcial')
        ..writeAsStringSync('no es una película');
      final r = await copiarArchivo(origen, destinoEn('E'));
      expect(r.fin, FinCopia.hecha);
      expect(resto.existsSync(), isFalse);
      expect(ajeno.existsSync(), isTrue);
    });

    test('la película ya no está', () async {
      final r = await copiarArchivo(
        '${temporal.path}\\No existe (2000).mp4',
        destinoEn('E'),
      );
      expect(r.fin, FinCopia.fallo);
      expect(r.fallo, FalloCopia.origenNoEsta);
      expect(Directory('${temporal.path}\\E').existsSync(), isFalse);
    });

    test('el disco de destino no está (se ha quitado el pendrive)', () async {
      final r = await copiarArchivo(
        origen,
        '${_letraLibre()}\\Películas\\Factory Girl (2006).mp4',
      );
      expect(r.fin, FinCopia.fallo);
      expect(r.fallo, FalloCopia.destinoQuitado);
    });

    test('no se llega a la película (disco desconectado)', () async {
      final r = await copiarArchivo(
        '${_letraLibre()}\\Drama\\Factory Girl (2006).mp4',
        destinoEn('E'),
      );
      expect(r.fallo, FalloCopia.origenSinConexion);
      expect(Directory('${temporal.path}\\E').existsSync(), isFalse);
    });

    test('en otro hilo: avanza y se puede cancelar', () async {
      final destino = destinoEn('E');
      final hecha = copiarAparte(origen, destino);
      final avances = await hecha.avance.toList();
      expect((await hecha.resultado).fin, FinCopia.hecha);
      expect(avances.last.comprobando, isTrue);
      expect(File(destino).lengthSync(), File(origen).lengthSync());

      final otra = destinoEn('F');
      final cancelada = copiarAparte(origen, otra)..cancelar();
      expect((await cancelada.resultado).fin, FinCopia.cancelada);
      expect(File(otra).existsSync(), isFalse);
      expect(File('$otra$finalParcial').existsSync(), isFalse);
    });
  }, skip: !Platform.isWindows);

  group('Antes de empezar', () {
    const pendrive = Volumen(
      sistema: 'FAT32',
      libre: 20 * _gb,
      total: 32 * _gb,
    );
    const disco = Volumen(sistema: 'exFAT', libre: 5 * _gb, total: 64 * _gb);

    test('FAT32 no admite películas de más de 4 GB', () {
      expect(
        impedimentoCopia(pendrive, (4.1 * _gb).round()),
        Impedimento.formato,
      );
      expect(impedimentoCopia(pendrive, (3.9 * _gb).round()), isNull);
      expect(maximoArchivo('NTFS'), isNull);
      expect(maximoArchivo('exFAT'), isNull);
    });

    test('no cabe (con un poco de margen)', () {
      expect(impedimentoCopia(disco, 6 * _gb), Impedimento.noCabe);
      expect(impedimentoCopia(disco, 5 * _gb), Impedimento.noCabe);
      expect(impedimentoCopia(disco, 4 * _gb), isNull);
      // Si se reemplaza una que ya está, su sitio también cuenta.
      expect(impedimentoCopia(disco, 6 * _gb, existente: 2 * _gb), isNull);
      expect(hayQueBorrarAntes(disco, 6 * _gb, existente: 2 * _gb), isTrue);
      expect(hayQueBorrarAntes(disco, 2 * _gb, existente: 2 * _gb), isFalse);
    });

    test('el disco de las películas no se toca', () {
      expect(mismoDisco(r'D:\Copias', r'D:\'), isTrue);
      expect(mismoDisco(r'd:\', r'D:\Pelis'), isTrue);
      expect(mismoDisco(r'E:\Películas', r'D:\'), isFalse);
      expect(
        mismoDisco(
          r'\\ayo-pc\MULTIMEDIA\Otra',
          r'\\AYO-PC\Multimedia\Películas',
        ),
        isTrue,
      );
      expect(
        mismoDisco(r'\\AYO-PC\Otra', r'\\AYO-PC\Multimedia\Películas'),
        isFalse,
      );
      expect(mismoDisco(r'C:\Users', ''), isFalse);
    });

    test('solo lectura', () {
      const protegido = Volumen(
        sistema: 'exFAT',
        libre: 50 * _gb,
        total: 64 * _gb,
        soloLectura: true,
      );
      expect(impedimentoCopia(protegido, _gb), Impedimento.soloLectura);
    });

    test('nombres de las unidades', () {
      const usb = Unidad(
        letra: 'E:',
        conexion: Conexion.usb,
        extraible: true,
        sistema: 'exFAT',
        libre: 0,
        total: 1,
      );
      expect(usb.nombre, 'Pendrive (E:)');
      expect(usb.tipo, 'Pendrive USB');
      expect(usb.carpeta, r'E:\Películas');
      const kingston = Unidad(
        letra: 'F:',
        etiqueta: 'KINGSTON',
        conexion: Conexion.usb,
        sistema: 'NTFS',
        libre: 0,
        total: 1,
      );
      expect(kingston.nombre, 'KINGSTON (F:)');
      expect(kingston.tipo, 'Disco USB');
    });
  });

  test('textos de tamaños y tiempos', () {
    expect(textoBytes((4.1 * _gb).round()), '4,1 GB');
    expect(textoBytes(620 * _mb), '620 MB');
    expect(textoBytes(365 * _gb), '365 GB');
    expect(textoBytes(5719 * _gb), '5,6 TB');
    expect(textoBytes(38 * _mb), '38 MB');
    expect(textoRestante(const Duration(seconds: 4)), 'unos segundos');
    expect(textoRestante(const Duration(seconds: 38)), 'unos 40 s');
    expect(textoRestante(const Duration(seconds: 170)), 'unos 3 min');
    expect(textoRestante(const Duration(minutes: 65)), '1 h 5 min');
  });

  test('unidades de este PC', () {
    final unidades = unidadesDeEstePc();
    // Al menos el disco de Windows, con espacio y formato.
    final c = unidades.firstWhere((u) => u.letra == 'C:');
    expect(c.conexion, Conexion.interna);
    expect(c.total, greaterThan(0));
    expect(c.sistema, isNotEmpty);
    for (final u in unidades) {
      expect(u.total, greaterThan(0), reason: u.letra);
    }
    final v = volumenDe(Directory.systemTemp.path);
    expect(v, isNotNull);
    expect(v!.libre, greaterThan(0));
    expect(v.sistema, isNotEmpty);
  }, skip: !Platform.isWindows);
}
