import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../disco/vigilante.dart';
import '../modelos/pelicula.dart';
import '../utilidades.dart';
import 'catalogo.dart';
import 'pendientes.dart';

// Cambios en el disco (vigilancia de carpetas), Películas nuevas y
// Pendientes.

/// Vigila la carpeta raíz mientras el disco está conectado. Cada vez que
/// Windows avisa de un cambio, la app hace una revisión rápida.
///
/// También revisa al arrancar y al volver a conectar el disco, por si algo
/// cambió mientras la app estaba cerrada o el disco desconectado.
///
/// Devuelve si está vigilando (para el recuadro de estado del menú).
final vigilanciaProvider = Provider<bool>((ref) {
  final raiz = ref.watch(carpetaRaizProvider);
  final conectado = ref.watch(discoConectadoProvider).value ?? false;
  // Hasta que termine el primer escaneo (el del asistente) no se vigila.
  final escaneada = ref.watch(ultimoEscaneoProvider.select((f) => f != null));
  if (!esAdministrador || raiz == null || !conectado || !escaneada) {
    return false;
  }

  final escaneo = ref.read(escaneoProvider.notifier);
  final vigilante = VigilanteCarpeta(raiz)..iniciar();
  final suscripcion = vigilante.cambios.listen((_) => escaneo.revisar());
  // Revisión inicial, cuando la pantalla ya está dibujada.
  final inicial = Timer(const Duration(seconds: 2), escaneo.revisar);
  ref.onDispose(() {
    inicial.cancel();
    suscripcion.cancel();
    vigilante.cerrar();
  });
  return true;
});

/// Películas en la bandeja de Películas nuevas, de la más reciente a la más
/// antigua.
final nuevasProvider = Provider<List<Pelicula>>((ref) {
  final catalogo = ref.watch(catalogoProvider).value ?? const <Pelicula>[];
  return [
    for (final p in catalogo)
      if (p.nueva) p,
  ]..sort(
    (a, b) => (b.anadida ?? DateTime(0)).compareTo(a.anadida ?? DateTime(0)),
  );
});

/// Pendientes marcados como revisados (por su clave). Se guardan en los
/// ajustes.
final revisadosProvider = NotifierProvider<Revisados, Set<String>>(
  Revisados.new,
);

class Revisados extends Notifier<Set<String>> {
  static const clave = 'pendientesRevisados';

  @override
  Set<String> build() {
    final texto = ref.read(ajustesInicialesProvider)[clave];
    if (texto == null) return const {};
    try {
      return {...(jsonDecode(texto) as List).cast<String>()};
    } catch (_) {
      return const {};
    }
  }

  Future<void> marcar(String clavePendiente, {bool revisado = true}) async {
    final nuevos = {...state};
    revisado ? nuevos.add(clavePendiente) : nuevos.remove(clavePendiente);
    state = nuevos;
    await ref
        .read(baseDatosProvider)
        .guardarAjuste(clave, jsonEncode(state.toList()..sort()));
  }
}

/// Todos los pendientes de la colección.
final pendientesProvider = Provider(
  (ref) => buscarPendientes(
    ref.watch(catalogoProvider).value ?? const [],
    desaparecidas: ref.watch(desaparecidasProvider).value ?? const [],
    revisados: ref.watch(revisadosProvider),
  ),
);

/// Número total de pendientes sin revisar (para la insignia del menú).
final totalPendientesProvider = Provider<int>(
  (ref) => ref
      .watch(pendientesProvider)
      .pendientes
      .values
      .fold(0, (suma, lista) => suma + lista.length),
);
