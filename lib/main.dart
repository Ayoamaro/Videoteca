import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'navegacion/rutas.dart';
import 'tema/tema.dart';

Future<void> main() async {
  // Prepara los nombres de días y meses en español ("viernes, 3 de octubre").
  await initializeDateFormatting('es');
  runApp(const ProviderScope(child: VideotecaApp()));
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
