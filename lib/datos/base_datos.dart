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
  int get schemaVersion => 1;

  // ── Películas ──────────────────────────────────────────────────────────

  Future<List<FilaPelicula>> todasLasPeliculas() => select(peliculas).get();

  Future<int> contarPeliculas() async {
    final total = peliculas.id.count();
    final fila = await (selectOnly(peliculas)..addColumns([total])).getSingle();
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
            ]))
            .get();
    return {
      for (final f in filas)
        f.read(peliculas.ruta)!: (
          id: f.read(peliculas.id)!,
          tamano: f.read(peliculas.tamanoBytes)!,
          modificado: f.read(peliculas.modificado)!,
          conError: f.read(peliculas.errorLectura) != null,
        ),
    };
  }

  /// Guarda una película nueva o actualiza la que ya tenía esa ruta.
  /// Devuelve su número (id), que no cambia al actualizarla.
  Future<int> guardarPelicula(PeliculasCompanion datos) async {
    final fila = await into(peliculas).insertReturning(
      datos,
      onConflict: DoUpdate((_) => datos, target: [peliculas.ruta]),
    );
    return fila.id;
  }

  /// Borra las películas con esas rutas y devuelve sus números.
  Future<List<int>> borrarRutas(Iterable<String> rutas) async {
    final ids = <int>[];
    for (final ruta in rutas) {
      final borradas = await (delete(
        peliculas,
      )..where((p) => p.ruta.equals(ruta))).goAndReturn();
      ids.addAll(borradas.map((f) => f.id));
    }
    return ids;
  }

  // ── Ajustes ────────────────────────────────────────────────────────────

  Future<Map<String, String>> todosLosAjustes() async => {
    for (final a in await select(ajustes).get()) a.clave: a.valor,
  };

  Future<void> guardarAjuste(String clave, String valor) => into(
    ajustes,
  ).insertOnConflictUpdate(AjustesCompanion.insert(clave: clave, valor: valor));
}
