import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'colores.dart';

/// Tipografía de títulos (Bricolage Grotesque) y de texto (Manrope).
const fuenteTitulos = 'Bricolage';
const fuenteTexto = 'Manrope';
const fuenteRutas = 'Consolas';

/// Construye el tema completo (oscuro o claro) a partir de la paleta.
ThemeData construirTema(Brightness brillo) {
  final c = brillo == Brightness.dark
      ? ColoresVideoteca.oscuro
      : ColoresVideoteca.claro;

  final esquema = ColorScheme(
    brightness: brillo,
    primary: c.dorado,
    onPrimary: c.sobreDorado,
    secondary: c.doradoTexto,
    onSecondary: c.sobreDorado,
    error: c.rojo,
    onError: c.fondo,
    surface: c.superficie,
    onSurface: c.texto,
    onSurfaceVariant: c.textoSecundario,
    outline: c.bordeFuerte,
    outlineVariant: c.borde,
    surfaceContainerHighest: c.superficieAlta,
  );

  TextStyle titulo(double tam) => TextStyle(
    fontFamily: fuenteTitulos,
    fontSize: tam,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.02 * tam,
    height: 1.1,
    color: c.texto,
  );

  TextStyle texto(double tam, FontWeight peso, [Color? color]) => TextStyle(
    fontFamily: fuenteTexto,
    fontSize: tam,
    fontWeight: peso,
    color: color ?? c.texto,
  );

  final bordeCampo = OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: BorderSide(color: c.bordeFuerte),
  );

  final formaBoton = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(10),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brillo,
    colorScheme: esquema,
    fontFamily: fuenteTexto,
    scaffoldBackgroundColor: c.fondo,
    canvasColor: c.fondo,
    dividerColor: c.borde,
    extensions: [c],
    textTheme: TextTheme(
      displaySmall: titulo(40),
      headlineMedium: titulo(36),
      headlineSmall: titulo(24),
      titleLarge: titulo(22),
      titleMedium: texto(17, FontWeight.w700),
      titleSmall: texto(15, FontWeight.w700),
      bodyLarge: texto(16, FontWeight.w400),
      bodyMedium: texto(14, FontWeight.w400),
      bodySmall: texto(13, FontWeight.w400, c.textoSecundario),
      labelLarge: texto(14, FontWeight.w700),
      labelMedium: texto(13, FontWeight.w600),
      labelSmall: texto(
        12,
        FontWeight.w700,
        c.textoTenue,
      ).copyWith(letterSpacing: 1.2),
    ),
    iconTheme: IconThemeData(color: c.textoSecundario),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.superficieAlta,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: bordeCampo,
      enabledBorder: bordeCampo,
      disabledBorder: bordeCampo,
      focusedBorder: bordeCampo.copyWith(
        borderSide: BorderSide(color: c.dorado, width: 1.5),
      ),
      hintStyle: TextStyle(color: c.textoTenue),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: c.dorado,
        foregroundColor: c.sobreDorado,
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 18),
        shape: formaBoton,
        textStyle: texto(14, FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: c.texto,
        side: BorderSide(color: c.bordeFuerte),
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 18),
        shape: formaBoton,
        textStyle: texto(14, FontWeight.w700),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: c.doradoTexto,
        textStyle: texto(14, FontWeight.w600),
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (estados) => estados.contains(WidgetState.selected) ? c.dorado : null,
      ),
      checkColor: WidgetStatePropertyAll(c.sobreDorado),
      side: BorderSide(color: c.bordeFuerte, width: 1.5),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith(
          (estados) =>
              estados.contains(WidgetState.selected) ? c.doradoFondo : null,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (estados) => estados.contains(WidgetState.selected)
              ? c.doradoTexto
              : c.textoSuave,
        ),
        side: WidgetStatePropertyAll(BorderSide(color: c.bordeFuerte)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: c.menu,
      indicatorColor: c.doradoFondo,
      height: 68,
      iconTheme: WidgetStateProperty.resolveWith(
        (estados) => IconThemeData(
          color: estados.contains(WidgetState.selected)
              ? c.doradoTexto
              : c.textoSecundario,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (estados) => estados.contains(WidgetState.selected)
            ? texto(12, FontWeight.w700, c.doradoTexto)
            : texto(12, FontWeight.w600, c.textoSecundario),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: c.superficie,
      side: BorderSide(color: c.borde),
      shape: const StadiumBorder(),
      labelStyle: texto(14, FontWeight.w600),
      deleteIconColor: c.textoSecundario,
    ),
    listTileTheme: ListTileThemeData(iconColor: c.textoSecundario),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: c.seleccion,
      contentTextStyle: texto(14, FontWeight.w600),
      actionTextColor: c.doradoTexto,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: c.seleccion,
        borderRadius: BorderRadius.circular(6),
      ),
      textStyle: texto(12, FontWeight.w600),
    ),
    scrollbarTheme: ScrollbarThemeData(
      thumbColor: WidgetStatePropertyAll(c.bordeFuerte),
    ),
  );
}

/// Modo de color elegido en Ajustes. Empieza en oscuro (el diseño principal).
/// Más adelante se guardará en la configuración para recordarlo al reabrir.
class ModoTema extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ThemeMode.dark;

  void cambiar(ThemeMode modo) => state = modo;
}

final modoTemaProvider = NotifierProvider<ModoTema, ThemeMode>(ModoTema.new);
