import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:videoteca/disco/red.dart';
import 'package:videoteca/disco/red_windows.dart';

void main() {
  group('Rutas', () {
    test('se limpian como se escriben o se pegan', () {
      expect(
        limpiarRutaRed(r'  "\\AYO-PC\Multimedia\Películas\"  '),
        r'\\AYO-PC\Multimedia\Películas',
      );
      expect(
        limpiarRutaRed('//casa-pc/pelis//Películas/'),
        r'\\casa-pc\pelis\Películas',
      );
      expect(limpiarRutaRed('z:'), r'Z:\');
      expect(limpiarRutaRed(r'z:\Pelis\'), r'Z:\Pelis');
      // Hace falta el PC y la carpeta compartida.
      expect(limpiarRutaRed(r'\\AYO-PC'), isNull);
      expect(limpiarRutaRed('Películas'), isNull);
      expect(limpiarRutaRed(''), isNull);
    });

    test('ruta de una película por la red', () {
      const relativa = r'Drama y Musical\Drama\Factory Girl (2006).mp4';
      expect(
        unirRuta(r'\\AYO-PC\Multimedia\Películas', relativa),
        r'\\AYO-PC\Multimedia\Películas\Drama y Musical\Drama\Factory Girl (2006).mp4',
      );
      expect(unirRuta(r'Z:\', relativa), 'Z:\\$relativa');
      expect(
        unirRuta(r'Z:\Pelis', '/Comedias/X.mp4'),
        r'Z:\Pelis\Comedias\X.mp4',
      );
    });

    test('ruta dentro de la colección', () {
      expect(
        rutaRelativa(r'D:\Comedias\Comedia\X.mp4', r'D:\'),
        r'Comedias\Comedia\X.mp4',
      );
      expect(rutaRelativa(r'd:\Comedias\X.mp4', r'D:\'), r'Comedias\X.mp4');
      expect(
        rutaRelativa(r'D:\Pelis\Comedias\X.mp4', r'D:\Pelis'),
        r'Comedias\X.mp4',
      );
      expect(rutaRelativa(r'E:\Otra\X.mp4', r'D:\'), isNull);
      expect(rutaRelativa(r'D:\X.mp4', ''), isNull);
    });

    test('películas de prueba repartidas por toda la colección', () {
      final todas = [
        for (final grupo in ['Comedias', 'Drama', 'Terror'])
          for (var i = 0; i < 100; i++) '$grupo\\G\\Película $i.mp4',
      ];
      final muestra = muestraPeliculas(todas.reversed);
      expect(muestra, hasLength(peliculasDePrueba));
      expect(muestra.toSet(), hasLength(peliculasDePrueba));
      for (final grupo in ['Comedias', 'Drama', 'Terror']) {
        expect(muestra.where((m) => m.startsWith(grupo)), isNotEmpty);
      }
      // Siempre las mismas.
      expect(muestraPeliculas(todas), muestra);
      expect(muestraPeliculas(['a', 'b']), ['a', 'b']);
    });

    test('a qué PC lleva una ruta', () {
      expect(equipoDeRuta(r'\\AYO-PC\Multimedia\Películas'), 'AYO-PC');
      expect(equipoDeRuta(r'\\192.168.1.20\Pelis'), '192.168.1.20');
    });

    test('qué quiere decir cada error de Windows', () {
      expect(estadoDeError(5), EstadoRed.contrasena); // acceso denegado
      expect(estadoDeError(1326), EstadoRed.contrasena); // contraseña mala
      expect(estadoDeError(1272), EstadoRed.contrasena); // invitado bloqueado
      expect(estadoDeError(67), EstadoRed.noEncontrada); // no hay esa carpeta
      expect(estadoDeError(3), EstadoRed.noEncontrada);
      expect(estadoDeError(53), EstadoRed.sinConexion); // no se encuentra el PC
      expect(estadoDeError(null), EstadoRed.sinConexion);
    });
  });

  group('Usuario y contraseña', () {
    test('la carpeta compartida de una ruta', () {
      expect(
        carpetaCompartidaDe(r'\\AYO-PC\Multimedia\Películas\Drama'),
        r'\\AYO-PC\Multimedia',
      );
      expect(
        carpetaCompartidaDe(r'\\AYO-PC\Multimedia'),
        r'\\AYO-PC\Multimedia',
      );
      expect(carpetaCompartidaDe(r'\\AYO-PC'), isNull);
      expect(carpetaCompartidaDe(r'Z:\Películas'), isNull);
    });

    test('el usuario lleva delante el PC, salvo que ya lo lleve', () {
      expect(usuarioDeRed(' Ayoze ', 'AYO-PC'), r'AYO-PC\Ayoze');
      expect(usuarioDeRed(r'OTRO\Ayoze', 'AYO-PC'), r'OTRO\Ayoze');
      // Cuenta de Microsoft: su correo, tal cual.
      expect(usuarioDeRed('ayoze@outlook.es', 'AYO-PC'), 'ayoze@outlook.es');
    });

    test('qué quiere decir lo que contesta Windows', () {
      expect(resultadoDeConectar(0), ResultadoCredenciales.hecho);
      expect(resultadoDeConectar(1326), ResultadoCredenciales.incorrectos);
      expect(resultadoDeConectar(86), ResultadoCredenciales.incorrectos);
      // Cuenta sin contraseña (Windows no deja entrar con ella por la red).
      expect(
        resultadoDeConectar(1327),
        ResultadoCredenciales.cuentaSinContrasena,
      );
      expect(resultadoDeConectar(1331), ResultadoCredenciales.cuentaNoValida);
      // Usuario que no existe allí: lo trata como invitado y aquí se bloquea.
      expect(resultadoDeConectar(1272), ResultadoCredenciales.noExiste);
      expect(resultadoDeConectar(5), ResultadoCredenciales.sinPermiso);
      expect(resultadoDeConectar(1219), ResultadoCredenciales.otroUsuario);
      expect(resultadoDeConectar(53), ResultadoCredenciales.sinConexion);
      expect(resultadoDeConectar(67), ResultadoCredenciales.noEsRed);
      expect(resultadoDeConectar(31), ResultadoCredenciales.error);
    });

    test('de verdad: un PC que no contesta no hace esperar', () async {
      final reloj = Stopwatch()..start();
      expect(
        await entrarConUsuario(r'\\NOEXISTE-VIDEOTECA\Pelis', 'yo', 'x'),
        ResultadoCredenciales.sinConexion,
      );
      expect(reloj.elapsed, lessThan(const Duration(seconds: 6)));
      expect(
        await entrarConUsuario(r'C:\Pelis', 'yo', 'x'),
        ResultadoCredenciales.noEsRed,
      );
    }, skip: Platform.isWindows ? false : 'Solo en Windows');

    test('de verdad: se guardan en Windows y se pueden borrar', () {
      // Un «PC» inventado, para no tocar nada de verdad.
      final equipo =
          'VIDEOTECA-PRUEBA-${DateTime.now().microsecondsSinceEpoch}';
      addTearDown(() => borrarCredencial(equipo));
      expect(usuarioGuardado(equipo), isNull);
      expect(guardarCredencial(equipo, '$equipo\\Ayoze', 'secreta'), isTrue);
      expect(usuarioGuardado(equipo), '$equipo\\Ayoze');
      // Volver a guardarla la cambia (no se duplica).
      expect(guardarCredencial(equipo, '$equipo\\Otra', 'otra'), isTrue);
      expect(usuarioGuardado(equipo), '$equipo\\Otra');
      expect(borrarCredencial(equipo), isTrue);
      expect(usuarioGuardado(equipo), isNull);
    }, skip: Platform.isWindows ? false : 'Solo en Windows');
  });

  group('Carpetas de verdad', () {
    late Directory temporal;

    setUp(() {
      temporal = Directory.systemTemp.createTempSync('red');
      // Como en casa: una carpeta compartida con «Películas» dentro, y
      // dentro las carpetas de la colección; y otra compartida sin nada.
      for (final ruta in [
        r'Multimedia\Películas\Comedias\Comedia\Uno (2000).mp4',
        r'Multimedia\Películas\Drama y Musical\Drama\Dos (2001).mp4',
        r'Multimedia\Series\Una serie\Capítulo 1.mp4',
        r'Fotos\Verano\foto.jpg',
      ]) {
        File('${temporal.path}\\$ruta').createSync(recursive: true);
      }
    });

    tearDown(() => temporal.deleteSync(recursive: true));

    const muestras = [
      r'Comedias\Comedia\Uno (2000).mp4',
      r'Drama y Musical\Drama\Dos (2001).mp4',
    ];

    test(
      'comprobar una ruta: encontradas, carpeta equivocada o que no existe',
      () async {
        final buena = await comprobarRuta(
          '${temporal.path}\\Multimedia\\Películas',
          muestras,
        );
        expect(buena.estado, EstadoRed.disponible);
        expect((buena.encontradas, buena.probadas), (2, 2));

        final equivocada = await comprobarRuta(
          '${temporal.path}\\Multimedia',
          muestras,
        );
        expect(equivocada.estado, EstadoRed.noEncontrada);
        expect(equivocada.probadas, 2);

        final noExiste = await comprobarRuta(
          '${temporal.path}\\NoExiste',
          muestras,
        );
        expect(noExiste.estado, EstadoRed.noEncontrada);
      },
    );

    test(
      'busca entre las carpetas compartidas la que lleva a las películas',
      () async {
        final propuesta = await buscarRutaRed(
          raiz: r'D:\',
          muestras: muestras,
          compartidas: [
            '${temporal.path}\\Fotos',
            '${temporal.path}\\Multimedia',
          ],
        );
        expect(propuesta, isNotNull);
        expect(propuesta!.ruta, '${temporal.path}\\Multimedia\\Películas');
        expect((propuesta.encontradas, propuesta.probadas), (2, 2));

        // Si no se comparte ninguna que lleve a ellas, nada.
        expect(
          await buscarRutaRed(
            raiz: r'D:\',
            muestras: muestras,
            compartidas: ['${temporal.path}\\Fotos'],
          ),
          isNull,
        );
      },
    );

    test('un PC que no existe no deja la app esperando', () async {
      final reloj = Stopwatch()..start();
      final r = await comprobarRuta(r'\\NOEXISTE-VIDEOTECA\Pelis', muestras);
      expect(r.estado, EstadoRed.sinConexion);
      expect(reloj.elapsed, lessThan(const Duration(seconds: 6)));
    });

    test('si una película sigue en su sitio (o no se sabe)', () async {
      final peliculas = '${temporal.path}\\Multimedia\\Películas';
      expect(await archivoEsta(unirRuta(peliculas, muestras[0])), isTrue);
      expect(await archivoEsta('$peliculas\\Comedias\\Otra (2002).mp4'), false);
      // De un PC que no contesta no se sabe, y no se espera de más.
      final reloj = Stopwatch()..start();
      expect(
        await archivoEsta(r'\\NOEXISTE-VIDEOTECA\Pelis\Uno (2000).mp4'),
        isNull,
      );
      expect(reloj.elapsed, lessThan(const Duration(seconds: 6)));
    });

    test('las carpetas compartidas de este PC se pueden leer', () {
      // No se sabe cuáles hay; solo que Windows contesta y que no salen las
      // de los administradores (C$, ADMIN$…).
      final nombres = carpetasCompartidas();
      expect(nombres.where((n) => n == 'ADMIN\$' || n == 'IPC\$'), isEmpty);
    });
  }, skip: Platform.isWindows ? false : 'Solo en Windows');
}
