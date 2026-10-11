import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../datos/actualizaciones.dart';
import '../disco/abrir_enlace.dart';
import '../fuentes/actualizaciones.dart';
import '../tema/colores.dart';

// Aviso de versión nueva de la app: franja en Inicio y ventana con las
// novedades y el botón de descarga.

/// Franja de Inicio: «Hay una versión nueva de Videoteca».
class AvisoVersionNueva extends ConsumerWidget {
  const AvisoVersionNueva({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colores;
    final e = ref.watch(actualizacionProvider);
    final v = e.nueva;
    if (!e.avisar || v == null) return const SizedBox.shrink();
    return Material(
      color: c.doradoFondo,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: c.doradoBorde),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 8,
          children: [
            Icon(Icons.system_update_rounded, color: c.doradoTexto),
            Text(
              'Hay una versión nueva de Videoteca: la ${v.numero} '
              '(tienes la $versionApp).',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: c.texto,
              ),
            ),
            FilledButton.tonal(
              onPressed: () => mostrarVersionNueva(context, v),
              child: const Text('Novedades y descarga'),
            ),
            TextButton(
              onPressed: () =>
                  ref.read(actualizacionProvider.notifier).descartar(),
              child: const Text('Más tarde'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ventana con las novedades de [v] y el botón para descargarla.
Future<void> mostrarVersionNueva(BuildContext context, VersionPublicada v) {
  final c = context.colores;
  final movil = Platform.isAndroid;
  final descarga = (movil ? v.apkAndroid : v.instaladorWindows) ?? v.enlace;
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Videoteca ${v.numero}'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (v.notasLimpias.isNotEmpty)
                Text(
                  v.notasLimpias,
                  style: TextStyle(fontSize: 14, height: 1.5, color: c.texto),
                ),
              const SizedBox(height: 16),
              Text(
                movil
                    ? 'Al pulsar «Descargar» se baja la APK. Ábrela cuando '
                          'termine e instálala encima de la que tienes: no se '
                          'pierde nada.'
                    : 'Al pulsar «Descargar» se baja el instalador. Ábrelo '
                          'cuando termine: cierra la app, la actualiza y la '
                          'vuelve a abrir. Tu catálogo se conserva.',
                style: TextStyle(fontSize: 13, color: c.textoSecundario),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => abrirEnlace(v.enlace),
          child: const Text('Ver en GitHub'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cerrar'),
        ),
        FilledButton.icon(
          onPressed: () {
            Navigator.pop(context);
            abrirEnlace(descarga);
          },
          icon: const Icon(Icons.download_rounded, size: 18),
          label: const Text('Descargar'),
        ),
      ],
    ),
  );
}
