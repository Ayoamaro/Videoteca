import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../datos/buscador.dart';
import '../datos/catalogo.dart';
import '../modelos/pelicula.dart';
import '../tema/colores.dart';
import '../utilidades.dart';
import '../widgets/caratula.dart';
import '../widgets/comunes.dart';

enum Orden { parecidas, recientes, titulo, anio, estrellas }

const _nombresOrden = {
  Orden.parecidas: 'Más parecidas',
  Orden.recientes: 'Añadidas recientemente',
  Orden.titulo: 'Título',
  Orden.anio: 'Año',
  Orden.estrellas: 'Estrellas',
};

const _nombresAmbito = {
  AmbitoBusqueda.todo: 'Todo',
  AmbitoBusqueda.titulos: 'Títulos',
  AmbitoBusqueda.actores: 'Actores',
  AmbitoBusqueda.directores: 'Directores',
};

/// Catálogo con buscador, filtros, orden y vista de cuadrícula o lista.
///
/// Solo se dibujan las películas que caben en pantalla: así va igual de
/// fluido con 10 que con 5.541. Los filtros completos llegan el día 6.
class PantallaCatalogo extends ConsumerStatefulWidget {
  const PantallaCatalogo({
    super.key,
    this.busqueda = '',
    this.genero,
    this.ambito = AmbitoBusqueda.todo,
  });

  final String busqueda;
  final String? genero;

  /// Dónde buscar el texto: en todo, solo títulos, actores o directores.
  final AmbitoBusqueda ambito;

  @override
  ConsumerState<PantallaCatalogo> createState() => _PantallaCatalogoState();
}

class _PantallaCatalogoState extends ConsumerState<PantallaCatalogo> {
  late final _texto = TextEditingController(text: widget.busqueda);
  late final Set<String> _generos = {if (widget.genero != null) widget.genero!};
  late AmbitoBusqueda _ambito = widget.ambito;
  late Orden _orden = widget.busqueda.trim().isEmpty
      ? Orden.recientes
      : Orden.parecidas;
  bool _lista = false;

  bool get _buscando => _texto.text.trim().isNotEmpty;

  @override
  void dispose() {
    _texto.dispose();
    super.dispose();
  }

  void _alEscribir(String texto) => setState(() {
    // Al empezar a buscar se ordena por parecido; al borrar, como antes.
    if (_buscando && _orden == Orden.recientes) _orden = Orden.parecidas;
    if (!_buscando && _orden == Orden.parecidas) _orden = Orden.recientes;
  });

