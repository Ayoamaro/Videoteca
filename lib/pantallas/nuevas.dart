import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../datos/catalogo.dart';
import '../datos/fuentes.dart';
import '../datos/nuevas.dart';
import '../datos/vigilancia.dart';
import '../modelos/pelicula.dart';
import '../tema/colores.dart';
import '../tema/tema.dart';
import '../utilidades.dart';
import '../widgets/caratula.dart';
import '../widgets/comunes.dart';
import '../widgets/completar.dart';

/// Bandeja de películas detectadas en el disco después del primer escaneo.
/// La app busca sola sus datos en internet; tú abres «Completar ficha»,
/// pones la carátula y guardas.
class PantallaNuevas extends ConsumerWidget {
  const PantallaNuevas({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colores;
    final nuevas = ref.watch(nuevasProvider);
    final busquedas = ref.watch(busquedasNuevasProvider);
    final hayClave = ref.watch(fuentesDatosProvider) != null;
    final revisando = ref.watch(escaneoProvider)?.enMarcha ?? false;
    final estados = {
      for (final p in nuevas)
        p.id: estadoNueva(p, busquedas[p.id], clave: hayClave),
    };
    int cuantas(Set<EstadoNueva> e) => estados.values.where(e.contains).length;
    final hoy = DateUtils.dateOnly(DateTime.now());
    final deHoy = nuevas
        .where((p) => p.anadida != null && !p.anadida!.isBefore(hoy))
        .length;
    final guardadas = [
      for (final p in nuevas)
        if (p.completada != null) p.id,
    ];
    final conError = cuantas({EstadoNueva.error});

    return PaginaBase(
      children: [
        CabeceraPagina(
          titulo: 'Películas nuevas',
          descripcion:
              'Películas que han aparecido en el disco. Los datos se buscan '
              'solos; tú solo revisas, añades la carátula y guardas.',
          acciones: [
            if (conError > 0)
              OutlinedButton.icon(
                onPressed: () => ref
                    .read(busquedasNuevasProvider.notifier)
                    .reintentarErrores(),
                icon: const Icon(Icons.wifi_rounded, size: 18),
                label: const Text('Volver a buscar'),
              ),
            if (guardadas.isNotEmpty)
              OutlinedButton.icon(
                onPressed: () => ref
                    .read(catalogoProvider.notifier)
                    .quitarDeNuevas(guardadas),
                icon: const Icon(Icons.done_all_rounded, size: 18),
                label: Text('Quitar las guardadas (${guardadas.length})'),
              ),
            OutlinedButton.icon(
              onPressed: revisando
                  ? null
                  : () => ref.read(escaneoProvider.notifier).revisar(),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(revisando ? 'Revisando…' : 'Revisar el disco'),
            ),
          ],
        ),
        CuadriculaAdaptable(
          anchoMinimo: 180,
          separacion: 12,
          children: [
            Contador(
              valor: formatoNumero(deHoy),
              texto: deHoy == 1 ? 'detectada hoy' : 'detectadas hoy',
            ),
            Contador(
              valor: formatoNumero(cuantas({EstadoNueva.lista})),
              texto: 'listas para revisar',
              color: c.azul,
            ),
            Contador(
              valor: formatoNumero(
                cuantas({EstadoNueva.elegir, EstadoNueva.noEncontrada}),
              ),
              texto: 'necesitan que elijas',
              color: c.naranja,
            ),
            Contador(
              valor: formatoNumero(guardadas.length),
              texto: guardadas.length == 1 ? 'guardada' : 'guardadas',
              color: c.verde,
            ),
          ],
        ),
        if (!hayClave && nuevas.isNotEmpty)
          Tarjeta(
            fondo: c.doradoFondo,
            borde: c.doradoBorde,
            child: Row(
              children: [
                Icon(Icons.key_rounded, color: c.doradoTexto),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Para que los datos se busquen solos hace falta la clave '
                    'gratuita de TMDB. Mientras tanto puedes completar las '
                    'fichas a mano.',
                  ),
                ),
                TextButton(
                  onPressed: () => context.go('/ajustes'),
                  child: const Text('Ir a Ajustes'),
                ),
              ],
            ),
          ),
        if (nuevas.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Column(
              children: [
                Icon(Icons.inbox_outlined, size: 44, color: c.textoTenue),
                const SizedBox(height: 10),
                Text(
                  'No hay películas nuevas. Copia una en una carpeta de la '
                  'colección y aparecerá aquí al momento.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: c.textoSecundario),
                ),
              ],
            ),
          )
        else
          _tabla(context, ref, nuevas, estados),
      ],
    );
  }

  Widget _tabla(
    BuildContext context,
    WidgetRef ref,
    List<Pelicula> nuevas,
    Map<int, EstadoNueva> estados,
  ) {
    final c = context.colores;
    Widget cabecera(String t) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Etiqueta(t),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: c.borde),
          borderRadius: BorderRadius.circular(14),
        ),
        child: LayoutBuilder(
          builder: (context, medidas) => SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: medidas.maxWidth < 900 ? 900 : medidas.maxWidth,
              child: Table(
                columnWidths: const {
                  0: FlexColumnWidth(2.6),
                  1: FlexColumnWidth(1),
                  2: FlexColumnWidth(1),
                  3: FlexColumnWidth(1.5),
                  4: FlexColumnWidth(2),
                },
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                children: [
                  TableRow(
                    decoration: BoxDecoration(color: c.superficie),
                    children: [
                      cabecera('Archivo'),
                      cabecera('Carpeta'),
                      cabecera('Detectada'),
                      cabecera('Estado'),
                      Align(
                        alignment: Alignment.centerRight,
                        child: cabecera('Acción'),
                      ),
                    ],
                  ),
                  for (final p in nuevas)
                    _fila(context, ref, p, estados[p.id]!),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  TableRow _fila(
    BuildContext context,
    WidgetRef ref,
    Pelicula p,
    EstadoNueva estado,
  ) {
    final c = context.colores;
    const relleno = EdgeInsets.symmetric(horizontal: 18, vertical: 16);
    final guardada =
        estado == EstadoNueva.guardada ||
        estado == EstadoNueva.guardadaSinCaratula;
    return TableRow(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: c.borde)),
      ),
      children: [
        Padding(
          padding: relleno,
          child: Row(
            children: [
              SizedBox(width: 36, child: Caratula.de(p, mostrarNueva: false)),
              const SizedBox(width: 12),
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
                      p.archivo,
                      style: TextStyle(
                        fontFamily: fuenteRutas,
                        fontSize: 12,
                        color: c.textoTenue,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: relleno,
          child: Text(p.generoCarpeta, style: TextStyle(color: c.textoSuave)),
        ),
        Padding(
          padding: relleno,
          child: Text(
            cuandoTexto(p.anadida),
            style: TextStyle(color: c.textoSuave),
          ),
        ),
        Padding(
          padding: relleno,
          child: Align(
            alignment: Alignment.centerLeft,
            child: PastillaEstado(estado),
          ),
        ),
        Padding(
          padding: relleno,
          child: Wrap(
            alignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 4,
            runSpacing: 4,
            children: [
              if (guardada)
                OutlinedButton(
                  onPressed: () => context.push('/pelicula/${p.id}'),
                  child: const Text('Ver ficha'),
                )
              else if (estado == EstadoNueva.elegir)
                OutlinedButton(
                  onPressed: () => context.go('/nuevas/${p.id}'),
                  child: const Text('Elegir'),
                )
              else if (estado == EstadoNueva.lista)
                FilledButton(
                  onPressed: () => context.go('/nuevas/${p.id}'),
                  child: const Text('Completar ficha'),
                )
              else
                OutlinedButton(
                  onPressed: () => context.go('/nuevas/${p.id}'),
                  child: const Text('Completar ficha'),
                ),
              IconButton(
                tooltip: 'Quitar de nuevas (sigue en el catálogo)',
                onPressed: () =>
                    ref.read(catalogoProvider.notifier).quitarDeNuevas([p.id]),
                icon: Icon(Icons.close_rounded, color: c.textoSuave),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// «Hace 5 min», «Hoy, 10:42», «Ayer, 18:03» o «12/09/2026».
String cuandoTexto(DateTime? fecha, [DateTime? ahora]) {
  if (fecha == null) return '—';
  ahora ??= DateTime.now();
  final diferencia = ahora.difference(fecha);
  if (diferencia.inMinutes < 1) return 'Ahora mismo';
  if (diferencia.inMinutes < 60) return 'Hace ${diferencia.inMinutes} min';
  final dia = DateUtils.dateOnly(fecha);
  final hoy = DateUtils.dateOnly(ahora);
  final hora = DateFormat('HH:mm').format(fecha);
  if (dia == hoy) return 'Hoy, $hora';
  if (dia == hoy.subtract(const Duration(days: 1))) return 'Ayer, $hora';
  return DateFormat('dd/MM/yyyy').format(fecha);
}
