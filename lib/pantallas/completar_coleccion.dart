import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../tema/colores.dart';
import '../tema/tema.dart';
import '../utilidades.dart';
import '../widgets/comunes.dart';

/// Proceso por lotes que rellena los campos vacíos de toda la colección.
/// De momento muestra un ejemplo de cómo se verá; funciona el día 13.
class PantallaCompletarColeccion extends StatefulWidget {
  const PantallaCompletarColeccion({super.key});

  @override
  State<PantallaCompletarColeccion> createState() =>
      _PantallaCompletarColeccionState();
}

class _PantallaCompletarColeccionState
    extends State<PantallaCompletarColeccion> {
  // (campo, dónde se guarda en Windows, marcado)
  final _campos = [
    ['País', 'Campo «Editor»', true],
    ['Guion', 'Campo «Escritores»', true],
    ['Fotografía', 'Campo «Director de orquesta»', true],
    ['Saga y nº', 'Campos «Álbum» y «Nº»', true],
    ['Ficha IMDb', 'Campo «URL de promoción»', true],
    ['Ficha FilmAffinity', 'Campo «URL del autor»', true],
    ['Temas', 'Solo FilmAffinity · lento', false],
    ['Premios', 'Solo FilmAffinity · lento', false],
  ];

  static const _registro = [
    (
      '12:41:08',
      'El Atardecer (2007)',
      '+ País, Guion, Fotografía, IMDb',
      true,
    ),
    (
      '12:41:06',
      'Joy (2015)',
      '+ País, Guion, Fotografía, IMDb, FilmAffinity',
      true,
    ),
    (
      '12:41:03',
      'Crash (Colisión) (2004)',
      'Dudosa: dos películas con ese título en 2004',
      false,
    ),
    (
      '12:41:01',
      'Forrest Gump (1994)',
      '+ País, Guion, Fotografía, IMDb, FilmAffinity',
      true,
    ),
    (
      '12:40:58',
      'Besos de Vampiro (1989)',
      '+ País, Guion, Fotografía, IMDb',
      true,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    const hechas = 2315;
    const total = 5541;
    return PaginaBase(
      separacion: 26,
      children: [
        const CabeceraPagina(
          titulo: 'Completar mi colección',
          descripcion:
              'Rellena los campos vacíos de todas tus películas de forma automática. '
              'Nunca cambia los datos que ya tienes ni las carátulas, y solo escribe '
              'cuando título, año y director coinciden.',
        ),
        Tarjeta(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Campos a rellenar',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 16),
              CuadriculaAdaptable(
                anchoMinimo: 230,
                separacion: 10,
                children: [
                  for (final campo in _campos) _casilla(context, campo),
                ],
              ),
            ],
          ),
        ),
        Tarjeta(
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
                    'Quedan unos 40 minutos · ${(hechas * 100 / total).round()} %',
                    style: TextStyle(fontSize: 15, color: c.textoSuave),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: LinearProgressIndicator(
                  value: hechas / total,
                  minHeight: 14,
                  backgroundColor: c.borde,
                  color: c.dorado,
                  semanticsLabel: 'Progreso',
                ),
              ),
              const SizedBox(height: 18),
              Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(text: 'Ahora: '),
                    TextSpan(
                      text: r'Drama \ El Atardecer (2007).mp4',
                      style: TextStyle(color: c.texto),
                    ),
                  ],
                ),
                style: TextStyle(fontSize: 14, color: c.textoSecundario),
              ),
              const SizedBox(height: 18),
              CuadriculaAdaptable(
                anchoMinimo: 180,
                separacion: 12,
                children: [
                  Contador(
                    valor: '2.270',
                    texto: 'completadas',
                    color: c.verde,
                    fondo: c.verdeFondo,
                    colorTexto: c.textoSuave,
                  ),
                  Contador(
                    valor: '41',
                    texto: 'dudosas (sin tocar)',
                    color: c.naranja,
                    fondo: c.naranjaFondo,
                    colorTexto: c.textoSuave,
                  ),
                  Contador(
                    valor: '4',
                    texto: 'no encontradas',
                    color: c.rojo,
                    fondo: c.rojoFondo,
                    colorTexto: c.textoSuave,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  FilledButton.icon(
                    onPressed: () => avisoProximamente(
                      context,
                      'Completar la colección',
                      13,
                    ),
                    icon: const Icon(Icons.pause_rounded, size: 18),
                    label: const Text('Pausar'),
                  ),
                  OutlinedButton(
                    onPressed: () => context.go('/pendientes'),
                    child: const Text('Ver dudosas'),
                  ),
                  OutlinedButton(
                    onPressed: () =>
                        avisoProximamente(context, 'Deshacer cambios', 9),
                    child: const Text('Deshacer cambios…'),
                  ),
                ],
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Registro de cambios',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 10),
            Tarjeta(
              relleno: EdgeInsets.zero,
              radio: 12,
              fondo: Colors.transparent,
              child: Column(
                children: [
                  for (var i = 0; i < _registro.length; i++)
                    _lineaRegistro(
                      context,
                      _registro[i],
                      ultima: i == _registro.length - 1,
                    ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _casilla(BuildContext context, List<Object> campo) {
    final c = context.colores;
    final marcado = campo[2] as bool;
    return Material(
      color: c.superficieAlta,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: c.borde),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => setState(() => campo[2] = !marcado),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              Checkbox(
                value: marcado,
                onChanged: (v) => setState(() => campo[2] = v ?? false),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      campo[0] as String,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      campo[1] as String,
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

  Widget _lineaRegistro(
    BuildContext context,
    (String, String, String, bool) linea, {
    required bool ultima,
  }) {
    final c = context.colores;
    final (hora, titulo, mensaje, bien) = linea;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
            width: 220,
            child: Text(
              titulo,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ),
          Text(
            mensaje,
            style: TextStyle(fontSize: 13, color: bien ? c.verde : c.naranja),
          ),
        ],
      ),
    );
  }
}
