import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../datos/buscador.dart';
import '../datos/catalogo.dart';
import '../datos/filtros.dart';
import '../modelos/pelicula.dart';
import '../tema/colores.dart';
import '../utilidades.dart';
import '../widgets/caratula.dart';
import '../widgets/comunes.dart';

enum Orden { parecidas, recientes, titulo, anio, estrellas }

const _nombresOrden = {
  Orden.parecidas: 'Más parecidas',
  Orden.recientes: 'Fecha añadida',
  Orden.titulo: 'Título',
  Orden.anio: 'Año',
  Orden.estrellas: 'Estrellas',
};

/// Qué significa cada orden en su sentido normal y al darle la vuelta.
const _sentidos = {
  Orden.recientes: ('Últimas añadidas primero', 'Primeras añadidas primero'),
  Orden.titulo: ('De la A a la Z', 'De la Z a la A'),
  Orden.anio: ('Más nuevas primero', 'Más antiguas primero'),
  Orden.estrellas: ('Más estrellas primero', 'Menos estrellas primero'),
};

const _nombresAmbito = {
  AmbitoBusqueda.todo: 'Todo',
  AmbitoBusqueda.titulos: 'Títulos',
  AmbitoBusqueda.actores: 'Actores',
  AmbitoBusqueda.directores: 'Directores',
};

/// "TP", "+12" o "Sin clasificar".
String _nombreEdad(String edad) => edad.isEmpty
    ? 'Sin clasificar'
    : edad == 'TP'
    ? 'TP'
    : '+$edad';

/// "Años 80", "Años 2010".
String _nombreDecada(int d) => 'Años ${d < 2000 ? d % 100 : d}';

/// Catálogo con buscador, filtros combinables, orden y vista de cuadrícula o
/// lista.
///
/// Solo se dibujan las películas que caben en pantalla: así va igual de
/// fluido con 10 que con 5.541.
class PantallaCatalogo extends ConsumerStatefulWidget {
  const PantallaCatalogo({
    super.key,
    this.busqueda = '',
    this.ambito = AmbitoBusqueda.todo,
    this.filtros = Filtros.ninguno,
  });

  final String busqueda;

  /// Dónde buscar el texto: en todo, solo títulos, actores o directores.
  final AmbitoBusqueda ambito;

  /// Filtros con los que se abre (p. ej. desde un género de Inicio).
  final Filtros filtros;

  @override
  ConsumerState<PantallaCatalogo> createState() => _PantallaCatalogoState();
}

class _PantallaCatalogoState extends ConsumerState<PantallaCatalogo> {
  late final _texto = TextEditingController(text: widget.busqueda);

  /// Los filtros elegidos. Es un `ValueNotifier` para que la hoja de filtros
  /// del móvil también se entere de cada cambio.
  late final _filtros = ValueNotifier(widget.filtros);
  late AmbitoBusqueda _ambito = widget.ambito;
  late Orden _orden = widget.busqueda.trim().isEmpty
      ? Orden.recientes
      : Orden.parecidas;
  bool _inverso = false;

  /// Películas que encajan con el texto, antes de aplicar los filtros.
  List<Pelicula> _base = const [];

