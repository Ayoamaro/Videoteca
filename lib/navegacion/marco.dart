import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../arranque.dart';
import '../datos/catalogo.dart';
import '../datos/consulta.dart';
import '../datos/lote.dart';
import '../datos/nuevas.dart';
import '../datos/publicacion.dart';
import '../datos/red_casa.dart';
import '../datos/vigilancia.dart';
import '../disco/escaner.dart';
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

// Las insignias (cuántas nuevas y cuántos pendientes) se ponen en el menú.
const destinosAdministracion = [
  Destino(
    '/nuevas',
    'Películas nuevas',
    Icons.download_outlined,
    insigniaDestacada: true,
  ),
  Destino('/pendientes', 'Pendientes', Icons.warning_amber_rounded),
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
  Widget build(BuildContext context) =>
      _Vigilancia(child: _AtajoBuscar(child: _construir(context)));

  Widget _construir(BuildContext context) {
    return LayoutBuilder(
      builder: (context, medidas) {
        if (medidas.maxWidth >= anchoEscritorio) {
          return Scaffold(
            body: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MenuLateral(activo: _activoEscritorio(ubicacion)),
                Expanded(child: _ConAviso(child: child)),
              ],
            ),
          );
        }
        final indice = _indiceMovil(ubicacion);
        // El botón «atrás» del móvil: si no hay nada a lo que volver dentro
        // de la pestaña, lleva a Inicio; desde Inicio, sale de la app.
        return PopScope(
          canPop: ubicacion == '/',
          onPopInvokedWithResult: (salio, _) {
            if (!salio) context.go('/');
          },
          child: _movil(context, indice),
        );
      },
    );
  }

  Widget _movil(BuildContext context, int indice) {
    return Scaffold(
      body: _ConAviso(child: child),
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
  }

  /// Qué entrada del menú lateral se ilumina según la pantalla actual.
  static String _activoEscritorio(String ruta) {
    if (ruta.startsWith('/pelicula') || ruta == '/generos') return '/catalogo';
    if (ruta.startsWith('/nuevas')) return '/nuevas';
    if (ruta.startsWith('/repaso') || ruta.startsWith('/dudosas')) {
      return '/coleccion';
    }
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

/// Ctrl + K desde cualquier pantalla: va a Inicio y pone el cursor en el
/// buscador.
class _AtajoBuscar extends ConsumerStatefulWidget {
  const _AtajoBuscar({required this.child});

  final Widget child;

  @override
  ConsumerState<_AtajoBuscar> createState() => _AtajoBuscarState();
}

class _AtajoBuscarState extends ConsumerState<_AtajoBuscar> {
  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_alPulsar);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_alPulsar);
    super.dispose();
  }

  bool _alPulsar(KeyEvent evento) {
    if (evento is! KeyDownEvent ||
        evento.logicalKey != LogicalKeyboardKey.keyK ||
        !HardwareKeyboard.instance.isControlPressed) {
      return false;
    }
    final foco = ref.read(focoBusquedaProvider);
    GoRouter.of(context).go('/');
    // Se espera a que Inicio esté en pantalla (si ya lo estaba, se fuerza un
    // redibujado para que la espera no sea eterna).
    WidgetsBinding.instance
      ..addPostFrameCallback((_) => foco.requestFocus())
      ..scheduleFrame();
    return true;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Vigila el disco mientras la app está abierta y avisa abajo de la pantalla
/// cuando aparecen, se mueven o desaparecen películas. En el modo consulta,
/// pone al día la copia del catálogo (al abrir y al volver a la app) y avisa
/// de las novedades; en un PC, además, mira desde el principio si se llega a
/// las películas por la red de casa (y otra vez al volver a la app).
class _Vigilancia extends ConsumerStatefulWidget {
  const _Vigilancia({required this.child});

  final Widget child;

  @override
  ConsumerState<_Vigilancia> createState() => _VigilanciaState();
}

class _VigilanciaState extends ConsumerState<_Vigilancia> {
  AppLifecycleListener? _ciclo;

  @override
  void initState() {
    super.initState();
    if (!esAdministrador) {
      _ciclo = AppLifecycleListener(
        onResume: () {
          ref.read(consultaProvider.notifier).comprobar(siHaceRato: true);
          if (hayRedDeCasa) ref.read(redCasaProvider.notifier).alVolver();
        },
      );
    }
  }

  @override
  void dispose() {
    _ciclo?.dispose();
    super.dispose();
  }

  void _avisar(String texto, {String? accion, VoidCallback? alPulsar}) =>
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(texto),
            duration: const Duration(seconds: 8),
            // Con botón, Flutter lo dejaría fijo hasta cerrarlo a mano.
            persist: false,
            action: accion == null
                ? null
                : SnackBarAction(label: accion, onPressed: alPulsar!),
          ),
        );

  @override
  Widget build(BuildContext context) {
    ref.watch(vigilanciaProvider);
    if (esAdministrador) {
      // Busca solas, en segundo plano, los datos de las películas nuevas.
      ref.listen(busquedasNuevasProvider, (_, _) {});
      // Publica sola en el tablón los cambios del catálogo.
      ref.listen(tablonProvider, (_, _) {});
    } else {
      if (hayRedDeCasa) ref.listen(redCasaProvider, (_, _) {});
      // Avisa cuando llega una versión nueva del catálogo (no la primera
      // descarga).
      ref.listen(consultaProvider.select((e) => e.ultimo), (_, r) {
        if (r == null || r.primera) return;
        _avisar(
          'Catálogo actualizado a la versión ${r.estado.version}: '
          '${textoNovedades(r)}',
        );
      });
    }
    ref.listen(avisoCambiosProvider, (_, resultado) {
      if (resultado == null) return;
      final unaNueva = resultado.idsNuevos.length == 1
          ? ref.read(peliculaPorIdProvider(resultado.idsNuevos.single))
          : null;
      final (texto, destino) = textoCambios(resultado, unaNueva?.titulo);
      _avisar(
        texto,
        accion: destino == null ? null : 'Ver',
        alPulsar: () =>
            GoRouter.of(context)
                .go(unaNueva != null ? '/nuevas/${unaNueva.id}' : destino!),
      );
    });
    return widget.child;
  }
}

