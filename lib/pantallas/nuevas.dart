import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../datos/catalogo.dart';
import '../datos/vigilancia.dart';
import '../modelos/pelicula.dart';
import '../tema/colores.dart';
import '../tema/tema.dart';
import '../utilidades.dart';
import '../widgets/caratula.dart';
import '../widgets/comunes.dart';

/// Bandeja de películas detectadas en el disco después del primer escaneo.
/// (Completar su ficha con datos automáticos llega el día 12.)
class PantallaNuevas extends ConsumerWidget {
  const PantallaNuevas({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colores;
    final nuevas = ref.watch(nuevasProvider);
    final revisando = ref.watch(escaneoProvider)?.enMarcha ?? false;
    final hoy = DateUtils.dateOnly(DateTime.now());
    final deHoy = nuevas
        .where((p) => p.anadida != null && !p.anadida!.isBefore(hoy))
        .length;
    final sinCaratula = nuevas.where((p) => !p.tieneCaratula).length;

    return PaginaBase(
      children: [
        CabeceraPagina(
          titulo: 'Películas nuevas',
          descripcion:
              'Películas que han aparecido en el disco. La app las detecta '
              'sola en cuanto las copias; pronto (día 12) buscará sus datos '
              'y tú solo añadirás la carátula y guardarás.',
          acciones: [
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
              valor: formatoNumero(nuevas.length),
              texto: 'en la bandeja',
            ),
            Contador(
              valor: formatoNumero(deHoy),
              texto: deHoy == 1 ? 'detectada hoy' : 'detectadas hoy',
              color: c.azul,
            ),
            Contador(
              valor: formatoNumero(sinCaratula),
              texto: 'sin carátula todavía',
              color: c.naranja,
            ),
          ],
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
          _tabla(context, ref, nuevas),
      ],
    );
  }

  Widget _tabla(BuildContext context, WidgetRef ref, List<Pelicula> nuevas) {
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
              width: medidas.maxWidth < 820 ? 820 : medidas.maxWidth,
              child: Table(
                columnWidths: const {
                  0: FlexColumnWidth(2.8),
                  1: FlexColumnWidth(1.1),
                  2: FlexColumnWidth(1.1),
                  3: FlexColumnWidth(1.3),
                  4: FlexColumnWidth(1.6),
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
                  for (final p in nuevas) _fila(context, ref, p),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  TableRow _fila(BuildContext context, WidgetRef ref, Pelicula p) {
    final c = context.colores;
    const relleno = EdgeInsets.symmetric(horizontal: 18, vertical: 16);
    final (estado, color, fondo) = p.tieneCaratula
        ? ('Por completar', c.azul, c.azulFondo)
        : ('Falta la carátula', c.naranja, c.naranjaFondo);
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
            child: Pastilla(estado, color: color, fondo: fondo),
          ),
        ),
        Padding(
          padding: relleno,
          child: Wrap(
            alignment: WrapAlignment.end,
            spacing: 4,
            runSpacing: 4,
            children: [
              FilledButton(
                onPressed: () => context.push('/pelicula/${p.id}'),
                child: const Text('Ver ficha'),
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
