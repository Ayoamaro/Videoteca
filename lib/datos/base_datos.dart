import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';

part 'base_datos.g.dart';

// La base de datos local de la app: un único archivo SQLite en el PC.
//
// Drift crea por nosotros el código para leer y escribir (el archivo
// `base_datos.g.dart`, que se genera con
// `dart run build_runner build`). Aquí solo se describen las tablas.
//
// Este archivo no usa nada de Flutter, para poder usarlo también desde las
// herramientas de la terminal (`tool/escanear.dart`).

/// Una fila por cada `.mp4` de la colección.
@DataClassName('FilaPelicula')
class Peliculas extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Ruta completa del archivo. No se repite.
  TextColumn get ruta => text().unique()();

  /// Carpeta de primer nivel ("Comedias") y la carpeta donde está el archivo
  /// ("Comedia"), que es el género según el disco.
  TextColumn get grupo => text().withDefault(const Constant(''))();
  TextColumn get generoCarpeta => text().withDefault(const Constant(''))();

  // Datos de "Propiedades → Detalles" (ver la tabla de CLAUDE.md).
  TextColumn get titulo => text()();
  TextColumn get tituloOriginal => text().withDefault(const Constant(''))();
  IntColumn get anio => integer().withDefault(const Constant(0))();

  /// Como en Windows: "Drama. Comedia. Romance".
  TextColumn get generos => text().withDefault(const Constant(''))();

  /// Temas separados por "; ".
  TextColumn get temas => text().withDefault(const Constant(''))();
  TextColumn get sinopsis => text().withDefault(const Constant(''))();
  TextColumn get direccion => text().withDefault(const Constant(''))();
  TextColumn get guion => text().withDefault(const Constant(''))();
  TextColumn get reparto => text().withDefault(const Constant(''))();
  TextColumn get musica => text().withDefault(const Constant(''))();
  TextColumn get fotografia => text().withDefault(const Constant(''))();
  TextColumn get productora => text().withDefault(const Constant(''))();
  TextColumn get pais => text().withDefault(const Constant(''))();
  TextColumn get premios => text().withDefault(const Constant(''))();
  TextColumn get clasificacion => text().withDefault(const Constant(''))();
  IntColumn get estrellas => integer().withDefault(const Constant(0))();
  TextColumn get saga => text().withDefault(const Constant(''))();
  IntColumn get numeroSaga => integer().withDefault(const Constant(0))();
  TextColumn get enlaceFilmaffinity => text().withDefault(const Constant(''))();
  TextColumn get enlaceImdb => text().withDefault(const Constant(''))();

  // Datos técnicos del archivo.
  IntColumn get duracionMin => integer().withDefault(const Constant(0))();
  TextColumn get resolucion => text().withDefault(const Constant(''))();
  IntColumn get tamanoBytes => integer().withDefault(const Constant(0))();

  /// Lleva carátula incrustada / la app tiene su miniatura guardada.
  BoolColumn get tieneCaratula =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get tieneMiniatura =>
      boolean().withDefault(const Constant(false))();

  /// Fecha de creación del archivo en el disco (= cuándo se añadió).
  DateTimeColumn get anadida => dateTime()();

  /// Última modificación del archivo: si cambia, hay que volver a leerlo.
  DateTimeColumn get modificado => dateTime()();
  DateTimeColumn get escaneada => dateTime()();

  /// Si Windows no pudo leer el archivo, el motivo (se reintenta al escanear).
  TextColumn get errorLectura => text().nullable()();

  /// Detectada en el disco después del primer escaneo: está en la bandeja de
  /// Películas nuevas hasta que se completa su ficha o se quita de allí.
  BoolColumn get nueva => boolean().withDefault(const Constant(false))();

  /// Cuándo se vio que el archivo ya no estaba en el disco (`null` = está).
  /// No se borra sola: sale en Pendientes hasta que se quite a mano o el
  /// archivo vuelva.
  DateTimeColumn get desaparecida => dateTime().nullable()();
}

/// Ajustes de la app (clave → valor), p. ej. la carpeta raíz.
@DataClassName('Ajuste')
class Ajustes extends Table {
  TextColumn get clave => text()();
  TextColumn get valor => text()();

  @override
  Set<Column> get primaryKey => {clave};
}

/// Lo que se sabe de un archivo ya escaneado, para saber si ha cambiado.
typedef ArchivoConocido = ({
  int id,
  int tamano,
  DateTime modificado,
  bool conError,
  bool desaparecida,
});

@DriftDatabase(tables: [Peliculas, Ajustes])
class BaseDatos extends _$BaseDatos {
  BaseDatos(super.conexion);

