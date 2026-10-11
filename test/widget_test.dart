import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:videoteca/datos/catalogo.dart';
import 'package:videoteca/datos/consulta.dart';
import 'package:videoteca/datos/ejemplo.dart';
import 'package:videoteca/datos/red_casa.dart';
import 'package:videoteca/disco/acciones_windows.dart';
import 'package:videoteca/disco/red.dart';
import 'package:videoteca/datos/sesion.dart';
import 'package:videoteca/main.dart';
import 'package:videoteca/modelos/pelicula.dart';
import 'package:videoteca/pantallas/acceso.dart';
import 'package:videoteca/tablon/copia_local.dart';
import 'package:videoteca/tema/tema.dart';
import 'package:videoteca/utilidades.dart';
import 'package:videoteca/widgets/buscador_sugerencias.dart';

/// Catálogo con los datos de ejemplo en lugar de la base de datos.
class _CatalogoEjemplo extends Catalogo {
  @override
  Future<List<Pelicula>> build() async => peliculasEjemplo;
}

/// Modo consulta con la copia descargada pero sin internet.
class _ConsultaSinInternet extends Consulta {
  @override
  EstadoConsulta build() => EstadoConsulta(
    copia: EstadoCopia(
      repositorio: 'Ayoamaro/Videoteca_Tablon',
      commit: 'abc',
      version: 2,
      fecha: DateTime(2026, 10, 4),
      peliculas: peliculasEjemplo.length,
    ),
    fase: FaseCopia.error,
    sinInternet: true,
    error: 'Sin conexión a internet.',
  );

  @override
  Future<void> comprobar({bool siHaceRato = false}) async {}
}

/// El catálogo de ejemplo como lo descarga el modo consulta: las rutas, sin
/// la raíz (`Dramas\Drama\Joy (2015).mp4`).
class _CatalogoConsulta extends Catalogo {
  @override
  Future<List<Pelicula>> build() async => [
    for (final p in peliculasEjemplo) _sinRaiz(p),
  ];
}

