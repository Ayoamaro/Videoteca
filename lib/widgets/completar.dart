import 'package:flutter/material.dart';

import '../datos/nuevas.dart';
import '../disco/acciones_windows.dart';
import '../disco/arrastre.dart';
import '../fuentes/identificacion.dart';
import '../modelos/pelicula.dart';
import '../tema/colores.dart';
import '../tema/tema.dart';
import 'comunes.dart';

// Piezas de «Completar ficha» y de la bandeja de Películas nuevas.

/// Colores (texto, fondo) de cada estado de la bandeja.
(Color, Color) coloresEstado(BuildContext context, EstadoNueva e) {
  final c = context.colores;
  return switch (e) {
    EstadoNueva.lista => (c.azul, c.azulFondo),
    EstadoNueva.elegir ||
    EstadoNueva.noEncontrada ||
    EstadoNueva.guardadaSinCaratula => (c.naranja, c.naranjaFondo),
    EstadoNueva.error => (c.rojo, c.rojoFondo),
    EstadoNueva.guardada => (c.verde, c.verdeFondo),
    EstadoNueva.buscando ||
    EstadoNueva.sinClave => (c.textoSecundario, c.seleccion),
  };
}

/// Pastilla con el estado de una película nueva.
class PastillaEstado extends StatelessWidget {
  const PastillaEstado(this.estado, {super.key});

  final EstadoNueva estado;

