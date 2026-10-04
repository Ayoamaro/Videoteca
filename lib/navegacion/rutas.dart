import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../datos/catalogo.dart';
import '../pantallas/ajustes.dart';
import '../pantallas/bienvenida.dart';
import '../pantallas/catalogo.dart';
import '../pantallas/completar_coleccion.dart';
import '../pantallas/estadisticas.dart';
import '../pantallas/ficha.dart';
import '../pantallas/generos.dart';
import '../modelos/pelicula.dart';
import '../pantallas/inicio.dart';
import '../pantallas/lectura.dart';
import '../pantallas/mas.dart';
import '../pantallas/nuevas.dart';
import '../pantallas/pendientes.dart';
import '../utilidades.dart';
import 'marco.dart';

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
            pageBuilder: (c, e) => sinAnimacion(
              e,
              PantallaCatalogo(
                key: ValueKey(e.uri.toString()),
                busqueda: e.uri.queryParameters['q'] ?? '',
                genero: e.uri.queryParameters['genero'],
              ),
            ),
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
            path: '/pendientes',
            pageBuilder: (c, e) => sinAnimacion(e, const PantallaPendientes()),
          ),
          GoRoute(
            path: '/coleccion',
            pageBuilder: (c, e) =>
                sinAnimacion(e, const PantallaCompletarColeccion()),
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
