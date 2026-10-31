import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../errores.dart';
import '../arranque.dart';
import '../datos/buscador.dart' show limpiarParaBuscar;
import '../datos/catalogo.dart';
import '../datos/copia_seguridad.dart';
import '../datos/excel.dart';
import '../datos/lote.dart';
import '../datos/publicacion.dart';
import '../disco/acciones_windows.dart';
import '../disco/dialogo_abrir.dart';
import '../modelos/pelicula.dart';
import '../utilidades.dart';
import 'avisos.dart';

// Exportar el catálogo a Excel, hacer una copia de seguridad y restaurarla
// (botones de Ajustes y de Estadísticas). Solo en Windows.

/// Guarda todo el catálogo en un `.xlsx` donde se elija.
Future<void> exportarExcel(BuildContext context, WidgetRef ref) async {
  final peliculas = ref.read(catalogoProvider).value ?? const <Pelicula>[];
  final hoy = DateTime.now().toIso8601String().substring(0, 10);
  final ruta = elegirDondeGuardar(
    nombre: 'Videoteca $hoy.xlsx',
    filtro: 'Libro de Excel (*.xlsx)\u0000*.xlsx\u0000',
    titulo: 'Exportar el catálogo a Excel',
  );
  if (ruta == null || !context.mounted) return;
  final bien = await _trabajando(context, 'Preparando el Excel…', () async {
    final bytes = await Isolate.run(() => _excel(peliculas));
    await File(ruta).writeAsBytes(bytes);
  });
  if (!bien || !context.mounted) return;
  _hecho(
    context,
    'Catálogo exportado: ${formatoNumero(peliculas.length)} películas.',
    ruta,
  );
}

/// Ordenadas por título (sin tener en cuenta tildes ni mayúsculas).
Uint8List _excel(List<Pelicula> peliculas) {
  final ordenadas = [...peliculas]
    ..sort(
      (a, b) =>
          limpiarParaBuscar(a.titulo).compareTo(limpiarParaBuscar(b.titulo)),
    );
  return crearExcel(ordenadas);
}

/// Hace una copia de seguridad del catálogo donde se elija.
Future<void> hacerCopia(BuildContext context, WidgetRef ref) async {
  final ruta = elegirDondeGuardar(
    nombre: nombreCopia(DateTime.now()),
    filtro: 'Copias de Videoteca (*.zip)\u0000*.zip\u0000',
    titulo: 'Guardar la copia de seguridad',
  );
  if (ruta == null || !context.mounted) return;
  final bd = ref.read(baseDatosProvider);
  InfoCopia? info;
  final bien = await _trabajando(
    context,
    'Haciendo la copia de seguridad…',
    () async {
      info = await crearCopia(
        carpetas: ref.read(carpetasAppProvider),
        destino: ruta,
        copiarBase: bd.copiarA,
      );
    },
  );
  if (!bien || !context.mounted || info == null) return;
  final mb = File(ruta).lengthSync() / (1024 * 1024);
  _hecho(
    context,
    'Copia hecha: ${formatoNumero(info!.peliculas)} películas '
    '(${mb.toStringAsFixed(0)} MB).',
    ruta,
  );
}

/// Elige una copia y, si se confirma, cambia los datos de la app por los
/// suyos. La app se cierra y se vuelve a abrir sola.
Future<void> restaurarDesdeCopia(BuildContext context, WidgetRef ref) async {
  final control = ref.read(sesionProvider);
  if (control == null) return;
  final ocupada = ref.read(escaneoProvider) != null
      ? 'se está revisando el disco'
      : ref.read(coleccionProvider).trabajando
      ? 'se está completando la colección'
      : ref.read(tablonProvider).fase == FasePublicacion.publicando
      ? 'se está publicando el catálogo'
      : null;
  if (ocupada != null) {
    _avisar(
      context,
      'Ahora no se puede restaurar: $ocupada. Espera a que termine.',
    );
    return;
  }
  final zip = elegirCopia(carpetaInicial: carpetaDocumentos());
  if (zip == null || !context.mounted) return;
  final bd = ref.read(baseDatosProvider);
  final InfoCopia info;
  try {
    info = await leerCopia(zip, versionBase: bd.schemaVersion);
  } on CopiaException catch (e) {
    if (context.mounted) _avisar(context, e.mensaje);
    return;
  }
  if (!context.mounted) return;
  final si = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('¿Restaurar esta copia?'),
      content: Text(
        'Copia del ${fechaLarga(info.fecha).toLowerCase()} de '
        '${info.fecha.year}, con ${formatoNumero(info.peliculas)} películas.\n\n'
        'El catálogo, el registro de cambios y los ajustes de la app pasan a '
        'ser los de la copia (tus claves y la conexión con el tablón se '
        'quedan como están). Los archivos de películas no se tocan: al '
        'abrirse, la app revisa el disco y se pone al día.\n\n'
        'La app se cerrará y se volverá a abrir sola.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Restaurar'),
        ),
      ],
    ),
  );
  if (!(si ?? false)) return;
  final ajustes = await bd.todosLosAjustes();
  final conservar = {
    for (final MapEntry(:key, :value) in ajustes.entries)
      if (ajustesDelEquipo.contains(key)) key: value,
  };
  final carpetas = ref.read(carpetasAppProvider);
  await control.reabrir(() async {
    await restaurarCopia(zip, carpetas, conservar: conservar);
    return 'Copia restaurada: ${formatoNumero(info.peliculas)} películas.';
  });
}

/// Hace [trabajo] con un aviso de «trabajando» encima. Si falla, lo dice y
/// devuelve `false`.
Future<bool> _trabajando(
  BuildContext context,
  String texto,
  Future<void> Function() trabajo,
) async {
  final navegador = Navigator.of(context, rootNavigator: true);
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => PopScope(
      canPop: false,
      child: AlertDialog(
        content: Row(
          children: [
            const SizedBox.square(
              dimension: 24,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            const SizedBox(width: 18),
            Expanded(child: Text(texto)),
          ],
        ),
      ),
    ),
  );
  try {
    await trabajo();
    return true;
  } catch (e) {
    if (context.mounted) {
      _avisar(context, 'No se ha podido terminar: ${explicarError(e)}');
    }
    return false;
  } finally {
    navegador.pop();
  }
}

void _hecho(BuildContext context, String texto, String ruta) {
  avisar(
    context,
    texto,
    accion: 'Ver en la carpeta',
    alPulsar: () => mostrarEnCarpeta(ruta),
  );
}

void _avisar(BuildContext context, String texto) {
  avisar(context, texto);
}
