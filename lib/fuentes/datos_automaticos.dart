import 'package:http/http.dart' as http;

import '../disco/escritor.dart' show Campo;
import 'conexion.dart';
import 'conversiones.dart';
import 'identificacion.dart';
import 'omdb.dart';
import 'tmdb.dart';
import 'wikidata.dart';

// Reúne lo que dicen TMDB, OMDb y Wikidata de una película y lo deja como
// campos de la ficha, cada uno con su origen.
//
// No usa nada de Flutter.

/// Un dato encontrado para un campo de la ficha.
class DatoEncontrado {
  const DatoEncontrado(this.valor, this.origen, {this.detalle = ''});

  /// Tal como se escribiría en el archivo (estrellas «1»–«5», números como
  /// cifras).
  final String valor;

  /// «TMDB», «OMDb» o «Wikidata».
  final String origen;

  /// Explicación extra, p. ej. «87 % en Rotten Tomatoes» o «TMDB: 12».
  final String detalle;
}

class ResultadoDatos {
  const ResultadoDatos(this.identificacion, this.datos, this.avisos);

  final Identificacion identificacion;

  /// Vacío si la película no se ha identificado sin dudas.
  final Map<Campo, DatoEncontrado> datos;

  /// Lo que no se ha podido consultar (p. ej. «OMDb: límite de hoy»).
  final List<String> avisos;
}

/// Los tres servicios juntos.
class FuentesDatos {
  FuentesDatos({
    required String claveTmdb,
    required String claveOmdb,
    http.Client? cliente,
  }) : tmdb = Tmdb(claveTmdb, cliente: cliente),
       omdb = claveOmdb.trim().isEmpty
           ? null
           : Omdb(claveOmdb, cliente: cliente),
       wikidata = Wikidata(cliente: cliente);

  final Tmdb tmdb;

  /// `null` si no hay clave de OMDb (entonces no se buscan estrellas).
  final Omdb? omdb;
  final Wikidata wikidata;

  /// Identifica la película [p] y, si no hay dudas, reúne sus datos.
  Future<ResultadoDatos> buscar(DatosIdentificacion p) async {
    final identificacion = await identificar(tmdb, p);
    final ficha = identificacion.ficha;
    if (ficha == null) {
      return ResultadoDatos(identificacion, const {}, const []);
    }
    return completar(identificacion, ficha);
  }

  /// Reúne los datos de [ficha] (la identificada, o la que has elegido tú
  /// entre las dudosas).
  Future<ResultadoDatos> completar(
    Identificacion identificacion,
    FichaTmdb ficha,
  ) async {
    final datos = <Campo, DatoEncontrado>{};
    final avisos = <String>[];
    void poner(Campo c, String valor, String origen, [String detalle = '']) {
      if (valor.trim().isNotEmpty) {
        datos[c] = DatoEncontrado(valor.trim(), origen, detalle: detalle);
      }
    }

    const t = 'TMDB';
    // El título original solo si está en letras latinas (FilmAffinity
    // escribe «Kaze tachinu», no «風立ちぬ»).
    if (esLatino(ficha.tituloOriginal)) {
      poner(Campo.tituloOriginal, ficha.tituloOriginal, t);
    }
    poner(Campo.direccion, ficha.directores.join(', '), t);
    poner(Campo.guion, ficha.guion.join(', '), t);
    poner(Campo.fotografia, ficha.fotografia.join(', '), t);
    poner(Campo.pais, ficha.paises.join(', '), t);
    if (ficha.saga.isNotEmpty) {
      poner(Campo.saga, ficha.saga, t);
      if (ficha.numeroSaga > 0) {
        poner(Campo.numeroSaga, '${ficha.numeroSaga}', t);
      }
    }
    final frase = fraseEdad(espana: ficha.edadEspana, eeuu: ficha.edadEeuu);
    if (frase != null) {
      poner(
        Campo.clasificacion,
        frase,
        t,
        [
          if (ficha.edadEspana.isNotEmpty) 'España: ${ficha.edadEspana}',
          if (ficha.edadEeuu.isNotEmpty) 'EE. UU.: ${ficha.edadEeuu}',
        ].join(' · '),
      );
    }
    if (ficha.imdb.isNotEmpty) {
      poner(Campo.enlaceImdb, enlaceImdb(ficha.imdb), t);

      final omdb = this.omdb;
      if (omdb != null) {
        try {
          final nota = await omdb.rottenTomatoes(ficha.imdb);
          if (nota != null) {
            poner(
              Campo.estrellas,
              '${estrellasDeRotten(nota)}',
              'OMDb',
              '$nota % en Rotten Tomatoes',
            );
          }
        } on FuenteException catch (e) {
          avisos.add('$e');
        }
      }

      try {
        final fa = await wikidata.idFilmaffinity(ficha.imdb);
        if (fa != null) {
          poner(Campo.enlaceFilmaffinity, enlaceFilmaffinity(fa), 'Wikidata');
        }
      } on FuenteException catch (e) {
        avisos.add('$e');
      }
    }
    return ResultadoDatos(identificacion, datos, avisos);
  }
}