Pelicula _sinRaiz(Pelicula p) => Pelicula(
  id: p.id,
  titulo: p.titulo,
  anio: p.anio,
  ruta: rutaRelativa(p.ruta, r'D:\')!,
  tituloOriginal: p.tituloOriginal,
  generos: p.generos,
  temas: p.temas,
  sinopsis: p.sinopsis,
  direccion: p.direccion,
  guion: p.guion,
  reparto: p.reparto,
  musica: p.musica,
  fotografia: p.fotografia,
  productora: p.productora,
  pais: p.pais,
  premios: p.premios,
  clasificacion: p.clasificacion,
  estrellas: p.estrellas,
  rottenTomatoes: p.rottenTomatoes,
  duracionMin: p.duracionMin,
  resolucion: p.resolucion,
  tamanoBytes: p.tamanoBytes,
  saga: p.saga,
  numeroSaga: p.numeroSaga,
  anadida: p.anadida,
  nueva: p.nueva,
  tono: p.tono,
  tieneCaratula: p.tieneCaratula,
  grupo: p.grupo,
  enlaceFilmaffinity: p.enlaceFilmaffinity,
  enlaceImdb: p.enlaceImdb,
);

/// Catálogo sin ninguna película.
class _CatalogoVacio extends Catalogo {
  @override
  Future<List<Pelicula>> build() async => const [];
}

/// Modo consulta con la copia ya descargada y al día (sin ir a internet).
class _ConsultaAlDia extends Consulta {
  @override
  EstadoConsulta build() => EstadoConsulta(
    copia: EstadoCopia(
      repositorio: 'Ayoamaro/Videoteca_Tablon',
      commit: 'abc',
      version: 2,
      fecha: DateTime(2026, 10, 4),
      peliculas: peliculasEjemplo.length,
      red: r'\\CASA-PC\Pelis\Películas',
    ),
    comprobada: DateTime.now(),
  );
}

/// Red de casa de mentira: en `\\CASA-PC\Pelis\Películas` están todas
/// menos *Joy*, que se ha movido; [casa] es lo que contesta ese PC. Apunta lo
/// que se abre en vez de abrirlo.
class _RedFalsa extends ServicioRed {
  _RedFalsa();

  static const rutaCasa = r'\\CASA-PC\Pelis\Películas';

  var casa = EstadoRed.disponible;

  /// Películas reproducidas (`false`) o abiertas en su carpeta (`true`).
  final abiertas = <(String, bool)>[];

  /// Carpetas abiertas en el Explorador.
  final exploradas = <String>[];

  @override
  Future<ComprobacionRed> comprobar(String ruta, List<String> muestras) async =>
      ruta.startsWith(rutaCasa)
      ? ComprobacionRed(
          casa,
          encontradas: casa == EstadoRed.disponible ? muestras.length : 0,
          probadas: casa == EstadoRed.disponible ? muestras.length : 0,
        )
      : ruta.startsWith(r'\\OTRO-PC')
      ? const ComprobacionRed(EstadoRed.contrasena, codigo: 1272)
      : ComprobacionRed(EstadoRed.noEncontrada, probadas: muestras.length);

  @override
  Future<PropuestaRed?> buscar(String raiz, List<String> muestras) async => (
    ruta: r'\\CASA-PC\Pelis\Películas',
    encontradas: muestras.length,
    probadas: muestras.length,
  );

  @override
  bool esDeEstePc(String ruta) => !ruta.startsWith(r'\\');

  @override
  Future<bool?> existe(String ruta) async =>
      casa != EstadoRed.disponible ? null : !ruta.contains('Joy (2015)');

  @override
  Future<ResultadoAbrir> abrir(String ruta, {bool enCarpeta = false}) async {
    if (ruta.startsWith(rutaCasa) && casa != EstadoRed.disponible) {
      return ResultadoAbrir.sinConexion;
    }
    abiertas.add((ruta, enCarpeta));
    return ResultadoAbrir.hecho;
  }

  @override
  Future<bool> abrirEnExplorador(String carpeta) async {
    exploradas.add(carpeta);
    return true;
  }
}

/// La ruta de red guardada solo en memoria (sin base de datos).
class _RutaRedEnMemoria extends RutaRed {
  @override
  String? build() => null;

  @override
  Future<void> cambiar(String ruta) async => state = ruta;
}

/// Arranca la app con una ventana del tamaño indicado. Sin [carpetaRaiz],
/// la app se comporta como en el primer arranque.
Future<void> abrirApp(
  WidgetTester tester,
  Size tamano, {
  String? carpetaRaiz = r'D:\',
  bool consulta = false,
  bool sinInternet = false,
  bool vacio = false,
  double letra = 1,
  ServicioRed? red,
}) async {
  tester.view.physicalSize = tamano;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = letra;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ajustesInicialesProvider.overrideWithValue({
          CarpetaRaiz.clave: ?carpetaRaiz,
        }),
        catalogoProvider.overrideWith(
          vacio
              ? _CatalogoVacio.new
              : consulta
              ? _CatalogoConsulta.new
              : _CatalogoEjemplo.new,
        ),
        // El disco del administrador: conectado y con todas las películas
        // menos *Joy*, que se ha movido.
        discoConectadoProvider.overrideWith((ref) => Stream.value(true)),
        archivoExisteProvider.overrideWith(
          (ref, ruta) async => !ruta.contains('Joy (2015)'),
        ),
        if (!vacio) generosProvider.overrideWithValue(generosEjemplo),
        if (consulta)
          consultaProvider.overrideWith(
            sinInternet ? _ConsultaSinInternet.new : _ConsultaAlDia.new,
          ),
        servicioRedProvider.overrideWithValue(red ?? _RedFalsa()),
        rutaRedProvider.overrideWith(_RutaRedEnMemoria.new),
      ],
      child: const VideotecaApp(),
    ),
  );
  await tester.pumpAndSettle();
}

/// Las pruebas simulan Android salvo que se indique otra cosa.
final windows = TargetPlatformVariant.only(TargetPlatform.windows);