  @override
  Widget build(BuildContext context) {
    final (color, fondo) = coloresEstado(context, estado);
    if (estado != EstadoNueva.buscando) {
      return Pastilla(estado.texto, color: color, fondo: fondo);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(strokeWidth: 2, color: color),
          ),
          const SizedBox(width: 8),
          Text(
            estado.texto,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Cabecera de «Completar ficha»: ruta del archivo, título y cómo se ha
/// identificado la película.
class CabeceraCompletar extends StatelessWidget {
  const CabeceraCompletar({
    super.key,
    required this.pelicula,
    required this.titulo,
    required this.busqueda,
    required this.hayClave,
    required this.alVerCandidatas,
  });

  final Pelicula pelicula;

  /// El título que hay ahora en el formulario.
  final String titulo;
  final BusquedaNueva? busqueda;
  final bool hayClave;
  final VoidCallback alVerCandidatas;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final b = busqueda;
    final identificada = b?.estado == EstadoBusqueda.lista ? b!.pelicula : null;
    final (icono, texto, color, fondo) = switch (b?.estado) {
      _ when !hayClave => (
        Icons.key_off_rounded,
        'Sin clave de TMDB: rellena los datos a mano o ponla en Ajustes',
        c.textoSecundario,
        c.seleccion,
      ),
      null || EstadoBusqueda.esperando || EstadoBusqueda.buscando => (
        null,
        'Buscando en TMDB…',
        c.textoSecundario,
        c.seleccion,
      ),
      EstadoBusqueda.lista when b!.elegida => (
        Icons.touch_app_rounded,
        'Elegida por ti',
        c.doradoTexto,
        c.doradoFondo,
      ),
      EstadoBusqueda.lista when b!.probable => (
        Icons.help_outline_rounded,
        'Probable · coinciden título y año (tu archivo aún no tiene '
            'director): compruébalo',
        c.doradoTexto,
        c.doradoFondo,
      ),
      EstadoBusqueda.lista => (
        Icons.check_rounded,
        'Encontrada · coinciden título, año y director',
        c.verde,
        c.verdeFondo,
      ),
      EstadoBusqueda.elegir => (
        Icons.call_split_rounded,
        'Varias coincidencias: elige cuál es',
        c.naranja,
        c.naranjaFondo,
      ),
      EstadoBusqueda.noEncontrada => (
        Icons.search_off_rounded,
        'No encontrada en TMDB',
        c.naranja,
        c.naranjaFondo,
      ),
      EstadoBusqueda.error => (
        Icons.cloud_off_rounded,
        b!.mensaje,
        c.rojo,
        c.rojoFondo,
      ),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SelectableText(
          pelicula.ruta,
          style: TextStyle(
            fontFamily: fuenteRutas,
            fontSize: 13,
            color: c.textoTenue,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Completar ficha · ${titulo.isEmpty ? pelicula.titulo : titulo}',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: fondo,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icono == null)
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: color,
                      ),
                    )
                  else
                    Icon(icono, size: 16, color: color),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      texto,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (identificada != null) ...[
              TextButton.icon(
                onPressed: () => abrirConWindows(identificada.ficha.enlace),
                icon: const Icon(Icons.open_in_new_rounded, size: 16),
                label: Text(
                  'TMDB: ${identificada.ficha.titulo} '
                  '(${identificada.ficha.anio})',
                ),
              ),
              TextButton(
                onPressed: alVerCandidatas,
                child: const Text('¿No es esta?'),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// Selector «¿Cuál es?»: las películas parecidas de TMDB para elegir la
/// buena, y un buscador por si no está ninguna.
class SelectorCandidatas extends StatefulWidget {
  const SelectorCandidatas({
    super.key,
    required this.titulo,
    required this.anio,
    required this.busqueda,
    required this.alElegir,
    required this.alBuscar,
    this.alCerrar,
  });

  final String titulo;
  final int anio;
  final BusquedaNueva busqueda;
  final ValueChanged<Candidato> alElegir;
  final void Function(String titulo, int anio) alBuscar;

  /// `null` si no se puede cerrar (todavía no hay ninguna elegida).
  final VoidCallback? alCerrar;

  @override
  State<SelectorCandidatas> createState() => _EstadoSelector();
}

class _EstadoSelector extends State<SelectorCandidatas> {
  late final _titulo = TextEditingController(text: widget.titulo);
  late final _anio = TextEditingController(
    text: widget.anio == 0 ? '' : '${widget.anio}',
  );

  @override
  void dispose() {
    _titulo.dispose();
    _anio.dispose();
    super.dispose();
  }

  void _buscar() {
    final t = _titulo.text.trim();
    if (t.isEmpty) return;
    widget.alBuscar(t, int.tryParse(_anio.text.trim()) ?? 0);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final b = widget.busqueda;
    final candidatas = b.identificacion?.candidatos ?? const <Candidato>[];
    final elegidaId = b.pelicula?.ficha.id;
    final ninguna = b.estado == EstadoBusqueda.noEncontrada;
    return Tarjeta(
      borde: c.naranja.withValues(alpha: 0.45),
      fondo: c.superficieAlta,
      relleno: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '¿Cuál es «${widget.titulo}'
                      '${widget.anio == 0 ? '' : ' (${widget.anio})'}»?',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      ninguna
                          ? '${b.mensaje} Prueba con otro título (por '
                                'ejemplo, el original) o rellena la ficha a '
                                'mano.'
                          : candidatas.length == 1
                          ? 'Esta es la única parecida que hay en TMDB. Si '
                                'no es la tuya, búscala con otro título (vale '
                                'el original).'
                          : 'Hay varias películas parecidas. Elige la '
                                'correcta y la app rellenará el resto.'
                                '${b.estado == EstadoBusqueda.elegir ? ' ${b.mensaje}' : ''}',
                      style: TextStyle(
                        fontSize: 14,
                        color: c.textoSecundario,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.alCerrar != null)
                IconButton(
                  tooltip: 'Cerrar',
                  onPressed: widget.alCerrar,
                  icon: const Icon(Icons.close_rounded),
                ),
            ],
          ),
          if (candidatas.isNotEmpty) ...[
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, medidas) {
                final columnas = (medidas.maxWidth / 300).floor().clamp(1, 3);
                const hueco = 12.0;
                final ancho =
                    (medidas.maxWidth - hueco * (columnas - 1)) / columnas;
                return Wrap(
                  spacing: hueco,
                  runSpacing: hueco,
                  children: [
                    for (final candidata in candidatas)
                      SizedBox(
                        width: ancho,
                        child: _TarjetaCandidata(
                          candidata,
                          elegida: candidata.ficha.id == elegidaId,
                          alPulsar: () => widget.alElegir(candidata),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Buscar con otro título:',
                style: TextStyle(fontSize: 13, color: c.textoSecundario),
              ),
              SizedBox(
                width: 300,
                child: TextField(
                  controller: _titulo,
                  onSubmitted: (_) => _buscar(),
                  decoration: const InputDecoration(
                    hintText: 'Título (vale el original)',
                    isDense: true,
                  ),
                ),
              ),
              SizedBox(
                width: 90,
                child: TextField(
                  controller: _anio,
                  onSubmitted: (_) => _buscar(),
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    hintText: 'Año',
                    isDense: true,
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _buscar,
                icon: const Icon(Icons.search_rounded, size: 18),
                label: const Text('Buscar'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TarjetaCandidata extends StatelessWidget {
  const _TarjetaCandidata(
    this.candidata, {
    required this.elegida,
    required this.alPulsar,
  });

  final Candidato candidata;
  final bool elegida;
  final VoidCallback alPulsar;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final f = candidata.ficha;
    final cartel = f.enlaceCartel;
    final (etiqueta, colorEtiqueta) = candidata.todo
        ? ('Coinciden título, año y director', c.verde)
        : candidata.titulo && candidata.anio
        ? ('Coinciden título y año', c.verde)
        : !candidata.anio
        ? ('Año distinto', c.textoSecundario)
        : !candidata.titulo
        ? ('Título distinto', c.textoSecundario)
        : ('Coincide el año', c.textoSecundario);
    return Material(
      color: elegida ? c.doradoFondo : c.superficie,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: elegida ? c.dorado : c.bordeFuerte),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: alPulsar,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // El cartel de TMDB solo sirve para reconocerla: nunca se
              // pone como carátula.
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  width: 56,
                  height: 80,
                  color: c.seleccion,
                  child: cartel == null
                      ? Icon(Icons.movie_outlined, color: c.textoTenue)
                      : Image.network(
                          cartel,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) =>
                              Icon(Icons.movie_outlined, color: c.textoTenue),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      f.titulo,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      [
                        if (f.anio > 0) '${f.anio}',
                        if (f.tituloOriginal != f.titulo) f.tituloOriginal,
                        if (f.directores.isNotEmpty)
                          'Dir. ${f.directores.join(', ')}',
                      ].join(' · '),
                      style: TextStyle(fontSize: 13, color: c.textoSecundario),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      etiqueta,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: colorEtiqueta,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          elegida ? 'Elegida' : 'Es esta',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: c.doradoTexto,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          tooltip: 'Ver en TMDB',
                          visualDensity: VisualDensity.compact,
                          onPressed: () => abrirConWindows(f.enlace),
                          icon: const Icon(Icons.open_in_new_rounded, size: 16),
                        ),
                      ],
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

/// Zona donde soltar la carátula arrastrada desde el Explorador. Sin
/// [child] (no hay carátula), es el recuadro de puntos «Arrastra aquí tu
/// carátula»; con él, se resalta mientras se arrastra algo encima.
class ZonaSoltarCaratula extends StatelessWidget {
  const ZonaSoltarCaratula({super.key, required this.activa, this.child});

  final bool activa;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    return ValueListenableBuilder(
      valueListenable: ArrastreArchivos.instancia.encima,
      builder: (context, encima, _) {
        final resaltada = activa && encima;
        final aviso = Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.file_upload_outlined, size: 40, color: c.dorado),
            const SizedBox(height: 12),
            Text(
              resaltada ? 'Suelta la imagen aquí' : 'Arrastra aquí tu carátula',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: c.texto,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'JPG o PNG · 350 × 500 px',
              style: TextStyle(fontSize: 13, color: c.textoSecundario),
            ),
          ],
        );
        if (child != null) {
          return Stack(
            children: [
              child!,
              if (resaltada)
                Positioned.fill(
                  child: CustomPaint(
                    foregroundPainter: _BordePuntos(c.dorado, radio: 8),
                    child: Container(
                      decoration: BoxDecoration(
                        color: c.fondo.withValues(alpha: 0.82),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: aviso,
                    ),
                  ),
                ),
            ],
          );
        }
        return AspectRatio(
          aspectRatio: 0.7,
          child: CustomPaint(
            foregroundPainter: _BordePuntos(
              resaltada ? c.dorado : c.doradoBorde,
              radio: 12,
            ),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              decoration: BoxDecoration(
                color: resaltada ? c.doradoFondo : c.superficie,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(20),
              child: aviso,
            ),
          ),
        );
      },
    );
  }
}

/// Borde de rayas (como el recuadro de «arrastra aquí» del diseño).
class _BordePuntos extends CustomPainter {
  _BordePuntos(this.color, {required this.radio});

  final Color color;
  final double radio;

  @override
  void paint(Canvas canvas, Size size) {
    final pincel = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final camino = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          Radius.circular(radio),
        ).deflate(1),
      );
    for (final tramo in camino.computeMetrics()) {
      for (var d = 0.0; d < tramo.length; d += 14) {
        canvas.drawPath(tramo.extractPath(d, d + 8), pincel);
      }
    }
  }

  @override
  bool shouldRepaint(_BordePuntos antes) =>
      antes.color != color || antes.radio != radio;
}
