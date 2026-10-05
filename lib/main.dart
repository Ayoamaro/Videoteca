import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'arranque.dart';
import 'datos/carpetas_app.dart';
import 'navegacion/rutas.dart';
import 'tema/tema.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Prepara los nombres de días y meses en español ("viernes, 3 de octubre").
  await initializeDateFormatting('es');

  // Primero, la pantalla de acceso (o, si ya se había entrado, la app con
  // la base de datos de ese modo).
  runApp(Arranque(carpeta: carpetaDatosApp()));
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
