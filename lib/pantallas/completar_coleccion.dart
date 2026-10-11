import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../datos/base_datos.dart' show FilaLote;
import '../datos/catalogo.dart';
import '../datos/fuentes.dart';
import '../datos/lote.dart';
import '../fuentes/lote.dart';
import '../tema/colores.dart';
import '../tema/tema.dart';
import '../utilidades.dart';
import '../widgets/comunes.dart';
import 'registro.dart' show fechaHora, mostrarError;

/// «Completar mi colección»: el lote que rellena los campos vacíos de todas
/// las películas (ver `datos/lote.dart`) y el repaso con FilmAffinity.
class PantallaCompletarColeccion extends ConsumerStatefulWidget {
  const PantallaCompletarColeccion({super.key});

  @override
  ConsumerState<PantallaCompletarColeccion> createState() =>
      _PantallaCompletarColeccionState();
}

class _PantallaCompletarColeccionState
    extends ConsumerState<PantallaCompletarColeccion> {
  /// Qué resultados se enseñan (`null` = todos).
  EstadoLote? _filtro;
  int _mostrar = _porTanda;
  static const _porTanda = 60;

  Coleccion get _lote => ref.read(coleccionProvider.notifier);

  @override
  Widget build(BuildContext context) {
    final estado = ref.watch(coleccionProvider);
    final hayClave = ref.watch(fuentesDatosProvider) != null;
    return PaginaBase(
      separacion: 26,
      children: [
        const CabeceraPagina(
          titulo: 'Completar mi colección',
          descripcion:
              'Rellena los campos vacíos de todas tus películas con TMDB, OMDb '
              'y Wikidata. Nunca cambia los datos que ya tienes ni las '
              'carátulas, y solo escribe cuando título, año y director '
              'coinciden. Cada cambio queda en el Registro y se puede deshacer.',
        ),
        if (!hayClave) _sinClave(context),
        _campos(context, estado),
        _progreso(context, estado, hayClave: hayClave),
        _dudosas(context, estado),
        if (estado.filas.isNotEmpty) _resultados(context, estado),
        if (estado.filas.isNotEmpty) _tandas(context, estado),
        const _Repaso(),
      ],
    );
  }

  Widget _sinClave(BuildContext context) {
    final c = context.colores;
    return Tarjeta(
      fondo: c.naranjaFondo,
      borde: c.naranjaFondo,
      child: Wrap(
        spacing: 16,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            'Falta la clave de TMDB: sin ella no se puede identificar ninguna '
            'película.',
            style: TextStyle(fontSize: 14, color: c.texto),
          ),
          FilledButton.tonal(
            onPressed: () => context.go('/ajustes'),
            child: const Text('Ir a Ajustes'),
          ),
        ],
      ),
    );
  }

  // ── Campos a rellenar ────────────────────────────────────────────────

  Widget _campos(BuildContext context, EstadoColeccion estado) {
    final c = context.colores;
    final vacios = ref.watch(vaciosPorOpcionProvider);
    return Tarjeta(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Campos a rellenar',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          Text(
            'Solo en las películas que los tienen vacíos (el número es '
            'cuántas).',
            style: TextStyle(fontSize: 13, color: c.textoSecundario),
          ),
          const SizedBox(height: 16),
          CuadriculaAdaptable(
            anchoMinimo: 230,
            separacion: 10,
            children: [
              for (final o in OpcionLote.values)
                _Casilla(
                  titulo: o.nombre,
                  detalle:
                      '${o.origen} · ${formatoNumero(vacios[o] ?? 0)} vacías',
                  marcada: estado.opciones.contains(o),
                  alCambiar: estado.trabajando
                      ? null
                      : (v) => _lote.cambiarOpcion(o, v),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Temas, premios y sinopsis completas solo están en FilmAffinity, '
            'que pide comprobar a mano que eres una persona: van en el '
            '«Repaso con FilmAffinity», más abajo.',
            style: TextStyle(fontSize: 13, color: c.textoSecundario),
          ),
        ],
      ),
    );
  }

  // ── Progreso y botones ───────────────────────────────────────────────

  Widget _progreso(
    BuildContext context,
    EstadoColeccion estado, {
    required bool hayClave,
  }) {
    final c = context.colores;
    final pendientes = ref.watch(pendientesLoteProvider);
    final hechas = estado.filas.length;
    final total = hechas + pendientes.length;
    final cuenta = {
      for (final e in EstadoLote.values)
        e: estado.filas.values.where((f) => f.estado == e.name).length,
    };
    final tanda = estado.tanda;
    // Lo que tiene la tanda (si quedan menos de las pedidas, las que quedan).
    final enTanda = tanda == null
        ? 0
        : [
            tanda.objetivo ?? 1 << 30,
            pendientes.length + estado.hechasTanda,
          ].reduce((a, b) => a < b ? a : b);
    final quedan = tanda == null
        ? pendientes.length
        : (enTanda - estado.hechasTanda).clamp(0, pendientes.length);
    final segundos = estado.segundosPorPelicula;
    final actual = estado.actual;
    final raiz = ref.watch(carpetaRaizProvider) ?? '';

    final botones = <Widget>[
      ...switch (estado.marcha) {
        Marcha.parado => [
          if (pendientes.isNotEmpty) ...[
            FilledButton.icon(
              onPressed: hayClave
                  ? () => _empezar(50, pendientes.length)
                  : null,
              icon: const Icon(Icons.play_arrow_rounded, size: 20),
              label: Text(
                hechas == 0
                    ? 'Probar con 50 películas'
                    : 'Seguir con 50 películas',
              ),
            ),
            if (pendientes.length > 500)
              OutlinedButton(
                onPressed: hayClave
                    ? () => _empezar(500, pendientes.length)
                    : null,
                child: const Text('Seguir con 500'),
              ),
            if (pendientes.length > 50)
              OutlinedButton(
                onPressed: hayClave
                    ? () => _empezar(null, pendientes.length)
                    : null,
                child: Text('Todas (${formatoNumero(pendientes.length)})'),
              ),
          ],
          for (final (e, texto) in [
            (EstadoLote.dudosa, 'las dudosas'),
            (EstadoLote.error, 'las de error'),
          ])
            if (cuenta[e]! > 0)
              OutlinedButton.icon(
                onPressed: hayClave ? () => _lote.reintentar(e) : null,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(
                  'Volver a intentar $texto (${formatoNumero(cuenta[e]!)})',
                ),
              ),
        ],
        Marcha.enMarcha => [
          FilledButton.icon(
            onPressed: _lote.pausar,
            icon: const Icon(Icons.pause_rounded, size: 18),
            label: const Text('Pausar'),
          ),
        ],
        Marcha.pausando => [
          FilledButton.icon(
            onPressed: null,
            icon: const Icon(Icons.pause_rounded, size: 18),
            label: const Text('Pausando al terminar esta…'),
          ),
        ],
        Marcha.pausado => [
          FilledButton.icon(
            onPressed: hayClave ? _lote.reanudar : null,
            icon: const Icon(Icons.play_arrow_rounded, size: 20),
            label: const Text('Reanudar'),
          ),
          OutlinedButton(
            onPressed: _lote.terminarTanda,
            child: const Text('Terminar esta tanda'),
          ),
        ],
        Marcha.deshaciendo => const <Widget>[],
      },
      OutlinedButton(
        onPressed: () => context.go('/registro'),
        child: const Text('Registro de cambios'),
      ),
    ];

    final String linea;
    if (estado.marcha == Marcha.deshaciendo) {
      final (i, n) = estado.progresoDeshacer ?? (0, 0);
      linea = 'Deshaciendo la tanda: $i de $n…';
    } else if (tanda != null) {
      final tiempo = segundos == null
          ? ''
          : ' · quedan ${_duracion(segundos * quedan)}';
      linea =
          'Tanda ${tanda.numero}: ${formatoNumero(estado.hechasTanda)} de '
          '${formatoNumero(enTanda)}$tiempo';
    } else if (pendientes.isEmpty && hechas > 0) {
      linea = 'Toda la colección está repasada.';
    } else {
      linea =
          'Quedan ${formatoNumero(pendientes.length)} películas con algún '
          'campo vacío (unos ${_duracion(1.6 * pendientes.length)}).';
    }

    return Tarjeta(
      relleno: const EdgeInsets.all(26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: 10,
            runSpacing: 6,
            children: [
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: formatoNumero(hechas)),
                    TextSpan(
                      text: ' / ${formatoNumero(total)}',
                      style: TextStyle(fontSize: 22, color: c.textoTenue),
                    ),
                  ],
                ),
                style: Theme.of(context).textTheme.displaySmall,
              ),
              Text(
                total == 0 ? '' : '${(hechas * 100 / total).floor()} %',
                style: TextStyle(fontSize: 15, color: c.textoSuave),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(7),
            child: LinearProgressIndicator(
              value: total == 0 ? 0 : hechas / total,
              minHeight: 14,
              backgroundColor: c.borde,
              color: c.dorado,
              semanticsLabel: 'Progreso',
            ),
          ),
          const SizedBox(height: 16),
          Text(linea, style: TextStyle(fontSize: 14, color: c.textoSuave)),
          if (actual != null) ...[
            const SizedBox(height: 6),
            Text.rich(
              TextSpan(
                children: [
                  const TextSpan(text: 'Ahora: '),
                  TextSpan(
                    text: actual.ruta.startsWith(raiz)
                        ? actual.ruta
                              .substring(raiz.length)
                              .replaceFirst(RegExp(r'^\\'), '')
                        : actual.ruta,
                    style: TextStyle(
                      color: c.texto,
                      fontFamily: fuenteRutas,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              style: TextStyle(fontSize: 14, color: c.textoSecundario),
            ),
          ],
          if (estado.aviso != null) ...[
            const SizedBox(height: 10),
            Text(
              'En pausa: ${estado.aviso}',
              style: TextStyle(fontSize: 14, color: c.naranja),
            ),
          ],
          if (estado.sinOmdb) ...[
            const SizedBox(height: 10),
            Text(
              'OMDb ya no da más consultas hoy (1.000 al día): las estrellas '
              'se saltan hasta mañana; lo demás sigue.',
              style: TextStyle(fontSize: 13, color: c.naranja),
            ),
          ],
          const SizedBox(height: 18),
          CuadriculaAdaptable(
            anchoMinimo: 150,
            separacion: 12,
            children: [
              Contador(
                valor: formatoNumero(cuenta[EstadoLote.completada]!),
                texto: 'completadas',
                color: c.verde,
                fondo: c.verdeFondo,
                colorTexto: c.textoSuave,
              ),
              Contador(
                valor: formatoNumero(cuenta[EstadoLote.sinDatos]!),
                texto: 'sin datos nuevos',
                colorTexto: c.textoSuave,
              ),
              Contador(
                valor: formatoNumero(cuenta[EstadoLote.dudosa]!),
                texto: 'dudosas (sin tocar)',
                color: c.naranja,
                fondo: c.naranjaFondo,
                colorTexto: c.textoSuave,
              ),
              Contador(
                valor: formatoNumero(
                  cuenta[EstadoLote.noEncontrada]! + cuenta[EstadoLote.error]!,
                ),
                texto: cuenta[EstadoLote.error]! == 0
                    ? 'no encontradas'
                    : 'no encontradas o con error',
                color: c.rojo,
                fondo: c.rojoFondo,
                colorTexto: c.textoSuave,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(spacing: 10, runSpacing: 10, children: botones),
        ],
      ),
    );
  }

  /// «unos 40 minutos», «1 h 20 min».
  static String _duracion(double segundos) {
    final min = (segundos / 60).ceil();
    if (min < 2) return 'menos de 2 minutos';
    if (min < 60) return '$min minutos';
    final h = min ~/ 60;
    final m = min % 60;
    return m == 0 ? '$h h' : '$h h $m min';
  }

  Future<void> _empezar(int? cuantas, int pendientes) async {
    final n = cuantas == null || cuantas > pendientes ? pendientes : cuantas;
    final si = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('¿Completar ${formatoNumero(n)} películas?'),
        content: Text(
          'Se buscarán en internet y, en las que se identifiquen sin dudas, se '
          'escribirán dentro del archivo los campos que tienen vacíos (unos '
          '${_duracion(1.6 * n)}). Cada escritura se comprueba con Windows y '
          'queda en el Registro de cambios. Se puede pausar cuando quieras y '
          'deshacer la tanda entera.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Empezar'),
          ),
        ],
      ),
    );
    if (si ?? false) await _lote.empezar(cuantas);
  }

  // ── Dudosas ──────────────────────────────────────────────────────────

  /// Las que el lote dejó sin tocar, para revisarlas de una en una.
  Widget _dudosas(BuildContext context, EstadoColeccion estado) {
    final c = context.colores;
    final cola = ref.watch(colaDudosasProvider);
    if (cola.isEmpty) return const SizedBox.shrink();
    return Tarjeta(
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 16,
        runSpacing: 10,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dudosas por revisar · ${formatoNumero(cola.length)}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  'El lote no las tocó porque no estaba seguro de cuál es cada '
                  'una (o el archivo no tiene director). Revísalas de una en '
                  'una: la app la busca, te enseña las parecidas y rellena los '
                  'campos vacíos; tú compruebas cuál es, guardas y pasa a la '
                  'siguiente.',
                  style: TextStyle(fontSize: 13, color: c.textoSecundario),
                ),
              ],
            ),
          ),
          FilledButton.tonalIcon(
            // Mientras el lote escribe, mejor no editar a la vez.
            onPressed: estado.trabajando
                ? null
                : () => context.go('/dudosas/${cola.first.id}'),
            icon: const Icon(Icons.fact_check_outlined, size: 18),
            label: const Text('Revisar una a una'),
          ),
        ],
      ),
    );
  }

  // ── Resultados ───────────────────────────────────────────────────────

  Widget _resultados(BuildContext context, EstadoColeccion estado) {
    final todas = estado.filas.values.toList()
      ..sort((a, b) => b.fecha.compareTo(a.fecha));
    final lista = _filtro == null
        ? todas
        : todas.where((f) => f.estado == _filtro!.name).toList();
    final peliculas = ref.watch(peliculasPorIdProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Resultados', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: Text('Todas (${formatoNumero(todas.length)})'),
              selected: _filtro == null,
              onSelected: (_) => setState(() {
                _filtro = null;
                _mostrar = _porTanda;
              }),
            ),
            for (final e in EstadoLote.values)
              if (todas.any((f) => f.estado == e.name))
                ChoiceChip(
                  label: Text(
                    '${e.texto} '
                    '(${formatoNumero(todas.where((f) => f.estado == e.name).length)})',
                  ),
                  selected: _filtro == e,
                  onSelected: (_) => setState(() {
                    _filtro = e;
                    _mostrar = _porTanda;
                  }),
                ),
          ],
        ),
        const SizedBox(height: 12),
        Tarjeta(
          relleno: EdgeInsets.zero,
          radio: 12,
          fondo: Colors.transparent,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (i, f) in lista.take(_mostrar).indexed)
                _LineaResultado(
                  fila: f,
                  titulo: peliculas[f.pelicula]?.titulo ?? '(ya no está)',
                  existe: peliculas.containsKey(f.pelicula),
                  ultima: i == lista.length - 1 || i == _mostrar - 1,
                  alRevisada: () => _lote.marcarRevisada(f.pelicula),
                ),
            ],
          ),
        ),
        if (lista.length > _mostrar)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Center(
              child: TextButton(
                onPressed: () => setState(() => _mostrar += _porTanda),
                child: Text(
                  'Ver más (quedan ${formatoNumero(lista.length - _mostrar)})',
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ── Tandas ───────────────────────────────────────────────────────────

  Widget _tandas(BuildContext context, EstadoColeccion estado) {
    final c = context.colores;
    final tandas = tandasDe(estado.filas.values);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Tandas', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        Text(
          '«Deshacer la tanda» deja sus archivos como estaban y las vuelve a '
          'poner como pendientes. Las que hayas cambiado después a mano no se '
          'tocan.',
          style: TextStyle(fontSize: 13, color: c.textoSecundario),
        ),
        const SizedBox(height: 10),
        for (final t in tandas)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Tarjeta(
              relleno: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 16,
                runSpacing: 8,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tanda ${t.numero} · ${fechaHora(t.fecha)}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [
                          for (final e in EstadoLote.values)
                            if (t.cuenta[e]! > 0) '${t.cuenta[e]} ${e.plural}',
                        ].join(' · '),
                        style: TextStyle(fontSize: 13, color: c.textoSuave),
                      ),
                    ],
                  ),
                  OutlinedButton.icon(
                    onPressed:
                        estado.marcha == Marcha.parado &&
                            t.numero != estado.tanda?.numero
                        ? () => _deshacerTanda(t.numero, t.cuenta)
                        : null,
                    icon: const Icon(Icons.undo_rounded, size: 18),
                    label: const Text('Deshacer la tanda'),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _deshacerTanda(int numero, Map<EstadoLote, int> cuenta) async {
    final escritas = cuenta[EstadoLote.completada]!;
    final si = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('¿Deshacer la tanda $numero?'),
        content: Text(
          escritas == 0
              ? 'No se escribió nada en esta tanda: solo se vuelven a poner '
                    'sus películas como pendientes.'
              : 'Se quitará lo que se escribió en $escritas '
                    '${escritas == 1 ? 'archivo' : 'archivos'} (cada uno '
                    'vuelve a quedar como estaba, y se comprueba). Sus '
                    'películas vuelven a quedar pendientes.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Deshacer'),
          ),
        ],
      ),
    );
    if (!(si ?? false) || !mounted) return;
    final mensajero = ScaffoldMessenger.of(context);
    final (deshechas, saltadas, errores) = await _lote.deshacerTanda(numero);
    if (!mounted) return;
    if (errores.isNotEmpty) {
      await mostrarError(
        context,
        'Algunas no se han podido deshacer',
        errores.take(8).join('\n'),
      );
    }
    mensajero
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            'Tanda $numero deshecha: $deshechas '
            '${deshechas == 1 ? 'archivo' : 'archivos'} como estaban'
            '${saltadas == 0 ? '' : '; $saltadas sin tocar porque las cambiaste después'}.',
          ),
        ),
      );
  }
}