  List<Pelicula> _resultados(List<Pelicula> todas) {
    // Con texto, el buscador devuelve las que encajan, de más a menos
    // parecidas.
    var lista = todas;
    if (_buscando) {
      final porId = ref.read(peliculasPorIdProvider);
      lista = [
        for (final c
            in ref.read(buscadorProvider).buscar(_texto.text, ambito: _ambito))
          ?porId[c.id],
      ];
    }
    final generos = _generos.map(normalizar).toSet();
    lista = lista.where((p) {
      if (generos.isNotEmpty) {
        final suyos = {p.generoCarpeta, ...p.generos}.map(normalizar);
        if (!suyos.any(generos.contains)) return false;
      }
      return true;
    }).toList();

    final antiguo = DateTime(1900);
    switch (_orden) {
      case Orden.parecidas:
        if (!_buscando) {
          lista.sort(
            (a, b) => (b.anadida ?? antiguo).compareTo(a.anadida ?? antiguo),
          );
        }
      case Orden.recientes:
        lista.sort(
          (a, b) => (b.anadida ?? antiguo).compareTo(a.anadida ?? antiguo),
        );
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

  void _abrirFiltrosMovil(List<(String, int)> generos) {
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
              generos: generos,
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
    final todas = ref.watch(catalogoProvider).value ?? const <Pelicula>[];
    final generos = ref.watch(generosProvider);
    ref
      ..watch(buscadorProvider)
      ..watch(peliculasPorIdProvider);
    final resultados = _resultados(todas);
    return LayoutBuilder(
      builder: (context, medidas) {
        final ancha = medidas.maxWidth >= 860;
        final estrecha = medidas.maxWidth < 700;
        final margen = estrecha ? 20.0 : 48.0;
        final zonaResultados = _zonaResultados(
          resultados,
          generos,
          ancha,
          EdgeInsets.only(bottom: estrecha ? 32 : 56),
        );
        return SafeArea(
          bottom: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(margen, estrecha ? 24 : 36, margen, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CampoBusqueda(
                  controlador: _texto,
                  alto: ancha ? 58 : 52,
                  indicacion: ancha
                      ? 'Busca por título, título original, actor o director…'
                      : 'Título, actor o director…',
                  alCambiar: _alEscribir,
                ),
                const SizedBox(height: 14),
                // Dónde buscar (como en el diseño del móvil).
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final MapEntry(key: ambito, value: nombre)
                        in _nombresAmbito.entries)
                      ChoiceChip(
                        label: Text(nombre),
                        selected: _ambito == ambito,
                        showCheckmark: false,
                        onSelected: (_) => setState(() => _ambito = ambito),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: ancha
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 230,
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.only(bottom: 32),
                                child: _PanelFiltros(
                                  generos: generos,
                                  seleccionados: _generos,
                                  alCambiar: _cambiarGenero,
                                  alLimpiar: () => setState(_generos.clear),
                                ),
                              ),
                            ),
                            const SizedBox(width: 28),
                            Expanded(child: zonaResultados),
                          ],
                        )
                      : zonaResultados,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Barra de resultados y la cuadrícula o lista, que se desplazan juntas.
  Widget _zonaResultados(
    List<Pelicula> resultados,
    List<(String, int)> generos,
    bool ancha,
    EdgeInsets relleno,
  ) {
    final c = context.colores;
    final barra = Wrap(
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
                    text: resultados.length == 1 ? ' película' : ' películas',
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
                onPressed: () => _abrirFiltrosMovil(generos),
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
                  if (o != Orden.parecidas || _buscando)
                    DropdownMenuItem(value: o, child: Text(_nombresOrden[o]!)),
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
    );

    return LayoutBuilder(
      builder: (context, medidas) {
        // Columnas que caben (como CuadriculaAdaptable), pero construyendo
        // cada fila solo cuando aparece en pantalla.
        final separacion = ancha ? 22.0 : 14.0;
        final anchoMinimo = ancha ? 150.0 : 130.0;
        final columnas =
            ((medidas.maxWidth + separacion) / (anchoMinimo + separacion))
                .floor()
                .clamp(1, 99);
        final anchoHijo =
            (medidas.maxWidth - separacion * (columnas - 1)) / columnas;
        final filas = (resultados.length / columnas).ceil();

        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: barra),
            const SliverToBoxAdapter(child: SizedBox(height: 18)),
            if (resultados.isEmpty)
              SliverToBoxAdapter(child: _SinResultados(texto: _texto.text))
            else if (_lista)
              SliverPadding(
                padding: relleno,
                sliver: SliverList.builder(
                  itemCount: resultados.length,
                  itemBuilder: (_, i) => _FilaPelicula(resultados[i]),
                ),
              )
            else
              SliverPadding(
                padding: relleno,
                sliver: SliverList.builder(
                  itemCount: filas,
                  itemBuilder: (_, fila) => Padding(
                    padding: EdgeInsets.only(
                      bottom: fila == filas - 1 ? 0 : separacion,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var col = 0; col < columnas; col++) ...[
                          if (col > 0) SizedBox(width: separacion),
                          SizedBox(
                            width: anchoHijo,
                            child: fila * columnas + col < resultados.length
                                ? TarjetaPelicula(
                                    resultados[fila * columnas + col],
                                  )
                                : null,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _PanelFiltros extends StatelessWidget {
  const _PanelFiltros({
    required this.generos,
    required this.seleccionados,
    required this.alCambiar,
    required this.alLimpiar,
  });

  final List<(String, int)> generos;
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
        for (final (nombre, total) in generos)
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
