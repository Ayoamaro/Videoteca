import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:videoteca/datos/catalogo.dart';
import 'package:videoteca/datos/ejemplo.dart';
import 'package:videoteca/main.dart';
import 'package:videoteca/modelos/pelicula.dart';
import 'package:videoteca/utilidades.dart';

/// Catálogo con los datos de ejemplo en lugar de la base de datos.
class _CatalogoEjemplo extends Catalogo {
  @override
  Future<List<Pelicula>> build() async => peliculasEjemplo;
}

/// Arranca la app con una ventana del tamaño indicado. Sin [carpetaRaiz],
/// la app se comporta como en el primer arranque.
Future<void> abrirApp(
  WidgetTester tester,
  Size tamano, {
  String? carpetaRaiz = r'D:\',
}) async {
  tester.view.physicalSize = tamano;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ajustesInicialesProvider.overrideWithValue({
          CarpetaRaiz.clave: ?carpetaRaiz,
        }),
        catalogoProvider.overrideWith(_CatalogoEjemplo.new),
        generosProvider.overrideWithValue(generosEjemplo),
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
      ('Películas nuevas', '¿Cuál es «Cazadores de Fronteras (2025)»?'),
      ('Pendientes', 'Todo lo que necesita tu atención en la colección.'),
      ('Completar colección', 'Completar mi colección'),
      ('Ajustes', 'Apariencia'),
      ('Estadísticas', 'Esta pantalla llega el día 17.'),
      ('Catálogo', 'Filtros'),
    ]) {
      await tester.tap(find.text(menu).first);
      await tester.pumpAndSettle();
      expect(find.text(titulo), findsOneWidget, reason: 'Pantalla $menu');
    }
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

  test('Números con punto de miles y búsqueda sin tildes', () {
    expect(formatoNumero(5541), '5.541');
    expect(formatoNumero(917), '917');
    expect(formatoNumero(1234567), '1.234.567');
    expect(normalizar('Ciencia Ficción'), 'ciencia ficcion');
  });
}
