import '../disco/escritor.dart' show Campo, validarCampo;
import 'conexion.dart';
import 'datos_automaticos.dart';
import 'identificacion.dart';

// «Completar mi colección»: qué escribir en cada película del lote.
//
// Solo se rellenan campos **vacíos**, con datos de TMDB, OMDb y Wikidata, y
// solo si la película se identifica sin dudas (título + año + director).
// Las dudosas y las no encontradas se dejan sin tocar. Los temas y premios
// (solo están en FilmAffinity) no van en el lote: se hacen en el «Repaso con
// FilmAffinity», contigo delante (copiando su ficha del navegador).
//
// No usa nada de Flutter.

/// Lo que se puede rellenar en el lote, como casillas: cada una con sus
/// campos (saga y número van juntos) y de dónde sale.
enum OpcionLote {
  tituloOriginal('Título original', 'TMDB', [Campo.tituloOriginal]),
  pais('País', 'TMDB', [Campo.pais]),
  sinopsis('Sinopsis', 'TMDB', [Campo.sinopsis]),
  reparto('Reparto', 'TMDB', [Campo.reparto]),
  guion('Guion', 'TMDB', [Campo.guion]),
  musica('Música', 'TMDB', [Campo.musica]),
  fotografia('Fotografía', 'TMDB', [Campo.fotografia]),
  productora('Productora', 'TMDB', [Campo.productora]),
  saga('Saga y nº', 'TMDB', [Campo.saga, Campo.numeroSaga]),
  clasificacion('Clasificación por edad', 'TMDB', [Campo.clasificacion]),
  estrellas('Estrellas', 'OMDb · Rotten Tomatoes', [Campo.estrellas]),
  imdb('Enlace a IMDb', 'TMDB', [Campo.enlaceImdb]),
  filmaffinity('Enlace a FilmAffinity', 'Wikidata', [Campo.enlaceFilmaffinity]);

  const OpcionLote(this.nombre, this.origen, this.campos);

  final String nombre;
  final String origen;
  final List<Campo> campos;

  static Set<Campo> camposDe(Iterable<OpcionLote> opciones) => {
    for (final o in opciones) ...o.campos,
  };
}

/// Cómo ha terminado una película del lote.
enum EstadoLote {
  /// Identificada y con datos nuevos escritos en el archivo.
  completada('Completada', 'completadas'),

  /// Identificada, pero las fuentes no tenían nada para sus campos vacíos.
  sinDatos('Sin datos nuevos', 'sin datos nuevos'),

  /// Hay parecidas, pero no coinciden título, año y director: sin tocar.
  dudosa('Dudosa', 'dudosas'),

  /// TMDB no tiene nada parecido.
  noEncontrada('No encontrada', 'no encontradas'),

  /// No se ha podido escribir (o ha fallado algo de esa película).
  error('Error', 'con error');

  const EstadoLote(this.texto, this.plural);

  final String texto;

  /// «14 completadas».
  final String plural;

  static EstadoLote porNombre(String nombre) =>
      values.firstWhere((e) => e.name == nombre, orElse: () => error);
}

/// Lo que se va a hacer con una película.
class PlanLote {
  const PlanLote(
    this.estado, {
    this.cambios = const {},
    this.mensaje = '',
    this.fallos = const [],
  });

  final EstadoLote estado;

  /// Campo → valor nuevo; solo campos que estaban vacíos.
  final Map<Campo, String> cambios;

  /// Para enseñar: «+ País, Guion…» o el motivo de las dudas.
  final String mensaje;

  /// Lo que no se ha podido consultar (p. ej. el límite de OMDb). La
  /// película se escribe igual con lo demás.
  final List<FuenteException> fallos;

  bool get limiteOmdb => fallos.any((f) => f.servicio == 'OMDb' && f.limite);
}

/// Los [campos] que están vacíos en [actuales].
Set<Campo> camposVacios(Map<Campo, String> actuales, Set<Campo> campos) => {
  for (final c in campos)
    if ((actuales[c] ?? '').trim().isEmpty) c,
};

