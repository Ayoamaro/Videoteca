import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:videoteca/main.dart';
import 'package:videoteca/utilidades.dart';

/// Arranca la app con una ventana del tamaño indicado.
Future<void> abrirApp(WidgetTester tester, Size tamano) async {
  tester.view.physicalSize = tamano;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const ProviderScope(child: VideotecaApp()));
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

  testWidgets('En pantalla estrecha se usa la barra inferior', (tester) async {
    await abrirApp(tester, const Size(400, 850));

    expect(find.byType(NavigationBar), findsOneWidget);
    await tester.tap(find.text('Géneros').last);
    await tester.pumpAndSettle();
    expect(find.text('Western'), findsOneWidget);
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
