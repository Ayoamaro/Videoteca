import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../datos/ejemplo.dart';
import '../modelos/pelicula.dart';
import '../tema/colores.dart';
import '../utilidades.dart';
import '../widgets/caratula.dart';
import '../widgets/comunes.dart';

enum Orden { recientes, titulo, anio, estrellas }

const _nombresOrden = {
  Orden.recientes: 'Añadidas recientemente',
  Orden.titulo: 'Título',
  Orden.anio: 'Año',
  Orden.estrellas: 'Estrellas',
};

/// Catálogo con buscador, filtros, orden y vista de cuadrícula o lista.
///
/// Por ahora trabaja con los datos de ejemplo. El buscador de verdad
/// (instantáneo, con autocompletado) llega el día 5 y los filtros completos
/// el día 6.
class PantallaCatalogo extends StatefulWidget {
  const PantallaCatalogo({super.key, this.busqueda = '', this.genero});

  final String busqueda;
  final String? genero;

  @override
  State<PantallaCatalogo> createState() => _PantallaCatalogoState();
}

class _PantallaCatalogoState extends State<PantallaCatalogo> {
  late final _texto = TextEditingController(text: widget.busqueda);
  late final Set<String> _generos = {if (widget.genero != null) widget.genero!};
  Orden _orden = Orden.recientes;
  bool _lista = false;

  @override
  void dispose() {
    _texto.dispose();
    super.dispose();
  }

  List<Pelicula> get _resultados {
    // Cada palabra escrita tiene que aparecer en algún sitio, en cualquier orden.
    final palabras = normalizar(_texto.text)
        .split(' ')
        .where((w) => w.isNotEmpty)
        .toList();
    final generos = _generos.map(normalizar).toSet();
    final lista = peliculasEjemplo.where((p) {
      if (palabras.isNotEmpty) {
        final donde = normalizar(
          '${p.titulo} ${p.tituloOriginal} ${p.reparto} ${p.direccion}',
        );
        if (!palabras.every(donde.contains)) return false;
      }
      if (generos.isNotEmpty) {
        final suyos = {p.generoCarpeta, ...p.generos}.map(normalizar);
        if (!suyos.any(generos.contains)) return false;
      }
      return true;
    }).toList();

    switch (_orden) {
      case Orden.recientes:
        lista.sort((a, b) => b.anadida!.compareTo(a.anadida!));
      case Orden.titulo:
        lista.sort(
          (a, b) => normalizar(a.titulo).compareTo(normalizar(b.titulo)),
        );
      case Orden.anio:
        lista.sort((a, b) => b.anio.compareTo(a.anio));
      case Orden.estrellas:
        lista.sort((a, b) => b.estrellas.compareTo(a.estrellas));
    }
    return lista;
  }

  void _cambiarGenero(String genero, bool marcado) => setState(() {
    marcado ? _generos.add(genero) : _generos.remove(genero);
  });

