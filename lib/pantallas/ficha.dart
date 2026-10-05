
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../fuentes/filmaffinity.dart' show busquedaFilmaffinity;
import '../datos/buscador.dart';
import '../datos/catalogo.dart';
import '../disco/abrir_enlace.dart';
import '../disco/acciones_windows.dart';
import '../modelos/pelicula.dart';
import '../tema/colores.dart';
import '../tema/tema.dart';
import '../utilidades.dart';
import '../widgets/caratula.dart';
import '../widgets/comunes.dart';

/// Ficha completa de una película.
class PantallaFicha extends ConsumerWidget {
  const PantallaFicha({super.key, this.id = 0, this.pelicula});

  final int id;

  /// Película ya cargada (p. ej. leída directamente de un `.mp4`). Si no se
  /// da, se busca por [id].
  final Pelicula? pelicula;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = pelicula ?? ref.watch(peliculaPorIdProvider(id));
    if (p == null) {
      return PaginaBase(
        children: [
          _volver(context),
          const Text('No se ha encontrado la película.'),
        ],
      );
    }
    return LayoutBuilder(
      builder: (context, medidas) {
        final ancha = medidas.maxWidth >= 820;
        final columnaCaratula = Column(
          children: [
            _CaratulaGrande(p),
            // En el modo consulta no hay archivos: no se habla de ellos.
            if (esAdministrador) ...[
              const SizedBox(height: 14),
              Text(
                !p.tieneCaratula
                    ? 'Sin carátula incrustada'
                    : 'Carátula incrustada en el archivo',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: context.colores.textoTenue,
                ),
              ),
            ],
          ],
        );
        return PaginaBase(
          separacion: 20,
          children: [
            _volver(context),
            if (ancha)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 300, child: columnaCaratula),
                  const SizedBox(width: 40),
                  Expanded(child: _Detalles(p)),
                ],
              )
            else ...[
              Center(child: SizedBox(width: 220, child: columnaCaratula)),
              _Detalles(p),
            ],
          ],
        );
      },
    );
  }

  Widget _volver(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: () =>
            context.canPop() ? context.pop() : context.go('/catalogo'),
        icon: const Icon(Icons.chevron_left_rounded),
        label: const Text('Volver'),
        style: TextButton.styleFrom(
          foregroundColor: context.colores.textoSecundario,
          minimumSize: const Size(0, 44),
        ),
      ),
    );
  }
}

/// Carátula de la ficha: la completa leída del `.mp4`; mientras se lee (o si
/// el disco no está conectado), la miniatura.
class _CaratulaGrande extends ConsumerWidget {
  const _CaratulaGrande(this.p);

  final Pelicula p;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // En el modo consulta no hay archivo: solo la miniatura descargada.
    final completa = p.caratula != null || !p.tieneCaratula || !esAdministrador
        ? null
        : ref.watch(caratulaCompletaProvider(p.ruta)).value;
    return Caratula(
      titulo: p.titulo,
      anio: p.anio,
      tono: p.tono,
      imagen: p.caratula ?? completa,
      miniatura: p.miniatura,
    );
  }
}

class _Detalles extends ConsumerWidget {
  const _Detalles(this.p);

