import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../datos/ejemplo.dart';
import '../modelos/pelicula.dart';
import '../tema/colores.dart';
import '../tema/tema.dart';
import '../utilidades.dart';
import '../widgets/caratula.dart';
import '../widgets/comunes.dart';

/// Ficha completa de una película.
class PantallaFicha extends StatelessWidget {
  const PantallaFicha({super.key, required this.id});

  final int id;

  @override
  Widget build(BuildContext context) {
    final p = peliculaPorId(id);
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
            Caratula.de(p, mostrarNueva: false),
            const SizedBox(height: 14),
            Text(
              p.caratula == null
                  ? 'Carátula provisional (la real llega el día 3)'
                  : 'Carátula personalizada · 350 × 500',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: context.colores.textoTenue),
            ),
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

class _Detalles extends StatelessWidget {
  const _Detalles(this.p);

  final Pelicula p;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final tema = Theme.of(context).textTheme;
    final separador = Text('•', style: TextStyle(color: c.bordeFuerte));
    final datos = [
      ('${p.anio}'),
      if (p.duracionTexto.isNotEmpty) p.duracionTexto,
      if (p.pais.isNotEmpty) p.pais,
    ];
    final creditos = [
      ('Dirección', p.direccion),
      ('Guion', p.guion),
      ('Reparto', p.reparto),
      ('Música', p.musica),
      ('Fotografía', p.fotografia),
      ('Productora', p.productora),
      ('Premios', p.premios),
      ('Clasificación', p.clasificacion),
    ].where((e) => e.$2.isNotEmpty).toList();
    final saga = p.saga.isEmpty
        ? <Pelicula>[]
        : (peliculasEjemplo.where((o) => o.saga == p.saga).toList()
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
            for (final (nombre, valor) in creditos)
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
                    Text(
                      valor,
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.5,
                        color: c.textoSuave,
                      ),
                    ),
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
        const SizedBox(height: 28),
        Container(
          padding: const EdgeInsets.only(top: 20),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: c.borde)),
          ),
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton.icon(
                onPressed: () =>
                    avisoProximamente(context, 'Abrir FilmAffinity', 10),
                icon: const Icon(Icons.open_in_new_rounded, size: 16),
                label: const Text('FilmAffinity'),
              ),
              OutlinedButton.icon(
                onPressed: () => avisoProximamente(context, 'Abrir IMDb', 10),
                icon: const Icon(Icons.open_in_new_rounded, size: 16),
                label: const Text('IMDb'),
              ),
              if (esAdministrador)
                OutlinedButton.icon(
                  onPressed: () =>
                      avisoProximamente(context, 'Editar la ficha', 9),
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
    final (fondo, texto) = colores[edad] ?? colores['TP']!;
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

/// Bloque dorado "Dónde está": ruta, calidad, tamaño y botones.
class _DondeEsta extends StatelessWidget {
  const _DondeEsta(this.p);

  final Pelicula p;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final datos = [
      p.resolucion,
      p.tamanoTexto,
      if (p.anadida != null)
        'Añadida el ${p.anadida!.day}/${p.anadida!.month}/${p.anadida!.year}',
    ].where((t) => t.isNotEmpty);
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
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (esAdministrador) ...[
                FilledButton.icon(
                  onPressed: () => avisoProximamente(context, 'Reproducir', 7),
                  icon: const Icon(Icons.play_arrow_rounded, size: 18),
                  label: const Text('Reproducir'),
                ),
                OutlinedButton.icon(
                  onPressed: () =>
                      avisoProximamente(context, 'Abrir la carpeta', 7),
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