  bool get _buscando => _texto.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _filtros.addListener(_refrescar);
  }

  void _refrescar() => setState(() {});

  @override
  void dispose() {
    _texto.dispose();
    _filtros.dispose();
    super.dispose();
  }

  void _alEscribir(String texto) => setState(() {
    // Al empezar a buscar se ordena por parecido; al borrar, como antes.
    if (_buscando && _orden == Orden.recientes) _orden = Orden.parecidas;
    if (!_buscando && _orden == Orden.parecidas) _orden = Orden.recientes;
  });

  /// Con texto, el buscador devuelve las que encajan, de más a menos
  /// parecidas; sin texto, todas.
  List<Pelicula> _buscar(List<Pelicula> todas) {
    if (!_buscando) return todas;
    final porId = ref.read(peliculasPorIdProvider);
    return [
      for (final c
          in ref.read(buscadorProvider).buscar(_texto.text, ambito: _ambito))
        ?porId[c.id],
    ];
  }

  List<Pelicula> _ordenar(List<Pelicula> lista) {
    final orden = _orden == Orden.parecidas && !_buscando
        ? Orden.recientes
        : _orden;
    if (orden == Orden.parecidas) {
      return _inverso ? lista.reversed.toList() : lista;
    }
    // El título se prepara una vez por película (y no en cada comparación).
    final titulos = {for (final p in lista) p.id: limpiarParaBuscar(p.titulo)};
    int porTitulo(Pelicula a, Pelicula b) =>
        titulos[a.id]!.compareTo(titulos[b.id]!);
    final antiguo = DateTime(1900);
    final signo = _inverso ? -1 : 1;
    // Primero por lo elegido; si empatan, por título.
    int Function(Pelicula, Pelicula) principal = switch (orden) {
      Orden.recientes => (a, b) => (b.anadida ?? antiguo).compareTo(
        a.anadida ?? antiguo,
      ),
      Orden.titulo => porTitulo,
      Orden.anio => (a, b) => b.anio.compareTo(a.anio),
      Orden.estrellas => (a, b) => b.estrellas.compareTo(a.estrellas),
      Orden.parecidas => (a, b) => 0,
    };
    return lista..sort((a, b) {
      final c = principal(a, b) * signo;
      return c != 0 ? c : porTitulo(a, b);
    });
  }

  void _cambiar(Filtros f) => _filtros.value = f;

  /// El panel de filtros, con lo que hay de cada opción.
  Widget _panel() {
    final f = _filtros.value;
    return _PanelFiltros(
      filtros: f,
      facetas: Facetas(_base, f),
      generos: ref.read(generosFichaProvider),
      carpetas: ref.read(arbolCarpetasProvider),
      anios: ref.read(aniosProvider),
      directores: ref.read(directoresProvider),
      actores: ref.read(actoresProvider),
      alCambiar: _cambiar,
    );
  }

  void _abrirFiltrosMovil() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: context.colores.superficie,
      builder: (contexto) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.8,
        maxChildSize: 0.95,
        builder: (contexto, desplazamiento) => ValueListenableBuilder(
          valueListenable: _filtros,
          builder: (contexto, filtros, _) {
            final total = filtros.aplicar(_base).length;
            return Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    controller: desplazamiento,
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                    child: _panel(),
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => Navigator.pop(contexto),
                        child: Text(
                          'Ver ${formatoNumero(total)} '
                          '${total == 1 ? 'película' : 'películas'}',
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final todas = ref.watch(catalogoProvider).value ?? const <Pelicula>[];
    ref
      ..watch(buscadorProvider)
      ..watch(peliculasPorIdProvider)
      ..watch(generosFichaProvider)
      ..watch(arbolCarpetasProvider)
      ..watch(aniosProvider)
      ..watch(directoresProvider)
      ..watch(actoresProvider);
    _base = _buscar(todas);
    final resultados = _ordenar(_filtros.value.aplicar(_base));
    return LayoutBuilder(
      builder: (context, medidas) {
        final ancha = medidas.maxWidth >= 860;
        final estrecha = medidas.maxWidth < 700;
        final margen = estrecha ? 20.0 : 48.0;
        final zonaResultados = _zonaResultados(
          resultados,
          ancha,
          // A la derecha, hueco para la barra de desplazamiento.
          EdgeInsets.only(bottom: estrecha ? 32 : 56, right: estrecha ? 0 : 14),
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
                              width: 260,
                              child: SingleChildScrollView(
                                // Hueco a la derecha para la barra de
                                // desplazamiento.
                                padding: const EdgeInsets.only(
                                  bottom: 32,
                                  right: 16,
                                ),
                                child: _panel(),
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

  /// Un botón por cada filtro activo, para quitarlo con la ✕.
  List<(String, Filtros)> _activos(Filtros f) {
    String anios() {
      final (d, h) = (f.desde, f.hasta);
      if (d != null && h != null) return d == h ? '$d' : '$d – $h';
      return d != null ? 'Desde $d' : 'Hasta $h';
    }

    Set<String> sin(Set<String> conjunto, String v) =>
        Filtros.alternar(conjunto, v, false);
    return [
      for (final g in f.generos) (g, f.copyWith(generos: sin(f.generos, g))),
      for (final g in f.grupos)
        ('Carpeta: $g', f.copyWith(grupos: sin(f.grupos, g))),
      for (final s in f.subcarpetas)
        ('Carpeta: $s', f.copyWith(subcarpetas: sin(f.subcarpetas, s))),
      if (f.hayAnio)
        (anios(), f.copyWith(desde: () => null, hasta: () => null)),
      for (final p in f.paises) (p, f.copyWith(paises: sin(f.paises, p))),
      if (f.estrellasMin > 0)
        (
          f.estrellasMin == 5 ? '5 estrellas' : '${f.estrellasMin}+ estrellas',
          f.copyWith(estrellasMin: 0),
        ),
      for (final e in f.edades)
        ('Edad: ${_nombreEdad(e)}', f.copyWith(edades: sin(f.edades, e))),
      for (final s in f.sagas) ('Saga: $s', f.copyWith(sagas: sin(f.sagas, s))),
      if (f.director != null)
        ('Dirección: ${f.director}', f.copyWith(director: () => null)),
      if (f.actor != null)
        ('Reparto: ${f.actor}', f.copyWith(actor: () => null)),
    ];
  }

  /// Barra de resultados y la cuadrícula o lista, que se desplazan juntas.
  Widget _zonaResultados(
    List<Pelicula> resultados,
    bool ancha,
    EdgeInsets relleno,
  ) {
    final c = context.colores;
    final lista = ref.watch(vistaListaProvider);
    final filtros = _filtros.value;
    final activos = _activos(filtros);
    final sentido = _sentidos[_orden];
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
            if (!ancha)
              OutlinedButton.icon(
                onPressed: _abrirFiltrosMovil,
                icon: Badge(
                  label: Text('${filtros.activos}'),
                  isLabelVisible: !filtros.vacios,
                  backgroundColor: c.dorado,
                  textColor: c.sobreDorado,
                  child: const Icon(Icons.tune_rounded, size: 18),
                ),
                label: const Text('Filtros'),
              ),
            for (final (nombre, sinEste) in activos)
              InputChip(
                label: Text(nombre),
                onDeleted: () => _cambiar(sinEste),
                deleteButtonTooltipMessage: 'Quitar filtro',
              ),
            if (activos.length > 1)
              TextButton(
                onPressed: () => _cambiar(Filtros.ninguno),
                child: const Text('Quitar todos'),
              ),
          ],
        ),
        Wrap(
          spacing: 6,
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
              onChanged: (o) => setState(() {
                _orden = o!;
                _inverso = false;
              }),
            ),
            if (sentido != null)
              IconButton(
                tooltip: _inverso ? sentido.$2 : sentido.$1,
                onPressed: () => setState(() => _inverso = !_inverso),
                icon: _inverso
                    ? const Icon(Icons.arrow_upward_rounded, size: 20)
                    : const Icon(Icons.arrow_downward_rounded, size: 20),
              ),
            const SizedBox(width: 4),
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
              selected: {lista},
              onSelectionChanged: (v) =>
                  ref.read(vistaListaProvider.notifier).cambiar(v.first),
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
        final ancho = medidas.maxWidth - relleno.horizontal;
        final columnas = ((ancho + separacion) / (anchoMinimo + separacion))
            .floor()
            .clamp(1, 99);
        final anchoHijo = (ancho - separacion * (columnas - 1)) / columnas;
        final filas = (resultados.length / columnas).ceil();

        return CustomScrollView(
          slivers: [
            SliverPadding(
              padding: EdgeInsets.only(right: relleno.right),
              sliver: SliverToBoxAdapter(child: barra),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 18)),
            if (resultados.isEmpty)
              SliverToBoxAdapter(
                child: _SinResultados(
                  texto: _texto.text,
                  conFiltros: !filtros.vacios,
                  alQuitarFiltros: () => _cambiar(Filtros.ninguno),
                ),
              )
            else if (lista)
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

/// Panel con todos los filtros: lateral en Windows y en una hoja inferior en
/// el móvil.
class _PanelFiltros extends StatelessWidget {
  const _PanelFiltros({
    required this.filtros,
    required this.facetas,
    required this.generos,
    required this.carpetas,
    required this.anios,
    required this.directores,
    required this.actores,
    required this.alCambiar,
  });

  final Filtros filtros;

  /// Cuántas películas hay de cada opción con el resto de filtros.
  final Facetas facetas;

  /// Todas las opciones de la colección (aunque ahora den 0).
  final List<(String, int)> generos;
  final List<CarpetaArbol> carpetas;
  final (int, int)? anios;
  final List<(String, int)> directores;
  final List<(String, int)> actores;

  final ValueChanged<Filtros> alCambiar;

  @override
  Widget build(BuildContext context) {
    final f = filtros;
    final edades = {...facetas.edades.keys, ...f.edades}.toList()
      ..sort(compararEdades);
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
            TextButton(
              onPressed: f.vacios ? null : () => alCambiar(Filtros.ninguno),
              child: const Text('Limpiar'),
            ),
          ],
        ),
        _Seccion(
          titulo: 'Género',
          child: _ListaCasillas(
            elementos: [
              for (final (nombre, _) in generos)
                _Casilla(
                  nombre: nombre,
                  total: facetas.generos[limpiarParaBuscar(nombre)] ?? 0,
                  marcada: f.generos.contains(nombre),
                  alCambiar: (v) => alCambiar(
                    f.copyWith(generos: Filtros.alternar(f.generos, nombre, v)),
                  ),
                ),
            ],
            // Se ven siempre los marcados aunque estén más abajo.
            marcados: {
              for (final (i, (nombre, _)) in generos.indexed)
                if (f.generos.contains(nombre)) i,
            },
          ),
        ),
        if (carpetas.isNotEmpty)
          _Seccion(
            titulo: 'Carpeta',
            child: Column(
              children: [
                for (final carpeta in carpetas)
                  _RamaCarpeta(
                    carpeta: carpeta,
                    filtros: f,
                    facetas: facetas,
                    alCambiar: alCambiar,
                  ),
              ],
            ),
          ),
        if (anios != null)
          _Seccion(
            titulo: 'Año',
            child: _FiltroAnios(
              filtros: f,
              limites: anios!,
              decadas: facetas.decadas,
              alCambiar: alCambiar,
            ),
          ),
        _Seccion(
          titulo: 'Estrellas',
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (var n = 0; n <= 5; n++)
                if (n != 1)
                  ChoiceChip(
                    showCheckmark: false,
                    selected: f.estrellasMin == n,
                    onSelected: (_) => alCambiar(f.copyWith(estrellasMin: n)),
                    avatar: n == 0
                        ? null
                        : Icon(
                            Icons.star_rounded,
                            size: 16,
                            color: context.colores.dorado,
                          ),
                    label: _ConCuenta(
                      n == 0
                          ? 'Cualquiera'
                          : n == 5
                          ? '5'
                          : '$n o más',
                      n == 0 ? null : facetas.conAlMenos(n),
                    ),
                  ),
            ],
          ),
        ),
        _Seccion(
          titulo: 'Edad',
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final e in edades)
                FilterChip(
                  showCheckmark: false,
                  selected: f.edades.contains(e),
                  onSelected: (v) => alCambiar(
                    f.copyWith(edades: Filtros.alternar(f.edades, e, v)),
                  ),
                  label: _ConCuenta(_nombreEdad(e), facetas.edades[e] ?? 0),
                ),
            ],
          ),
        ),
        _Seccion(
          titulo: 'País',
          child: _SelectorNombres(
            opciones: Facetas.ordenadas(facetas.paises),
            elegidos: f.paises,
            indicacion: 'Escribe un país…',
            sinDatos: 'Las fichas aún no tienen país: se rellena el día 10.',
            alCambiar: (nombre, v) => alCambiar(
              f.copyWith(paises: Filtros.alternar(f.paises, nombre, v)),
            ),
          ),
        ),
        _Seccion(
          titulo: 'Saga',
          child: _SelectorNombres(
            opciones: Facetas.ordenadas(facetas.sagas),
            elegidos: f.sagas,
            indicacion: 'Escribe una saga…',
            sinDatos: 'Las fichas aún no tienen saga: se rellena el día 10.',
            alCambiar: (nombre, v) => alCambiar(
              f.copyWith(sagas: Filtros.alternar(f.sagas, nombre, v)),
            ),
          ),
        ),
        _Seccion(
          titulo: 'Dirección',
          child: _SelectorNombres(
            opciones: directores,
            elegidos: {?f.director},
            indicacion: 'Escribe un director…',
            alCambiar: (nombre, v) =>
                alCambiar(f.copyWith(director: () => v ? nombre : null)),
          ),
        ),
        _Seccion(
          titulo: 'Reparto',
          child: _SelectorNombres(
            opciones: actores,
            elegidos: {?f.actor},
            indicacion: 'Escribe un actor o actriz…',
            alCambiar: (nombre, v) =>
                alCambiar(f.copyWith(actor: () => v ? nombre : null)),
          ),
        ),
      ],
    );
  }
}