void main() {
  setUpAll(() => initializeDateFormatting('es'));

  testWidgets('En Windows se ve el menú lateral y se navega por todo', (
    tester,
  ) async {
    await abrirApp(tester, const Size(1440, 1000));

    expect(find.text('¿Qué película buscas?'), findsOneWidget);
    expect(find.text('ADMINISTRACIÓN'), findsOneWidget);

    for (final (menu, titulo) in [
      ('Películas nuevas', 'Revisar el disco'),
      ('Pendientes', 'Nombre fuera de formato'),
      ('Completar colección', 'Completar mi colección'),
      ('Ajustes', 'Apariencia'),
      ('Estadísticas', 'Por década'),
      ('Catálogo', 'Filtros'),
    ]) {
      await tester.tap(find.text(menu).first);
      await tester.pumpAndSettle();
      expect(find.text(titulo), findsOneWidget, reason: 'Pantalla $menu');
    }
  }, variant: windows);

  testWidgets('Estadísticas: cada barra lleva al Catálogo filtrado', (
    tester,
  ) async {
    await abrirApp(tester, const Size(1440, 1000));
    await tester.tap(find.text('Estadísticas'));
    await tester.pumpAndSettle();
    expect(find.text('Exportar a Excel'), findsOneWidget);
    expect(find.text('Directores con más películas'), findsOneWidget);
    // Los Vengadores tiene la 1, 2, 3 y 4.
    await tester.ensureVisible(find.text('Sagas incompletas'));
    await tester.pumpAndSettle();
    expect(find.text('¡Todas tus sagas están completas!'), findsOneWidget);

    await tester.ensureVisible(find.text('Joss Whedon'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Joss Whedon'));
    await tester.pumpAndSettle();
    expect(find.text('Dirección: Joss Whedon'), findsOneWidget);
    expect(find.text('2 películas', findRichText: true), findsOneWidget);
  }, variant: windows);

  testWidgets('Buscar y abrir la ficha de una película', (tester) async {
    await abrirApp(tester, const Size(1440, 1000));

    await tester.tap(find.text('Catálogo'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'vengadores endgame');
    await tester.pumpAndSettle();
    expect(find.text('Los Vengadores 4: Endgame'), findsOneWidget);
    expect(find.text('Forrest Gump'), findsNothing);

    await tester.tap(find.text('Los Vengadores 4: Endgame'));
    await tester.pumpAndSettle();
    expect(find.text('Avengers: Endgame'), findsOneWidget);
    expect(find.text('DÓNDE ESTÁ'), findsOneWidget);
  }, variant: windows);

  testWidgets('Filtros combinables del catálogo', (tester) async {
    await abrirApp(tester, const Size(1440, 1000));
    await tester.tap(find.text('Catálogo'));
    await tester.pumpAndSettle();

    Finder total(String texto) => find.text(texto, findRichText: true);

    // Director: se escribe y se elige de la lista.
    await tester.enterText(
      find.widgetWithText(TextField, 'Escribe un director…'),
      'joss',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Joss Whedon'));
    await tester.pumpAndSettle();
    expect(total('2 películas'), findsOneWidget);
    expect(find.text('Dirección: Joss Whedon'), findsOneWidget);

    // Se combina con las estrellas: de Joss Whedon con 5, solo una.
    await tester.tap(find.text('5  1', findRichText: true));
    await tester.pumpAndSettle();
    expect(total('1 película'), findsOneWidget);
    expect(find.text('Los Vengadores'), findsOneWidget);

    // «Quitar todos» deja el catálogo entero.
    await tester.tap(find.text('Quitar todos'));
    await tester.pumpAndSettle();
    expect(find.text('Dirección: Joss Whedon'), findsNothing);
    expect(total('${peliculasEjemplo.length} películas'), findsOneWidget);
  }, variant: windows);

  testWidgets(
    'Autocompletado en Inicio: escribir, elegir con flechas e Intro',
    (tester) async {
      await abrirApp(tester, const Size(1440, 1000));

      await tester.tap(find.byType(TextField).first);
      await tester.enterText(find.byType(TextField).first, 'VENGADORES');
      await tester.pumpAndSettle();
      expect(find.textContaining('Avengers: Endgame · 2019'), findsOneWidget);
      expect(find.text('Ver los 4 resultados en el catálogo'), findsOneWidget);

      // Por director, con su sugerencia de persona.
      await tester.enterText(find.byType(TextField).first, 'whedon');
      await tester.pumpAndSettle();
      expect(find.text('Joss Whedon'), findsOneWidget);
      expect(
        find.text('Dirigida por Joss Whedon · 2012 · Fantasía'),
        findsWidgets,
      );

      // ↓ marca la primera y Intro abre su ficha.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(find.text('DÓNDE ESTÁ'), findsOneWidget);
    },
    variant: windows,
  );

  testWidgets('Intro sin elegir nada lleva al catálogo con los resultados', (
    tester,
  ) async {
    await abrirApp(tester, const Size(1440, 1000));
    await tester.tap(find.byType(TextField).first);
    await tester.enterText(find.byType(TextField).first, 'russ');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(find.text('Más parecidas'), findsOneWidget);
    expect(find.text('Los Vengadores 3: Infinity War'), findsOneWidget);
    expect(find.text('Joy'), findsOneWidget); // David O. Russell
    expect(find.text('Forrest Gump'), findsNothing);

    // Solo en los títulos: ninguno lleva «russ».
    await tester.tap(find.text('Títulos'));
    await tester.pumpAndSettle();
    expect(find.text('Los Vengadores 3: Infinity War'), findsNothing);
  }, variant: windows);

  testWidgets('Ctrl + K lleva al buscador desde cualquier pantalla', (
    tester,
  ) async {
    await abrirApp(tester, const Size(1440, 1000));
    await tester.tap(find.text('Ajustes'));
    await tester.pumpAndSettle();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(find.text('¿Qué película buscas?'), findsOneWidget);
    final contexto = tester.element(find.byType(VideotecaApp));
    final foco = ProviderScope.containerOf(contexto).read(focoBusquedaProvider);
    expect(foco.hasFocus, isTrue);
  }, variant: windows);

  testWidgets('En pantalla estrecha se usa la barra inferior', (tester) async {
    await abrirApp(tester, const Size(400, 850));

    expect(find.byType(NavigationBar), findsOneWidget);
    await tester.tap(find.text('Géneros').last);
    await tester.pumpAndSettle();
    expect(find.text('Western'), findsOneWidget);
  });

  testWidgets('Sin carpeta elegida, empieza el asistente de bienvenida', (
    tester,
  ) async {
    await abrirApp(tester, const Size(1440, 1000), carpetaRaiz: null);
    expect(find.text('¿Dónde guardas tus películas?'), findsOneWidget);
    expect(find.text('Elegir carpeta…'), findsOneWidget);
    expect(find.text('ADMINISTRACIÓN'), findsNothing);
  }, variant: windows);

  testWidgets('En Android no hay asistente (solo consulta)', (tester) async {
    await abrirApp(tester, const Size(400, 850), carpetaRaiz: null);
    expect(find.text('¿Dónde guardas tus películas?'), findsNothing);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('El modo claro se activa desde Ajustes', (tester) async {
    await abrirApp(tester, const Size(1440, 1000));
    await tester.tap(find.text('Ajustes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Claro'));
    await tester.pumpAndSettle();

    final contexto = tester.element(find.text('Apariencia'));
    expect(Theme.of(contexto).brightness, Brightness.light);
  }, variant: windows);

  Future<void> abrirAcceso(WidgetTester tester, Size tamano) async {
    tester.view.physicalSize = tamano;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final carpeta = Directory.systemTemp.createTempSync('acceso');
    addTearDown(() => carpeta.deleteSync(recursive: true));
    await tester.pumpWidget(
      MaterialApp(
        theme: construirTema(Brightness.dark),
        home: PantallaAcceso(
          sesion: Sesion(),
          carpeta: carpeta.path,
          alEntrar: (modo, {ajustes = const {}}) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Acceso en el PC: consultar o administrar', (tester) async {
    await abrirAcceso(tester, const Size(1440, 1000));
    expect(find.text('¿Cómo quieres entrar?'), findsOneWidget);
    expect(find.text('Consultar el catálogo'), findsOneWidget);
    expect(find.text('Administrar este PC'), findsOneWidget);

    // Sin contraseña de administrador todavía: hay que crearla dos veces.
    await tester.enterText(
      find.widgetWithText(TextField, 'Nueva contraseña'),
      'secreta1',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Repite la contraseña'),
      'secreta2',
    );
    await tester.tap(find.text('Crear y entrar'));
    await tester.pumpAndSettle();
    expect(find.text('Las dos contraseñas no coinciden.'), findsOneWidget);

    // Un tablón mal escrito.
    await tester.enterText(find.widgetWithText(TextField, 'Tablón'), 'nada');
    await tester.enterText(
      find.widgetWithText(TextField, 'Contraseña común'),
      'x',
    );
    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();
    expect(find.textContaining('El tablón se escribe'), findsOneWidget);
  }, variant: windows);

  testWidgets('Acceso en el móvil: solo consulta', (tester) async {
    await abrirAcceso(tester, const Size(400, 850));
    expect(find.text('Consultar el catálogo'), findsOneWidget);
    expect(find.text('Administrar este PC'), findsNothing);
  });

  testWidgets('Recorrido en el móvil (consulta): nada se sale de la pantalla', (
    tester,
  ) async {
    modoSesion = ModoApp.consulta;
    addTearDown(() => modoSesion = null);
    // El tamaño del diseño del móvil (con la letra de un móvil corriente).
    await abrirApp(tester, const Size(390, 844), consulta: true);
    expect(find.text('Añadidas recientemente'), findsOneWidget);

    // Buscar: tres columnas y la ficha entera, de arriba abajo.
    await tester.tap(find.text('Buscar'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'infinity war');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Los Vengadores 3: Infinity War'));
    await tester.pumpAndSettle();
    expect(find.text('DÓNDE ESTÁ'), findsOneWidget);
    // En consulta no se habla de los archivos ni se puede editar.
    expect(find.text('Carátula incrustada en el archivo'), findsNothing);
    expect(find.text('Editar ficha'), findsNothing);
    // Se baja hasta el final de la ficha, como con el dedo.
    for (var i = 0; i < 8; i++) {
      await tester.dragFrom(const Offset(195, 600), const Offset(0, -500));
      await tester.pumpAndSettle();
    }

    // El botón «atrás» del móvil vuelve de la ficha a Buscar…
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('DÓNDE ESTÁ'), findsNothing);
    expect(find.byType(TextField), findsWidgets);
    // …y desde Buscar, a Inicio (no sale de la app).
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Añadidas recientemente'), findsOneWidget);

    await tester.tap(find.text('Géneros').last);
    await tester.pumpAndSettle();
    expect(find.text('Western'), findsOneWidget);

    // Más → Estadísticas, de arriba abajo (sin exportar: es el móvil).
    await tester.tap(find.text('Más'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Estadísticas'));
    await tester.pumpAndSettle();
    expect(find.text('Por década'), findsOneWidget);
    expect(find.text('Exportar a Excel'), findsNothing);
    for (var i = 0; i < 8; i++) {
      await tester.dragFrom(const Offset(195, 600), const Offset(0, -500));
      await tester.pumpAndSettle();
    }
    expect(find.text('Sagas incompletas'), findsOneWidget);

    // Más → Ajustes (solo lo de consulta).
    await tester.tap(find.text('Más'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ajustes'));
    await tester.pumpAndSettle();
    expect(find.text('Apariencia'), findsOneWidget);
    expect(find.text('Publicación'), findsNothing);
  });

  testWidgets('Con la letra al 200 % nada se sale en el PC', (tester) async {
    await abrirApp(tester, const Size(1280, 800), letra: 2.0);
    for (final menu in [
      'Catálogo',
      'Películas nuevas',
      'Pendientes',
      'Completar colección',
      'Estadísticas',
      'Ajustes',
    ]) {
      // Con la letra tan grande, el menú se desplaza para llegar al final.
      await tester.ensureVisible(find.text(menu).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text(menu).first);
      await tester.pumpAndSettle();
    }
    await tester.ensureVisible(find.text('Catálogo').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Catálogo').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'forrest');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Forrest Gump'));
    await tester.pumpAndSettle();
    expect(find.text('DÓNDE ESTÁ'), findsOneWidget);
  }, variant: windows);

  testWidgets('Con la letra al máximo (200 %) nada se sale en el móvil', (
    tester,
  ) async {
    modoSesion = ModoApp.consulta;
    addTearDown(() => modoSesion = null);
    await abrirApp(tester, const Size(390, 844), consulta: true, letra: 2.0);
    await tester.tap(find.text('Buscar'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'forrest');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Forrest Gump'));
    await tester.pumpAndSettle();
    for (var i = 0; i < 8; i++) {
      await tester.dragFrom(const Offset(195, 600), const Offset(0, -500));
      await tester.pumpAndSettle();
    }
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    for (final menu in ['Géneros', 'Más']) {
      await tester.tap(find.text(menu).last);
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Estadísticas'));
    await tester.pumpAndSettle();
    expect(find.text('Por década'), findsOneWidget);
  });

  testWidgets('Botones con nombre y del tamaño de un dedo en el móvil', (
    tester,
  ) async {
    modoSesion = ModoApp.consulta;
    addTearDown(() => modoSesion = null);
    final semantica = tester.ensureSemantics();
    await abrirApp(tester, const Size(390, 844), consulta: true);
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await tester.tap(find.text('Buscar'));
    await tester.pumpAndSettle();
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await tester.enterText(find.byType(TextField).first, 'forrest');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Forrest Gump'));
    await tester.pumpAndSettle();
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    semantica.dispose();
  });

  testWidgets('Los textos se leen bien (contraste) en oscuro y en claro', (
    tester,
  ) async {
    final semantica = tester.ensureSemantics();
    await abrirApp(tester, const Size(1440, 1000));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    await tester.tap(find.text('Ajustes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Claro'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Inicio').first);
    await tester.pumpAndSettle();
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    semantica.dispose();
  }, variant: windows);

  testWidgets('Consulta sin internet: se sigue viendo lo descargado', (
    tester,
  ) async {
    modoSesion = ModoApp.consulta;
    addTearDown(() => modoSesion = null);
    await abrirApp(
      tester,
      const Size(390, 844),
      consulta: true,
      sinInternet: true,
    );
    expect(
      find.textContaining('Sin internet: estás viendo el catálogo descargado'),
      findsOneWidget,
    );
    expect(find.text('Añadidas recientemente'), findsOneWidget);
  });

  testWidgets('Consulta al día: sin hueco de más bajo el buscador', (
    tester,
  ) async {
    modoSesion = ModoApp.consulta;
    addTearDown(() => modoSesion = null);
    await abrirApp(tester, const Size(1440, 1000), consulta: true);
    final buscador = tester.getRect(find.byType(BuscadorConSugerencias));
    final titulo = tester.getRect(find.text('Añadidas recientemente'));
    // Una sola separación entre los dos (36 px en el PC), no dos.
    expect(titulo.top - buscador.bottom, inInclusiveRange(36, 60));
  }, variant: windows);

  testWidgets('Red de casa en el PC: la app propone la ruta y se guarda', (
    tester,
  ) async {
    final n = peliculasEjemplo.length;
    await abrirApp(tester, const Size(1440, 1000));
    await tester.tap(find.text('Ajustes'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Red de casa'));
    await tester.pumpAndSettle();
    // La busca sola y la propone.
    expect(find.text(r'\\CASA-PC\Pelis\Películas'), findsOneWidget);
    expect(
      find.text('Encontradas $n de $n películas de prueba por esa ruta.'),
      findsOneWidget,
    );

    // Una carpeta de este PC no vale: los demás no la ven.
    await tester.tap(find.text('Elegir otra…'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, r'D:\Películas');
    await tester.tap(find.text('Comprobar y guardar'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Esa carpeta es de este PC'), findsOneWidget);
    await tester.tap(find.text('Cancelar').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Usar esta ruta'));
    await tester.pumpAndSettle();
    expect(find.text('Disponible'), findsOneWidget);
    expect(
      find.text(
        'Encontradas $n de $n películas de prueba · comprobado: ahora mismo.',
      ),
      findsOneWidget,
    );

    // Se puede dejar sin ruta (los demás PC solo consultan).
    await tester.tap(find.text('Quitar'));
    await tester.pumpAndSettle();
    expect(find.text('Sin ruta de red'), findsOneWidget);
    expect(find.text('Buscar la ruta'), findsOneWidget);
  }, variant: windows);

  testWidgets('PC de consulta: usa la ruta de red del tablón si se llega', (
    tester,
  ) async {
    final n = peliculasEjemplo.length;
    modoSesion = ModoApp.consulta;
    addTearDown(() => modoSesion = null);
    await abrirApp(tester, const Size(1440, 1000), consulta: true);
    await tester.tap(find.text('Ajustes'));
    await tester.pumpAndSettle();
    expect(find.text('Películas en la red'), findsOneWidget);
    expect(find.text(r'\\CASA-PC\Pelis\Películas'), findsOneWidget);
    expect(find.text('Disponible'), findsOneWidget);
    expect(
      find.textContaining(
        'Publicada por el administrador · encontradas $n de $n',
      ),
      findsOneWidget,
    );

    // Otra carpeta en la que no están las películas no se guarda.
    await tester.tap(find.text('Cambiar…'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, r'\\CASA-PC\Fotos');
    await tester.tap(find.text('Comprobar y guardar'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('no está ninguna de las $n películas'),
      findsOneWidget,
    );
    await tester.tap(find.text('Cancelar').last);
    await tester.pumpAndSettle();
    expect(find.text(r'\\CASA-PC\Pelis\Películas'), findsOneWidget);

    // Un PC que pide contraseña: se guarda y se explica qué hacer.
    await tester.tap(find.text('Cambiar…'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, r'\\OTRO-PC\Pelis');
    await tester.tap(find.text('Comprobar y guardar'));
    await tester.pumpAndSettle();
    expect(find.text(r'\\OTRO-PC\Pelis'), findsOneWidget);
    expect(find.text('Pide contraseña'), findsOneWidget);
    expect(find.text('Abrir en el Explorador'), findsOneWidget);
    expect(find.textContaining('Elegida en este PC'), findsOneWidget);

    // Y se puede volver a la del administrador.
    await tester.tap(find.text('Usar la del administrador'));
    await tester.pumpAndSettle();
    expect(find.text(r'\\CASA-PC\Pelis\Películas'), findsOneWidget);
    expect(find.text('Disponible'), findsOneWidget);
  }, variant: windows);

  testWidgets('En el móvil no hay ruta de red', (tester) async {
    modoSesion = ModoApp.consulta;
    addTearDown(() => modoSesion = null);
    await abrirApp(tester, const Size(390, 844), consulta: true);
    await tester.tap(find.text('Más'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ajustes'));
    await tester.pumpAndSettle();
    expect(find.text('Películas en la red'), findsNothing);
  });

  /// Abre la ficha de [titulo] buscándola (en el PC, en el Catálogo; en el
  /// móvil, en Buscar).
  Future<void> abrirFicha(
    WidgetTester tester,
    String busqueda,
    String titulo, {
    String menu = 'Catálogo',
  }) async {
    await tester.tap(find.text(menu).last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, busqueda);
    await tester.pumpAndSettle();
    await tester.tap(find.text(titulo).first);
    await tester.pumpAndSettle();
    expect(find.text('DÓNDE ESTÁ'), findsOneWidget);
  }

  /// El botón con el texto [texto] (también los que llevan icono).
  ButtonStyleButton boton(WidgetTester tester, String texto) =>
      tester.widget<ButtonStyleButton>(
        find.ancestor(
          of: find.text(texto),
          matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
        ),
      );

  /// Lo que la app copia al portapapeles.
  List<String> portapapeles(WidgetTester tester) {
    final copiado = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (llamada) async {
        if (llamada.method == 'Clipboard.setData') {
          copiado.add((llamada.arguments as Map)['text'] as String);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    return copiado;
  }

  testWidgets('Ficha en el PC del administrador: la película del disco', (
    tester,
  ) async {
    final red = _RedFalsa();
    final copiado = portapapeles(tester);
    await abrirApp(tester, const Size(1440, 1000), red: red);
    await abrirFicha(tester, 'forrest', 'Forrest Gump');
    const ruta = r'D:\Dramas\Drama\Forrest Gump (1994).mp4';
    expect(find.text('D:\\Dramas\\Drama\\\nForrest Gump (1994).mp4'), findsOne);

    await tester.tap(find.text('Reproducir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Abrir carpeta'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Copiar ruta'));
    await tester.pumpAndSettle();
    expect(red.abiertas, [(ruta, false), (ruta, true)]);
    expect(copiado, [ruta]);
    expect(find.text('Ruta copiada.'), findsOneWidget);

    // Una película que ya no está en el disco no se puede reproducir.
    await abrirFicha(tester, 'joy', 'Joy');
    expect(
      find.textContaining('No se encuentra el archivo en esta ruta'),
      findsOneWidget,
    );
    expect(boton(tester, 'Reproducir').enabled, isFalse);
    expect(boton(tester, 'Abrir carpeta').enabled, isFalse);
    // En el PC del administrador la ficha no toca la red de casa (ponerla
    // en marcha buscaría la ruta entre las carpetas compartidas).
    final contenedor = ProviderScope.containerOf(
      tester.element(find.byType(VideotecaApp)),
    );
    expect(contenedor.exists(redCasaProvider), isFalse);
  }, variant: windows);

  testWidgets('Ficha en un PC de la red: la película por la red de casa', (
    tester,
  ) async {
    modoSesion = ModoApp.consulta;
    addTearDown(() => modoSesion = null);
    final red = _RedFalsa();
    final copiado = portapapeles(tester);
    await abrirApp(tester, const Size(1440, 1000), consulta: true, red: red);
    await abrirFicha(tester, 'forrest', 'Forrest Gump');
    const ruta =
        r'\\CASA-PC\Pelis\Películas\Dramas\Drama\Forrest Gump (1994).mp4';
    expect(
      find.text(
        '\\\\CASA-PC\\Pelis\\Películas\\Dramas\\Drama\\\n'
        'Forrest Gump (1994).mp4',
      ),
      findsOne,
    );
    await tester.tap(find.text('Reproducir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Abrir carpeta'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Copiar ruta'));
    await tester.pumpAndSettle();
    expect(red.abiertas, [(ruta, false), (ruta, true)]);
    expect(copiado, [ruta]);

    final contenedor = ProviderScope.containerOf(
      tester.element(find.byType(VideotecaApp)),
    );

    // Se apaga el PC de las películas: se explica y no se puede reproducir.
    red.casa = EstadoRed.sinConexion;
    contenedor.read(redCasaProvider.notifier).comprobar();
    await tester.pumpAndSettle();
    expect(
      find.textContaining('No se llega al PC de las películas'),
      findsOneWidget,
    );
    expect(boton(tester, 'Reproducir').enabled, isFalse);
    expect(boton(tester, 'Abrir carpeta').enabled, isFalse);
    // La ruta se puede copiar igual.
    expect(boton(tester, 'Copiar ruta').enabled, isTrue);

    // Pide contraseña: el Explorador la pide y la recuerda…
    red.casa = EstadoRed.contrasena;
    await tester.tap(find.text('Comprobar'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Windows pide usuario y contraseña'), findsOne);
    await tester.tap(find.text('Abrir en el Explorador'));
    await tester.pumpAndSettle();
    expect(red.exploradas, [_RedFalsa.rutaCasa]);
    // …y al volver a la app ya funciona todo.
    red.casa = EstadoRed.disponible;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.textContaining('Windows pide usuario'), findsNothing);
    expect(boton(tester, 'Reproducir').enabled, isTrue);

    // Una película que se ha movido en el PC de las películas.
    await abrirFicha(tester, 'joy', 'Joy');
    expect(
      find.textContaining('No se encuentra la película en esta ruta'),
      findsOneWidget,
    );
    expect(boton(tester, 'Reproducir').enabled, isFalse);
  }, variant: windows);

  testWidgets('PC sin la red de casa: la ficha, como en el móvil', (
    tester,
  ) async {
    modoSesion = ModoApp.consulta;
    addTearDown(() => modoSesion = null);
    // (La copia de «sin internet» no trae ruta de red.)
    await abrirApp(
      tester,
      const Size(1440, 1000),
      consulta: true,
      sinInternet: true,
    );
    await abrirFicha(tester, 'forrest', 'Forrest Gump');
    expect(find.text('Dramas  ›  Drama'), findsOneWidget);
    expect(find.text('Reproducir'), findsNothing);
    expect(find.text('Copiar ruta'), findsNothing);
  }, variant: windows);

  testWidgets('En el móvil, «Dónde está» solo dice la carpeta', (tester) async {
    modoSesion = ModoApp.consulta;
    addTearDown(() => modoSesion = null);
    await abrirApp(tester, const Size(390, 844), consulta: true);
    await abrirFicha(
      tester,
      'infinity war',
      'Los Vengadores 3: Infinity War',
      menu: 'Buscar',
    );
    expect(find.text('Aventuras y Fantasía  ›  Fantasía'), findsOneWidget);
    expect(find.text('1080p · 1918 × 816'), findsOneWidget);
    expect(find.text('4,1 GB'), findsOneWidget);
    expect(find.textContaining('CASA-PC'), findsNothing);
    expect(find.textContaining('Infinity War (2018).mp4'), findsNothing);
    for (final texto in ['Reproducir', 'Abrir carpeta', 'Copiar ruta']) {
      expect(find.text(texto), findsNothing);
    }
  });

  testWidgets('Colección vacía: se explica qué hacer', (tester) async {
    await abrirApp(tester, const Size(1440, 1000), vacio: true);
    expect(find.text('Todavía no hay películas'), findsOneWidget);
    await tester.tap(find.text('Catálogo'));
    await tester.pumpAndSettle();
    expect(find.text('Todavía no hay películas'), findsOneWidget);
    expect(find.text('Ninguna película cumple los filtros'), findsNothing);
    await tester.enterText(find.byType(TextField).first, 'xyz');
    await tester.pumpAndSettle();
    expect(
      find.text('No hay ninguna película que coincida con «xyz»'),
      findsOneWidget,
    );
    await tester.tap(find.text('Estadísticas'));
    await tester.pumpAndSettle();
    expect(find.text('Todavía no hay películas'), findsOneWidget);
  }, variant: windows);

  test('Números con punto de miles y búsqueda sin tildes', () {
    expect(formatoNumero(5541), '5.541');
    expect(formatoNumero(917), '917');
    expect(formatoNumero(1234567), '1.234.567');
    expect(normalizar('Ciencia Ficción'), 'ciencia ficcion');
  });
}