/// «+ País, Guion, Fotografía».
String resumenCampos(Iterable<Campo> campos) =>
    '+ ${[for (final c in Campo.values)
      if (campos.contains(c)) c.nombre].join(', ')}';

/// Decide qué escribir en una película: la identifica con [fuentes] y se
/// queda con los datos de sus [campos] vacíos.
///
/// Con [sinOmdb] no se piden estrellas (se ha llegado al límite del día).
/// Lanza [FuenteException] si falla la conexión o la clave de TMDB (entonces
/// el lote se para: no es culpa de esta película).
Future<PlanLote> planificarLote(
  FuentesDatos fuentes, {
  required DatosIdentificacion datos,
  required Map<Campo, String> actuales,
  required Set<Campo> campos,
  bool sinOmdb = false,
}) async {
  final vacios = camposVacios(actuales, campos);
  if (sinOmdb) vacios.remove(Campo.estrellas);
  if (vacios.isEmpty) {
    return const PlanLote(EstadoLote.sinDatos, mensaje: 'Ya estaba completa.');
  }
  final r = await fuentes.buscar(datos, solo: vacios);
  final ident = r.identificacion;
  switch (ident.seguridad) {
    case Seguridad.dudosa:
      return PlanLote(EstadoLote.dudosa, mensaje: ident.motivo);
    case Seguridad.noEncontrada:
      return PlanLote(EstadoLote.noEncontrada, mensaje: ident.motivo);
    case Seguridad.segura:
      break;
  }

  final cambios = <Campo, String>{};
  for (final c in vacios) {
    final valor = r.datos[c]?.valor.trim() ?? '';
    if (valor.isEmpty || validarCampo(c, valor) != null) continue;
    cambios[c] = valor;
  }
  // El número en la saga solo vale para la saga de TMDB: si ya tenías otra
  // saga distinta escrita, no se pone.
  if (cambios.containsKey(Campo.numeroSaga) &&
      !cambios.containsKey(Campo.saga)) {
    final tuya = actuales[Campo.saga] ?? '';
    final suya = r.datos[Campo.saga]?.valor ?? '';
    if (tuya.isEmpty || suya.isEmpty || !titulosParecidos(tuya, suya)) {
      cambios.remove(Campo.numeroSaga);
    }
  }

  if (cambios.isEmpty) {
    return PlanLote(
      EstadoLote.sinDatos,
      mensaje: 'Las fuentes no tienen nada para sus campos vacíos.',
      fallos: r.fallos,
    );
  }
  return PlanLote(
    EstadoLote.completada,
    cambios: cambios,
    mensaje: resumenCampos(cambios.keys),
    fallos: r.fallos,
  );
}

// ── Repaso con FilmAffinity ──────────────────────────────────────────────

/// Qué películas se proponen en el repaso con FilmAffinity.
enum TipoRepaso {
  cortadas(
    'Sinopsis cortadas',
    'Se quedaron en 255 letras al editarlas en el Explorador de Windows.',
  ),
  sinTemas('Sin temas', 'Temas y premios solo están en FilmAffinity.');

  const TipoRepaso(this.nombre, this.descripcion);

  final String nombre;
  final String descripcion;

  static TipoRepaso? porNombre(String? nombre) {
    for (final t in values) {
      if (t.name == nombre) return t;
    }
    return null;
  }
}

/// La sinopsis parece cortada: tiene justo el máximo que deja el Explorador
/// (255 letras, o 254 si se quitó un espacio final) y no acaba en punto.
bool sinopsisCortadaProbable(String sinopsis) {
  final s = sinopsis.trim();
  if (s.length < 250 || s.length > 255) return false;
  return !RegExp(r'[.!?…»")]$').hasMatch(s);
}

/// La película (por su [sinopsis] y sus [temas]) entra en el repaso de tipo
/// [tipo]. (Los premios no cuentan: muchas películas no tienen.)
bool entraEnRepaso(
  TipoRepaso tipo, {
  required String sinopsis,
  required String temas,
}) => switch (tipo) {
  TipoRepaso.cortadas => sinopsisCortadaProbable(sinopsis),
  TipoRepaso.sinTemas => temas.trim().isEmpty,
};
