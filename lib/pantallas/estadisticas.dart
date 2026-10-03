import 'package:flutter/material.dart';

import '../tema/colores.dart';
import '../widgets/comunes.dart';

/// Estadísticas de la colección (llegan el día 17).
class PantallaEstadisticas extends StatelessWidget {
  const PantallaEstadisticas({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    return PaginaBase(
      children: [
        const CabeceraPagina(
          titulo: 'Estadísticas',
          descripcion:
              'Películas por género, década y país, directores y actores más '
              'presentes y sagas incompletas.',
        ),
        Tarjeta(
          relleno: const EdgeInsets.symmetric(vertical: 60, horizontal: 24),
          child: Column(
            children: [
              Icon(Icons.bar_chart_rounded, size: 48, color: c.textoTenue),
              const SizedBox(height: 12),
              Text(
                'Esta pantalla llega el día 17.',
                style: TextStyle(fontSize: 15, color: c.textoSecundario),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
