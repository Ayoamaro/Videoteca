import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../errores.dart';
import '../fuentes/actualizaciones.dart';
import '../fuentes/conexion.dart';
import 'catalogo.dart';

// Aviso de versión nueva de la app (en el PC y en el móvil): un rato después
// de abrir y cada 12 horas se mira en GitHub si hay una versión más nueva
// que esta (ver `fuentes/actualizaciones.dart`). «Más tarde» deja de avisar
// en Inicio de esa versión; en Ajustes se sigue viendo.

class EstadoActualizacion {
  const EstadoActualizacion({
    this.nueva,
    this.comprobada,
    this.buscando = false,
    this.error,
    this.descartada = '',
  });

  /// La versión publicada, solo si es más nueva que esta.
  final VersionPublicada? nueva;
  final DateTime? comprobada;
  final bool buscando;
  final String? error;

  /// La versión de la que ya no se avisa en Inicio («Más tarde»).
  final String descartada;

  /// Se avisa en Inicio.
  bool get avisar => nueva != null && nueva!.etiqueta != descartada;

  EstadoActualizacion copyWith({
    VersionPublicada? Function()? nueva,
    DateTime? comprobada,
    bool? buscando,
    String? Function()? error,
    String? descartada,
  }) => EstadoActualizacion(
    nueva: nueva == null ? this.nueva : nueva(),
    comprobada: comprobada ?? this.comprobada,
    buscando: buscando ?? this.buscando,
    error: error == null ? this.error : error(),
    descartada: descartada ?? this.descartada,
  );
}

final actualizacionProvider =
    NotifierProvider<Actualizacion, EstadoActualizacion>(Actualizacion.new);

class Actualizacion extends Notifier<EstadoActualizacion> {
  static const _ajusteDescartada = 'versionDescartada';

  /// Solo se comprueba en las versiones compiladas por GitHub Actions (saben
  /// su número y dónde se publican).
  static bool get disponible => repoApp.isNotEmpty && versionApp.isNotEmpty;

  @override
  EstadoActualizacion build() {
    if (disponible) {
      // Sin frenar el arranque.
      final primera = Timer(const Duration(seconds: 8), comprobar);
      final cada12h = Timer.periodic(
        const Duration(hours: 12),
        (_) => comprobar(),
      );
      ref.onDispose(() {
        primera.cancel();
        cada12h.cancel();
      });
    }
    return EstadoActualizacion(
      descartada: ref.read(ajustesInicialesProvider)[_ajusteDescartada] ?? '',
    );
  }

  Future<void> comprobar() async {
    if (!disponible || state.buscando) return;
    state = state.copyWith(buscando: true, error: () => null);
    try {
      final v = await ultimaVersion(repoApp);
      state = state.copyWith(
        buscando: false,
        comprobada: DateTime.now(),
        nueva: () => v != null && esMasNueva(v.etiqueta, versionApp) ? v : null,
      );
    } on FuenteException catch (e) {
      state = state.copyWith(buscando: false, error: () => e.mensaje);
    } catch (e) {
      state = state.copyWith(buscando: false, error: () => explicarError(e));
    }
  }

  /// «Más tarde»: no se vuelve a avisar en Inicio de esta versión.
  Future<void> descartar() async {
    final etiqueta = state.nueva?.etiqueta;
    if (etiqueta == null) return;
    state = state.copyWith(descartada: etiqueta);
    await ref
        .read(baseDatosProvider)
        .guardarAjuste(_ajusteDescartada, etiqueta);
  }
}
