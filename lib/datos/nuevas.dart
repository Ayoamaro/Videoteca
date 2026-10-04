import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../fuentes/conexion.dart';
import '../fuentes/datos_automaticos.dart';
import '../fuentes/identificacion.dart';
import '../modelos/pelicula.dart';
import 'fuentes.dart';
import 'vigilancia.dart';

// Películas nuevas: en cuanto aparece una en la bandeja, la app busca sola
// sus datos en TMDB (de una en una, sin que hagas nada). Cuando abres
// «Completar ficha», los datos ya están ahí.
//
// Lo encontrado se guarda solo en memoria: si cierras la app, se vuelve a
// buscar (tarda un par de segundos por película).

enum EstadoBusqueda {
  /// En la cola, todavía no se ha buscado.
  esperando,
  buscando,

  /// Identificada (o elegida por ti) y con sus datos: lista para revisar.
  lista,

  /// Hay varias parecidas y ninguna segura: tienes que elegir cuál es.
  elegir,

  /// TMDB no tiene nada parecido.
  noEncontrada,

  /// Ha fallado (sin internet, clave mala…).
  error,
}

/// Lo que se sabe de la búsqueda de una película nueva.
class BusquedaNueva {
  const BusquedaNueva(
    this.estado, {
    this.identificacion,
    this.resultado,
    this.pelicula,
    this.probable = false,
    this.elegida = false,
    this.mensaje = '',
  });

  final EstadoBusqueda estado;

  /// Las candidatas de TMDB (para el selector «¿Cuál es?»).
  final Identificacion? identificacion;

  /// Los datos de la película identificada o elegida.
  final ResultadoDatos? resultado;
  final Candidato? pelicula;

  /// Identificada solo por título y año (el archivo no tiene director).
  final bool probable;

  /// La has elegido tú entre las parecidas.
  final bool elegida;

  /// Explicación para enseñar (motivo de las dudas, error…).
  final String mensaje;
}

/// Búsquedas de las películas de la bandeja (id → búsqueda).
final busquedasNuevasProvider =
    NotifierProvider<BusquedasNuevas, Map<int, BusquedaNueva>>(
      BusquedasNuevas.new,
    );

class BusquedasNuevas extends Notifier<Map<int, BusquedaNueva>> {
  var _enMarcha = false;

  @override
  Map<int, BusquedaNueva> build() {
    // Cada vez que cambia la bandeja (o se pone la clave de TMDB), se
    // buscan las que falten.
    ref.listen(nuevasProvider, (_, _) => _procesar());
    ref.listen(fuentesDatosProvider, (_, _) => _procesar());
    Future.microtask(_procesar);
    return const {};
  }

  /// Datos de la película para identificarla (los del catálogo: si el
  /// archivo no tiene título ni año, salen de su nombre).
  static DatosIdentificacion datosDe(Pelicula p) => (
    titulo: p.titulo,
    tituloOriginal: p.tituloOriginal,
    anio: p.anio,
    direccion: p.direccion,
  );

  void _poner(int id, BusquedaNueva b) => state = {...state, id: b};

  /// Busca, de una en una, las películas de la bandeja que no tienen
  /// búsqueda (las ya guardadas no se buscan).
  Future<void> _procesar() async {
    if (_enMarcha) return;
    _enMarcha = true;
    try {
      while (true) {
        final fuentes = ref.read(fuentesDatosProvider);
        if (fuentes == null) return;
        final siguiente = ref
            .read(nuevasProvider)
            .where((p) => p.completada == null && !state.containsKey(p.id))
            .firstOrNull;
        if (siguiente == null) return;
        await _buscar(siguiente.id, datosDe(siguiente), fuentes);
      }
    } finally {
      _enMarcha = false;
    }
  }