  void _abrirFiltrosMovil() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colores.superficie,
      builder: (contexto) => StatefulBuilder(
        builder: (contexto, refrescar) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          builder: (contexto, desplazamiento) => SingleChildScrollView(
            controller: desplazamiento,
            padding: const EdgeInsets.all(20),
            child: _PanelFiltros(
              seleccionados: _generos,
              alCambiar: (g, v) {
                _cambiarGenero(g, v);
                refrescar(() {});
              },
              alLimpiar: () {
                setState(_generos.clear);
                refrescar(() {});
              },
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final resultados = _resultados;
    return LayoutBuilder(
      builder: (context, medidas) {
        final ancha = medidas.maxWidth >= 860;
        return PaginaBase(
          separacion: 24,
          children: [
            CampoBusqueda(
              controlador: _texto,
              alto: ancha ? 58 : 52,
              indicacion: ancha
                  ? 'Busca por título, título original, actor o director…'
                  : 'Título, actor o director…',
              alCambiar: (_) => setState(() {}),
            ),
            if (ancha)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 230,
                    child: _PanelFiltros(
                      seleccionados: _generos,
                      alCambiar: _cambiarGenero,
                      alLimpiar: () => setState(_generos.clear),
                    ),
                  ),
                  const SizedBox(width: 28),
                  Expanded(child: _zonaResultados(resultados, ancha)),
                ],
              )
            else
              _zonaResultados(resultados, ancha),
          ],
        );
      },
    );
  }

  Widget _zonaResultados(List<Pelicula> resultados, bool ancha) {
    final c = context.colores;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 12,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: formatoNumero(resultados.length),
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: c.texto,
                        ),
                      ),
                      TextSpan(
                        text: resultados.length == 1
                            ? ' película'
                            : ' películas',
                      ),
                    ],
                  ),
                  style: TextStyle(fontSize: 15, color: c.textoSecundario),
                ),
                for (final g in _generos)
                  InputChip(
                    label: Text(g),
                    onDeleted: () => _cambiarGenero(g, false),
                    deleteButtonTooltipMessage: 'Quitar filtro',
                  ),
                if (!ancha)
                  OutlinedButton.icon(
                    onPressed: _abrirFiltrosMovil,
                    icon: const Icon(Icons.tune_rounded, size: 18),
                    label: const Text('Filtros'),
                  ),
              ],
            ),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                DropdownButton<Orden>(
                  value: _orden,
                  underline: const SizedBox.shrink(),
                  borderRadius: BorderRadius.circular(10),
                  dropdownColor: c.superficieAlta,
                  items: [
                    for (final o in Orden.values)
                      DropdownMenuItem(
                        value: o,
                        child: Text(_nombresOrden[o]!),
                      ),
                  ],
                  onChanged: (o) => setState(() => _orden = o!),
                ),
                SegmentedButton<bool>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                      value: false,
                      icon: Icon(Icons.grid_view_rounded, size: 18),
                      tooltip: 'Vista de cuadrícula',
                    ),
                    ButtonSegment(
                      value: true,
                      icon: Icon(Icons.view_list_rounded, size: 18),
                      tooltip: 'Vista de lista',
                    ),
                  ],
                  selected: {_lista},
                  onSelectionChanged: (v) => setState(() => _lista = v.first),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 18),
        if (resultados.isEmpty)
          _SinResultados(texto: _texto.text)
        else if (_lista)
          Column(children: [for (final p in resultados) _FilaPelicula(p)])
        else
          CuadriculaAdaptable(
            anchoMinimo: ancha ? 150 : 130,
            separacion: ancha ? 22 : 14,
            children: [for (final p in resultados) TarjetaPelicula(p)],
          ),
      ],
    );
  }
}

class _PanelFiltros extends StatelessWidget {
  const _PanelFiltros({
    required this.seleccionados,
    required this.alCambiar,
    required this.alLimpiar,
  });

  final Set<String> seleccionados;
  final void Function(String genero, bool marcado) alCambiar;
  final VoidCallback alLimpiar;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Filtros',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            TextButton(onPressed: alLimpiar, child: const Text('Limpiar')),
          ],
        ),
        const SizedBox(height: 12),
        const Etiqueta('Género'),
        const SizedBox(height: 6),
        for (final (nombre, total) in generosEjemplo)
          InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: () => alCambiar(nombre, !seleccionados.contains(nombre)),
            child: SizedBox(
              height: 34,
              child: Row(
                children: [
                  SizedBox(
                    width: 28,
                    child: Checkbox(
                      value: seleccionados.contains(nombre),
                      onChanged: (v) => alCambiar(nombre, v ?? false),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      nombre,
                      style: TextStyle(fontSize: 14, color: c.textoSuave),
                    ),
                  ),
                  Text(
                    formatoNumero(total),
                    style: TextStyle(fontSize: 12, color: c.textoTenue),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 18),
        Tarjeta(
          relleno: const EdgeInsets.all(14),
          radio: 10,
          child: Text(
            'Más filtros (año, país, estrellas, edad, saga, director y actor) '
            'llegan el día 6.',
            style: TextStyle(
              fontSize: 13,
              color: c.textoSecundario,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

/// Fila de la vista de lista.
class _FilaPelicula extends StatelessWidget {
  const _FilaPelicula(this.p);

  final Pelicula p;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    return InkWell(
      onTap: () => context.push('/pelicula/${p.id}'),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: c.borde)),
        ),
        child: Row(
          children: [
            SizedBox(width: 44, child: Caratula.de(p)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.titulo,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      p.tituloOriginal,
                      '${p.anio}',
                      p.direccion,
                    ].where((t) => t.isNotEmpty).join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: c.textoSecundario),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Estrellas(p.estrellas, tam: 16),
          ],
        ),
      ),
    );
  }
}

class _SinResultados extends StatelessWidget {
  const _SinResultados({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        children: [
          Icon(Icons.search_off_rounded, size: 48, color: c.textoTenue),
          const SizedBox(height: 12),
          Text(
            texto.isEmpty
                ? 'Ninguna película cumple los filtros.'
                : 'No hay ninguna película que coincida con «$texto».',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: c.textoSecundario),
          ),
        ],
      ),
    );
  }
}
