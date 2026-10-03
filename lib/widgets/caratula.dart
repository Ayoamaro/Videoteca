import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../modelos/pelicula.dart';
import '../tema/colores.dart';
import '../tema/tema.dart';

/// Carátula de una película, en proporción 7:10 (como las de 350 × 500).
///
/// Si la película tiene carátula incrustada, la muestra. Si no, dibuja una
/// provisional con el color, el título y el año. Se adapta sola al ancho que
/// le den: en tamaños pequeños (listas) oculta los textos.
class Caratula extends StatelessWidget {
  const Caratula({
    super.key,
    this.titulo = '',
    this.anio,
    this.tono = const Color(0xFF2E4034),
    this.nueva = false,
    this.imagen,
  });

  Caratula.de(Pelicula p, {super.key, bool mostrarNueva = true})
    : titulo = p.titulo,
      anio = p.anio,
      tono = p.tono,
      nueva = mostrarNueva && p.nueva,
      imagen = p.caratula;

  final String titulo;
  final int? anio;
  final Color tono;
  final bool nueva;
  final Uint8List? imagen;

  static const proporcion = 7 / 10;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: proporcion,
      child: LayoutBuilder(
        builder: (context, medidas) {
          final ancho = medidas.maxWidth;
          final radio = ancho < 60 ? 4.0 : 8.0;
          return DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radio),
              boxShadow: ancho < 60
                  ? null
                  : const [
                      BoxShadow(
                        color: Color(0x73000000),
                        blurRadius: 28,
                        offset: Offset(0, 10),
                      ),
                    ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(radio),
              child: imagen != null
                  ? Image.memory(imagen!, fit: BoxFit.cover)
                  : _provisional(context, ancho),
            ),
          );
        },
      ),
    );
  }

  Widget _provisional(BuildContext context, double ancho) {
    // Tamaños proporcionales al ancho (175 px de ancho → título de 19 px).
    final tamTitulo = (ancho * 0.108).clamp(9.0, 34.0);
    final margen = (ancho * 0.09).clamp(6.0, 24.0);
    final marco = (ancho * 0.045).clamp(3.0, 12.0);
    final conTexto = ancho >= 60;
    const crema = Color(0xFFF4EFE6);

    return Container(
      color: tono,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            left: marco,
            top: marco,
            right: marco,
            bottom: marco,
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0x2EF4EFE6)),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            width: ancho * 0.55,
            height: ancho / proporcion * 0.45,
            child: const DecoratedBox(
              decoration: BoxDecoration(
                color: Color(0x0DFFFFFF),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.elliptical(9999, 9999),
                ),
              ),
            ),
          ),
          if (nueva && ancho >= 90)
            Positioned(
              top: 10,
              left: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: context.colores.dorado,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'NUEVA',
                  style: TextStyle(
                    fontFamily: fuenteTexto,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: context.colores.sobreDorado,
                  ),
                ),
              ),
            ),
          if (conTexto)
            Positioned(
              left: margen,
              right: margen,
              bottom: margen,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    titulo.toUpperCase(),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: fuenteTitulos,
                      fontSize: tamTitulo,
                      fontWeight: FontWeight.w700,
                      height: 1.02,
                      color: crema,
                    ),
                  ),
                  if (anio != null) ...[
                    SizedBox(height: tamTitulo * 0.3),
                    Text(
                      '$anio',
                      style: TextStyle(
                        fontFamily: fuenteTexto,
                        fontSize: (tamTitulo * 0.63).clamp(9.0, 16.0),
                        color: crema.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}