/// Título de un grupo de filtros y su contenido.
class _Seccion extends StatelessWidget {
  const _Seccion({required this.titulo, required this.child});

  final String titulo;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [Etiqueta(titulo), const SizedBox(height: 8), child],
      ),
    );
  }
}

/// Texto de una opción con su número de películas en gris.
class _ConCuenta extends StatelessWidget {
  const _ConCuenta(this.texto, this.total);

  final String texto;
  final int? total;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: texto),
          if (total != null)
            TextSpan(
              text: '  ${formatoNumero(total!)}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: c.textoTenue,
              ),
            ),
        ],
      ),
    );
  }
}

/// Casilla de una opción (género o carpeta) con su número de películas.
class _Casilla extends StatelessWidget {
  const _Casilla({
    required this.nombre,
    required this.total,
    required this.marcada,
    required this.alCambiar,
  });

  final String nombre;
  final int total;
  final bool marcada;
  final ValueChanged<bool> alCambiar;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    // Las opciones que ahora no darían ninguna película se ven apagadas.
    final apagada = total == 0 && !marcada;
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: () => alCambiar(!marcada),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 34),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            children: [
              SizedBox(
                width: 28,
                child: Checkbox(
                  value: marcada,
                  onChanged: (v) => alCambiar(v ?? false),
                  visualDensity: VisualDensity.compact,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  nombre,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.25,
                    color: apagada ? c.textoTenue : c.textoSuave,
                  ),
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
    );
  }
}