class _Casilla extends StatelessWidget {
  const _Casilla({
    required this.titulo,
    required this.detalle,
    required this.marcada,
    required this.alCambiar,
  });

  final String titulo;
  final String detalle;
  final bool marcada;
  final ValueChanged<bool>? alCambiar;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    return Material(
      color: c.superficieAlta,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: c.borde),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: alCambiar == null ? null : () => alCambiar!(!marcada),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              Checkbox(
                value: marcada,
                onChanged: alCambiar == null
                    ? null
                    : (v) => alCambiar!(v ?? false),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      detalle,
                      style: TextStyle(fontSize: 12, color: c.textoSecundario),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LineaResultado extends StatelessWidget {
  const _LineaResultado({
    required this.fila,
    required this.titulo,
    required this.existe,
    required this.ultima,
    required this.alRevisada,
  });

  final FilaLote fila;
  final String titulo;
  final bool existe;
  final bool ultima;
  final VoidCallback alRevisada;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final estado = EstadoLote.porNombre(fila.estado);
    final color = switch (estado) {
      EstadoLote.completada => c.verde,
      EstadoLote.sinDatos => c.textoSecundario,
      EstadoLote.dudosa => c.naranja,
      EstadoLote.noEncontrada || EstadoLote.error => c.rojo,
    };
    final f = fila.fecha;
    final hora =
        '${f.hour.toString().padLeft(2, '0')}:'
        '${f.minute.toString().padLeft(2, '0')}:'
        '${f.second.toString().padLeft(2, '0')}';
    final revisar =
        existe &&
        (estado == EstadoLote.dudosa || estado == EstadoLote.noEncontrada);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        border: ultima ? null : Border(bottom: BorderSide(color: c.borde)),
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            hora,
            style: TextStyle(
              fontFamily: fuenteRutas,
              fontSize: 12,
              color: c.textoTenue,
            ),
          ),
          SizedBox(
            width: 240,
            child: InkWell(
              onTap: existe
                  ? () => context.push('/pelicula/${fila.pelicula}')
                  : null,
              child: Text(
                titulo,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Text(
              fila.mensaje.isEmpty ? estado.texto : fila.mensaje,
              style: TextStyle(fontSize: 13, color: color),
            ),
          ),
          if (revisar) ...[
            TextButton(
              onPressed: () => context.go('/dudosas/${fila.pelicula}'),
              child: const Text('Revisar'),
            ),
            TextButton(onPressed: alRevisada, child: const Text('Ya está')),
          ],
        ],
      ),
    );
  }
}

