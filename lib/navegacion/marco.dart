import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../tema/colores.dart';
import '../tema/tema.dart';
import '../utilidades.dart';
import '../widgets/comunes.dart';

/// Una entrada del menú.
class Destino {
  const Destino(
    this.ruta,
    this.etiqueta,
    this.icono, {
    this.insignia,
    this.insigniaDestacada = false,
  });

  final String ruta;
  final String etiqueta;
  final IconData icono;
  final int? insignia;
  final bool insigniaDestacada;
}

const destinosColeccion = [
  Destino('/', 'Inicio', Icons.home_outlined),
  Destino('/catalogo', 'Catálogo', Icons.grid_view_outlined),
  Destino('/estadisticas', 'Estadísticas', Icons.bar_chart_rounded),
];

// Las insignias son datos de ejemplo hasta que la app lea el disco.
const destinosAdministracion = [
  Destino(
    '/nuevas',
    'Películas nuevas',
    Icons.download_outlined,
    insignia: 3,
    insigniaDestacada: true,
  ),
  Destino(
    '/pendientes',
    'Pendientes',
    Icons.warning_amber_rounded,
    insignia: 57,
  ),
  Destino('/coleccion', 'Completar colección', Icons.layers_outlined),
  Destino('/ajustes', 'Ajustes', Icons.settings_outlined),
];

/// Pestañas de la barra inferior (pantallas estrechas, como el móvil).
const destinosMovil = [
  Destino('/', 'Inicio', Icons.home_outlined),
  Destino('/catalogo', 'Buscar', Icons.search_rounded),
  Destino('/generos', 'Géneros', Icons.grid_view_outlined),
  Destino('/mas', 'Más', Icons.menu_rounded),
];

/// Marco común de todas las pantallas: menú lateral en ventanas anchas
/// (Windows) y barra inferior en estrechas (Android).
class Marco extends StatelessWidget {
  const Marco({super.key, required this.ubicacion, required this.child});

  final String ubicacion;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, medidas) {
        if (medidas.maxWidth >= anchoEscritorio) {
          return Scaffold(
            body: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MenuLateral(activo: _activoEscritorio(ubicacion)),
                Expanded(child: child),
              ],
            ),
          );
        }
        final indice = _indiceMovil(ubicacion);
        return Scaffold(
          body: child,
          bottomNavigationBar: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: context.colores.borde)),
            ),
            child: NavigationBar(
              selectedIndex: indice,
              onDestinationSelected: (i) => context.go(destinosMovil[i].ruta),
              destinations: [
                for (final d in destinosMovil)
                  NavigationDestination(icon: Icon(d.icono), label: d.etiqueta),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Qué entrada del menú lateral se ilumina según la pantalla actual.
  static String _activoEscritorio(String ruta) {
    if (ruta.startsWith('/pelicula') || ruta == '/generos') return '/catalogo';
    if (ruta == '/mas' || ruta == '/lectura' || ruta == '/archivo') {
      return '/ajustes';
    }
    return ruta;
  }

  static int _indiceMovil(String ruta) {
    if (ruta == '/') return 0;
    if (ruta.startsWith('/catalogo') || ruta.startsWith('/pelicula')) return 1;
    if (ruta == '/generos') return 2;
    return 3;
  }
}

/// Menú lateral del diseño de escritorio.
class MenuLateral extends StatelessWidget {
  const MenuLateral({super.key, required this.activo});

  final String activo;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    return Container(
      width: 248,
      decoration: BoxDecoration(
        color: c.menu,
        border: Border(right: BorderSide(color: c.borde)),
      ),
      child: LayoutBuilder(
        builder: (context, medidas) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: medidas.maxHeight),
            child: IntrinsicHeight(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 28, 16, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _logo(context),
                    const SizedBox(height: 28),
                    _grupo(context, 'Colección', destinosColeccion),
                    if (esAdministrador) ...[
                      const SizedBox(height: 28),
                      _grupo(context, 'Administración', destinosAdministracion),
                    ] else ...[
                      const SizedBox(height: 4),
                      _ElementoMenu(
                        destino: destinosAdministracion.last,
                        activo: activo == '/ajustes',
                      ),
                    ],
                    const Spacer(),
                    const SizedBox(height: 20),
                    const _Estado(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _logo(BuildContext context) {
    return InkWell(
      onTap: () => context.go('/'),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            Icon(Icons.movie_outlined, size: 28, color: context.colores.dorado),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                'Videoteca',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: fuenteTitulos,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: context.colores.texto,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _grupo(BuildContext context, String titulo, List<Destino> destinos) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
          child: Text(
            titulo.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.3,
              color: context.colores.textoTenue,
            ),
          ),
        ),
        for (final d in destinos) ...[
          _ElementoMenu(destino: d, activo: d.ruta == activo),
          const SizedBox(height: 4),
        ],
      ],
    );
  }
}

class _ElementoMenu extends StatelessWidget {
  const _ElementoMenu({required this.destino, required this.activo});

  final Destino destino;
  final bool activo;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final color = activo ? c.texto : c.textoSecundario;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Material(
        color: activo ? c.seleccion : Colors.transparent,
        child: InkWell(
          onTap: () => context.go(destino.ruta),
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: activo
                ? BoxDecoration(
                    border: Border(left: BorderSide(color: c.dorado, width: 3)),
                  )
                : null,
            child: Row(
              children: [
                Icon(destino.icono, size: 19, color: color),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    destino.etiqueta,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ),
                if (destino.insignia != null)
                  Insignia(
                    destino.insignia!,
                    destacada: destino.insigniaDestacada,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Recuadro inferior del menú: estado del disco y de la publicación.
class _Estado extends StatelessWidget {
  const _Estado();

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final estilo = TextStyle(fontSize: 13, color: c.textoSuave);
    return Tarjeta(
      relleno: const EdgeInsets.all(14),
      radio: 10,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: c.verde,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Disco D: conectado',
                  style: estilo.copyWith(color: c.texto),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.cloud_outlined, size: 16, color: c.textoSuave),
              const SizedBox(width: 8),
              Flexible(child: Text('Publicado hace 2 min', style: estilo)),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Divider(height: 1, color: c.borde),
          ),
          Text(
            esAdministrador ? 'Administrador · este PC' : 'Consulta',
            style: estilo.copyWith(color: c.textoSecundario),
          ),
          const SizedBox(height: 4),
          Text(
            'Datos de ejemplo',
            style: estilo.copyWith(fontSize: 12, color: c.doradoTexto),
          ),
        ],
      ),
    );
  }
}
