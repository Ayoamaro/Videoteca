import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../datos/catalogo.dart';
import '../datos/consulta.dart';
import '../utilidades.dart';
import 'comunes.dart';

/// Aviso para cuando el catálogo no tiene ninguna película: explica por qué
/// (se está cargando, revisando la carpeta, descargando…) y qué hacer.
class ColeccionVacia extends ConsumerWidget {
  const ColeccionVacia({super.key, this.enTarjeta = true});

  final bool enTarjeta;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogo = ref.watch(catalogoProvider);
    if (catalogo.isLoading) {
      return AvisoVacio(
        icono: Icons.hourglass_empty_rounded,
        titulo: 'Cargando el catálogo…',
        enTarjeta: enTarjeta,
      );
    }
    if (catalogo.hasError) {
      return AvisoVacio(
        icono: Icons.error_outline_rounded,
        titulo: 'No se ha podido abrir el catálogo',
        texto:
            'La base de datos de la app ha fallado. Prueba a cerrar y '
            'volver a abrir la app.',
        enTarjeta: enTarjeta,
      );
    }
    if (!esAdministrador) {
      final e = ref.watch(consultaProvider);
      return AvisoVacio(
        icono: e.fase == FaseCopia.error
            ? Icons.cloud_off_outlined
            : Icons.cloud_download_outlined,
        titulo: e.trabajando
            ? 'Descargando el catálogo…'
            : e.fase == FaseCopia.error
            ? 'Todavía no se ha descargado el catálogo'
            : 'El catálogo está vacío',
        texto: e.trabajando
            ? 'Las películas aparecerán aquí en cuanto termine.'
            : e.fase == FaseCopia.error
            ? e.sinInternet
                  ? 'Hace falta internet la primera vez. Conéctate y pulsa '
                        '«Reintentar».'
                  : (e.error ?? 'Vuelve a intentarlo dentro de un rato.')
            : 'Quien administra la colección todavía no ha publicado '
                  'ninguna película.',
        accion: e.fase == FaseCopia.error ? 'Reintentar' : null,
        alPulsar: () => ref.read(consultaProvider.notifier).comprobar(),
        enTarjeta: enTarjeta,
      );
    }
    final revisando = ref.watch(escaneoProvider)?.enMarcha ?? false;
    final conectado = ref.watch(discoConectadoProvider).value ?? true;
    final disco = nombreDisco(ref.watch(carpetaRaizProvider));
    return AvisoVacio(
      icono: revisando ? Icons.manage_search_rounded : Icons.movie_outlined,
      titulo: revisando
          ? 'Revisando la carpeta de la colección…'
          : 'Todavía no hay películas',
      texto: revisando
          ? 'Las películas irán apareciendo en cuanto termine.'
          : !conectado
          ? 'No se encuentra $disco. Conéctalo o elige otra carpeta en '
                'Ajustes.'
          : 'Copia tus películas en la carpeta de la colección (con '
                'nombres como «Origen (2010).mp4») o elige otra carpeta en '
                'Ajustes.',
      accion: revisando ? null : 'Ir a Ajustes',
      alPulsar: () => context.go('/ajustes'),
      enTarjeta: enTarjeta,
    );
  }
}
