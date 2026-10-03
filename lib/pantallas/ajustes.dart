import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../pantallas/ficha.dart' show InsigniaEdad;
import '../tema/colores.dart';
import '../tema/tema.dart';
import '../utilidades.dart';
import '../widgets/comunes.dart';

/// Ajustes de la app. De momento solo funciona la apariencia; el resto se
/// irá activando en los días indicados.
class PantallaAjustes extends ConsumerWidget {
  const PantallaAjustes({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modo = ref.watch(modoTemaProvider);
    return PaginaBase(
      separacion: 22,
      children: [
        const CabeceraPagina(titulo: 'Ajustes'),
        CuadriculaAdaptable(
          anchoMinimo: 440,
          separacion: 18,
          children: [
            _Seccion(
              titulo: 'Apariencia',
              children: [
                SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(
                      value: ThemeMode.dark,
                      label: Text('Oscuro'),
                      icon: Icon(Icons.dark_mode_outlined),
                    ),
                    ButtonSegment(
                      value: ThemeMode.light,
                      label: Text('Claro'),
                      icon: Icon(Icons.light_mode_outlined),
                    ),
                    ButtonSegment(
                      value: ThemeMode.system,
                      label: Text('Sistema'),
                      icon: Icon(Icons.brightness_auto_outlined),
                    ),
                  ],
                  selected: {modo},
                  onSelectionChanged: (v) =>
                      ref.read(modoTemaProvider.notifier).cambiar(v.first),
                ),
              ],
            ),
            if (esAdministrador) ...[
              _Seccion(
                titulo: 'Colección',
                dia: 4,
                children: [
                  _campo(context, 'Carpeta raíz', r'D:\', monoespacio: true),
                  Text(
                    'Detectadas automáticamente: 7 carpetas y 16 géneros · '
                    '5.541 archivos .mp4 (ejemplo)',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.6,
                      color: context.colores.textoSuave,
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: () => context.go('/lectura'),
                      icon: const Icon(Icons.manage_search_rounded, size: 18),
                      label: const Text('Leer un archivo .mp4'),
                    ),
                  ),
                ],
              ),
              _Seccion(
                titulo: 'Publicación (tablón en GitHub)',
                dia: 14,
                children: [
                  _campo(
                    context,
                    'Repositorio del tablón',
                    '[TU-USUARIO]/videoteca-tablon',
                    monoespacio: true,
                  ),
                  _campo(
                    context,
                    'Llave de acceso de GitHub',
                    'Se guarda solo en este PC',
                  ),
                  _campo(
                    context,
                    'Contraseña común para los usuarios',
                    'Se elige el día 14',
                  ),
                ],
              ),
              _Seccion(
                titulo: 'Rotten Tomatoes → estrellas',
                dia: 10,
                children: [
                  Text(
                    'Rangos provisionales; los confirmamos el día 10.',
                    style: TextStyle(
                      fontSize: 13,
                      color: context.colores.textoSecundario,
                    ),
                  ),
                  for (final (estrellas, rango) in const [
                    (5, '90–100 %'),
                    (4, '70–89 %'),
                    (3, '50–69 %'),
                    (2, '30–49 %'),
                    (1, '0–29 %'),
                  ])
                    Row(
                      children: [
                        SizedBox(
                          width: 110,
                          child: Estrellas(estrellas, tam: 17),
                        ),
                        Text(
                          rango,
                          style: TextStyle(color: context.colores.textoSuave),
                        ),
                      ],
                    ),
                ],
              ),
              _Seccion(
                titulo: 'Clasificación por edades',
                dia: 10,
                children: [
                  Text(
                    'Cómo se escribe cada calificación oficial de España en tus archivos.',
                    style: TextStyle(
                      fontSize: 13,
                      color: context.colores.textoSecundario,
                    ),
                  ),
                  for (final (edad, frase) in const [
                    ('TP', 'Apta para todos los públicos'),
                    ('7', 'No recomendado para menores de 7 años'),
                    ('12', 'No recomendado para menores de 12 años'),
                    ('16', 'No recomendado para menores de 16 años'),
                    ('18', 'No recomendado para menores de 18 años'),
                  ])
                    Row(
                      children: [
                        SizedBox(
                          width: 56,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: InsigniaEdad(edad),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            frase,
                            style: TextStyle(color: context.colores.textoSuave),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              _Seccion(
                titulo: 'Servicios de datos',
                dia: 10,
                children: [
                  for (final (nombre, uso) in const [
                    ('TMDB', 'País, guion, fotografía, saga, edad, IMDb'),
                    ('OMDb', 'Nota de Rotten Tomatoes'),
                    (
                      'FilmAffinity',
                      'Lectura semiautomática con navegador integrado',
                    ),
                  ])
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                nombre,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                uso,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: context.colores.textoSecundario,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Pastilla(
                          'Sin configurar',
                          color: context.colores.naranja,
                          fondo: context.colores.naranjaFondo,
                        ),
                      ],
                    ),
                ],
              ),
              _Seccion(
                titulo: 'Datos',
                children: [
                  for (final (texto, dia) in const [
                    ('Exportar catálogo a Excel', 17),
                    ('Copia de seguridad del catálogo', 17),
                    ('Volver a escanear todo el disco', 4),
                  ])
                    OutlinedButton(
                      onPressed: () => avisoProximamente(context, texto, dia),
                      style: OutlinedButton.styleFrom(
                        alignment: Alignment.centerLeft,
                        minimumSize: const Size.fromHeight(46),
                      ),
                      child: Text(texto),
                    ),
                ],
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _campo(
    BuildContext context,
    String etiqueta,
    String valor, {
    bool monoespacio = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          etiqueta,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: context.colores.textoSuave,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          initialValue: valor,
          readOnly: true,
          style: TextStyle(
            fontSize: 14,
            fontFamily: monoespacio ? fuenteRutas : null,
            color: context.colores.textoSecundario,
          ),
        ),
      ],
    );
  }
}

class _Seccion extends StatelessWidget {
  const _Seccion({required this.titulo, required this.children, this.dia});

  final String titulo;
  final List<Widget> children;

  /// Día del planning en que esta sección empieza a funcionar.
  final int? dia;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    return Tarjeta(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  titulo,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (dia != null)
                Text(
                  'Día $dia',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: c.textoTenue,
                  ),
                ),
            ],
          ),
          for (final hijo in children) ...[const SizedBox(height: 14), hijo],
        ],
      ),
    );
  }
}