  final Pelicula p;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colores;
    final tema = Theme.of(context).textTheme;
    final separador = Text('•', style: TextStyle(color: c.bordeFuerte));
    final datos = [
      ('${p.anio}'),
      if (p.duracionTexto.isNotEmpty) p.duracionTexto,
      if (p.pais.isNotEmpty) p.pais,
    ];
    // Dirección y reparto se pueden pulsar para ver sus otras películas.
    final creditos = <(String, String, Papel?)>[
      ('Dirección', p.direccion, Papel.direccion),
      ('Guion', p.guion, null),
      ('Reparto', p.reparto, Papel.reparto),
      ('Música', p.musica, null),
      ('Fotografía', p.fotografia, null),
      ('Productora', p.productora, null),
      ('Premios', p.premios, null),
      ('Clasificación', p.clasificacion, null),
    ].where((e) => e.$2.isNotEmpty).toList();
    final saga = p.saga.isEmpty
        ? <Pelicula>[]
        : ((ref.watch(catalogoProvider).value ?? const <Pelicula>[])
              .where((o) => o.saga == p.saga)
              .toList()
            ..sort((a, b) => a.numeroSaga.compareTo(b.numeroSaga)));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          p.titulo,
          style: tema.headlineMedium?.copyWith(fontSize: 44, height: 1.05),
        ),
        if (p.tituloOriginal.isNotEmpty && p.tituloOriginal != p.titulo) ...[
          const SizedBox(height: 8),
          Text(
            p.tituloOriginal,
            style: TextStyle(
              fontSize: 18,
              fontStyle: FontStyle.italic,
              color: c.textoSecundario,
            ),
          ),
        ],
        const SizedBox(height: 20),
        Wrap(
          spacing: 14,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (var i = 0; i < datos.length; i++) ...[
              if (i > 0) separador,
              Text(
                datos[i],
                style: TextStyle(fontSize: 15, color: c.textoSuave),
              ),
            ],
            if (p.estrellas > 0) ...[separador, Estrellas(p.estrellas)],
            if (p.rottenTomatoes != null)
              Text(
                'Rotten Tomatoes ${p.rottenTomatoes} %',
                style: TextStyle(fontSize: 13, color: c.textoSecundario),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (p.edadCorta.isNotEmpty) InsigniaEdad(p.edadCorta),
            for (final g in p.generos) _etiqueta(context, g, relleno: true),
            for (final t in p.temas) _etiqueta(context, t, relleno: false),
          ],
        ),
        const SizedBox(height: 24),
        _DondeEsta(p),
        if (p.sinopsis.isNotEmpty) ...[
          const SizedBox(height: 24),
          const Etiqueta('Sinopsis'),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Text(
              p.sinopsis,
              style: TextStyle(fontSize: 16, height: 1.65, color: c.textoSuave),
            ),
          ),
        ],
        const SizedBox(height: 24),
        CuadriculaAdaptable(
          anchoMinimo: 280,
          separacion: 32,
          separacionVertical: 16,
          children: [
            for (final (nombre, valor, papel) in creditos)
              Container(
                padding: const EdgeInsets.only(top: 12),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: c.borde)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Etiqueta(nombre),
                    const SizedBox(height: 4),
                    if (papel == null)
                      Text(
                        valor,
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.5,
                          color: c.textoSuave,
                        ),
                      )
                    else
                      _NombresPulsables(valor, papel: papel, actual: p),
                  ],
                ),
              ),
          ],
        ),
        if (saga.length > 1) ...[
          const SizedBox(height: 28),
          Wrap(
            spacing: 12,
            crossAxisAlignment: WrapCrossAlignment.end,
            children: [
              Text('Saga · ${p.saga}', style: tema.titleLarge),
              Text(
                'Tienes ${saga.length} de ${saga.length}',
                style: TextStyle(fontSize: 14, color: c.textoSecundario),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: CuadriculaAdaptable(
              anchoMinimo: 110,
              separacion: 16,
              children: [
                for (final o in saga)
                  InkWell(
                    onTap: o.id == p.id
                        ? null
                        : () => context.pushReplacement('/pelicula/${o.id}'),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Caratula.de(o, mostrarNueva: false),
                        const SizedBox(height: 6),
                        Text(
                          '${o.numeroSaga} · ${o.anio}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: o.id == p.id ? c.doradoTexto : c.textoSuave,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
        _MasDelDirector(p),
        const SizedBox(height: 28),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.only(top: 20),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: c.borde)),
          ),
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              // Con enlace guardado se abre la ficha; si no, se busca la
              // película por el título.
              _BotonWeb(
                p.enlaceFilmaffinity.isNotEmpty
                    ? 'FilmAffinity'
                    : 'Buscar en FilmAffinity',
                p.enlaceFilmaffinity.isNotEmpty
                    ? p.enlaceFilmaffinity
                    : busquedaFilmaffinity(p.titulo),
              ),
              _BotonWeb(
                p.enlaceImdb.isNotEmpty ? 'IMDb' : 'Buscar en IMDb',
                p.enlaceImdb.isNotEmpty
                    ? p.enlaceImdb
                    : 'https://www.imdb.com/find/?q=${Uri.encodeQueryComponent('${p.tituloOriginal.isNotEmpty ? p.tituloOriginal : p.titulo} ${p.anio}')}',
              ),
              // Solo las películas del catálogo (no un archivo suelto abierto
              // desde Ajustes → Leer un archivo).
              if (esAdministrador && p.id > 0)
                OutlinedButton.icon(
                  onPressed: () => context.push('/pelicula/${p.id}/editar'),
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Editar ficha'),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _etiqueta(
    BuildContext context,
    String texto, {
    required bool relleno,
  }) {
    final c = context.colores;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: relleno ? c.seleccion : null,
        border: relleno ? null : Border.all(color: c.bordeFuerte),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        texto,
        style: TextStyle(
          fontSize: 13,
          fontWeight: relleno ? FontWeight.w600 : FontWeight.w400,
          color: relleno ? c.texto : c.textoSuave,
        ),
      ),
    );
  }
}

/// Insignia de edad con el color de la calificación española.
class InsigniaEdad extends StatelessWidget {
  const InsigniaEdad(this.edad, {super.key});

  final String edad;

  static const colores = {
    'TP': (Color(0xFF5FBF7A), Color(0xFF0B2414)),
    '7': (Color(0xFF7FB8E8), Color(0xFF0B1D2E)),
    '12': (Color(0xFFF2C94C), Color(0xFF1A1306)),
    '16': (Color(0xFFF0A35E), Color(0xFF2A1606)),
    '18': (Color(0xFFE5695C), Color(0xFF2A0D09)),
  };

  @override
  Widget build(BuildContext context) {
    // Edades sin color propio (10, 13…) toman el de la siguiente más alta.
    final n = int.tryParse(edad);
    final clave = n == null
        ? 'TP'
        : n <= 7
        ? '7'
        : n <= 13
        ? '12'
        : n <= 16
        ? '16'
        : '18';
    final (fondo, texto) = colores[clave]!;
    return Container(
      constraints: const BoxConstraints(minWidth: 40),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        edad == 'TP' ? 'TP' : '+$edad',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: texto,
        ),
      ),
    );
  }
}

