import 'package:flutter/material.dart';

/// Paleta "sala de cine" del diseño aprobado.
///
/// Cada color tiene su versión oscura (la principal) y clara. Las pantallas
/// nunca escriben colores a mano: piden `context.colores.dorado`, etc., y así
/// el modo claro funciona solo.
@immutable
class ColoresVideoteca extends ThemeExtension<ColoresVideoteca> {
  const ColoresVideoteca({
    required this.fondo,
    required this.menu,
    required this.superficie,
    required this.superficieAlta,
    required this.seleccion,
    required this.borde,
    required this.bordeFuerte,
    required this.texto,
    required this.textoSuave,
    required this.textoSecundario,
    required this.textoTenue,
    required this.dorado,
    required this.doradoTexto,
    required this.sobreDorado,
    required this.doradoFondo,
    required this.doradoBorde,
    required this.verde,
    required this.verdeFondo,
    required this.azul,
    required this.azulFondo,
    required this.naranja,
    required this.naranjaFondo,
    required this.rojo,
    required this.rojoFondo,
    required this.morado,
    required this.moradoFondo,
  });

  /// Fondo general de la ventana.
  final Color fondo;

  /// Fondo del menú lateral y de la barra inferior.
  final Color menu;

  /// Tarjetas y paneles.
  final Color superficie;

  /// Buscador y campos de texto.
  final Color superficieAlta;

  /// Elemento seleccionado del menú y etiquetas de género.
  final Color seleccion;

  final Color borde;
  final Color bordeFuerte;

  final Color texto;
  final Color textoSuave;
  final Color textoSecundario;
  final Color textoTenue;

  /// Dorado para rellenos (botones, insignias).
  final Color dorado;

  /// Dorado para textos y enlaces (más oscuro en modo claro para leerse bien).
  final Color doradoTexto;

  /// Texto encima de un relleno dorado.
  final Color sobreDorado;

  /// Fondo y borde de los avisos destacados ("Dónde está", "3 nuevas"…).
  final Color doradoFondo;
  final Color doradoBorde;

  // Colores de estado: correcto, información, aviso y error.
  final Color verde;
  final Color verdeFondo;
  final Color azul;
  final Color azulFondo;
  final Color naranja;
  final Color naranjaFondo;
  final Color rojo;
  final Color rojoFondo;

  /// Etiqueta de los datos de Wikidata.
  final Color morado;
  final Color moradoFondo;

  static const oscuro = ColoresVideoteca(
    fondo: Color(0xFF0F0E13),
    menu: Color(0xFF121117),
    superficie: Color(0xFF17151C),
    superficieAlta: Color(0xFF1A1820),
    seleccion: Color(0xFF24212C),
    borde: Color(0xFF26232E),
    bordeFuerte: Color(0xFF3A3645),
    texto: Color(0xFFF4EFE6),
    textoSuave: Color(0xFFD9D4E3),
    textoSecundario: Color(0xFFA8A3B3),
    textoTenue: Color(0xFF8E89A0),
    dorado: Color(0xFFE2AE4F),
    doradoTexto: Color(0xFFE2AE4F),
    sobreDorado: Color(0xFF1A1306),
    doradoFondo: Color(0xFF2A2213),
    doradoBorde: Color(0xFF5C4720),
    verde: Color(0xFF5FBF7A),
    verdeFondo: Color(0xFF15301F),
    azul: Color(0xFF7FB8E8),
    azulFondo: Color(0xFF16283A),
    naranja: Color(0xFFF0A35E),
    naranjaFondo: Color(0xFF3A2614),
    rojo: Color(0xFFF08A7E),
    rojoFondo: Color(0xFF3A1C1A),
    morado: Color(0xFFB49CE6),
    moradoFondo: Color(0xFF261E38),
  );

  static const claro = ColoresVideoteca(
    fondo: Color(0xFFF6F2EA),
    menu: Color(0xFFEFEAE0),
    superficie: Color(0xFFFFFFFF),
    superficieAlta: Color(0xFFFFFFFF),
    seleccion: Color(0xFFE8E0D2),
    borde: Color(0xFFE3DCCF),
    bordeFuerte: Color(0xFFCFC6B6),
    texto: Color(0xFF1B1922),
    textoSuave: Color(0xFF3A3645),
    textoSecundario: Color(0xFF5E5868),
    textoTenue: Color(0xFF6E6776),
    dorado: Color(0xFFE2AE4F),
    doradoTexto: Color(0xFF8A5D10),
    sobreDorado: Color(0xFF1A1306),
    doradoFondo: Color(0xFFFBEFD6),
    doradoBorde: Color(0xFFE6C98A),
    verde: Color(0xFF2E7D45),
    verdeFondo: Color(0xFFE3F2E7),
    azul: Color(0xFF2D6FA8),
    azulFondo: Color(0xFFE2EDF7),
    naranja: Color(0xFFA85A16),
    naranjaFondo: Color(0xFFF8E9DA),
    rojo: Color(0xFFB5443A),
    rojoFondo: Color(0xFFF7E1DE),
    morado: Color(0xFF6A4BB0),
    moradoFondo: Color(0xFFEDE6F8),
  );

  @override
  ColoresVideoteca copyWith() => this;

  @override
  ColoresVideoteca lerp(ColoresVideoteca? other, double t) =>
      other == null || t < 0.5 ? this : other;
}

/// Atajo: `context.colores.dorado`.
extension ColoresDelContexto on BuildContext {
  ColoresVideoteca get colores =>
      Theme.of(this).extension<ColoresVideoteca>() ?? ColoresVideoteca.oscuro;
}