/// Lista de casillas que enseña las 10 primeras y un botón «Ver todos».
class _ListaCasillas extends StatefulWidget {
  const _ListaCasillas({required this.elementos, this.marcados = const {}});

  final List<Widget> elementos;

  /// Posiciones de los elementos marcados (siempre se enseñan).
  final Set<int> marcados;

  @override
  State<_ListaCasillas> createState() => _ListaCasillasState();
}

class _ListaCasillasState extends State<_ListaCasillas> {
  static const _primeros = 10;
  bool _todos = false;

  @override
  Widget build(BuildContext context) {
    final sobran = widget.elementos.length - _primeros;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (i, e) in widget.elementos.indexed)
          if (_todos || i < _primeros || widget.marcados.contains(i)) e,
        if (sobran > 0)
          TextButton(
            onPressed: () => setState(() => _todos = !_todos),
            child: Text(_todos ? 'Ver menos' : 'Ver todos ($sobran más)'),
          ),
      ],
    );
  }
}

/// Una carpeta de primer nivel y, al desplegarla, sus subcarpetas.
class _RamaCarpeta extends StatefulWidget {
  const _RamaCarpeta({
    required this.carpeta,
    required this.filtros,
    required this.facetas,
    required this.alCambiar,
  });

  final CarpetaArbol carpeta;
  final Filtros filtros;
  final Facetas facetas;
  final ValueChanged<Filtros> alCambiar;

