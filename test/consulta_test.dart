import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:videoteca/datos/base_datos.dart';
import 'package:videoteca/datos/carpetas_app.dart';
import 'package:videoteca/datos/sesion.dart';
import 'package:videoteca/tablon/cifrado.dart';
import 'package:videoteca/tablon/copia_local.dart';
import 'package:videoteca/tablon/github.dart';
import 'package:videoteca/tablon/lector.dart';
import 'package:videoteca/tablon/publicador.dart';

import 'ayuda/github_falso.dart';

void main() {
  // Aquí hay dos bases de datos a la vez a propósito (la del PC y la del
  // móvil).
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  // Parámetros pequeños para que los tests vayan rápido.
  final parametros = ParametrosLlave(
    sal: Uint8List.fromList(List.filled(16, 7)),
    memoria: 64,
    iteraciones: 1,
  );

  group('Copia del modo consulta', () {
    late Directory temporal;
    late CarpetasApp carpetasPc, carpetasMovil;
    late BaseDatos pc, movil;
    late GitHubFalso falso;
    late LlaveTablon llave;

    setUp(() async {
      temporal = Directory.systemTemp.createTempSync('consulta');
      carpetasPc = CarpetasApp.preparar(temporal.path);
      carpetasMovil = CarpetasApp.consulta(temporal.path);
      pc = BaseDatos(NativeDatabase.memory());
      movil = BaseDatos(NativeDatabase.memory());
      falso = GitHubFalso();
      llave = await derivarLlave('común', parametros);
      final jpeg = img.encodeJpg(img.Image(width: 240, height: 343));
      for (final (id, titulo) in [(1, 'Uno'), (2, 'Dos'), (150, 'Tres')]) {
        await pc.guardarPelicula(
          PeliculasCompanion.insert(
            id: Value(id),
            ruta: 'D:\\Drama\\Drama\\$titulo (2000).mp4',
            titulo: titulo,
            anio: const Value(2000),
            grupo: const Value('Drama'),
            generoCarpeta: const Value('Drama'),
            direccion: const Value('Alguien'),
            estrellas: const Value(4),
            tieneCaratula: Value(id != 2),
            tieneMiniatura: Value(id != 2),
            anadida: DateTime(2020, 5, 6),
            modificado: DateTime(2020),
            escaneada: DateTime(2020),
          ),
        );
        if (id != 2) File(carpetasPc.miniatura(id)).writeAsBytesSync(jpeg);
      }
    });

    tearDown(() async {
      await pc.close();
      await movil.close();
      temporal.deleteSync(recursive: true);
    });

    var version = 0;
    Future<void> publicar({String red = ''}) async {
      final r = await publicarTablon(
        github: GitHub('yo/tablon', 'llave', cliente: falso.cliente),
        llave: llave,
        parametros: parametros,
        filas: await pc.todasLasPeliculas(),
        raiz: 'D:\\',
        carpetas: carpetasPc,
        versionAnterior: version,
        red: red,
      );
      version = r.version;
    }

    Future<ResultadoDescarga> descargar({
      LlaveTablon? otra,
      String repositorio = 'yo/tablon',
    }) => actualizarCopia(
      lector: LectorTablon(repositorio, cliente: falso.cliente),
      llave: otra ?? llave,
      parametros: parametros,
      bd: movil,
      carpetas: carpetasMovil,
    );

    test('la primera vez lo descarga todo, descifrado', () async {
      version = 0;
      await publicar();
      final r = await descargar();
      expect(r.primera, isTrue);
      expect(r.alDia, isFalse);
      expect(r.estado.version, 1);
      expect(r.estado.peliculas, 3);
      // tablon.json, índice, 2 paquetes de fichas y 2 de carátulas.
      expect(falso.descargas, 6);

      final filas = await movil.todasLasPeliculas();
      expect(filas.map((f) => f.id), unorderedEquals([1, 2, 150]));
      final uno = filas.firstWhere((f) => f.id == 1);
      expect(uno.titulo, 'Uno');
      expect(uno.direccion, 'Alguien');
      expect(uno.estrellas, 4);
      expect(uno.ruta, r'Drama\Drama\Uno (2000).mp4');
      expect(uno.anadida, DateTime(2020, 5, 6));
      expect(uno.tieneMiniatura, isTrue);
      expect(filas.firstWhere((f) => f.id == 2).tieneMiniatura, isFalse);

      // Carátulas en WebP, en la carpeta del modo consulta.
      expect(carpetasMovil.miniatura(1), endsWith('1.webp'));
      final webp = File(carpetasMovil.miniatura(1)).readAsBytesSync();
      expect(img.decodeWebP(webp), isNotNull);
      expect(File(carpetasMovil.miniatura(2)).existsSync(), isFalse);
      expect(File(carpetasMovil.miniatura(150)).existsSync(), isTrue);
    });

    test('sin cambios no baja nada; con un cambio, solo su paquete', () async {
      version = 0;
      await publicar();
      await descargar();
      final antes = falso.descargas;

      final igual = await descargar();
      expect(igual.alDia, isTrue);
      expect(falso.descargas, antes);

      // En el PC se cambia una ficha y llega una película nueva al grupo 000.
      await (pc.update(pc.peliculas)..where((p) => p.id.equals(150))).write(
        const PeliculasCompanion(pais: Value('Francia')),
      );
      await pc.guardarPelicula(
        PeliculasCompanion.insert(
          id: const Value(3),
          ruta: r'D:\Drama\Drama\Cuatro (2001).mp4',
          titulo: 'Cuatro',
          anadida: DateTime(2021),
          modificado: DateTime(2021),
          escaneada: DateTime(2021),
        ),
      );
      await publicar();
      final r = await descargar();
      expect(r.estado.version, 2);
      expect(r.primera, isFalse);
      expect(r.nuevas, 1);
      expect(r.cambiadas, 1);
      expect(r.quitadas, 0);
      expect(r.caratulasCambiadas, isFalse);
      // tablon.json, índice y los dos paquetes de fichas (000 y 001); las
      // carátulas no han cambiado.
      expect(falso.descargas, antes + 4);
      final filas = await movil.todasLasPeliculas();
      expect(filas, hasLength(4));
      expect(filas.firstWhere((f) => f.id == 150).pais, 'Francia');
    });

    test(
      'una ruta que pasa a otra película de otro paquete (issue #15)',
      () async {
        version = 0;
        await publicar();
        await descargar();

        // En el PC se quita «Tres» (la 150, paquete 001) y «Uno» (la 1,
        // paquete 000) se mueve a su sitio: el paquete 000 trae una ruta que en
        // la copia todavía es de la 150.
        final ruta = r'D:\Drama\Drama\Tres (2000).mp4';
        await pc.borrarPeliculas([150]);
        await (pc.update(pc.peliculas)..where((p) => p.id.equals(1))).write(
          PeliculasCompanion(ruta: Value(ruta)),
        );
        await publicar();
        final r = await descargar();
        expect(r.estado.version, 2);
        expect(r.quitadas, 1);
        final filas = await movil.todasLasPeliculas();
        expect(filas.map((f) => f.id), unorderedEquals([1, 2]));
        expect(
          filas.firstWhere((f) => f.id == 1).ruta,
          r'Drama\Drama\Tres (2000).mp4',
        );

        // Y al revés: la película del paquete de después se queda la ruta de
        // la de antes (se cambian de sitio).
        await pc.guardarPelicula(
          PeliculasCompanion.insert(
            id: const Value(150),
            ruta: r'D:\Drama\Drama\Uno (2000).mp4',
            titulo: 'Tres',
            anadida: DateTime(2021),
            modificado: DateTime(2021),
            escaneada: DateTime(2021),
          ),
        );
        await publicar();
        await descargar();
        await (pc.update(pc.peliculas)..where((p) => p.id.equals(150))).write(
          PeliculasCompanion(ruta: Value('$ruta.tmp')),
        );
        await (pc.update(pc.peliculas)..where((p) => p.id.equals(1))).write(
          const PeliculasCompanion(
            ruta: Value(r'D:\Drama\Drama\Uno (2000).mp4'),
          ),
        );
        await (pc.update(pc.peliculas)..where((p) => p.id.equals(150))).write(
          PeliculasCompanion(ruta: Value(ruta)),
        );
        await publicar();
        await descargar();
        final cambiadas = await movil.todasLasPeliculas();
        expect(
          {for (final f in cambiadas) f.id: f.ruta},
          {
            1: r'Drama\Drama\Uno (2000).mp4',
            2: r'Drama\Drama\Dos (2000).mp4',
            150: r'Drama\Drama\Tres (2000).mp4',
          },
        );
      },
    );

    test('la ruta de red del PC llega con el catálogo', () async {
      version = 0;
      await publicar(red: r'\\CASA-PC\Pelis\Películas');
      final r = await descargar();
      expect(r.estado.red, r'\\CASA-PC\Pelis\Películas');
      // Se guarda con la copia.
      expect(
        EstadoCopia.deAjustes(await movil.todosLosAjustes()).red,
        r'\\CASA-PC\Pelis\Películas',
      );
      // Si el administrador la quita, también se quita aquí.
      await publicar();
      expect((await descargar()).estado.red, '');
    });

    test(
      'una copia de la versión 1.0 (sin la ruta) lee el índice una vez',
      () async {
        version = 0;
        await publicar(red: r'\\CASA-PC\Pelis');
        await descargar();
        // Como la dejaba la 1.0: sin «red».
        final copia = EstadoCopia.deAjustes(await movil.todosLosAjustes());
        final json = copia.toJson()..remove('red');
        await movil.guardarAjuste(AjusteConsulta.copia, jsonEncode(json));
        expect(
          EstadoCopia.deAjustes(await movil.todosLosAjustes()).red,
          isNull,
        );

        final antes = falso.descargas;
        final r = await descargar();
        expect(r.alDia, isTrue);
        expect(r.estado.red, r'\\CASA-PC\Pelis');
        expect(falso.descargas, antes + 1); // solo el índice
        // La siguiente vez ya no hace falta.
        await descargar();
        expect(falso.descargas, antes + 1);
      },
    );

    test('las películas quitadas en el PC desaparecen de la copia', () async {
      version = 0;
      await publicar();
      await descargar();
      await pc.borrarPeliculas([150]);
      await publicar();
      final r = await descargar();
      expect(r.quitadas, 1);
      final filas = await movil.todasLasPeliculas();
      expect(filas.map((f) => f.id), unorderedEquals([1, 2]));
      expect(File(carpetasMovil.miniatura(150)).existsSync(), isFalse);
    });

    test('si se corta a medias, la siguiente vez sigue donde iba', () async {
      version = 0;
      await publicar();
      falso.cortarTras = 3; // tablon.json, índice y un paquete
      await expectLater(
        descargar(),
        throwsA(
          isA<TablonException>().having((e) => e.sinInternet, 'sin', true),
        ),
      );
      // Lo bajado se queda: ya se pueden ver esas fichas.
      expect(await movil.todasLasPeliculas(), isNotEmpty);
      falso
        ..cortarTras = null
        ..descargas = 0;
      final r = await descargar();
      expect(r.estado.version, 1);
      // tablon.json y el índice otra vez y los 3 paquetes que faltaban.
      expect(falso.descargas, 5);
      expect(await movil.todasLasPeliculas(), hasLength(3));
    });

    test('si cambia la contraseña común hay que volver a entrar', () async {
      version = 0;
      await publicar();
      await descargar();
      // El administrador cambia la contraseña (parámetros nuevos).
      final nuevos = ParametrosLlave(
        sal: Uint8List.fromList(List.filled(16, 9)),
        memoria: 64,
        iteraciones: 1,
      );
      final nueva = await derivarLlave('otra', nuevos);
      await publicarTablon(
        github: GitHub('yo/tablon', 'llave', cliente: falso.cliente),
        llave: nueva,
        parametros: nuevos,
        filas: await pc.todasLasPeliculas(),
        raiz: 'D:\\',
        carpetas: carpetasPc,
        versionAnterior: 1,
      );
      await expectLater(descargar(), throwsA(isA<ContrasenaCambiada>()));
      // La copia se sigue pudiendo ver.
      expect(await movil.todasLasPeliculas(), hasLength(3));
    });

    test('comprobar la contraseña al entrar', () async {
      version = 0;
      await publicar();
      final lector = LectorTablon('yo/tablon', cliente: falso.cliente);
      final r = await comprobarContrasena(lector, 'común');
      expect(r.indice.version, 1);
      expect(r.llave.bytes, llave.bytes);
      expect(
        () => comprobarContrasena(lector, 'mala'),
        throwsA(isA<ContrasenaIncorrecta>()),
      );
    });

    test('con otro tablón se empieza de cero', () async {
      version = 0;
      await publicar();
      await descargar();
      await movil.guardarPelicula(
        PeliculasCompanion.insert(
          id: const Value(99),
          ruta: 'otra',
          titulo: 'De otro tablón',
          anadida: DateTime(2020),
          modificado: DateTime(2020),
          escaneada: DateTime(2020),
        ),
      );
      // Se apunta como si la copia fuera de otro repositorio.
      await movil.guardarAjuste(
        AjusteConsulta.copia,
        '{"repositorio": "otro/tablon", "commit": "x"}',
      );
      final r = await descargar();
      expect(r.primera, isTrue);
      expect(
        (await movil.todasLasPeliculas()).map((f) => f.id),
        unorderedEquals([1, 2, 150]),
      );
    });
  });

  group('Sesión', () {
    test('nombre del tablón: «usuario/nombre» o el enlace', () {
      expect(nombreTablon('Ana/Tablon'), 'Ana/Tablon');
      expect(
        nombreTablon(' https://github.com/Ana/Mi_Tablon/ '),
        'Ana/Mi_Tablon',
      );
      expect(nombreTablon('github.com/Ana/Tablon.git'), 'Ana/Tablon');
      expect(nombreTablon('Ana'), isNull);
      expect(nombreTablon('Ana/Tab lon'), isNull);
      expect(nombreTablon('a/b/c'), isNull);
    });

    test(
      'se guarda y se lee; la contraseña de administrador se comprueba',
      () async {
        final carpeta = Directory.systemTemp.createTempSync('sesion');
        addTearDown(() => carpeta.deleteSync(recursive: true));
        expect(Sesion.leer(carpeta.path).modo, isNull);

        final admin = await ContrasenaAdmin.crear('secreta1');
        Sesion(
          modo: ModoApp.administrador,
          contrasenaAdmin: admin,
          tablon: 'Ana/Tablon',
        ).guardar(carpeta.path);
        final texto = File('${carpeta.path}/sesion.json').readAsStringSync();
        expect(texto, isNot(contains('secreta1')));

        final leida = Sesion.leer(carpeta.path);
        expect(leida.modo, ModoApp.administrador);
        expect(leida.tablon, 'Ana/Tablon');
        expect(await leida.contrasenaAdmin!.comprobar('secreta1'), isTrue);
        expect(await leida.contrasenaAdmin!.comprobar('secreta2'), isFalse);

        // Un archivo dañado no impide arrancar: hay que volver a entrar.
        File('${carpeta.path}/sesion.json').writeAsStringSync('{roto');
        expect(Sesion.leer(carpeta.path).modo, isNull);
      },
    );
  });
}
