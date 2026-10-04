import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../fuentes/datos_automaticos.dart';
import '../fuentes/omdb.dart';
import '../fuentes/tmdb.dart';
import 'catalogo.dart';

// Las claves de los servicios de datos (TMDB y OMDb) y el acceso a ellos
// desde la app. Las claves se guardan solo en la base de datos de este PC
// (nunca en el repositorio ni en el tablón).

enum Servicio {
  tmdb('TMDB', 'claveTmdb'),
  omdb('OMDb', 'claveOmdb');

  const Servicio(this.nombre, this.ajuste);

  final String nombre;

  /// Nombre del ajuste donde se guarda su clave.
  final String ajuste;
}

final clavesProvider = NotifierProvider<Claves, Map<Servicio, String>>(
  Claves.new,
);

class Claves extends Notifier<Map<Servicio, String>> {
  @override
  Map<Servicio, String> build() {
    final ajustes = ref.read(ajustesInicialesProvider);
    return {for (final s in Servicio.values) s: ajustes[s.ajuste] ?? ''};
  }

  /// Comprueba [clave] con el servicio y, si funciona, la guarda. Lanza
  /// `FuenteException` si no funciona (y entonces no se guarda).
  Future<void> probarYGuardar(Servicio servicio, String clave) async {
    clave = clave.trim();
    if (clave.isNotEmpty) {
      await switch (servicio) {
        Servicio.tmdb => Tmdb(clave).probar(),
        Servicio.omdb => Omdb(clave).probar(),
      };
    }
    await ref.read(baseDatosProvider).guardarAjuste(servicio.ajuste, clave);
    state = {...state, servicio: clave};
  }
}

/// Los servicios listos para usar, o `null` si falta la clave de TMDB (sin
/// ella no se puede identificar ninguna película).
final fuentesDatosProvider = Provider<FuentesDatos?>((ref) {
  final claves = ref.watch(clavesProvider);
  final tmdb = claves[Servicio.tmdb]!;
  if (tmdb.isEmpty) return null;
  return FuentesDatos(claveTmdb: tmdb, claveOmdb: claves[Servicio.omdb]!);
});