/// Bloque dorado "Dónde está": ruta, calidad, tamaño y botones. Avisa si el
/// disco no está conectado o si el archivo ya no está en esa ruta.
class _DondeEsta extends ConsumerWidget {
  const _DondeEsta(this.p);

  final Pelicula p;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colores;
    final datos = [
      p.resolucion,
      p.tamanoTexto,
      if (p.anadida != null)
        'Añadida el ${p.anadida!.day}/${p.anadida!.month}/${p.anadida!.year}',
    ].where((t) => t.isNotEmpty);

    // Mientras se comprueba, se da por bueno (así no parpadea el aviso).
    final conectado = ref.watch(discoConectadoProvider).value ?? true;
    final existe = ref.watch(archivoExisteProvider(p.ruta)).value ?? true;
    final disponible = conectado && existe;
    final disco = nombreDisco(ref.watch(carpetaRaizProvider));
    final aviso = !esAdministrador
        ? null
        : !conectado
        ? 'No se puede reproducir: $disco no está conectado.'
        : !existe
        ? 'No se encuentra el archivo en esta ruta: puede que se haya movido, '
              'renombrado o borrado. Ajustes → Buscar cambios pone el catálogo '
              'al día.'
        : null;

    void error(String texto) => ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(texto)));

    return Tarjeta(
      fondo: c.doradoFondo,
      borde: c.doradoBorde,
      relleno: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.folder_outlined, size: 18, color: c.doradoTexto),
              const SizedBox(width: 10),
              Etiqueta('Dónde está', color: c.doradoTexto),
            ],
          ),
          const SizedBox(height: 12),
          SelectableText.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: p.carpeta,
                  style: TextStyle(color: c.textoSecundario),
                ),
                const TextSpan(text: '\n'),
                TextSpan(text: p.archivo),
              ],
            ),
            style: TextStyle(
              fontFamily: fuenteRutas,
              fontFamilyFallback: const ['Cascadia Mono', 'monospace'],
              fontSize: 15,
              height: 1.5,
              color: c.texto,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 18,
            runSpacing: 6,
            children: [
              for (final d in datos)
                Text(d, style: TextStyle(fontSize: 13, color: c.textoSuave)),
            ],
          ),
          if (aviso != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: c.rojoFondo,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    conectado
                        ? Icons.help_outline_rounded
                        : Icons.usb_off_rounded,
                    size: 18,
                    color: c.rojo,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      aviso,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.45,
                        color: c.texto,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (esAdministrador) ...[
                FilledButton.icon(
                  onPressed: !disponible
                      ? null
                      : () {
                          if (!abrirConWindows(p.ruta)) {
                            error('Windows no ha podido abrir la película.');
                          }
                        },
                  icon: const Icon(Icons.play_arrow_rounded, size: 18),
                  label: const Text('Reproducir'),
                ),
                OutlinedButton.icon(
                  onPressed: !disponible
                      ? null
                      : () {
                          if (!mostrarEnCarpeta(p.ruta)) {
                            error('No se ha podido abrir la carpeta.');
                          }
                        },
                  icon: const Icon(Icons.folder_open_outlined, size: 16),
                  label: const Text('Abrir carpeta'),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: c.doradoBorde),
                  ),
                ),
              ],
              OutlinedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: p.ruta));
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(
                      const SnackBar(content: Text('Ruta copiada.')),
                    );
                },
                icon: const Icon(Icons.copy_rounded, size: 16),
                label: const Text('Copiar ruta'),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: c.doradoBorde),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Botón que abre una web en el navegador.
