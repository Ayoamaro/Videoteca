import 'package:flutter/material.dart';

void main() {
  runApp(const VideotecaApp());
}

/// Colores provisionales del diseño "sala de cine".
/// El tema completo (tipografías, modo claro…) llega el día 2.
const colorFondo = Color(0xFF0F0E13);
const colorDorado = Color(0xFFE2AE4F);

class VideotecaApp extends StatelessWidget {
  const VideotecaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Videoteca',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: colorFondo,
        colorScheme: ColorScheme.fromSeed(
          seedColor: colorDorado,
          brightness: Brightness.dark,
        ),
      ),
      home: const PantallaInicial(),
    );
  }
}

class PantallaInicial extends StatelessWidget {
  const PantallaInicial({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.movie_outlined, size: 72, color: colorDorado),
            SizedBox(height: 16),
            Text(
              'Videoteca',
              style: TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.w700,
                color: colorDorado,
              ),
            ),
            SizedBox(height: 8),
            Text('Próximamente: tus películas aquí'),
          ],
        ),
      ),
    );
  }
}
