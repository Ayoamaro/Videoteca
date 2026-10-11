import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../utilidades.dart';
import 'catalogo.dart';
import 'red_casa.dart';

// Dónde está, desde este aparato, el archivo de cada película: en el PC del
// administrador, en su disco; en un PC de consulta, en el PC de las
// películas, por la red de casa; en el móvil (o en un PC sin la red), en
// ningún sitio al que se pueda llegar: solo se dice en qué carpeta está.

/// Si desde este aparato se llega al archivo de una película.
enum AccesoArchivo {
  /// Se llega: se puede reproducir, abrir su carpeta y leer la carátula.
  disponible,

  /// Todavía se está mirando si se llega al PC de las películas.
  comprobando,

  /// PC del administrador: el disco (o la carpeta) de la colección no está
  /// conectado.
  sinDisco,

  /// Red de casa: el PC de las películas no contesta (apagado, sin red o
  /// este PC fuera de casa).
  sinConexion,

  /// Red de casa: Windows pide usuario y contraseña para entrar.
  contrasena,

  /// Red de casa: se llega al PC, pero en esa carpeta no están las
  /// películas.
  carpetaIncorrecta,

  /// El archivo ya no está en esa ruta (se ha movido, renombrado o borrado
  /// y el catálogo aún no está al día).
  noEsta,
}

class Ubicacion {
  const Ubicacion({
    this.ruta,
    this.acceso = AccesoArchivo.disponible,
    this.red,
  });

  /// Ruta completa del archivo en este aparato (`D:\…` o `\\PC\…`); `null`
  /// si desde aquí no se llega a los archivos (móvil o PC sin la red de
  /// casa).
  final String? ruta;

  final AccesoArchivo acceso;

  /// Red de casa: la carpeta de las películas en la red (para abrirla en el
  /// Explorador si pide contraseña).
  final String? red;

  bool get disponible => ruta != null && acceso == AccesoArchivo.disponible;
}

/// Dónde está, desde este aparato, la película de [ruta] (la del catálogo:
/// completa en el PC del administrador, dentro de la colección en consulta).
final ubicacionProvider = Provider.autoDispose.family<Ubicacion, String>((
  ref,
  ruta,
) {
  if (esAdministrador) {
    // Mientras se comprueba, se da por bueno (así no parpadea el aviso).
    final conectado = ref.watch(discoConectadoProvider).value ?? true;
    final existe = ref.watch(archivoExisteProvider(ruta)).value ?? true;
    return Ubicacion(
      ruta: ruta,
      acceso: !conectado
          ? AccesoArchivo.sinDisco
          : !existe
          ? AccesoArchivo.noEsta
          : AccesoArchivo.disponible,
    );
  }
  if (!hayRedDeCasa) return const Ubicacion();
  final red = ref.watch(redCasaProvider);
  final completa = red.rutaDe(ruta);
  if (completa == null) return const Ubicacion();
  final acceso = switch (red.fase) {
    FaseRed.sinRuta || FaseRed.sinComprobar => AccesoArchivo.comprobando,
    FaseRed.sinConexion => AccesoArchivo.sinConexion,
    FaseRed.contrasena => AccesoArchivo.contrasena,
    FaseRed.noEncontrada => AccesoArchivo.carpetaIncorrecta,
    FaseRed.disponible => switch (ref.watch(archivoEnRedProvider(completa))) {
      // Mientras se mira, también se da por bueno.
      AsyncValue(hasValue: false) => AccesoArchivo.disponible,
      AsyncValue(value: true) => AccesoArchivo.disponible,
      AsyncValue(value: false) => AccesoArchivo.noEsta,
      _ => AccesoArchivo.sinConexion,
    },
  };
  return Ubicacion(ruta: completa, acceso: acceso, red: red.ruta);
});

/// ¿Está el archivo [ruta] por la red de casa? Se vuelve a mirar con cada
/// comprobación de la red (cada minuto). `null` si el PC no contesta.
final archivoEnRedProvider = FutureProvider.autoDispose.family<bool?, String>((
  ref,
  ruta,
) {
  ref.watch(redCasaProvider.select((e) => e.comprobada));
  return ref.read(servicioRedProvider).existe(ruta);
});
