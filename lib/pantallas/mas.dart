import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../navegacion/marco.dart';
import '../tema/colores.dart';
import '../utilidades.dart';
import '../widgets/comunes.dart';

/// Pestaña "Más" de la barra inferior: el resto de secciones.
class PantallaMas extends StatelessWidget {
  const PantallaMas({super.key});

  @override
  Widget build(BuildContext context) {
    final destinos = [
      destinosColeccion[2], // Estadísticas
      if (esAdministrador)
        ...destinosAdministracion
      else
        destinosAdministracion.last, // Ajustes
    ];
    return PaginaBase(
      separacion: 20,
      children: [
        const CabeceraPagina(titulo: 'Más'),
        Tarjeta(
          relleno: EdgeInsets.zero,
          child: Column(
            children: [
              for (final d in destinos)
                ListTile(
                  leading: Icon(d.icono),
                  title: Text(
                    d.etiqueta,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  trailing: d.insignia != null
                      ? Insignia(d.insignia!, destacada: d.insigniaDestacada)
                      : Icon(
                          Icons.chevron_right_rounded,
                          color: context.colores.textoTenue,
                        ),
                  minTileHeight: 56,
                  onTap: () => context.go(d.ruta),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
