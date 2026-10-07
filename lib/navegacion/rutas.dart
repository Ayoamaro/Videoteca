import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../datos/buscador.dart';
import '../datos/catalogo.dart';
import '../datos/filtros.dart';
import '../fuentes/lote.dart' show TipoRepaso;
import '../pantallas/ajustes.dart';
import '../pantallas/bienvenida.dart';
import '../pantallas/catalogo.dart';
import '../pantallas/completar_coleccion.dart';
import '../pantallas/editar_ficha.dart';
import '../pantallas/estadisticas.dart';
import '../pantallas/ficha.dart';
import '../pantallas/generos.dart';
import '../modelos/pelicula.dart';
import '../pantallas/inicio.dart';
import '../pantallas/lectura.dart';
import '../pantallas/mas.dart';
import '../pantallas/nuevas.dart';
import '../pantallas/pendientes.dart';
import '../pantallas/registro.dart';
import '../utilidades.dart';
import 'marco.dart';

/// Pantallas que solo son del administrador.
bool _deAdministracion(String ruta) =>
    ruta.endsWith('/editar') ||
    const [
      '/bienvenida',
      '/nuevas',
      '/pendientes',
      '/coleccion',
      '/repaso',
      '/registro',
      '/lectura',
      '/archivo',
    ].any((r) => ruta == r || ruta.startsWith('$r/'));

/// Mapa de pantallas de la app. Cada "ruta" es como la dirección de una web:
/// `/catalogo`, `/pelicula/12`… Todas se muestran dentro del [Marco], menos el
/// asistente de bienvenida.
final rutasProvider = Provider<GoRouter>((ref) {
  Page<void> sinAnimacion(GoRouterState estado, Widget pantalla) =>
      NoTransitionPage(key: estado.pageKey, child: pantalla);

  return GoRouter(
    // Si aún no se ha elegido la carpeta de las películas, se empieza por el
    // asistente de primer arranque (solo el administrador, en el PC).
    redirect: (context, estado) {
      final sinCarpeta = ref.read(carpetaRaizProvider) == null;
      final enBienvenida = estado.uri.path == '/bienvenida';
      if (sinCarpeta && esAdministrador && !enBienvenida) return '/bienvenida';
      // En el modo consulta no se llega a ninguna pantalla de administración.
      if (!esAdministrador && _deAdministracion(estado.uri.path)) return '/';
      return null;
    },
    routes: [
      GoRoute(
        path: '/bienvenida',
        builder: (c, e) => const PantallaBienvenida(),
      ),
      ShellRoute(
        builder: (context, estado, hijo) =>
            Marco(ubicacion: estado.uri.path, child: hijo),
        routes: [
          GoRoute(
            path: '/',
            pageBuilder: (c, e) => sinAnimacion(e, const PantallaInicio()),
          ),
          GoRoute(
            path: '/catalogo',
            pageBuilder: (c, e) {
              // P. ej. `/catalogo?carpeta=Western&director=John%20Ford`:
              // `carpeta` es la de segundo nivel y `grupo` la de primero.
              final datos = e.uri.queryParameters;
              Set<String> uno(String clave) => {?datos[clave]};
              return sinAnimacion(
                e,
                PantallaCatalogo(
                  key: ValueKey(e.uri.toString()),
                  busqueda: datos['q'] ?? '',
                  ambito: AmbitoBusqueda.values.firstWhere(
                    (a) => a.name == datos['en'],
                    orElse: () => AmbitoBusqueda.todo,
                  ),
                  filtros: Filtros(
                    generos: uno('genero'),
                    grupos: uno('grupo'),
                    subcarpetas: uno('carpeta'),
                    desde: int.tryParse(datos['desde'] ?? ''),
                    hasta: int.tryParse(datos['hasta'] ?? ''),
                    paises: uno('pais'),
                    sagas: uno('saga'),
                    director: datos['director'],
                    actor: datos['actor'],
                  ),
                ),
              );
            },
          ),
          GoRoute(
            path: '/generos',
            pageBuilder: (c, e) => sinAnimacion(e, const PantallaGeneros()),
          ),
          GoRoute(
            path: '/pelicula/:id',
            pageBuilder: (c, e) => sinAnimacion(
              e,
              PantallaFicha(
                id: int.tryParse(e.pathParameters['id'] ?? '') ?? 0,
              ),
            ),
          ),
          GoRoute(
            path: '/pelicula/:id/editar',
            pageBuilder: (c, e) => sinAnimacion(
              e,
              PantallaEditarFicha(
                id: int.tryParse(e.pathParameters['id'] ?? '') ?? 0,
              ),
            ),
          ),
          GoRoute(
            path: '/registro',
            pageBuilder: (c, e) => sinAnimacion(e, const PantallaRegistro()),
          ),
          GoRoute(
            path: '/archivo',
            pageBuilder: (c, e) =>
                sinAnimacion(e, PantallaFicha(pelicula: e.extra as Pelicula?)),
          ),
          GoRoute(
            path: '/lectura',
            pageBuilder: (c, e) => sinAnimacion(e, const PantallaLectura()),
          ),
          GoRoute(
            path: '/estadisticas',
            pageBuilder: (c, e) =>
                sinAnimacion(e, const PantallaEstadisticas()),
          ),
          GoRoute(
            path: '/nuevas',
            pageBuilder: (c, e) => sinAnimacion(e, const PantallaNuevas()),
          ),
          GoRoute(
            path: '/nuevas/:id',
            pageBuilder: (c, e) {
              final id = int.tryParse(e.pathParameters['id'] ?? '') ?? 0;
              return sinAnimacion(
                e,
                // La clave hace que, al pasar a la siguiente, la pantalla
                // empiece de cero.
                PantallaEditarFicha(
                  key: ValueKey('completar-$id'),
                  id: id,
                  completar: true,
                ),
              );
            },
          ),
          GoRoute(
            path: '/pendientes',
            pageBuilder: (c, e) => sinAnimacion(e, const PantallaPendientes()),
          ),
          GoRoute(
            path: '/coleccion',
            pageBuilder: (c, e) =>
                sinAnimacion(e, const PantallaCompletarColeccion()),
          ),
          GoRoute(
            path: '/repaso/:tipo/:id',
            pageBuilder: (c, e) {
              final id = int.tryParse(e.pathParameters['id'] ?? '') ?? 0;
              return sinAnimacion(
                e,
                PantallaEditarFicha(
                  key: ValueKey('repaso-$id'),
                  id: id,
                  repaso:
                      TipoRepaso.porNombre(e.pathParameters['tipo']) ??
                      TipoRepaso.cortadas,
                ),
              );
            },
          ),
          GoRoute(
            path: '/ajustes',
            pageBuilder: (c, e) => sinAnimacion(e, const PantallaAjustes()),
          ),
          GoRoute(
            path: '/mas',
            pageBuilder: (c, e) => sinAnimacion(e, const PantallaMas()),
          ),
        ],
      ),
    ],
  );
});
