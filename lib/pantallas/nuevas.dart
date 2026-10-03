import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../tema/colores.dart';
import '../tema/tema.dart';
import '../utilidades.dart';
import '../widgets/caratula.dart';
import '../widgets/comunes.dart';

enum EstadoNueva { lista, varias, guardada }

class _Nueva {
  const _Nueva(
    this.titulo,
    this.archivo,
    this.carpeta,
    this.cuando,
    this.tono,
    this.estado, [
    this.id,
  ]);

  final String titulo;
  final String archivo;
  final String carpeta;
  final String cuando;
  final Color tono;
  final EstadoNueva estado;
  final int? id;
}

// Datos de ejemplo (la detección real llega el día 8 y la bandeja el día 12).
const _nuevas = [
  _Nueva(
    'Los Vengadores 3: Infinity War',
    'Los Vengadores 3꞉ Infinity War (2018).mp4',
    'Fantasía',
    'Hace 5 min',
    Color(0xFF4A2330),
    EstadoNueva.lista,
    1,
  ),
  _Nueva(
    'También Esto Pasará',
    'También Esto Pasará (2025).mp4',
    'Drama',
    'Hace 5 min',
    Color(0xFF3B2A4A),
    EstadoNueva.lista,
  ),
  _Nueva(
    'Cazadores de Fronteras',
    'Cazadores de Fronteras (2025).mp4',
    'Drama',
    'Hace 5 min',
    Color(0xFF4A3426),
    EstadoNueva.varias,
  ),
  _Nueva(
    'Hipnótico',
    'Hipnótico (2021).mp4',
    'Suspense',
    'Hoy, 10:42',
    Color(0xFF2C3E3E),
    EstadoNueva.guardada,
    5,
  ),
];

/// Bandeja de películas detectadas en el disco que aún no tienen ficha.
class PantallaNuevas extends StatefulWidget {
  const PantallaNuevas({super.key});

  @override
  State<PantallaNuevas> createState() => _PantallaNuevasState();
}

class _PantallaNuevasState extends State<PantallaNuevas> {
  int _elegida = 0;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    return PaginaBase(
      children: [
        CabeceraPagina(
          titulo: 'Películas nuevas',
          descripcion:
              'Archivos detectados en el disco que aún no tienen ficha. Los datos '
              'se buscan solos; tú solo añades la carátula y guardas.',
          acciones: [
            OutlinedButton.icon(
              onPressed: () =>
                  avisoProximamente(context, 'Escanear el disco', 4),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Volver a escanear'),
            ),
          ],
        ),
        CuadriculaAdaptable(
          anchoMinimo: 180,
          separacion: 12,
          children: [
            const Contador(valor: '4', texto: 'detectadas hoy'),
            Contador(valor: '2', texto: 'listas para revisar', color: c.azul),
            Contador(
              valor: '1',
              texto: 'necesitan que elijas',
              color: c.naranja,
            ),
            Contador(
              valor: '1',
              texto: 'guardadas y publicadas',
              color: c.verde,
            ),
          ],
        ),
        _tabla(context),
        _elegirCoincidencia(context),
      ],
    );
  }

  Widget _tabla(BuildContext context) {
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
                  1: FlexColumnWidth(1),
                  2: FlexColumnWidth(1.1),
                  3: FlexColumnWidth(1.7),
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
                  for (final n in _nuevas) _fila(context, n),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  TableRow _fila(BuildContext context, _Nueva n) {
    final c = context.colores;
    const relleno = EdgeInsets.symmetric(horizontal: 18, vertical: 16);
    final (estado, color, fondo) = switch (n.estado) {
      EstadoNueva.lista => ('Lista para revisar', c.azul, c.azulFondo),
      EstadoNueva.varias => ('Varias coincidencias', c.naranja, c.naranjaFondo),
      EstadoNueva.guardada => ('Guardada y publicada', c.verde, c.verdeFondo),
    };
    final accion = switch (n.estado) {
      EstadoNueva.lista => FilledButton(
        onPressed: () => avisoProximamente(context, 'Completar ficha', 12),
        child: const Text('Completar ficha'),
      ),
      EstadoNueva.varias => OutlinedButton(
        onPressed: () => avisoProximamente(context, 'Elegir coincidencia', 12),
        child: const Text('Elegir'),
      ),
      EstadoNueva.guardada => OutlinedButton(
        onPressed: () => context.push('/pelicula/${n.id}'),
        child: const Text('Ver ficha'),
      ),
    };
    return TableRow(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: c.borde)),
      ),
      children: [
        Padding(
          padding: relleno,
          child: Row(
            children: [
              SizedBox(width: 36, child: Caratula(tono: n.tono)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      n.titulo,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      n.archivo,
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
          child: Text(n.carpeta, style: TextStyle(color: c.textoSuave)),
        ),
        Padding(
          padding: relleno,
          child: Text(n.cuando, style: TextStyle(color: c.textoSuave)),
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
          child: Align(alignment: Alignment.centerRight, child: accion),
        ),
      ],
    );
  }

  Widget _elegirCoincidencia(BuildContext context) {
    final c = context.colores;
    const opciones = [
      (
        'Cazadores de Fronteras',
        '2025 · [País] · Dir. [Director]',
        Color(0xFF4A3426),
        'Coincide el año',
        true,
      ),
      (
        'Cazadores de la Frontera',
        '[Año] · [País] · Dir. [Director]',
        Color(0xFF3B2E22),
        'Año distinto',
        false,
      ),
      (
        'Frontera',
        '2025 · [País] · Dir. [Director]',
        Color(0xFF23314F),
        'Título distinto',
        false,
      ),
    ];
    return Tarjeta(
      fondo: c.superficieAlta,
      borde: c.naranjaFondo,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '¿Cuál es «Cazadores de Fronteras (2025)»?',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            'Hay varias películas parecidas. Elige la correcta y la app rellenará el resto.',
            style: TextStyle(fontSize: 14, color: c.textoSecundario),
          ),
          const SizedBox(height: 16),
          CuadriculaAdaptable(
            anchoMinimo: 240,
            separacion: 12,
            children: [
              for (var i = 0; i < opciones.length; i++)
                _opcion(context, i, opciones[i]),
            ],
          ),
        ],
      ),
    );
  }

  Widget _opcion(
    BuildContext context,
    int i,
    (String, String, Color, String, bool) opcion,
  ) {
    final c = context.colores;
    final (titulo, datos, tono, pista, buena) = opcion;
    final marcada = i == _elegida;
    return Material(
      color: marcada ? c.doradoFondo : c.superficie,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: marcada ? c.dorado : c.borde),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => _elegida = i),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              SizedBox(width: 56, child: Caratula(tono: tono)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      datos,
                      style: TextStyle(fontSize: 13, color: c.textoSecundario),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      pista,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: buena ? c.verde : c.textoSecundario,
                      ),
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