class _BotonWeb extends StatelessWidget {
  const _BotonWeb(this.texto, this.direccion);

  final String texto;
  final String direccion;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () async {
        if (!await abrirEnlace(direccion) && context.mounted) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              const SnackBar(
                content: Text('No se ha podido abrir el navegador.'),
              ),
            );
        }
      },
      icon: const Icon(Icons.open_in_new_rounded, size: 16),
      label: Text(texto),
    );
  }
}

/// Lista de nombres ("Tom Hanks, Meg Ryan…") en la que cada uno se puede
/// pulsar para ver sus películas de la colección.
class _NombresPulsables extends ConsumerWidget {
  const _NombresPulsables(
    this.texto, {
    required this.papel,
    required this.actual,
  });

  final String texto;
  final Papel papel;
  final Pelicula actual;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nombres = separarNombres(texto);
    return Wrap(
      children: [
        for (var i = 0; i < nombres.length; i++)
          _NombrePulsable(
            nombres[i],
            coma: i < nombres.length - 1,
            total: ref
                .watch(peliculasDePersonaProvider((nombres[i], papel)))
                .length,
            alPulsar: () => mostrarPersona(context, nombres[i], papel, actual),
          ),
      ],
    );
  }
}

class _NombrePulsable extends StatefulWidget {
  const _NombrePulsable(
    this.nombre, {
    required this.coma,
    required this.total,
    required this.alPulsar,
  });

  final String nombre;
  final bool coma;

  /// Películas suyas en la colección (contando esta).
  final int total;
  final VoidCallback alPulsar;

  @override
  State<_NombrePulsable> createState() => _NombrePulsableState();
}

class _NombrePulsableState extends State<_NombrePulsable> {
  var _encima = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final otras = widget.total - 1;
    return Tooltip(
      message: otras <= 0
          ? 'Solo tienes esta película'
          : otras == 1
          ? 'Tienes 1 película más'
          : 'Tienes $otras películas más',
      waitDuration: const Duration(milliseconds: 500),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _encima = true),
        onExit: (_) => setState(() => _encima = false),
        child: GestureDetector(
          onTap: widget.alPulsar,
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: widget.nombre,
                  style: TextStyle(
                    color: _encima ? c.doradoTexto : c.texto,
                    decoration: TextDecoration.underline,
                    decorationColor: _encima ? c.doradoTexto : c.bordeFuerte,
                  ),
                ),
                // Cuántas tienes suyas (solo si hay más que esta).
                if (otras > 0)
                  TextSpan(
                    text: ' ${widget.total}',
                    style: TextStyle(fontSize: 12, color: c.textoTenue),
                  ),
                if (widget.coma) const TextSpan(text: ',  '),
              ],
            ),
            style: TextStyle(fontSize: 15, height: 1.5, color: c.textoSuave),
          ),
        ),
      ),
    );
  }
}

/// Ventana con las películas de una persona en la colección.
Future<void> mostrarPersona(
  BuildContext context,
  String nombre,
  Papel papel,
  Pelicula actual,
) {
  return showDialog<void>(
    context: context,
    builder: (contexto) => _VentanaPersona(nombre, papel, actual),
  );
}

class _VentanaPersona extends ConsumerWidget {
  const _VentanaPersona(this.nombre, this.papel, this.actual);