/// Repaso con FilmAffinity: lista de películas que se abren de una en una
/// en «Editar ficha» con FilmAffinity ya buscando, contigo delante.
class _Repaso extends ConsumerWidget {
  const _Repaso();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colores;
    final repasadas = ref.watch(repasadasProvider);
    final ocupado = ref.watch(coleccionProvider).trabajando;
    return Tarjeta(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Repaso con FilmAffinity',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          Text(
            'Contigo delante: la app abre cada película con FilmAffinity ya '
            'buscando, revisas lo que trae, guardas y pasa sola a la '
            'siguiente. Si FilmAffinity pide comprobar que eres una persona, '
            'marca la casilla en su ventana. Puedes dejarlo cuando quieras y '
            'seguir otro día por donde ibas.',
            style: TextStyle(fontSize: 13, color: c.textoSecundario),
          ),
          const SizedBox(height: 14),
          for (final tipo in TipoRepaso.values)
            _FilaRepaso(tipo: tipo, ocupado: ocupado),
          if (repasadas.isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => ref.read(repasadasProvider.notifier).olvidar(),
                child: Text(
                  repasadas.length == 1
                      ? 'Volver a proponer la ya repasada o saltada'
                      : 'Volver a proponer las '
                            '${formatoNumero(repasadas.length)} ya repasadas o '
                            'saltadas',
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FilaRepaso extends ConsumerWidget {
  const _FilaRepaso({required this.tipo, required this.ocupado});

  final TipoRepaso tipo;
  final bool ocupado;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colores;
    final cola = ref.watch(colaRepasoProvider(tipo));
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 16,
        runSpacing: 8,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${tipo.nombre} · ${formatoNumero(cola.length)}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                tipo.descripcion,
                style: TextStyle(fontSize: 13, color: c.textoSuave),
              ),
            ],
          ),
          FilledButton.tonalIcon(
            // Mientras el lote escribe, mejor no editar a la vez.
            onPressed: cola.isEmpty || ocupado
                ? null
                : () => context.go('/repaso/${tipo.name}/${cola.first.id}'),
            icon: const Icon(Icons.movie_filter_rounded, size: 18),
            label: const Text('Empezar el repaso'),
          ),
        ],
      ),
    );
  }
}
