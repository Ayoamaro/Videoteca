import 'dart:isolate';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../disco/dialogo_abrir.dart';
import '../disco/lector_archivo.dart';
import '../modelos/pelicula.dart';
import '../tema/colores.dart';
import '../tema/tema.dart';
import '../widgets/caratula.dart';
import '../widgets/comunes.dart';

/// Último archivo leído, para no perderlo al ir a la ficha y volver.
class UltimaLectura extends Notifier<DatosArchivo?> {
  @override
  DatosArchivo? build() => null;

  void guardar(DatosArchivo datos) => state = datos;
}

final ultimaLecturaProvider = NotifierProvider<UltimaLectura, DatosArchivo?>(
  UltimaLectura.new,
);

/// Prueba de lectura: eliges un `.mp4` y la app enseña lo que lee de él, para
/// compararlo con "Propiedades → Detalles" del Explorador. Solo lee.
class PantallaLectura extends ConsumerStatefulWidget {
  const PantallaLectura({super.key});

  @override
  ConsumerState<PantallaLectura> createState() => _PantallaLecturaState();
}

class _PantallaLecturaState extends ConsumerState<PantallaLectura> {
  bool _leyendo = false;
  String? _error;

  Future<void> _elegir() async {
    final anterior = ref.read(ultimaLecturaProvider)?.ruta;
    final ruta = elegirMp4(
      carpetaInicial: anterior?.substring(0, anterior.lastIndexOf(r'\')),
    );
    if (ruta == null) return;
    setState(() {
      _leyendo = true;
      _error = null;
    });
    try {
      // Se lee en segundo plano para que la ventana no se quede congelada.
      final datos = await Isolate.run(() => leerArchivo(ruta));
      ref.read(ultimaLecturaProvider.notifier).guardar(datos);
    } catch (e) {
      _error = '$e';
    } finally {
      if (mounted) setState(() => _leyendo = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final datos = ref.watch(ultimaLecturaProvider);
    return PaginaBase(
      children: [
        CabeceraPagina(
          titulo: 'Leer un archivo',
          descripcion:
              'Elige una película del disco y mira lo que la app lee de ella: '
              'los datos de "Propiedades → Detalles", la carátula, la duración, '
              'la resolución y el tamaño. Solo lectura: el archivo no se toca.',
          acciones: [
            FilledButton.icon(
              onPressed: _leyendo ? null : _elegir,
              icon: _leyendo
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.folder_open_rounded, size: 18),
              label: Text(_leyendo ? 'Leyendo…' : 'Elegir un .mp4…'),
            ),
          ],
        ),
        if (_error != null)
          Tarjeta(borde: context.colores.rojo, child: Text(_error!)),
        if (datos != null) _Resultado(datos),
      ],
    );
  }
}

class _Resultado extends StatelessWidget {
  const _Resultado(this.d);

  final DatosArchivo d;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final p = Pelicula.desdeArchivo(d);
    final resumen = [
      if (p.duracionTexto.isNotEmpty) p.duracionTexto,
      if (p.resolucion.isNotEmpty) p.resolucion,
      if (p.tamanoTexto.isNotEmpty) p.tamanoTexto,
      d.caratula == null
          ? 'sin carátula'
          : 'carátula de ${(d.caratula!.length / 1024).round()} KB',
    ].join(' · ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Tarjeta(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 110, child: Caratula.de(p)),
              const SizedBox(width: 22),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.titulo,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        if (p.anio > 0) '${p.anio}',
                        if (p.tituloOriginal.isNotEmpty) p.tituloOriginal,
                      ].join(' · '),
                      style: TextStyle(color: c.textoSecundario),
                    ),
                    const SizedBox(height: 10),
                    Estrellas(p.estrellas),
                    const SizedBox(height: 10),
                    Text(
                      resumen,
                      style: TextStyle(fontSize: 13, color: c.textoSuave),
                    ),
                    const SizedBox(height: 6),
                    SelectableText(
                      d.ruta,
                      style: TextStyle(
                        fontSize: 13,
                        fontFamily: fuenteRutas,
                        color: c.textoTenue,
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.tonalIcon(
                      onPressed: () => context.push('/archivo', extra: p),
                      icon: const Icon(Icons.movie_outlined, size: 18),
                      label: const Text('Ver ficha completa'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Tarjeta(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Propiedades de Windows',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                'Tal cual las devuelve Windows. Las vacías aparecen con «—».',
                style: TextStyle(fontSize: 13, color: c.textoTenue),
              ),
              const SizedBox(height: 14),
              for (final MapEntry(key: nombre, value: etiqueta)
                  in propiedadesLeidas.entries)
                _fila(context, etiqueta, nombre, d.texto(nombre)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _fila(
    BuildContext context,
    String etiqueta,
    String nombre,
    String valor,
  ) {
    final c = context.colores;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: c.borde)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 210,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  etiqueta,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  nombre,
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: fuenteRutas,
                    color: c.textoTenue,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: SelectableText(
              valor.isEmpty ? '—' : valor,
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: valor.isEmpty ? c.textoTenue : c.textoSecundario,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
