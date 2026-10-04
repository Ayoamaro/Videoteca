import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../datos/catalogo.dart';
import '../disco/dialogo_abrir.dart';
import '../disco/escaner.dart';
import '../tema/colores.dart';
import '../tema/tema.dart';
import '../utilidades.dart';
import '../widgets/comunes.dart';
import '../widgets/progreso_escaneo.dart';

enum _Paso { inicio, analizando, resumen, escaneando }

/// Asistente de primer arranque: elegir la carpeta de las películas, ver qué
/// se ha encontrado y leerlas todas.
///
/// También se abre desde Ajustes → "Cambiar carpeta".
class PantallaBienvenida extends ConsumerStatefulWidget {
  const PantallaBienvenida({super.key});

  @override
  ConsumerState<PantallaBienvenida> createState() => _PantallaBienvenidaState();
}

class _PantallaBienvenidaState extends ConsumerState<PantallaBienvenida> {
  var _paso = _Paso.inicio;
  String? _carpeta;
  EstructuraColeccion? _estructura;
  String? _error;

  Future<void> _elegirCarpeta() async {
    final carpeta = elegirCarpeta(
      carpetaInicial: _carpeta ?? ref.read(carpetaRaizProvider),
    );
    if (carpeta == null) return;
    setState(() {
      _carpeta = carpeta;
      _paso = _Paso.analizando;
      _error = null;
    });
    try {
      final estructura = await analizarCarpeta(carpeta);
      if (!mounted) return;
      setState(() {
        _estructura = estructura;
        _paso = _Paso.resumen;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'No se ha podido leer la carpeta: $e';
        _paso = _Paso.inicio;
      });
    }
  }

  Future<void> _escanear() async {
    setState(() => _paso = _Paso.escaneando);
    await ref.read(escaneoProvider.notifier).iniciar(raiz: _carpeta);
  }

  Future<void> _terminar() async {
    await ref.read(carpetaRaizProvider.notifier).cambiar(_carpeta!);
    if (mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final yaConfigurada = ref.watch(carpetaRaizProvider) != null;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(Icons.movie_outlined, size: 30, color: c.dorado),
                      const SizedBox(width: 10),
                      Text(
                        'Videoteca',
                        style: TextStyle(
                          fontFamily: fuenteTitulos,
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: c.texto,
                        ),
                      ),
                      const Spacer(),
                      if (yaConfigurada && _paso != _Paso.escaneando)
                        TextButton(
                          onPressed: () => context.go('/ajustes'),
                          child: const Text('Volver'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  _Pasos(actual: _paso),
                  const SizedBox(height: 18),
                  Tarjeta(
                    relleno: const EdgeInsets.all(32),
                    child: AnimatedSize(
                      duration: const Duration(milliseconds: 200),
                      alignment: Alignment.topCenter,
                      child: switch (_paso) {
                        _Paso.inicio => _inicio(),
                        _Paso.analizando => _analizando(),
                        _Paso.resumen => _resumen(),
                        _Paso.escaneando => _escaneando(),
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _inicio() {
    final c = context.colores;
    final tema = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('¿Dónde guardas tus películas?', style: tema.headlineSmall),
        const SizedBox(height: 14),
        Text(
          'Elige la carpeta principal de tu colección (por ejemplo, el disco '
          'entero). La app buscará todos los archivos .mp4 que haya dentro, '
          'en todas sus subcarpetas, y leerá sus datos y carátulas.',
          style: TextStyle(fontSize: 15, height: 1.55, color: c.textoSuave),
        ),
        const SizedBox(height: 14),
        _Nota(
          icono: Icons.lock_outline_rounded,
          texto: 'Solo se leen los archivos: no se cambia nada de ellos.',
        ),
        const SizedBox(height: 6),
        _Nota(
          icono: Icons.folder_outlined,
          texto:
              'Los géneros se sacan de los nombres de las carpetas, '
              'p. ej. Comedias › Comedia › Película (2015).mp4.',
        ),
        if (_error != null) ...[
          const SizedBox(height: 16),
          Text(_error!, style: TextStyle(color: c.rojo)),
        ],
        const SizedBox(height: 26),
        FilledButton.icon(
          onPressed: _elegirCarpeta,
          icon: const Icon(Icons.folder_open_rounded),
          label: const Text('Elegir carpeta…'),
        ),
      ],
    );
  }

  Widget _analizando() {
    final c = context.colores;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          SizedBox(
            width: 36,
            height: 36,
            child: CircularProgressIndicator(color: c.dorado),
          ),
          const SizedBox(height: 18),
          Text(
            'Buscando películas en $_carpeta…',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: c.textoSuave),
          ),
        ],
      ),
    );
  }

  Widget _resumen() {
    final c = context.colores;
    final tema = Theme.of(context).textTheme;
    final e = _estructura!;
    final vacia = e.total == 0;
    // Medido en un disco duro mecánico: unos 65 ms por película.
    final estimado = Duration(milliseconds: e.total * 65);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CarpetaElegida(_carpeta!),
        const SizedBox(height: 22),
        if (vacia) ...[
          Text('No hay películas aquí', style: tema.headlineSmall),
          const SizedBox(height: 10),
          Text(
            'No se ha encontrado ningún archivo .mp4 en esta carpeta ni en '
            'sus subcarpetas. Prueba con otra.',
            style: TextStyle(fontSize: 15, height: 1.5, color: c.textoSuave),
          ),
        ] else ...[
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: formatoNumero(e.total),
                  style: TextStyle(color: c.dorado),
                ),
                TextSpan(
                  text: e.total == 1 ? ' película encontrada' : ' películas',
                ),
              ],
            ),
            style: tema.headlineMedium,
          ),
          const SizedBox(height: 6),
          Text(
            [
              if (e.porGrupo.isNotEmpty)
                '${e.porGrupo.length} '
                    '${e.porGrupo.length == 1 ? 'carpeta' : 'carpetas'}',
              '${e.porGenero.length} '
                  '${e.porGenero.length == 1 ? 'género' : 'géneros'}',
            ].join(' y '),
            style: TextStyle(fontSize: 15, color: c.textoSecundario),
          ),
          const SizedBox(height: 20),
          const Etiqueta('Géneros detectados'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (genero, total) in e.generos)
                Chip(
                  label: Text('$genero  ·  ${formatoNumero(total)}'),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          const SizedBox(height: 22),
          _Nota(
            icono: Icons.schedule_rounded,
            texto:
                'Leer todas tardará ${duracionTexto(estimado)} la primera '
                'vez. Después solo se leen las nuevas o cambiadas.',
          ),
        ],
        const SizedBox(height: 26),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            if (!vacia)
              FilledButton.icon(
                onPressed: _escanear,
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Leer las películas'),
              ),
            OutlinedButton(
              onPressed: _elegirCarpeta,
              child: const Text('Elegir otra carpeta'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _escaneando() {
    final progreso =
        ref.watch(escaneoProvider) ??
        const ProgresoEscaneo(fase: FaseEscaneo.buscando);
    final c = context.colores;
    final acabado =
        progreso.fase == FaseEscaneo.terminado ||
        progreso.fase == FaseEscaneo.cancelado;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CarpetaElegida(_carpeta!),
        const SizedBox(height: 26),
        ProgresoEscaneoVista(
          progreso,
          alCancelar: ref.read(escaneoProvider.notifier).cancelar,
        ),
        if (progreso.enMarcha) ...[
          const SizedBox(height: 20),
          Text(
            'Puedes seguir usando el PC mientras tanto.',
            style: TextStyle(fontSize: 13, color: c.textoTenue),
          ),
        ],
        if (acabado) ...[
          const SizedBox(height: 26),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: _terminar,
              icon: const Icon(Icons.arrow_forward_rounded),
              label: const Text('Ir a mi colección'),
            ),
          ),
        ],
        if (progreso.fase == FaseEscaneo.error) ...[
          const SizedBox(height: 26),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton(
              onPressed: _elegirCarpeta,
              child: const Text('Elegir otra carpeta'),
            ),
          ),
        ],
      ],
    );
  }
}

