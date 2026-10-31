import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'arranque.dart';
import 'datos/carpetas_app.dart';
import 'navegacion/rutas.dart';
import 'tema/tema.dart';
import 'widgets/avisos.dart';
import 'widgets/barra_ventana.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Prepara los nombres de días y meses en español ("viernes, 3 de octubre").
  await initializeDateFormatting('es');

  // Solo para probar en el PC cómo se ve en el móvil (compilación de
  // depuración con VIDEOTECA_MOVIL=1): la app se comporta como en Android.
  if (kDebugMode && Platform.environment['VIDEOTECA_MOVIL'] == '1') {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
  }
  if (Platform.isAndroid) {
    // La app se dibuja también detrás de las barras del sistema (la de la
    // hora y la de los botones), que quedan transparentes.
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

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
      scrollBehavior: const DesplazamientoApp(),
      builder: (context, hijo) => BarrasSistema(
        child: _AvisoAlAbrir(
          aviso: ref.read(avisoAlAbrirProvider),
          child: hijo!,
        ),
      ),
    );
  }
}

/// Enseña [aviso] (si lo hay) en cuanto se abre la app.
class _AvisoAlAbrir extends StatefulWidget {
  const _AvisoAlAbrir({required this.aviso, required this.child});

  final String? aviso;
  final Widget child;

  @override
  State<_AvisoAlAbrir> createState() => _AvisoAlAbrirState();
}

class _AvisoAlAbrirState extends State<_AvisoAlAbrir> {
  @override
  void initState() {
    super.initState();
    final aviso = widget.aviso;
    if (aviso == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      avisar(context, aviso, largo: true);
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Iconos de las barras del sistema del móvil (hora, batería, botones) en
/// claro sobre el tema oscuro y en oscuro sobre el claro. En Windows, además,
/// la barra de la ventana.
class BarrasSistema extends StatelessWidget {
  const BarrasSistema({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final oscuro = Theme.of(context).brightness == Brightness.dark;
    final iconos = oscuro ? Brightness.light : Brightness.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: iconos,
        statusBarBrightness: oscuro ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: iconos,
        systemNavigationBarContrastEnforced: false,
      ),
      // En Windows, la barra de la ventana la pone la app (como Chrome).
      child: ConBarraVentana(child: child),
    );
  }
}

/// Cómo se desplazan las listas. Como siempre, salvo en las pruebas «como
/// en el móvil» en el PC: ahí también se arrastran con el ratón, igual que
/// con el dedo.
class DesplazamientoApp extends MaterialScrollBehavior {
  const DesplazamientoApp();

  @override
  Set<PointerDeviceKind> get dragDevices => {
    ...super.dragDevices,
    if (debugDefaultTargetPlatformOverride == TargetPlatform.android)
      PointerDeviceKind.mouse,
  };
}
