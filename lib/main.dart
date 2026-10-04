import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'datos/base_datos.dart';
import 'datos/carpetas_app.dart';
import 'datos/catalogo.dart';
import 'navegacion/rutas.dart';
import 'tema/tema.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Prepara los nombres de días y meses en español ("viernes, 3 de octubre").
  await initializeDateFormatting('es');

  // Abre la base de datos local y lee los ajustes guardados.
  final carpetas = CarpetasApp.preparar();
  final bd = BaseDatos.abrir(carpetas.baseDatos);
  final ajustes = await bd.todosLosAjustes();

  runApp(
    ProviderScope(
      overrides: [
        baseDatosProvider.overrideWithValue(bd),
        carpetasAppProvider.overrideWithValue(carpetas),
        ajustesInicialesProvider.overrideWithValue(ajustes),
      ],
      child: const VideotecaApp(),
    ),
  );
}

class VideotecaApp extends ConsumerWidget {
  const VideotecaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Videoteca',
      debugShowCheckedModeBanner: false,
      theme: construirTema(Brightness.light),
      darkTheme: construirTema(Brightness.dark),
      themeMode: ref.watch(modoTemaProvider),
      routerConfig: ref.watch(rutasProvider),
      locale: const Locale('es', 'ES'),
      supportedLocales: const [Locale('es', 'ES')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
    );
  }
}