/// "1 Carpeta · 2 Revisión · 3 Lectura"
class _Pasos extends StatelessWidget {
  const _Pasos({required this.actual});

  final _Paso actual;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final numero = switch (actual) {
      _Paso.inicio || _Paso.analizando => 1,
      _Paso.resumen => 2,
      _Paso.escaneando => 3,
    };
    return Row(
      children: [
        for (final (i, nombre) in const [
          (1, 'Carpeta'),
          (2, 'Revisión'),
          (3, 'Lectura'),
        ]) ...[
          if (i > 1)
            Expanded(
              child: Divider(
                indent: 10,
                endIndent: 10,
                color: i <= numero ? c.doradoBorde : c.borde,
              ),
            ),
          CircleAvatar(
            radius: 13,
            backgroundColor: i <= numero ? c.dorado : c.seleccion,
            child: Text(
              '$i',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: i <= numero ? c.sobreDorado : c.textoSecundario,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            nombre,
            style: TextStyle(
              fontSize: 14,
              fontWeight: i == numero ? FontWeight.w700 : FontWeight.w500,
              color: i == numero ? c.texto : c.textoSecundario,
            ),
          ),
        ],
      ],
    );
  }
}

class _CarpetaElegida extends StatelessWidget {
  const _CarpetaElegida(this.ruta);

  final String ruta;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    return Row(
      children: [
        Icon(Icons.folder_rounded, color: c.doradoTexto),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            ruta,
            style: TextStyle(
              fontFamily: fuenteRutas,
              fontSize: 15,
              color: c.textoSuave,
            ),
          ),
        ),
      ],
    );
  }
}

class _Nota extends StatelessWidget {
  const _Nota({required this.icono, required this.texto});

  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icono, size: 18, color: c.textoSecundario),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            texto,
            style: TextStyle(
              fontSize: 14,
              height: 1.45,
              color: c.textoSecundario,
            ),
          ),
        ),
      ],
    );
  }
}
