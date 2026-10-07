import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../datos/estadisticas.dart';
import '../datos/fuentes.dart';
import '../datos/sagas.dart';
import '../modelos/pelicula.dart';
import '../pantallas/nuevas.dart' show cuandoTexto;
import '../tema/colores.dart';
import '../utilidades.dart';
import '../widgets/coleccion_vacia.dart';
import '../widgets/comunes.dart';
import '../widgets/exportar.dart';

/// Estadísticas de la colección: resumen, películas por género, década y
/// país, directores y actores con más películas y sagas incompletas. Cada
/// barra lleva al Catálogo con ese filtro puesto.
class PantallaEstadisticas extends ConsumerWidget {
  const PantallaEstadisticas({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final e = ref.watch(estadisticasProvider).value;
    return PaginaBase(
      separacion: 22,
      children: [
        CabeceraPagina(
          titulo: 'Estadísticas',
          descripcion: e == null || e.peliculas == 0
              ? null
              : 'Tu colección en números. Pulsa cualquier barra para ver esas '
                    'películas en el Catálogo.',
          acciones: [
            if (puedeAdministrar && (e?.peliculas ?? 0) > 0)
              OutlinedButton.icon(
                onPressed: () => exportarExcel(context, ref),
                icon: const Icon(Icons.table_view_outlined, size: 18),
                label: const Text('Exportar a Excel'),
              ),
          ],
        ),
        if (e == null)
          const Padding(
            padding: EdgeInsets.all(60),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (e.peliculas == 0)
          const ColeccionVacia()
        else ...[
          _Resumen(e),
          _Decadas(e.decadas),
          CuadriculaAdaptable(
            anchoMinimo: 420,
            separacion: 18,
            children: [
              _ListaBarras(
                titulo: 'Géneros',
                datos: e.generos,
                enlace: (n) => _catalogo({'genero': n}),
              ),
              _ListaBarras(
                titulo: 'Países',
                datos: e.paises,
                enlace: (n) => _catalogo({'pais': n}),
              ),
              _ListaBarras(
                titulo: 'Directores con más películas',
                datos: e.directores,
                enlace: (n) => _catalogo({'director': n}),
              ),
              _ListaBarras(
                titulo: 'Actores con más películas',
                datos: e.actores,
                enlace: (n) => _catalogo({'actor': n}),
              ),
            ],
          ),
          _Sagas(e),
        ],
      ],
    );
  }
}

String _catalogo(Map<String, String> filtro) =>
    Uri(path: '/catalogo', queryParameters: filtro).toString();

// ── Resumen ──────────────────────────────────────────────────────────────

class _Resumen extends StatelessWidget {
  const _Resumen(this.e);

  final Estadisticas e;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final horas = e.minutos ~/ 60;
    final tb = e.bytes / (1 << 40);
    final espacio = tb >= 1
        ? '${_decimal(tb)} TB'
        : '${formatoNumero(e.bytes ~/ (1 << 30))} GB';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CuadriculaAdaptable(
          anchoMinimo: 200,
          separacion: 12,
          children: [
            Contador(
              valor: formatoNumero(e.peliculas),
              texto: 'películas',
              color: c.doradoTexto,
              fondo: c.doradoFondo,
              colorTexto: c.textoSuave,
            ),
            Contador(
              valor: '${formatoNumero(horas)} h',
              texto: 'de cine (${formatoNumero(horas ~/ 24)} días)',
            ),
            if (e.bytes > 0) Contador(valor: espacio, texto: 'en el disco'),
            if (e.mediaEstrellas > 0)
              Contador(
                valor: '${_decimal(e.mediaEstrellas)} ★',
                texto: 'estrellas de media',
              ),
            if (e.sagas > 0)
              Contador(
                valor: formatoNumero(e.sagas),
                texto: 'sagas, ${formatoNumero(e.sagasCompletas)} completas',
              ),
          ],
        ),
        if (e.masAntigua != null || e.masLarga != null) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (e.masAntigua case final p?)
                _Curiosidad(
                  icono: Icons.history_rounded,
                  texto: 'La más antigua',
                  pelicula: p,
                  dato: '${p.anio}',
                ),
              if (e.masLarga case final p?)
                _Curiosidad(
                  icono: Icons.timer_outlined,
                  texto: 'La más larga',
                  pelicula: p,
                  dato: p.duracionTexto,
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// «3,4» (con coma decimal).
String _decimal(double n) => n.toStringAsFixed(1).replaceAll('.', ',');

/// Un dato curioso con su película (al pulsarlo, abre la ficha).
class _Curiosidad extends StatelessWidget {
  const _Curiosidad({
    required this.icono,
    required this.texto,
    required this.pelicula,
    required this.dato,
  });

  final IconData icono;
  final String texto;
  final Pelicula pelicula;
  final String dato;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    return Material(
      color: c.superficie,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: c.borde),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => context.push('/pelicula/${pelicula.id}'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icono, size: 18, color: c.doradoTexto),
              const SizedBox(width: 10),
              Flexible(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '$texto: ',
                        style: TextStyle(color: c.textoSecundario),
                      ),
                      TextSpan(
                        text: pelicula.titulo,
                        style: TextStyle(
                          color: c.texto,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      TextSpan(
                        text: ' · $dato',
                        style: TextStyle(color: c.textoSecundario),
                      ),
                    ],
                  ),
                  style: const TextStyle(fontSize: 13.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Décadas ──────────────────────────────────────────────────────────────

/// Columnas verticales, una por década.
class _Decadas extends StatelessWidget {
  const _Decadas(this.decadas);

  final List<(int, int)> decadas;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final maximo = decadas.fold(0, (m, d) => d.$2 > m ? d.$2 : m);
    return Tarjeta(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Por década', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, medidas) {
              final ancho = medidas.maxWidth / decadas.length;
              // Si no cabe «1980», se escribe «’80».
              final corta = ancho < 46;
              return SizedBox(
                height: 200,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (final (decada, total) in decadas)
                      Expanded(
                        child: Tooltip(
                          message:
                              'Años ${decada % 100 == 0 ? decada : decada % 100}: '
                              '${formatoNumero(total)} películas',
                          child: InkWell(
                            borderRadius: BorderRadius.circular(6),
                            onTap: total == 0
                                ? null
                                : () => context.go(
                                    _catalogo({
                                      'desde': '$decada',
                                      'hasta': '${decada + 9}',
                                    }),
                                  ),
                            child: _Columna(
                              total: total,
                              proporcion: maximo == 0 ? 0 : total / maximo,
                              etiqueta: corta
                                  ? '’${(decada % 100).toString().padLeft(2, '0')}'
                                  : '$decada',
                              colorBarra: c.dorado,
                              colorTexto: c.textoSecundario,
                              estrecha: ancho < 30,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Columna extends StatelessWidget {
  const _Columna({
    required this.total,
    required this.proporcion,
    required this.etiqueta,
    required this.colorBarra,
    required this.colorTexto,
    required this.estrecha,
  });

  final int total;
  final double proporcion;
  final String etiqueta;
  final Color colorBarra;
  final Color colorTexto;
  final bool estrecha;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: estrecha ? 2 : 5),
      child: Column(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                FittedBox(
                  child: Text(
                    total > 0 ? formatoNumero(total) : '',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: colorTexto,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                // La barra ocupa su parte del sitio que queda.
                Flexible(
                  child: FractionallySizedBox(
                    heightFactor: proporcion,
                    child: Container(
                      constraints: BoxConstraints(minHeight: total > 0 ? 3 : 0),
                      decoration: BoxDecoration(
                        color: colorBarra,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            child: Text(
              etiqueta,
              style: TextStyle(fontSize: 12, color: colorTexto),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Listas con barras ────────────────────────────────────────────────────

/// Los primeros de una lista (nombre y número de películas) con una barra
/// cada uno; «Ver más» enseña más.
class _ListaBarras extends StatefulWidget {
  const _ListaBarras({
    required this.titulo,
    required this.datos,
    required this.enlace,
  });

  final String titulo;
  final List<(String, int)> datos;
  final String Function(String nombre) enlace;

  @override
  State<_ListaBarras> createState() => _ListaBarrasState();
}

class _ListaBarrasState extends State<_ListaBarras> {
  static const _primeros = 10;
  static const _mas = 40;
  var _cuantos = _primeros;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final datos = widget.datos;
    final visibles = datos.take(_cuantos).toList();
    final maximo = datos.isEmpty ? 1 : datos.first.$2;
    return Tarjeta(
      relleno: const EdgeInsets.fromLTRB(22, 22, 22, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.titulo, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          if (datos.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Ninguna ficha tiene este dato todavía.',
                style: TextStyle(color: c.textoSecundario),
              ),
            ),
          for (final (nombre, total) in visibles)
            _FilaBarra(
              nombre: nombre,
              total: total,
              proporcion: total / maximo,
              alPulsar: () => context.go(widget.enlace(nombre)),
            ),
          if (datos.length > _primeros)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => setState(
                  () => _cuantos = _cuantos >= _mas || _cuantos >= datos.length
                      ? _primeros
                      : _mas,
                ),
                child: Text(
                  _cuantos >= _mas || _cuantos >= datos.length
                      ? 'Ver menos'
                      : 'Ver más',
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FilaBarra extends StatelessWidget {
  const _FilaBarra({
    required this.nombre,
    required this.total,
    required this.proporcion,
    required this.alPulsar,
  });

  final String nombre;
  final int total;
  final double proporcion;
  final VoidCallback alPulsar;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: alPulsar,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    nombre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 14, color: c.texto),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  formatoNumero(total),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: c.textoSuave,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            _Barra(proporcion: proporcion, color: c.dorado, fondo: c.seleccion),
          ],
        ),
      ),
    );
  }
}

class _Barra extends StatelessWidget {
  const _Barra({
    required this.proporcion,
    required this.color,
    required this.fondo,
  });

  final double proporcion;
  final Color color;
  final Color fondo;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: SizedBox(
        height: 6,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: fondo),
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: proporcion.clamp(0.0, 1.0),
              child: ColoredBox(color: color),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Sagas incompletas ────────────────────────────────────────────────────

class _Sagas extends ConsumerStatefulWidget {
  const _Sagas(this.e);

  final Estadisticas e;

  @override
  ConsumerState<_Sagas> createState() => _SagasState();
}

class _SagasState extends ConsumerState<_Sagas> {
  static const _primeras = 12;
  var _todas = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final e = widget.e;
    final estado = ref.watch(sagasTmdbProvider);
    final hayClave =
        esAdministrador &&
        puedeAdministrar &&
        (ref.watch(clavesProvider)[Servicio.tmdb] ?? '').isNotEmpty;
    final incompletas = e.sagasIncompletas;
    final visibles = _todas ? incompletas : incompletas.take(_primeras);
    final comprobadas = estado.datos;

    final explicacion = comprobadas != null
        ? 'Comprobadas en TMDB (${cuandoTexto(comprobadas.fecha).toLowerCase()}). '
              'Las que TMDB no conoce se cuentan por el número de cada '
              'película en la saga.'
        : hayClave
        ? 'Por ahora se cuentan por el número de cada película en la saga: '
              'si te falta la última, no se nota. Compruébalas en TMDB para '
              'saber cuántas tiene de verdad cada saga y cuáles te faltan.'
        : 'Se cuentan por el número de cada película en la saga: si te '
              'falta la última, no se nota.';

    return Tarjeta(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 10,
            children: [
              Text(
                incompletas.isEmpty
                    ? 'Sagas incompletas'
                    : 'Sagas incompletas (${formatoNumero(incompletas.length)})',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (hayClave)
                OutlinedButton.icon(
                  onPressed: estado.comprobando
                      ? null
                      : () => ref.read(sagasTmdbProvider.notifier).comprobar(),
                  icon: const Icon(Icons.travel_explore_rounded, size: 18),
                  label: Text(
                    comprobadas == null
                        ? 'Comprobar en TMDB'
                        : 'Volver a comprobar',
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            explicacion,
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: c.textoSecundario,
            ),
          ),
          if (estado.comprobando) ...[
            const SizedBox(height: 14),
            Text(
              'Comprobando en TMDB… ${formatoNumero(estado.hechas)} de '
              '${formatoNumero(estado.total)} sagas',
              style: TextStyle(fontSize: 13, color: c.textoSuave),
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: estado.total == 0 ? null : estado.hechas / estado.total,
              color: c.dorado,
              backgroundColor: c.seleccion,
              borderRadius: BorderRadius.circular(3),
            ),
          ],
          if (estado.error != null) ...[
            const SizedBox(height: 12),
            Text(
              'No se ha podido comprobar: ${estado.error}',
              style: TextStyle(fontSize: 13, color: c.rojo),
            ),
          ],
          const SizedBox(height: 10),
          if (incompletas.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                e.sagas == 0
                    ? 'Ninguna película tiene saga todavía.'
                    : '¡Todas tus sagas están completas!',
                style: TextStyle(color: c.textoSuave),
              ),
            ),
          for (final s in visibles) _FilaSaga(s),
          if (incompletas.length > _primeras)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => setState(() => _todas = !_todas),
                child: Text(
                  _todas
                      ? 'Ver menos'
                      : 'Ver las ${formatoNumero(incompletas.length)}',
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FilaSaga extends StatelessWidget {
  const _FilaSaga(this.saga);

  final SagaIncompleta saga;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final s = saga;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => context.go(_catalogo({'saga': s.nombre})),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    s.nombre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: c.texto,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Pastilla(
                  'Tienes ${s.tengo} de ${s.total}',
                  color: c.doradoTexto,
                  fondo: c.doradoFondo,
                ),
              ],
            ),
            const SizedBox(height: 8),
            _Barra(
              proporcion: s.total == 0 ? 0 : s.tengo / s.total,
              color: c.dorado,
              fondo: c.seleccion,
            ),
            const SizedBox(height: 8),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: s.faltan.length == 1 ? 'Te falta: ' : 'Te faltan: ',
                    style: TextStyle(color: c.textoSecundario),
                  ),
                  TextSpan(
                    text: s.faltan.join(' · '),
                    style: TextStyle(color: c.textoSuave),
                  ),
                ],
              ),
              style: const TextStyle(fontSize: 13, height: 1.45),
            ),
          ],
        ),
      ),
    );
  }
}