  @override
  State<_RamaCarpeta> createState() => _RamaCarpetaState();
}

class _RamaCarpetaState extends State<_RamaCarpeta> {
  // Abierta de entrada si alguna de sus subcarpetas está marcada.
  late bool _abierta = widget.carpeta.subcarpetas.any(
    (s) => widget.filtros.subcarpetas.contains(s.$1),
  );

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final f = widget.filtros;
    final carpeta = widget.carpeta;
    final hijas = carpeta.subcarpetas;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _Casilla(
                nombre: carpeta.nombre,
                total: widget.facetas.grupos[carpeta.nombre] ?? 0,
                marcada: f.grupos.contains(carpeta.nombre),
                alCambiar: (v) => widget.alCambiar(
                  f.copyWith(
                    grupos: Filtros.alternar(f.grupos, carpeta.nombre, v),
                  ),
                ),
              ),
            ),
            SizedBox(
              width: 28,
              child: hijas.isEmpty
                  ? null
                  : IconButton(
                      tooltip: _abierta
                          ? 'Ocultar subcarpetas'
                          : 'Ver subcarpetas',
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                      iconSize: 20,
                      color: c.textoSecundario,
                      onPressed: () => setState(() => _abierta = !_abierta),
                      icon: _abierta
                          ? const Icon(Icons.expand_less_rounded)
                          : const Icon(Icons.expand_more_rounded),
                    ),
            ),
          ],
        ),
        if (_abierta)
          for (final (nombre, _) in hijas)
            Padding(
              padding: const EdgeInsets.only(left: 26, right: 28),
              child: _Casilla(
                nombre: nombre,
                total: widget.facetas.subcarpetas[nombre] ?? 0,
                // Si la de arriba está marcada, las de dentro también.
                marcada:
                    f.grupos.contains(carpeta.nombre) ||
                    f.subcarpetas.contains(nombre),
                alCambiar: (v) => widget.alCambiar(
                  f.copyWith(
                    subcarpetas: Filtros.alternar(f.subcarpetas, nombre, v),
                  ),
                ),
              ),
            ),
      ],
    );
  }
}