  /// Abre (o crea) la base de datos en [ruta]. SQLite trabaja en un hilo
  /// aparte para no frenar la pantalla.
  factory BaseDatos.abrir(String ruta) => BaseDatos(
    NativeDatabase.createInBackground(
      File(ruta),
      setup: (bd) => bd.execute('PRAGMA journal_mode = WAL'),
    ),
  );

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, desde, hasta) async {
      // Versión 2 (día 8): películas nuevas y desaparecidas.
      if (desde < 2) {
        await m.addColumn(peliculas, peliculas.nueva);
        await m.addColumn(peliculas, peliculas.desaparecida);
      }
    },
  );

  // ── Películas ──────────────────────────────────────────────────────────

  /// Las películas que están en el disco.
  Future<List<FilaPelicula>> todasLasPeliculas() =>
      (select(peliculas)..where((p) => p.desaparecida.isNull())).get();

  /// Las que ya no están en el disco (se ven en Pendientes).
  Future<List<FilaPelicula>> peliculasDesaparecidas() =>
      (select(peliculas)..where((p) => p.desaparecida.isNotNull())).get();

  Future<int> contarPeliculas() async {
    final total = peliculas.id.count();
    final fila =
        await (selectOnly(peliculas)
              ..addColumns([total])
              ..where(peliculas.desaparecida.isNull()))
            .getSingle();
    return fila.read(total) ?? 0;
  }

  /// Ruta → datos mínimos de todas las películas guardadas.
  Future<Map<String, ArchivoConocido>> archivosConocidos() async {
    final filas =
        await (selectOnly(peliculas)..addColumns([
              peliculas.id,
              peliculas.ruta,
              peliculas.tamanoBytes,
              peliculas.modificado,
              peliculas.errorLectura,
              peliculas.desaparecida,
            ]))
            .get();
    return {
      for (final f in filas)
        f.read(peliculas.ruta)!: (
          id: f.read(peliculas.id)!,
          tamano: f.read(peliculas.tamanoBytes)!,
          modificado: f.read(peliculas.modificado)!,
          conError: f.read(peliculas.errorLectura) != null,
          desaparecida: f.read(peliculas.desaparecida) != null,
        ),
    };
  }

  /// Guarda una película nueva o actualiza la que ya tenía esa ruta.
  /// Devuelve su número (id), que no cambia al actualizarla. Al actualizar no
  /// se toca la marca de «nueva».
  Future<int> guardarPelicula(PeliculasCompanion datos) async {
    final fila = await into(peliculas).insertReturning(
      datos,
      onConflict: DoUpdate(
        (_) => datos.copyWith(nueva: const Value.absent()),
        target: [peliculas.ruta],
      ),
    );
    return fila.id;
  }

  /// La película [id] se ha movido (o renombrado) a [ruta]: se cambia la
  /// ruta y la carpeta, y se conserva todo lo demás.
  Future<void> moverPelicula(
    int id, {
    required String ruta,
    required String grupo,
    required String generoCarpeta,
  }) => (update(peliculas)..where((p) => p.id.equals(id))).write(
    PeliculasCompanion(
      ruta: Value(ruta),
      grupo: Value(grupo),
      generoCarpeta: Value(generoCarpeta),
      desaparecida: const Value(null),
    ),
  );

  /// Marca como desaparecidas (con la fecha [cuando]) o, con `null`, como
  /// de nuevo en su sitio.
  Future<void> marcarDesaparecidas(Iterable<int> ids, DateTime? cuando) =>
      _cambiar(ids, PeliculasCompanion(desaparecida: Value(cuando)));

  /// Quita (o pone) la marca de «nueva».
  Future<void> marcarNuevas(Iterable<int> ids, {required bool nueva}) =>
      _cambiar(ids, PeliculasCompanion(nueva: Value(nueva)));

  Future<void> _cambiar(Iterable<int> ids, PeliculasCompanion cambio) async {
    if (ids.isEmpty) return;
    await (update(peliculas)..where((p) => p.id.isIn(ids))).write(cambio);
  }

  /// Borra las películas con esos números (solo del catálogo, nunca del
  /// disco).
  Future<void> borrarPeliculas(Iterable<int> ids) async {
    if (ids.isEmpty) return;
    await (delete(peliculas)..where((p) => p.id.isIn(ids))).go();
  }

  // ── Ajustes ────────────────────────────────────────────────────────────

  Future<Map<String, String>> todosLosAjustes() async => {
    for (final a in await select(ajustes).get()) a.clave: a.valor,
  };

  Future<void> guardarAjuste(String clave, String valor) => into(
    ajustes,
  ).insertOnConflictUpdate(AjustesCompanion.insert(clave: clave, valor: valor));
}