  Future<void> _buscar(
    int id,
    DatosIdentificacion datos,
    FuentesDatos fuentes,
  ) async {
    _poner(id, const BusquedaNueva(EstadoBusqueda.buscando));
    try {
      final r = await fuentes.buscar(datos);
      final ident = r.identificacion;
      if (ident.seguridad == Seguridad.segura) {
        _poner(
          id,
          BusquedaNueva(
            EstadoBusqueda.lista,
            identificacion: ident,
            resultado: r,
            pelicula: ident.candidatos.first,
            mensaje: ident.motivo,
          ),
        );
        return;
      }
      if (ident.seguridad == Seguridad.noEncontrada) {
        _poner(
          id,
          BusquedaNueva(
            EstadoBusqueda.noEncontrada,
            identificacion: ident,
            mensaje: ident.motivo,
          ),
        );
        return;
      }
      final probable = candidataProbable(ident, datos);
      if (probable == null) {
        _poner(
          id,
          BusquedaNueva(
            EstadoBusqueda.elegir,
            identificacion: ident,
            mensaje: ident.motivo,
          ),
        );
        return;
      }
      final completo = await fuentes.completar(ident, probable.ficha);
      _poner(
        id,
        BusquedaNueva(
          EstadoBusqueda.lista,
          identificacion: ident,
          resultado: completo,
          pelicula: probable,
          probable: true,
          mensaje: probable.explicacion,
        ),
      );
    } on FuenteException catch (e) {
      _poner(id, BusquedaNueva(EstadoBusqueda.error, mensaje: e.mensaje));
    } catch (e) {
      _poner(
        id,
        BusquedaNueva(EstadoBusqueda.error, mensaje: 'Ha fallado: $e'),
      );
    }
  }

  /// La película [id] es la candidata [c] (elegida en «¿Cuál es?»).
  Future<void> elegir(int id, Candidato c) async {
    final fuentes = ref.read(fuentesDatosProvider);
    final ident = state[id]?.identificacion;
    if (fuentes == null || ident == null) return;
    _poner(id, BusquedaNueva(EstadoBusqueda.buscando, identificacion: ident));
    try {
      final r = await fuentes.completar(ident, c.ficha);
      _poner(
        id,
        BusquedaNueva(
          EstadoBusqueda.lista,
          identificacion: ident,
          resultado: r,
          pelicula: c,
          elegida: true,
        ),
      );
    } on FuenteException catch (e) {
      _poner(
        id,
        BusquedaNueva(
          EstadoBusqueda.error,
          identificacion: ident,
          mensaje: e.mensaje,
        ),
      );
    }
  }

  /// Vuelve a buscar la película [id] con otros datos (p. ej. otro título)
  /// o, sin [datos], con los del catálogo.
  Future<void> buscarDeNuevo(int id, [DatosIdentificacion? datos]) async {
    final fuentes = ref.read(fuentesDatosProvider);
    final p = ref.read(nuevasProvider).where((p) => p.id == id).firstOrNull;
    datos ??= p == null ? null : datosDe(p);
    if (fuentes == null || datos == null) return;
    await _buscar(id, datos, fuentes);
  }

  /// Vuelve a intentar las que fallaron (p. ej. al volver internet).
  void reintentarErrores() {
    state = {
      for (final MapEntry(:key, :value) in state.entries)
        if (value.estado != EstadoBusqueda.error) key: value,
    };
    _procesar();
  }
}

/// Estado de una película en la bandeja, para enseñarlo.
enum EstadoNueva {
  sinClave('Falta la clave de TMDB'),
  buscando('Buscando datos…'),
  lista('Lista para revisar'),
  elegir('Varias coincidencias'),
  noEncontrada('No encontrada'),
  error('Sin conexión'),
  guardada('Guardada'),
  guardadaSinCaratula('Guardada · sin carátula');

  const EstadoNueva(this.texto);

  final String texto;
}

/// El estado de [p] en la bandeja según su búsqueda [b].
EstadoNueva estadoNueva(Pelicula p, BusquedaNueva? b, {required bool clave}) {
  if (p.completada != null) {
    return p.tieneCaratula
        ? EstadoNueva.guardada
        : EstadoNueva.guardadaSinCaratula;
  }
  if (b == null) return clave ? EstadoNueva.buscando : EstadoNueva.sinClave;
  return switch (b.estado) {
    EstadoBusqueda.esperando || EstadoBusqueda.buscando => EstadoNueva.buscando,
    EstadoBusqueda.lista => EstadoNueva.lista,
    EstadoBusqueda.elegir => EstadoNueva.elegir,
    EstadoBusqueda.noEncontrada => EstadoNueva.noEncontrada,
    EstadoBusqueda.error => EstadoNueva.error,
  };
}

/// Películas de la bandeja que aún no se han guardado (para la insignia del
/// menú y para pasar a la siguiente al guardar).
final nuevasSinGuardarProvider = Provider<List<Pelicula>>(
  (ref) => [
    for (final p in ref.watch(nuevasProvider))
      if (p.completada == null) p,
  ],
);