/// Barra "desde – hasta" y atajos por décadas.
class _FiltroAnios extends StatelessWidget {
  const _FiltroAnios({
    required this.filtros,
    required this.limites,
    required this.decadas,
    required this.alCambiar,
  });

  final Filtros filtros;
  final (int, int) limites;

  /// Películas de cada década (con el resto de filtros).
  final Map<int, int> decadas;
  final ValueChanged<Filtros> alCambiar;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final (minimo, maximo) = limites;
    final f = filtros;
    final desde = (f.desde ?? minimo).clamp(minimo, maximo);
    final hasta = (f.hasta ?? maximo).clamp(desde, maximo);

    void elegir(int? d, int? h) => alCambiar(
      f.copyWith(
        // En los extremos no hace falta límite.
        desde: () => d == null || d <= minimo ? null : d,
        hasta: () => h == null || h >= maximo ? null : h,
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              '$desde',
              style: TextStyle(fontWeight: FontWeight.w700, color: c.texto),
            ),
            const Spacer(),
            Text(
              '$hasta',
              style: TextStyle(fontWeight: FontWeight.w700, color: c.texto),
            ),
          ],
        ),
        if (maximo > minimo)
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            ),
            child: RangeSlider(
              min: minimo.toDouble(),
              max: maximo.toDouble(),
              divisions: maximo - minimo,
              values: RangeValues(desde.toDouble(), hasta.toDouble()),
              labels: RangeLabels('$desde', '$hasta'),
              onChanged: (v) => elegir(v.start.round(), v.end.round()),
            ),
          ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (var d = minimo ~/ 10 * 10; d <= maximo; d += 10)
              if ((decadas[d] ?? 0) > 0 || (f.desde == d && f.hasta == d + 9))
                FilterChip(
                  showCheckmark: false,
                  visualDensity: VisualDensity.compact,
                  selected: f.desde == d && f.hasta == d + 9,
                  onSelected: (v) => v
                      ? alCambiar(
                          f.copyWith(desde: () => d, hasta: () => d + 9),
                        )
                      : elegir(null, null),
                  label: _ConCuenta(_nombreDecada(d), decadas[d] ?? 0),
                ),
          ],
        ),
      ],
    );
  }
}

/// Elegir nombres (países, sagas, directores, actores) escribiendo: se
/// proponen los que empiezan así, con su número de películas.
class _SelectorNombres extends StatefulWidget {
  const _SelectorNombres({
    required this.opciones,
    required this.elegidos,
    required this.indicacion,
    required this.alCambiar,
    this.sinDatos,
  });

  /// Nombres y su número de películas, de más a menos.
  final List<(String, int)> opciones;
  final Set<String> elegidos;
  final String indicacion;
  final void Function(String nombre, bool elegido) alCambiar;

  /// Mensaje si todavía no hay ningún dato de este tipo.
  final String? sinDatos;

  @override
  State<_SelectorNombres> createState() => _SelectorNombresState();
}

class _SelectorNombresState extends State<_SelectorNombres> {
  final _controlador = TextEditingController();
  final _foco = FocusNode();

  /// Cada opción con su nombre ya limpio, para comparar rápido.
  late List<(String, int, String)> _limpias = _preparar();

  List<(String, int, String)> _preparar() => [
    for (final (nombre, total) in widget.opciones)
      (nombre, total, limpiarParaBuscar(nombre)),
  ];