/// Mensaje que resume los cambios encontrados y a qué pantalla llevar.
/// «Película nueva: Joy», «3 películas nuevas · 1 movida»…
(String, String?) textoCambios(ProgresoEscaneo r, String? tituloNueva) {
  String plural(int n, String una, String varias) =>
      n == 1 ? una : '${formatoNumero(n)} $varias';
  final partes = [
    if (r.nuevas == 1 && tituloNueva != null)
      'Película nueva: $tituloNueva'
    else if (r.nuevas > 0)
      plural(r.nuevas, '1 película nueva', 'películas nuevas'),
    if (r.movidas > 0)
      plural(r.movidas, '1 película movida', 'películas movidas'),
    if (r.actualizadas > 0)
      plural(
        r.actualizadas,
        '1 película actualizada',
        'películas actualizadas',
      ),
    if (r.recuperadas > 0)
      plural(r.recuperadas, '1 película ha vuelto', 'películas han vuelto'),
    if (r.desaparecidas > 0)
      plural(
        r.desaparecidas,
        '1 película ya no está en el disco',
        'películas ya no están en el disco',
      ),
  ];
  final destino = r.nuevas > 0
      ? '/nuevas'
      : r.desaparecidas > 0
      ? '/pendientes'
      : null;
  return (partes.join(' · '), destino);
}

/// Menú lateral del diseño de escritorio.
class MenuLateral extends ConsumerWidget {
  const MenuLateral({super.key, required this.activo});

  final String activo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colores;
    final insignias = {
      '/nuevas': ref.watch(nuevasSinGuardarProvider).length,
      '/pendientes': ref.watch(totalPendientesProvider),
    };
    // Mientras «Completar mi colección» trabaja, su entrada lo indica.
    final ocupados = {
      if (ref.watch(coleccionProvider.select((e) => e.trabajando)))
        '/coleccion',
    };
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
                    _grupo(context, 'Colección', destinosColeccion, const {}),
                    if (esAdministrador) ...[
                      const SizedBox(height: 28),
                      _grupo(
                        context,
                        'Administración',
                        destinosAdministracion,
                        insignias,
                        ocupados: ocupados,
                      ),
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

  Widget _grupo(
    BuildContext context,
    String titulo,
    List<Destino> destinos,
    Map<String, int> insignias, {
    Set<String> ocupados = const {},
  }) {
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
          _ElementoMenu(
            destino: d,
            activo: d.ruta == activo,
            insignia: insignias[d.ruta],
            ocupado: ocupados.contains(d.ruta),
          ),
          const SizedBox(height: 4),
        ],
      ],
    );
  }
}

class _ElementoMenu extends StatelessWidget {
  const _ElementoMenu({
    required this.destino,
    required this.activo,
    this.insignia,
    this.ocupado = false,
  });

  final Destino destino;
  final bool activo;

  /// Está trabajando en segundo plano (se ve una ruedecita).
  final bool ocupado;