  final String nombre;
  final Papel papel;
  final Pelicula actual;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colores;
    final tema = Theme.of(context).textTheme;
    final peliculas = ref.watch(peliculasDePersonaProvider((nombre, papel)));
    final rol = papel == Papel.direccion ? 'Dirección' : 'Reparto';
    final router = GoRouter.of(context);
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 24, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Etiqueta(rol, color: c.doradoTexto),
                        const SizedBox(height: 4),
                        Text(nombre, style: tema.headlineSmall),
                        const SizedBox(height: 4),
                        Text(
                          peliculas.length <= 1
                              ? 'Solo tienes esta película en la colección.'
                              : '${peliculas.length} películas en tu colección',
                          style: TextStyle(
                            fontSize: 14,
                            color: c.textoSecundario,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cerrar',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(right: 12),
                  child: CuadriculaAdaptable(
                    anchoMinimo: 130,
                    separacion: 16,
                    separacionVertical: 20,
                    children: [
                      for (final o in peliculas)
                        _MiniTarjeta(
                          o,
                          actual: o.id == actual.id,
                          copia: o.id != actual.id && esCopia(o, actual),
                          alPulsar: () {
                            Navigator.of(context).pop();
                            if (o.id != actual.id) {
                              router.push('/pelicula/${o.id}');
                            }
                          },
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: TextButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      final clave = papel == Papel.direccion
                          ? 'director'
                          : 'actor';
                      router.go(
                        Uri(
                          path: '/catalogo',
                          queryParameters: {clave: nombre},
                        ).toString(),
                      );
                    },
                    icon: const Icon(Icons.grid_view_outlined, size: 16),
                    label: const Text('Ver en el Catálogo'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ¿Son la misma película en dos archivos? (Título y año iguales.)
bool esCopia(Pelicula a, Pelicula b) =>
    a.anio == b.anio && a.titulo.toLowerCase() == b.titulo.toLowerCase();

/// Carátula pequeña con título y año (ventana de una persona y "Más de…").
class _MiniTarjeta extends StatelessWidget {
  const _MiniTarjeta(
    this.p, {
    required this.alPulsar,
    this.actual = false,
    this.copia = false,
  });

  final Pelicula p;
  final VoidCallback alPulsar;

  /// Es la película de la ficha abierta (se marca en dorado).
  final bool actual;

  /// Es otra copia de la película abierta (mismo título y año, en otra
  /// carpeta).
  final bool copia;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    return InkWell(
      onTap: alPulsar,
      borderRadius: BorderRadius.circular(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Caratula.de(p, mostrarNueva: false),
          const SizedBox(height: 8),
          Text(
            p.titulo,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              height: 1.3,
              fontWeight: FontWeight.w600,
              color: actual ? c.doradoTexto : c.texto,
            ),
          ),
          Text(
            actual
                ? '${p.anio} · la que estás viendo'
                : copia
                ? '${p.anio} · otra copia'
                : '${p.anio}',
            style: TextStyle(fontSize: 12, color: c.textoSecundario),
          ),
        ],
      ),
    );
  }
}

/// "Más de Christopher Nolan": otras películas del director en la colección.
class _MasDelDirector extends ConsumerWidget {
  const _MasDelDirector(this.p);

  final Pelicula p;

  static const maximo = 6;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Con varios directores, el primero que tenga otras películas.
    for (final nombre in separarNombres(p.direccion)) {
      final otras = ref
          .watch(peliculasDePersonaProvider((nombre, Papel.direccion)))
          .where((o) => o.id != p.id)
          .toList();
      if (otras.isEmpty) continue;
      return Padding(
        padding: const EdgeInsets.only(top: 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TituloSeccion(
              'Más de $nombre',
              accion: otras.length > maximo
                  ? 'Ver las ${otras.length + 1}'
                  : null,
              alPulsar: () =>
                  mostrarPersona(context, nombre, Papel.direccion, p),
            ),
            const SizedBox(height: 14),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: CuadriculaAdaptable(
                anchoMinimo: 120,
                separacion: 16,
                separacionVertical: 20,
                children: [
                  for (final o in otras.take(maximo))
                    _MiniTarjeta(
                      o,
                      copia: esCopia(o, p),
                      alPulsar: () => context.push('/pelicula/${o.id}'),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }
}