  @override
  void didUpdateWidget(_SelectorNombres antes) {
    super.didUpdateWidget(antes);
    if (!identical(antes.opciones, widget.opciones)) _limpias = _preparar();
  }

  @override
  void dispose() {
    _controlador.dispose();
    _foco.dispose();
    super.dispose();
  }

  /// Hasta 8 opciones en las que cada palabra escrita es el principio de una
  /// palabra del nombre («tom han» → Tom Hanks).
  Iterable<(String, int)> _proponer(TextEditingValue valor) {
    final palabras = Buscador.palabras(valor.text);
    final propuestas = <(String, int)>[];
    for (final (nombre, total, limpio) in _limpias) {
      if (widget.elegidos.contains(nombre)) continue;
      final suyas = limpio.split(' ');
      if (palabras.every((p) => suyas.any((s) => s.startsWith(p)))) {
        propuestas.add((nombre, total));
        if (propuestas.length == 8) break;
      }
    }
    return propuestas;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    if (widget.opciones.isEmpty && widget.elegidos.isEmpty) {
      return Text(
        widget.sinDatos ?? 'Ninguna película con estos filtros.',
        style: TextStyle(fontSize: 13, color: c.textoTenue, height: 1.4),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.elegidos.isNotEmpty) ...[
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final nombre in widget.elegidos)
                InputChip(
                  label: Text(nombre),
                  onDeleted: () => widget.alCambiar(nombre, false),
                  deleteButtonTooltipMessage: 'Quitar',
                ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        LayoutBuilder(
          builder: (context, medidas) => RawAutocomplete<(String, int)>(
            textEditingController: _controlador,
            focusNode: _foco,
            displayStringForOption: (o) => o.$1,
            optionsBuilder: _proponer,
            onSelected: (o) {
              widget.alCambiar(o.$1, true);
              _controlador.clear();
            },
            fieldViewBuilder: (context, controlador, foco, alEnviar) =>
                TextField(
                  controller: controlador,
                  focusNode: foco,
                  onSubmitted: (_) => alEnviar(),
                  style: TextStyle(fontSize: 14, color: c.texto),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: widget.indicacion,
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      size: 18,
                      color: c.textoTenue,
                    ),
                    prefixIconConstraints: const BoxConstraints(minWidth: 36),
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: c.borde),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: c.borde),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: c.dorado),
                    ),
                  ),
                ),
            optionsViewBuilder: (context, alElegir, opciones) => Align(
              alignment: Alignment.topLeft,
              child: Material(
                color: c.superficieAlta,
                elevation: 6,
                borderRadius: BorderRadius.circular(10),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: medidas.maxWidth,
                    maxHeight: 320,
                  ),
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    shrinkWrap: true,
                    children: [
                      for (final (i, o) in opciones.indexed)
                        _OpcionNombre(
                          opcion: o,
                          resaltada:
                              AutocompleteHighlightedOption.of(context) == i,
                          alPulsar: () => alElegir(o),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _OpcionNombre extends StatelessWidget {
  const _OpcionNombre({
    required this.opcion,
    required this.resaltada,
    required this.alPulsar,
  });

  final (String, int) opcion;
  final bool resaltada;
  final VoidCallback alPulsar;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final (nombre, total) = opcion;
    return InkWell(
      onTap: alPulsar,
      child: Container(
        color: resaltada ? c.seleccion : null,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                nombre,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 14, color: c.texto),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              formatoNumero(total),
              style: TextStyle(fontSize: 12, color: c.textoTenue),
            ),
          ],
        ),
      ),
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
  const _SinResultados({
    required this.texto,
    required this.conFiltros,
    required this.alQuitarFiltros,
  });

  final String texto;
  final bool conFiltros;
  final VoidCallback alQuitarFiltros;

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
            texto.trim().isEmpty
                ? 'Ninguna película cumple los filtros.'
                : conFiltros
                ? 'Ninguna película con «$texto» cumple los filtros.'
                : 'No hay ninguna película que coincida con «$texto».',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: c.textoSecundario),
          ),
          if (conFiltros) ...[
            const SizedBox(height: 14),
            OutlinedButton(
              onPressed: alQuitarFiltros,
              child: const Text('Quitar los filtros'),
            ),
          ],
        ],
      ),
    );
  }
}