  /// Número a la derecha (si es 0 no se enseña).
  final int? insignia;

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
                // Si está trabajando, una ruedecita en lugar del icono.
                if (ocupado)
                  Padding(
                    padding: const EdgeInsets.all(2),
                    child: SizedBox(
                      width: 15,
                      height: 15,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: c.dorado,
                        semanticsLabel: 'Trabajando',
                      ),
                    ),
                  )
                else
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
                if ((insignia ?? destino.insignia ?? 0) > 0)
                  Insignia(
                    insignia ?? destino.insignia!,
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

/// Pone encima de la pantalla una franja de aviso cuando el disco de la
/// colección no está conectado. En el modo consulta, mientras se descarga el
/// catálogo por primera vez o si la contraseña común ha cambiado.
class _ConAviso extends ConsumerWidget {
  const _ConAviso({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final franja = esAdministrador
        ? _franjaDisco(context, ref)
        : _franjaConsulta(context, ref);
    if (franja == null) return child;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        franja,
        Expanded(child: child),
      ],
    );
  }

  Widget? _franjaDisco(BuildContext context, WidgetRef ref) {
    final conectado = ref.watch(discoConectadoProvider).value ?? true;
    if (conectado) return null;
    final disco = nombreDisco(ref.watch(carpetaRaizProvider));
    return _Franja(
      icono: Icons.usb_off_rounded,
      texto:
          '${disco[0].toUpperCase()}${disco.substring(1)} no está '
          'conectado. Puedes seguir buscando en el catálogo; para '
          'reproducir, conéctalo.',
    );
  }

  Widget? _franjaConsulta(BuildContext context, WidgetRef ref) {
    final e = ref.watch(consultaProvider);
    if (e.fase == FaseCopia.contrasenaCambiada) {
      return _Franja(
        icono: Icons.key_off_outlined,
        texto:
            'La contraseña común ha cambiado. Puedes seguir viendo el '
            'catálogo descargado; para recibir las novedades, vuelve a entrar.',
        accion: 'Volver a entrar',
        alPulsar: () => ref.read(sesionProvider)?.cerrar(),
      );
    }
    // Lo demás, solo mientras no hay nada descargado.
    if (e.copia.commit.isNotEmpty) return null;
    if (e.fase == FaseCopia.error) {
      return _Franja(
        icono: e.sinInternet ? Icons.wifi_off_rounded : Icons.error_outline,
        texto: 'No se ha podido descargar el catálogo. ${e.error ?? ''}',
        accion: 'Reintentar',
        alPulsar: () => ref.read(consultaProvider.notifier).comprobar(),
      );
    }
    final p = e.progreso;
    return _Franja(
      icono: Icons.cloud_download_outlined,
      destacada: true,
      texto: p == null
          ? 'Conectando con el tablón…'
          : p.fase == 'fichas'
          ? 'Descargando el catálogo… (${p.hechos} de ${p.total} paquetes de '
                'fichas)'
          : 'Descargando las carátulas… (${p.hechos} de ${p.total}). Ya '
                'puedes buscar.',
      progreso: p == null || p.total == 0 ? null : p.hechos / p.total,
    );
  }
}

/// Franja de aviso de la parte de arriba (roja, o dorada si [destacada]).
class _Franja extends StatelessWidget {
  const _Franja({
    required this.icono,
    required this.texto,
    this.accion,
    this.alPulsar,
    this.destacada = false,
    this.progreso,
  });

  final IconData icono;
  final String texto;
  final String? accion;
  final VoidCallback? alPulsar;
  final bool destacada;
  final double? progreso;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final color = destacada ? c.doradoTexto : c.rojo;
    return Material(
      color: destacada ? c.doradoFondo : c.rojoFondo,
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                children: [
                  Icon(icono, size: 18, color: color),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      texto,
                      style: TextStyle(fontSize: 13, color: c.texto),
                    ),
                  ),
                  if (accion != null) ...[
                    const SizedBox(width: 12),
                    TextButton(onPressed: alPulsar, child: Text(accion!)),
                  ],
                ],
              ),
            ),
            if (destacada)
              LinearProgressIndicator(
                value: progreso,
                minHeight: 2,
                color: c.dorado,
                backgroundColor: Colors.transparent,
              ),
          ],
        ),
      ),
    );
  }
}

