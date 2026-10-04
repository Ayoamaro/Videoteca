import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../datos/catalogo.dart';
import '../widgets/comunes.dart';
import 'inicio.dart' show BotonGenero;

/// Lista de géneros (pestaña "Géneros" del móvil).
class PantallaGeneros extends ConsumerWidget {
  const PantallaGeneros({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PaginaBase(
      separacion: 20,
      children: [
        const CabeceraPagina(titulo: 'Géneros'),
        CuadriculaAdaptable(
          anchoMinimo: 200,
          separacion: 10,
          children: [
            for (final (nombre, total) in ref.watch(generosProvider))
              BotonGenero(
                nombre: nombre,
                total: total,
                alPulsar: () => context.go(
                  '/catalogo?carpeta=${Uri.encodeQueryComponent(nombre)}',
                ),
              ),
          ],
        ),
      ],
    );
  }
}