/// Recuadro inferior del menú: estado del disco y de la publicación.
class _Estado extends ConsumerWidget {
  const _Estado();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colores;
    final conectado = ref.watch(discoConectadoProvider).value ?? true;
    final disco = nombreDisco(ref.watch(carpetaRaizProvider));
    final vigilando = ref.watch(vigilanciaProvider);
    final revisando = ref.watch(escaneoProvider)?.enMarcha ?? false;
    // «Disco D: conectado»; si la raíz no es una unidad, «Carpeta …».
    final textoDisco = disco.startsWith('el ')
        ? '${disco.replaceFirst('el disco', 'Disco')} ${conectado ? 'conectado' : 'desconectado'}'
        : 'Carpeta ${conectado ? 'disponible' : 'no disponible'}';
    final estilo = TextStyle(fontSize: 13, color: c.textoSuave);
    return Tarjeta(
      relleno: const EdgeInsets.all(14),
      radio: 10,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!esAdministrador)
            _EstadoCopia(estilo: estilo)
          else
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: conectado ? c.verde : c.rojo,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    textoDisco,
                    style: estilo.copyWith(color: c.texto),
                  ),
                ),
              ],
            ),
          if (esAdministrador) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  revisando
                      ? Icons.sync_rounded
                      : vigilando
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 16,
                  color: c.textoSuave,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    revisando
                        ? 'Revisando cambios…'
                        : vigilando
                        ? 'Vigilando cambios'
                        : 'Sin vigilar cambios',
                    style: estilo,
                  ),
                ),
              ],
            ),
          ],
          if (esAdministrador) ...[
            const SizedBox(height: 10),
            _EstadoTablon(estilo: estilo),
          ],
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Divider(height: 1, color: c.borde),
          ),
          Text(
            esAdministrador ? 'Administrador · este PC' : 'Consulta',
            style: estilo.copyWith(color: c.textoSecundario),
          ),
        ],
      ),
    );
  }
}

/// Modo consulta: qué versión del catálogo hay descargada (pulsando, a
/// Ajustes).
class _EstadoCopia extends ConsumerWidget {
  const _EstadoCopia({required this.estilo});

  final TextStyle estilo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colores;
    final e = ref.watch(consultaProvider);
    final version = e.copia.version;
    final (icono, texto, color) = switch (e.fase) {
      FaseCopia.buscando => (Icons.sync_rounded, 'Buscando novedades…', null),
      FaseCopia.descargando => (
        Icons.cloud_download_outlined,
        'Descargando…',
        null,
      ),
      FaseCopia.contrasenaCambiada => (
        Icons.key_off_outlined,
        'Hay que volver a entrar',
        c.rojo,
      ),
      FaseCopia.error when version == 0 => (
        Icons.cloud_off_outlined,
        'Sin descargar',
        c.rojo,
      ),
      FaseCopia.error => (
        Icons.cloud_off_outlined,
        e.sinInternet
            ? 'Sin internet · v$version'
            : 'Sin actualizar · v$version',
        null,
      ),
      _ when version == 0 => (Icons.cloud_outlined, 'Sin descargar', null),
      _ => (Icons.cloud_done_outlined, 'Catálogo v$version', null),
    };
    return InkWell(
      onTap: () => context.go('/ajustes'),
      borderRadius: BorderRadius.circular(6),
      child: Row(
        children: [
          Icon(icono, size: 16, color: color ?? c.textoSuave),
          const SizedBox(width: 8),
          Flexible(
            child: Text(texto, style: estilo.copyWith(color: color ?? c.texto)),
          ),
        ],
      ),
    );
  }
}

/// Cómo va la publicación en el tablón (pulsando, a Ajustes).
class _EstadoTablon extends ConsumerWidget {
  const _EstadoTablon({required this.estilo});

  final TextStyle estilo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colores;
    final t = ref.watch(tablonProvider);
    final (icono, texto, color) = switch (t.fase) {
      _ when !t.configurado => (Icons.cloud_off_outlined, 'Sin publicar', null),
      FasePublicacion.publicando => (
        Icons.cloud_upload_outlined,
        'Publicando…',
        null,
      ),
      FasePublicacion.esperando => (
        Icons.cloud_queue_outlined,
        'Cambios por publicar',
        null,
      ),
      FasePublicacion.error => (
        Icons.cloud_off_outlined,
        'Sin publicar',
        c.rojo,
      ),
      _ when t.version == 0 => (Icons.cloud_outlined, 'Sin publicar', null),
      _ => (Icons.cloud_done_outlined, 'Publicada v${t.version}', null),
    };
    return InkWell(
      onTap: () => context.go('/ajustes'),
      borderRadius: BorderRadius.circular(6),
      child: Row(
        children: [
          Icon(icono, size: 16, color: color ?? c.textoSuave),
          const SizedBox(width: 8),
          Flexible(
            child: Text(texto, style: estilo.copyWith(color: color)),
          ),
        ],
      ),
    );
  }
}
