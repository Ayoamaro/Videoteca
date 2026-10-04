// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'base_datos.dart';

// ignore_for_file: type=lint
class $PeliculasTable extends Peliculas
    with TableInfo<$PeliculasTable, FilaPelicula> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PeliculasTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _rutaMeta = const VerificationMeta('ruta');
  @override
  late final GeneratedColumn<String> ruta = GeneratedColumn<String>(
    'ruta',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _grupoMeta = const VerificationMeta('grupo');
  @override
  late final GeneratedColumn<String> grupo = GeneratedColumn<String>(
    'grupo',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _generoCarpetaMeta = const VerificationMeta(
    'generoCarpeta',
  );
  @override
  late final GeneratedColumn<String> generoCarpeta = GeneratedColumn<String>(
    'genero_carpeta',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _tituloMeta = const VerificationMeta('titulo');
  @override
  late final GeneratedColumn<String> titulo = GeneratedColumn<String>(
    'titulo',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tituloOriginalMeta = const VerificationMeta(
    'tituloOriginal',
  );
  @override
  late final GeneratedColumn<String> tituloOriginal = GeneratedColumn<String>(
    'titulo_original',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _anioMeta = const VerificationMeta('anio');
  @override
  late final GeneratedColumn<int> anio = GeneratedColumn<int>(
    'anio',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _generosMeta = const VerificationMeta(
    'generos',
  );
  @override
  late final GeneratedColumn<String> generos = GeneratedColumn<String>(
    'generos',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _temasMeta = const VerificationMeta('temas');
  @override
  late final GeneratedColumn<String> temas = GeneratedColumn<String>(
    'temas',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _sinopsisMeta = const VerificationMeta(
    'sinopsis',
  );
  @override
  late final GeneratedColumn<String> sinopsis = GeneratedColumn<String>(
    'sinopsis',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _direccionMeta = const VerificationMeta(
    'direccion',
  );
  @override
  late final GeneratedColumn<String> direccion = GeneratedColumn<String>(
    'direccion',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _guionMeta = const VerificationMeta('guion');
  @override
  late final GeneratedColumn<String> guion = GeneratedColumn<String>(
    'guion',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _repartoMeta = const VerificationMeta(
    'reparto',
  );
  @override
  late final GeneratedColumn<String> reparto = GeneratedColumn<String>(
    'reparto',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _musicaMeta = const VerificationMeta('musica');
  @override
  late final GeneratedColumn<String> musica = GeneratedColumn<String>(
    'musica',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _fotografiaMeta = const VerificationMeta(
    'fotografia',
  );
  @override
  late final GeneratedColumn<String> fotografia = GeneratedColumn<String>(
    'fotografia',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _productoraMeta = const VerificationMeta(
    'productora',
  );
  @override
  late final GeneratedColumn<String> productora = GeneratedColumn<String>(
    'productora',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _paisMeta = const VerificationMeta('pais');
  @override
  late final GeneratedColumn<String> pais = GeneratedColumn<String>(
    'pais',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _premiosMeta = const VerificationMeta(
    'premios',
  );
  @override
  late final GeneratedColumn<String> premios = GeneratedColumn<String>(
    'premios',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _clasificacionMeta = const VerificationMeta(
    'clasificacion',
  );
  @override
  late final GeneratedColumn<String> clasificacion = GeneratedColumn<String>(
    'clasificacion',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _estrellasMeta = const VerificationMeta(
    'estrellas',
  );
  @override
  late final GeneratedColumn<int> estrellas = GeneratedColumn<int>(
    'estrellas',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _sagaMeta = const VerificationMeta('saga');
  @override
  late final GeneratedColumn<String> saga = GeneratedColumn<String>(
    'saga',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _numeroSagaMeta = const VerificationMeta(
    'numeroSaga',
  );
  @override
  late final GeneratedColumn<int> numeroSaga = GeneratedColumn<int>(
    'numero_saga',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _enlaceFilmaffinityMeta =
      const VerificationMeta('enlaceFilmaffinity');
  @override
  late final GeneratedColumn<String> enlaceFilmaffinity =
      GeneratedColumn<String>(
        'enlace_filmaffinity',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant(''),
      );
  static const VerificationMeta _enlaceImdbMeta = const VerificationMeta(
    'enlaceImdb',
  );
  @override
  late final GeneratedColumn<String> enlaceImdb = GeneratedColumn<String>(
    'enlace_imdb',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _duracionMinMeta = const VerificationMeta(
    'duracionMin',
  );
  @override
  late final GeneratedColumn<int> duracionMin = GeneratedColumn<int>(
    'duracion_min',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _resolucionMeta = const VerificationMeta(
    'resolucion',
  );
  @override
  late final GeneratedColumn<String> resolucion = GeneratedColumn<String>(
    'resolucion',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _tamanoBytesMeta = const VerificationMeta(
    'tamanoBytes',
  );
  @override
  late final GeneratedColumn<int> tamanoBytes = GeneratedColumn<int>(
    'tamano_bytes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _tieneCaratulaMeta = const VerificationMeta(
    'tieneCaratula',
  );
  @override
  late final GeneratedColumn<bool> tieneCaratula = GeneratedColumn<bool>(
    'tiene_caratula',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("tiene_caratula" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _tieneMiniaturaMeta = const VerificationMeta(
    'tieneMiniatura',
  );
  @override
  late final GeneratedColumn<bool> tieneMiniatura = GeneratedColumn<bool>(
    'tiene_miniatura',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("tiene_miniatura" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _anadidaMeta = const VerificationMeta(
    'anadida',
  );
  @override
  late final GeneratedColumn<DateTime> anadida = GeneratedColumn<DateTime>(
    'anadida',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _modificadoMeta = const VerificationMeta(
    'modificado',
  );
  @override
  late final GeneratedColumn<DateTime> modificado = GeneratedColumn<DateTime>(
    'modificado',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _escaneadaMeta = const VerificationMeta(
    'escaneada',
  );
  @override
  late final GeneratedColumn<DateTime> escaneada = GeneratedColumn<DateTime>(
    'escaneada',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _errorLecturaMeta = const VerificationMeta(
    'errorLectura',
  );
  @override
  late final GeneratedColumn<String> errorLectura = GeneratedColumn<String>(
    'error_lectura',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nuevaMeta = const VerificationMeta('nueva');
  @override
  late final GeneratedColumn<bool> nueva = GeneratedColumn<bool>(
    'nueva',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("nueva" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _desaparecidaMeta = const VerificationMeta(
    'desaparecida',
  );
  @override
  late final GeneratedColumn<DateTime> desaparecida = GeneratedColumn<DateTime>(
    'desaparecida',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    ruta,
    grupo,
    generoCarpeta,
    titulo,
    tituloOriginal,
    anio,
    generos,
    temas,
    sinopsis,
    direccion,
    guion,
    reparto,
    musica,
    fotografia,
    productora,
    pais,
    premios,
    clasificacion,
    estrellas,
    saga,
    numeroSaga,
    enlaceFilmaffinity,
    enlaceImdb,
    duracionMin,
    resolucion,
    tamanoBytes,
    tieneCaratula,
    tieneMiniatura,
    anadida,
    modificado,
    escaneada,
    errorLectura,
    nueva,
    desaparecida,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'peliculas';
  @override
  VerificationContext validateIntegrity(
    Insertable<FilaPelicula> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('ruta')) {
      context.handle(
        _rutaMeta,
        ruta.isAcceptableOrUnknown(data['ruta']!, _rutaMeta),
      );
    } else if (isInserting) {
      context.missing(_rutaMeta);
    }
    if (data.containsKey('grupo')) {
      context.handle(
        _grupoMeta,
        grupo.isAcceptableOrUnknown(data['grupo']!, _grupoMeta),
      );
    }
    if (data.containsKey('genero_carpeta')) {
      context.handle(
        _generoCarpetaMeta,
        generoCarpeta.isAcceptableOrUnknown(
          data['genero_carpeta']!,
          _generoCarpetaMeta,
        ),
      );
    }
    if (data.containsKey('titulo')) {
      context.handle(
        _tituloMeta,
        titulo.isAcceptableOrUnknown(data['titulo']!, _tituloMeta),
      );
    } else if (isInserting) {
      context.missing(_tituloMeta);
    }
    if (data.containsKey('titulo_original')) {
      context.handle(
        _tituloOriginalMeta,
        tituloOriginal.isAcceptableOrUnknown(
          data['titulo_original']!,
          _tituloOriginalMeta,
        ),
      );
    }
    if (data.containsKey('anio')) {
      context.handle(
        _anioMeta,
        anio.isAcceptableOrUnknown(data['anio']!, _anioMeta),
      );
    }
    if (data.containsKey('generos')) {
      context.handle(
        _generosMeta,
        generos.isAcceptableOrUnknown(data['generos']!, _generosMeta),
      );
    }
    if (data.containsKey('temas')) {
      context.handle(
        _temasMeta,
        temas.isAcceptableOrUnknown(data['temas']!, _temasMeta),
      );
    }
    if (data.containsKey('sinopsis')) {
      context.handle(
        _sinopsisMeta,
        sinopsis.isAcceptableOrUnknown(data['sinopsis']!, _sinopsisMeta),
      );
    }
    if (data.containsKey('direccion')) {
      context.handle(
        _direccionMeta,
        direccion.isAcceptableOrUnknown(data['direccion']!, _direccionMeta),
      );
    }
    if (data.containsKey('guion')) {
      context.handle(
        _guionMeta,
        guion.isAcceptableOrUnknown(data['guion']!, _guionMeta),
      );
    }
    if (data.containsKey('reparto')) {
      context.handle(
        _repartoMeta,
        reparto.isAcceptableOrUnknown(data['reparto']!, _repartoMeta),
      );
    }
    if (data.containsKey('musica')) {
      context.handle(
        _musicaMeta,
        musica.isAcceptableOrUnknown(data['musica']!, _musicaMeta),
      );
    }
    if (data.containsKey('fotografia')) {
      context.handle(
        _fotografiaMeta,
        fotografia.isAcceptableOrUnknown(data['fotografia']!, _fotografiaMeta),
      );
    }
    if (data.containsKey('productora')) {
      context.handle(
        _productoraMeta,
        productora.isAcceptableOrUnknown(data['productora']!, _productoraMeta),
      );
    }
    if (data.containsKey('pais')) {
      context.handle(
        _paisMeta,
        pais.isAcceptableOrUnknown(data['pais']!, _paisMeta),
      );
    }
    if (data.containsKey('premios')) {
      context.handle(
        _premiosMeta,
        premios.isAcceptableOrUnknown(data['premios']!, _premiosMeta),
      );
    }
    if (data.containsKey('clasificacion')) {
      context.handle(
        _clasificacionMeta,
        clasificacion.isAcceptableOrUnknown(
          data['clasificacion']!,
          _clasificacionMeta,
        ),
      );
    }
    if (data.containsKey('estrellas')) {
      context.handle(
        _estrellasMeta,
        estrellas.isAcceptableOrUnknown(data['estrellas']!, _estrellasMeta),
      );
    }
    if (data.containsKey('saga')) {
      context.handle(
        _sagaMeta,
        saga.isAcceptableOrUnknown(data['saga']!, _sagaMeta),
      );
    }
    if (data.containsKey('numero_saga')) {
      context.handle(
        _numeroSagaMeta,
        numeroSaga.isAcceptableOrUnknown(data['numero_saga']!, _numeroSagaMeta),
      );
    }
    if (data.containsKey('enlace_filmaffinity')) {
      context.handle(
        _enlaceFilmaffinityMeta,
        enlaceFilmaffinity.isAcceptableOrUnknown(
          data['enlace_filmaffinity']!,
          _enlaceFilmaffinityMeta,
        ),
      );
    }
    if (data.containsKey('enlace_imdb')) {
      context.handle(
        _enlaceImdbMeta,
        enlaceImdb.isAcceptableOrUnknown(data['enlace_imdb']!, _enlaceImdbMeta),
      );
    }
    if (data.containsKey('duracion_min')) {
      context.handle(
        _duracionMinMeta,
        duracionMin.isAcceptableOrUnknown(
          data['duracion_min']!,
          _duracionMinMeta,
        ),
      );
    }
    if (data.containsKey('resolucion')) {
      context.handle(
        _resolucionMeta,
        resolucion.isAcceptableOrUnknown(data['resolucion']!, _resolucionMeta),
      );
    }
    if (data.containsKey('tamano_bytes')) {
      context.handle(
        _tamanoBytesMeta,
        tamanoBytes.isAcceptableOrUnknown(
          data['tamano_bytes']!,
          _tamanoBytesMeta,
        ),
      );
    }
    if (data.containsKey('tiene_caratula')) {
      context.handle(
        _tieneCaratulaMeta,
        tieneCaratula.isAcceptableOrUnknown(
          data['tiene_caratula']!,
          _tieneCaratulaMeta,
        ),
      );
    }
    if (data.containsKey('tiene_miniatura')) {
      context.handle(
        _tieneMiniaturaMeta,
        tieneMiniatura.isAcceptableOrUnknown(
          data['tiene_miniatura']!,
          _tieneMiniaturaMeta,
        ),
      );
    }
    if (data.containsKey('anadida')) {
      context.handle(
        _anadidaMeta,
        anadida.isAcceptableOrUnknown(data['anadida']!, _anadidaMeta),
      );
    } else if (isInserting) {
      context.missing(_anadidaMeta);
    }
    if (data.containsKey('modificado')) {
      context.handle(
        _modificadoMeta,
        modificado.isAcceptableOrUnknown(data['modificado']!, _modificadoMeta),
      );
    } else if (isInserting) {
      context.missing(_modificadoMeta);
    }
    if (data.containsKey('escaneada')) {
      context.handle(
        _escaneadaMeta,
        escaneada.isAcceptableOrUnknown(data['escaneada']!, _escaneadaMeta),
      );
    } else if (isInserting) {
      context.missing(_escaneadaMeta);
    }
    if (data.containsKey('error_lectura')) {
      context.handle(
        _errorLecturaMeta,
        errorLectura.isAcceptableOrUnknown(
          data['error_lectura']!,
          _errorLecturaMeta,
        ),
      );
    }
    if (data.containsKey('nueva')) {
      context.handle(
        _nuevaMeta,
        nueva.isAcceptableOrUnknown(data['nueva']!, _nuevaMeta),
      );
    }
    if (data.containsKey('desaparecida')) {
      context.handle(
        _desaparecidaMeta,
        desaparecida.isAcceptableOrUnknown(
          data['desaparecida']!,
          _desaparecidaMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  FilaPelicula map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FilaPelicula(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      ruta: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ruta'],
      )!,
      grupo: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}grupo'],
      )!,
      generoCarpeta: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}genero_carpeta'],
      )!,
      titulo: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}titulo'],
      )!,
      tituloOriginal: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}titulo_original'],
      )!,
      anio: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}anio'],
      )!,
      generos: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}generos'],
      )!,
      temas: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}temas'],
      )!,
      sinopsis: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sinopsis'],
      )!,
      direccion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}direccion'],
      )!,
      guion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}guion'],
      )!,
      reparto: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reparto'],
      )!,
      musica: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}musica'],
      )!,
      fotografia: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}fotografia'],
      )!,
      productora: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}productora'],
      )!,
      pais: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pais'],
      )!,
      premios: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}premios'],
      )!,
      clasificacion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}clasificacion'],
      )!,
      estrellas: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}estrellas'],
      )!,
      saga: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}saga'],
      )!,
      numeroSaga: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}numero_saga'],
      )!,
      enlaceFilmaffinity: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}enlace_filmaffinity'],
      )!,
      enlaceImdb: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}enlace_imdb'],
      )!,
      duracionMin: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duracion_min'],
      )!,
      resolucion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}resolucion'],
      )!,
      tamanoBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}tamano_bytes'],
      )!,
      tieneCaratula: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}tiene_caratula'],
      )!,
      tieneMiniatura: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}tiene_miniatura'],
      )!,
      anadida: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}anadida'],
      )!,
      modificado: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}modificado'],
      )!,
      escaneada: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}escaneada'],
      )!,
      errorLectura: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error_lectura'],
      ),
      nueva: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}nueva'],
      )!,
      desaparecida: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}desaparecida'],
      ),
    );
  }

  @override
  $PeliculasTable createAlias(String alias) {
    return $PeliculasTable(attachedDatabase, alias);
  }
}

class FilaPelicula extends DataClass implements Insertable<FilaPelicula> {
  final int id;

  /// Ruta completa del archivo. No se repite.
  final String ruta;

  /// Carpeta de primer nivel ("Comedias") y la carpeta donde está el archivo
  /// ("Comedia"), que es el género según el disco.
  final String grupo;
  final String generoCarpeta;
  final String titulo;
  final String tituloOriginal;
  final int anio;

  /// Como en Windows: "Drama. Comedia. Romance".
  final String generos;

  /// Temas separados por "; ".
  final String temas;
  final String sinopsis;
  final String direccion;
  final String guion;
  final String reparto;
  final String musica;
  final String fotografia;
  final String productora;
  final String pais;
  final String premios;
  final String clasificacion;
  final int estrellas;
  final String saga;
  final int numeroSaga;
  final String enlaceFilmaffinity;
  final String enlaceImdb;
  final int duracionMin;
  final String resolucion;
  final int tamanoBytes;

  /// Lleva carátula incrustada / la app tiene su miniatura guardada.
  final bool tieneCaratula;
  final bool tieneMiniatura;

  /// Fecha de creación del archivo en el disco (= cuándo se añadió).
  final DateTime anadida;

  /// Última modificación del archivo: si cambia, hay que volver a leerlo.
  final DateTime modificado;
  final DateTime escaneada;

  /// Si Windows no pudo leer el archivo, el motivo (se reintenta al escanear).
  final String? errorLectura;

  /// Detectada en el disco después del primer escaneo: está en la bandeja de
  /// Películas nuevas hasta que se completa su ficha o se quita de allí.
  final bool nueva;

  /// Cuándo se vio que el archivo ya no estaba en el disco (`null` = está).
  /// No se borra sola: sale en Pendientes hasta que se quite a mano o el
  /// archivo vuelva.
  final DateTime? desaparecida;
  const FilaPelicula({
    required this.id,
    required this.ruta,
    required this.grupo,
    required this.generoCarpeta,
    required this.titulo,
    required this.tituloOriginal,
    required this.anio,
    required this.generos,
    required this.temas,
    required this.sinopsis,
    required this.direccion,
    required this.guion,
    required this.reparto,
    required this.musica,
    required this.fotografia,
    required this.productora,
    required this.pais,
    required this.premios,
    required this.clasificacion,
    required this.estrellas,
    required this.saga,
    required this.numeroSaga,
    required this.enlaceFilmaffinity,
    required this.enlaceImdb,
    required this.duracionMin,
    required this.resolucion,
    required this.tamanoBytes,
    required this.tieneCaratula,
    required this.tieneMiniatura,
    required this.anadida,
    required this.modificado,
    required this.escaneada,
    this.errorLectura,
    required this.nueva,
    this.desaparecida,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['ruta'] = Variable<String>(ruta);
    map['grupo'] = Variable<String>(grupo);
    map['genero_carpeta'] = Variable<String>(generoCarpeta);
    map['titulo'] = Variable<String>(titulo);
    map['titulo_original'] = Variable<String>(tituloOriginal);
    map['anio'] = Variable<int>(anio);
    map['generos'] = Variable<String>(generos);
    map['temas'] = Variable<String>(temas);
    map['sinopsis'] = Variable<String>(sinopsis);
    map['direccion'] = Variable<String>(direccion);
    map['guion'] = Variable<String>(guion);
    map['reparto'] = Variable<String>(reparto);
    map['musica'] = Variable<String>(musica);
    map['fotografia'] = Variable<String>(fotografia);
    map['productora'] = Variable<String>(productora);
    map['pais'] = Variable<String>(pais);
    map['premios'] = Variable<String>(premios);
    map['clasificacion'] = Variable<String>(clasificacion);
    map['estrellas'] = Variable<int>(estrellas);
    map['saga'] = Variable<String>(saga);
    map['numero_saga'] = Variable<int>(numeroSaga);
    map['enlace_filmaffinity'] = Variable<String>(enlaceFilmaffinity);
    map['enlace_imdb'] = Variable<String>(enlaceImdb);
    map['duracion_min'] = Variable<int>(duracionMin);
    map['resolucion'] = Variable<String>(resolucion);
    map['tamano_bytes'] = Variable<int>(tamanoBytes);
    map['tiene_caratula'] = Variable<bool>(tieneCaratula);
    map['tiene_miniatura'] = Variable<bool>(tieneMiniatura);
    map['anadida'] = Variable<DateTime>(anadida);
    map['modificado'] = Variable<DateTime>(modificado);
    map['escaneada'] = Variable<DateTime>(escaneada);
    if (!nullToAbsent || errorLectura != null) {
      map['error_lectura'] = Variable<String>(errorLectura);
    }
    map['nueva'] = Variable<bool>(nueva);
    if (!nullToAbsent || desaparecida != null) {
      map['desaparecida'] = Variable<DateTime>(desaparecida);
    }
    return map;
  }

  PeliculasCompanion toCompanion(bool nullToAbsent) {
    return PeliculasCompanion(
      id: Value(id),
      ruta: Value(ruta),
      grupo: Value(grupo),
      generoCarpeta: Value(generoCarpeta),
      titulo: Value(titulo),
      tituloOriginal: Value(tituloOriginal),
      anio: Value(anio),
      generos: Value(generos),
      temas: Value(temas),
      sinopsis: Value(sinopsis),
      direccion: Value(direccion),
      guion: Value(guion),
      reparto: Value(reparto),
      musica: Value(musica),
      fotografia: Value(fotografia),
      productora: Value(productora),
      pais: Value(pais),
      premios: Value(premios),
      clasificacion: Value(clasificacion),
      estrellas: Value(estrellas),
      saga: Value(saga),
      numeroSaga: Value(numeroSaga),
      enlaceFilmaffinity: Value(enlaceFilmaffinity),
      enlaceImdb: Value(enlaceImdb),
      duracionMin: Value(duracionMin),
      resolucion: Value(resolucion),
      tamanoBytes: Value(tamanoBytes),
      tieneCaratula: Value(tieneCaratula),
      tieneMiniatura: Value(tieneMiniatura),
      anadida: Value(anadida),
      modificado: Value(modificado),
      escaneada: Value(escaneada),
      errorLectura: errorLectura == null && nullToAbsent
          ? const Value.absent()
          : Value(errorLectura),
      nueva: Value(nueva),
      desaparecida: desaparecida == null && nullToAbsent
          ? const Value.absent()
          : Value(desaparecida),
    );
  }

  factory FilaPelicula.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FilaPelicula(
      id: serializer.fromJson<int>(json['id']),
      ruta: serializer.fromJson<String>(json['ruta']),
      grupo: serializer.fromJson<String>(json['grupo']),
      generoCarpeta: serializer.fromJson<String>(json['generoCarpeta']),
      titulo: serializer.fromJson<String>(json['titulo']),
      tituloOriginal: serializer.fromJson<String>(json['tituloOriginal']),
      anio: serializer.fromJson<int>(json['anio']),
      generos: serializer.fromJson<String>(json['generos']),
      temas: serializer.fromJson<String>(json['temas']),
      sinopsis: serializer.fromJson<String>(json['sinopsis']),
      direccion: serializer.fromJson<String>(json['direccion']),
      guion: serializer.fromJson<String>(json['guion']),
      reparto: serializer.fromJson<String>(json['reparto']),
      musica: serializer.fromJson<String>(json['musica']),
      fotografia: serializer.fromJson<String>(json['fotografia']),
      productora: serializer.fromJson<String>(json['productora']),
      pais: serializer.fromJson<String>(json['pais']),
      premios: serializer.fromJson<String>(json['premios']),
      clasificacion: serializer.fromJson<String>(json['clasificacion']),
      estrellas: serializer.fromJson<int>(json['estrellas']),
      saga: serializer.fromJson<String>(json['saga']),
      numeroSaga: serializer.fromJson<int>(json['numeroSaga']),
      enlaceFilmaffinity: serializer.fromJson<String>(
        json['enlaceFilmaffinity'],
      ),
      enlaceImdb: serializer.fromJson<String>(json['enlaceImdb']),
      duracionMin: serializer.fromJson<int>(json['duracionMin']),
      resolucion: serializer.fromJson<String>(json['resolucion']),
      tamanoBytes: serializer.fromJson<int>(json['tamanoBytes']),
      tieneCaratula: serializer.fromJson<bool>(json['tieneCaratula']),
      tieneMiniatura: serializer.fromJson<bool>(json['tieneMiniatura']),
      anadida: serializer.fromJson<DateTime>(json['anadida']),
      modificado: serializer.fromJson<DateTime>(json['modificado']),
      escaneada: serializer.fromJson<DateTime>(json['escaneada']),
      errorLectura: serializer.fromJson<String?>(json['errorLectura']),
      nueva: serializer.fromJson<bool>(json['nueva']),
      desaparecida: serializer.fromJson<DateTime?>(json['desaparecida']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'ruta': serializer.toJson<String>(ruta),
      'grupo': serializer.toJson<String>(grupo),
      'generoCarpeta': serializer.toJson<String>(generoCarpeta),
      'titulo': serializer.toJson<String>(titulo),
      'tituloOriginal': serializer.toJson<String>(tituloOriginal),
      'anio': serializer.toJson<int>(anio),
      'generos': serializer.toJson<String>(generos),
      'temas': serializer.toJson<String>(temas),
      'sinopsis': serializer.toJson<String>(sinopsis),
      'direccion': serializer.toJson<String>(direccion),
      'guion': serializer.toJson<String>(guion),
      'reparto': serializer.toJson<String>(reparto),
      'musica': serializer.toJson<String>(musica),
      'fotografia': serializer.toJson<String>(fotografia),
      'productora': serializer.toJson<String>(productora),
      'pais': serializer.toJson<String>(pais),
      'premios': serializer.toJson<String>(premios),
      'clasificacion': serializer.toJson<String>(clasificacion),
      'estrellas': serializer.toJson<int>(estrellas),
      'saga': serializer.toJson<String>(saga),
      'numeroSaga': serializer.toJson<int>(numeroSaga),
      'enlaceFilmaffinity': serializer.toJson<String>(enlaceFilmaffinity),
      'enlaceImdb': serializer.toJson<String>(enlaceImdb),
      'duracionMin': serializer.toJson<int>(duracionMin),
      'resolucion': serializer.toJson<String>(resolucion),
      'tamanoBytes': serializer.toJson<int>(tamanoBytes),
      'tieneCaratula': serializer.toJson<bool>(tieneCaratula),
      'tieneMiniatura': serializer.toJson<bool>(tieneMiniatura),
      'anadida': serializer.toJson<DateTime>(anadida),
      'modificado': serializer.toJson<DateTime>(modificado),
      'escaneada': serializer.toJson<DateTime>(escaneada),
      'errorLectura': serializer.toJson<String?>(errorLectura),
      'nueva': serializer.toJson<bool>(nueva),
      'desaparecida': serializer.toJson<DateTime?>(desaparecida),
    };
  }

  FilaPelicula copyWith({
    int? id,
    String? ruta,
    String? grupo,
    String? generoCarpeta,
    String? titulo,
    String? tituloOriginal,
    int? anio,
    String? generos,
    String? temas,
    String? sinopsis,
    String? direccion,
    String? guion,
    String? reparto,
    String? musica,
    String? fotografia,
    String? productora,
    String? pais,
    String? premios,
    String? clasificacion,
    int? estrellas,
    String? saga,
    int? numeroSaga,
    String? enlaceFilmaffinity,
    String? enlaceImdb,
    int? duracionMin,
    String? resolucion,
    int? tamanoBytes,
    bool? tieneCaratula,
    bool? tieneMiniatura,
    DateTime? anadida,
    DateTime? modificado,
    DateTime? escaneada,
    Value<String?> errorLectura = const Value.absent(),
    bool? nueva,
    Value<DateTime?> desaparecida = const Value.absent(),
  }) => FilaPelicula(
    id: id ?? this.id,
    ruta: ruta ?? this.ruta,
    grupo: grupo ?? this.grupo,
    generoCarpeta: generoCarpeta ?? this.generoCarpeta,
    titulo: titulo ?? this.titulo,
    tituloOriginal: tituloOriginal ?? this.tituloOriginal,
    anio: anio ?? this.anio,
    generos: generos ?? this.generos,
    temas: temas ?? this.temas,
    sinopsis: sinopsis ?? this.sinopsis,
    direccion: direccion ?? this.direccion,
    guion: guion ?? this.guion,
    reparto: reparto ?? this.reparto,
    musica: musica ?? this.musica,
    fotografia: fotografia ?? this.fotografia,
    productora: productora ?? this.productora,
    pais: pais ?? this.pais,
    premios: premios ?? this.premios,
    clasificacion: clasificacion ?? this.clasificacion,
    estrellas: estrellas ?? this.estrellas,
    saga: saga ?? this.saga,
    numeroSaga: numeroSaga ?? this.numeroSaga,
    enlaceFilmaffinity: enlaceFilmaffinity ?? this.enlaceFilmaffinity,
    enlaceImdb: enlaceImdb ?? this.enlaceImdb,
    duracionMin: duracionMin ?? this.duracionMin,
    resolucion: resolucion ?? this.resolucion,
    tamanoBytes: tamanoBytes ?? this.tamanoBytes,
    tieneCaratula: tieneCaratula ?? this.tieneCaratula,
    tieneMiniatura: tieneMiniatura ?? this.tieneMiniatura,
    anadida: anadida ?? this.anadida,
    modificado: modificado ?? this.modificado,
    escaneada: escaneada ?? this.escaneada,
    errorLectura: errorLectura.present ? errorLectura.value : this.errorLectura,
    nueva: nueva ?? this.nueva,
    desaparecida: desaparecida.present ? desaparecida.value : this.desaparecida,
  );
  FilaPelicula copyWithCompanion(PeliculasCompanion data) {
    return FilaPelicula(
      id: data.id.present ? data.id.value : this.id,
      ruta: data.ruta.present ? data.ruta.value : this.ruta,
      grupo: data.grupo.present ? data.grupo.value : this.grupo,
      generoCarpeta: data.generoCarpeta.present
          ? data.generoCarpeta.value
          : this.generoCarpeta,
      titulo: data.titulo.present ? data.titulo.value : this.titulo,
      tituloOriginal: data.tituloOriginal.present
          ? data.tituloOriginal.value
          : this.tituloOriginal,
      anio: data.anio.present ? data.anio.value : this.anio,
      generos: data.generos.present ? data.generos.value : this.generos,
      temas: data.temas.present ? data.temas.value : this.temas,
      sinopsis: data.sinopsis.present ? data.sinopsis.value : this.sinopsis,
      direccion: data.direccion.present ? data.direccion.value : this.direccion,
      guion: data.guion.present ? data.guion.value : this.guion,
      reparto: data.reparto.present ? data.reparto.value : this.reparto,
      musica: data.musica.present ? data.musica.value : this.musica,
      fotografia: data.fotografia.present
          ? data.fotografia.value
          : this.fotografia,
      productora: data.productora.present
          ? data.productora.value
          : this.productora,
      pais: data.pais.present ? data.pais.value : this.pais,
      premios: data.premios.present ? data.premios.value : this.premios,
      clasificacion: data.clasificacion.present
          ? data.clasificacion.value
          : this.clasificacion,
      estrellas: data.estrellas.present ? data.estrellas.value : this.estrellas,
      saga: data.saga.present ? data.saga.value : this.saga,
      numeroSaga: data.numeroSaga.present
          ? data.numeroSaga.value
          : this.numeroSaga,
      enlaceFilmaffinity: data.enlaceFilmaffinity.present
          ? data.enlaceFilmaffinity.value
          : this.enlaceFilmaffinity,
      enlaceImdb: data.enlaceImdb.present
          ? data.enlaceImdb.value
          : this.enlaceImdb,
      duracionMin: data.duracionMin.present
          ? data.duracionMin.value
          : this.duracionMin,
      resolucion: data.resolucion.present
          ? data.resolucion.value
          : this.resolucion,
      tamanoBytes: data.tamanoBytes.present
          ? data.tamanoBytes.value
          : this.tamanoBytes,
      tieneCaratula: data.tieneCaratula.present
          ? data.tieneCaratula.value
          : this.tieneCaratula,
      tieneMiniatura: data.tieneMiniatura.present
          ? data.tieneMiniatura.value
          : this.tieneMiniatura,
      anadida: data.anadida.present ? data.anadida.value : this.anadida,
      modificado: data.modificado.present
          ? data.modificado.value
          : this.modificado,
      escaneada: data.escaneada.present ? data.escaneada.value : this.escaneada,
      errorLectura: data.errorLectura.present
          ? data.errorLectura.value
          : this.errorLectura,
      nueva: data.nueva.present ? data.nueva.value : this.nueva,
      desaparecida: data.desaparecida.present
          ? data.desaparecida.value
          : this.desaparecida,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FilaPelicula(')
          ..write('id: $id, ')
          ..write('ruta: $ruta, ')
          ..write('grupo: $grupo, ')
          ..write('generoCarpeta: $generoCarpeta, ')
          ..write('titulo: $titulo, ')
          ..write('tituloOriginal: $tituloOriginal, ')
          ..write('anio: $anio, ')
          ..write('generos: $generos, ')
          ..write('temas: $temas, ')
          ..write('sinopsis: $sinopsis, ')
          ..write('direccion: $direccion, ')
          ..write('guion: $guion, ')
          ..write('reparto: $reparto, ')
          ..write('musica: $musica, ')
          ..write('fotografia: $fotografia, ')
          ..write('productora: $productora, ')
          ..write('pais: $pais, ')
          ..write('premios: $premios, ')
          ..write('clasificacion: $clasificacion, ')
          ..write('estrellas: $estrellas, ')
          ..write('saga: $saga, ')
          ..write('numeroSaga: $numeroSaga, ')
          ..write('enlaceFilmaffinity: $enlaceFilmaffinity, ')
          ..write('enlaceImdb: $enlaceImdb, ')
          ..write('duracionMin: $duracionMin, ')
          ..write('resolucion: $resolucion, ')
          ..write('tamanoBytes: $tamanoBytes, ')
          ..write('tieneCaratula: $tieneCaratula, ')
          ..write('tieneMiniatura: $tieneMiniatura, ')
          ..write('anadida: $anadida, ')
          ..write('modificado: $modificado, ')
          ..write('escaneada: $escaneada, ')
          ..write('errorLectura: $errorLectura, ')
          ..write('nueva: $nueva, ')
          ..write('desaparecida: $desaparecida')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    ruta,
    grupo,
    generoCarpeta,
    titulo,
    tituloOriginal,
    anio,
    generos,
    temas,
    sinopsis,
    direccion,
    guion,
    reparto,
    musica,
    fotografia,
    productora,
    pais,
    premios,
    clasificacion,
    estrellas,
    saga,
    numeroSaga,
    enlaceFilmaffinity,
    enlaceImdb,
    duracionMin,
    resolucion,
    tamanoBytes,
    tieneCaratula,
    tieneMiniatura,
    anadida,
    modificado,
    escaneada,
    errorLectura,
    nueva,
    desaparecida,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FilaPelicula &&
          other.id == this.id &&
          other.ruta == this.ruta &&
          other.grupo == this.grupo &&
          other.generoCarpeta == this.generoCarpeta &&
          other.titulo == this.titulo &&
          other.tituloOriginal == this.tituloOriginal &&
          other.anio == this.anio &&
          other.generos == this.generos &&
          other.temas == this.temas &&
          other.sinopsis == this.sinopsis &&
          other.direccion == this.direccion &&
          other.guion == this.guion &&
          other.reparto == this.reparto &&
          other.musica == this.musica &&
          other.fotografia == this.fotografia &&
          other.productora == this.productora &&
          other.pais == this.pais &&
          other.premios == this.premios &&
          other.clasificacion == this.clasificacion &&
          other.estrellas == this.estrellas &&
          other.saga == this.saga &&
          other.numeroSaga == this.numeroSaga &&
          other.enlaceFilmaffinity == this.enlaceFilmaffinity &&
          other.enlaceImdb == this.enlaceImdb &&
          other.duracionMin == this.duracionMin &&
          other.resolucion == this.resolucion &&
          other.tamanoBytes == this.tamanoBytes &&
          other.tieneCaratula == this.tieneCaratula &&
          other.tieneMiniatura == this.tieneMiniatura &&
          other.anadida == this.anadida &&
          other.modificado == this.modificado &&
          other.escaneada == this.escaneada &&
          other.errorLectura == this.errorLectura &&
          other.nueva == this.nueva &&
          other.desaparecida == this.desaparecida);
}

class PeliculasCompanion extends UpdateCompanion<FilaPelicula> {
  final Value<int> id;
  final Value<String> ruta;
  final Value<String> grupo;
  final Value<String> generoCarpeta;
  final Value<String> titulo;
  final Value<String> tituloOriginal;
  final Value<int> anio;
  final Value<String> generos;
  final Value<String> temas;
  final Value<String> sinopsis;
  final Value<String> direccion;
  final Value<String> guion;
  final Value<String> reparto;
  final Value<String> musica;
  final Value<String> fotografia;
  final Value<String> productora;
  final Value<String> pais;
  final Value<String> premios;
  final Value<String> clasificacion;
  final Value<int> estrellas;
  final Value<String> saga;
  final Value<int> numeroSaga;
  final Value<String> enlaceFilmaffinity;
  final Value<String> enlaceImdb;
  final Value<int> duracionMin;
  final Value<String> resolucion;
  final Value<int> tamanoBytes;
  final Value<bool> tieneCaratula;
  final Value<bool> tieneMiniatura;
  final Value<DateTime> anadida;
  final Value<DateTime> modificado;
  final Value<DateTime> escaneada;
  final Value<String?> errorLectura;
  final Value<bool> nueva;
  final Value<DateTime?> desaparecida;
  const PeliculasCompanion({
    this.id = const Value.absent(),
    this.ruta = const Value.absent(),
    this.grupo = const Value.absent(),
    this.generoCarpeta = const Value.absent(),
    this.titulo = const Value.absent(),
    this.tituloOriginal = const Value.absent(),
    this.anio = const Value.absent(),
    this.generos = const Value.absent(),
    this.temas = const Value.absent(),
    this.sinopsis = const Value.absent(),
    this.direccion = const Value.absent(),
    this.guion = const Value.absent(),
    this.reparto = const Value.absent(),
    this.musica = const Value.absent(),
    this.fotografia = const Value.absent(),
    this.productora = const Value.absent(),
    this.pais = const Value.absent(),
    this.premios = const Value.absent(),
    this.clasificacion = const Value.absent(),
    this.estrellas = const Value.absent(),
    this.saga = const Value.absent(),
    this.numeroSaga = const Value.absent(),
    this.enlaceFilmaffinity = const Value.absent(),
    this.enlaceImdb = const Value.absent(),
    this.duracionMin = const Value.absent(),
    this.resolucion = const Value.absent(),
    this.tamanoBytes = const Value.absent(),
    this.tieneCaratula = const Value.absent(),
    this.tieneMiniatura = const Value.absent(),
    this.anadida = const Value.absent(),
    this.modificado = const Value.absent(),
    this.escaneada = const Value.absent(),
    this.errorLectura = const Value.absent(),
    this.nueva = const Value.absent(),
    this.desaparecida = const Value.absent(),
  });
  PeliculasCompanion.insert({
    this.id = const Value.absent(),
    required String ruta,
    this.grupo = const Value.absent(),
    this.generoCarpeta = const Value.absent(),
    required String titulo,
    this.tituloOriginal = const Value.absent(),
    this.anio = const Value.absent(),
    this.generos = const Value.absent(),
    this.temas = const Value.absent(),
    this.sinopsis = const Value.absent(),
    this.direccion = const Value.absent(),
    this.guion = const Value.absent(),
    this.reparto = const Value.absent(),
    this.musica = const Value.absent(),
    this.fotografia = const Value.absent(),
    this.productora = const Value.absent(),
    this.pais = const Value.absent(),
    this.premios = const Value.absent(),
    this.clasificacion = const Value.absent(),
    this.estrellas = const Value.absent(),
    this.saga = const Value.absent(),
    this.numeroSaga = const Value.absent(),
    this.enlaceFilmaffinity = const Value.absent(),
    this.enlaceImdb = const Value.absent(),
    this.duracionMin = const Value.absent(),
    this.resolucion = const Value.absent(),
    this.tamanoBytes = const Value.absent(),
    this.tieneCaratula = const Value.absent(),
    this.tieneMiniatura = const Value.absent(),
    required DateTime anadida,
    required DateTime modificado,
    required DateTime escaneada,
    this.errorLectura = const Value.absent(),
    this.nueva = const Value.absent(),
    this.desaparecida = const Value.absent(),
  }) : ruta = Value(ruta),
       titulo = Value(titulo),
       anadida = Value(anadida),
       modificado = Value(modificado),
       escaneada = Value(escaneada);
  static Insertable<FilaPelicula> custom({
    Expression<int>? id,
    Expression<String>? ruta,
    Expression<String>? grupo,
    Expression<String>? generoCarpeta,
    Expression<String>? titulo,
    Expression<String>? tituloOriginal,
    Expression<int>? anio,
    Expression<String>? generos,
    Expression<String>? temas,
    Expression<String>? sinopsis,
    Expression<String>? direccion,
    Expression<String>? guion,
    Expression<String>? reparto,
    Expression<String>? musica,
    Expression<String>? fotografia,
    Expression<String>? productora,
    Expression<String>? pais,
    Expression<String>? premios,
    Expression<String>? clasificacion,
    Expression<int>? estrellas,
    Expression<String>? saga,
    Expression<int>? numeroSaga,
    Expression<String>? enlaceFilmaffinity,
    Expression<String>? enlaceImdb,
    Expression<int>? duracionMin,
    Expression<String>? resolucion,
    Expression<int>? tamanoBytes,
    Expression<bool>? tieneCaratula,
    Expression<bool>? tieneMiniatura,
    Expression<DateTime>? anadida,
    Expression<DateTime>? modificado,
    Expression<DateTime>? escaneada,
    Expression<String>? errorLectura,
    Expression<bool>? nueva,
    Expression<DateTime>? desaparecida,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (ruta != null) 'ruta': ruta,
      if (grupo != null) 'grupo': grupo,
      if (generoCarpeta != null) 'genero_carpeta': generoCarpeta,
      if (titulo != null) 'titulo': titulo,
      if (tituloOriginal != null) 'titulo_original': tituloOriginal,
      if (anio != null) 'anio': anio,
      if (generos != null) 'generos': generos,
      if (temas != null) 'temas': temas,
      if (sinopsis != null) 'sinopsis': sinopsis,
      if (direccion != null) 'direccion': direccion,
      if (guion != null) 'guion': guion,
      if (reparto != null) 'reparto': reparto,
      if (musica != null) 'musica': musica,
      if (fotografia != null) 'fotografia': fotografia,
      if (productora != null) 'productora': productora,
      if (pais != null) 'pais': pais,
      if (premios != null) 'premios': premios,
      if (clasificacion != null) 'clasificacion': clasificacion,
      if (estrellas != null) 'estrellas': estrellas,
      if (saga != null) 'saga': saga,
      if (numeroSaga != null) 'numero_saga': numeroSaga,
      if (enlaceFilmaffinity != null) 'enlace_filmaffinity': enlaceFilmaffinity,
      if (enlaceImdb != null) 'enlace_imdb': enlaceImdb,
      if (duracionMin != null) 'duracion_min': duracionMin,
      if (resolucion != null) 'resolucion': resolucion,
      if (tamanoBytes != null) 'tamano_bytes': tamanoBytes,
      if (tieneCaratula != null) 'tiene_caratula': tieneCaratula,
      if (tieneMiniatura != null) 'tiene_miniatura': tieneMiniatura,
      if (anadida != null) 'anadida': anadida,
      if (modificado != null) 'modificado': modificado,
      if (escaneada != null) 'escaneada': escaneada,
      if (errorLectura != null) 'error_lectura': errorLectura,
      if (nueva != null) 'nueva': nueva,
      if (desaparecida != null) 'desaparecida': desaparecida,
    });
  }

  PeliculasCompanion copyWith({
    Value<int>? id,
    Value<String>? ruta,
    Value<String>? grupo,
    Value<String>? generoCarpeta,
    Value<String>? titulo,
    Value<String>? tituloOriginal,
    Value<int>? anio,
    Value<String>? generos,
    Value<String>? temas,
    Value<String>? sinopsis,
    Value<String>? direccion,
    Value<String>? guion,
    Value<String>? reparto,
    Value<String>? musica,
    Value<String>? fotografia,
    Value<String>? productora,
    Value<String>? pais,
    Value<String>? premios,
    Value<String>? clasificacion,
    Value<int>? estrellas,
    Value<String>? saga,
    Value<int>? numeroSaga,
    Value<String>? enlaceFilmaffinity,
    Value<String>? enlaceImdb,
    Value<int>? duracionMin,
    Value<String>? resolucion,
    Value<int>? tamanoBytes,
    Value<bool>? tieneCaratula,
    Value<bool>? tieneMiniatura,
    Value<DateTime>? anadida,
    Value<DateTime>? modificado,
    Value<DateTime>? escaneada,
    Value<String?>? errorLectura,
    Value<bool>? nueva,
    Value<DateTime?>? desaparecida,
  }) {
    return PeliculasCompanion(
      id: id ?? this.id,
      ruta: ruta ?? this.ruta,
      grupo: grupo ?? this.grupo,
      generoCarpeta: generoCarpeta ?? this.generoCarpeta,
      titulo: titulo ?? this.titulo,
      tituloOriginal: tituloOriginal ?? this.tituloOriginal,
      anio: anio ?? this.anio,
      generos: generos ?? this.generos,
      temas: temas ?? this.temas,
      sinopsis: sinopsis ?? this.sinopsis,
      direccion: direccion ?? this.direccion,
      guion: guion ?? this.guion,
      reparto: reparto ?? this.reparto,
      musica: musica ?? this.musica,
      fotografia: fotografia ?? this.fotografia,
      productora: productora ?? this.productora,
      pais: pais ?? this.pais,
      premios: premios ?? this.premios,
      clasificacion: clasificacion ?? this.clasificacion,
      estrellas: estrellas ?? this.estrellas,
      saga: saga ?? this.saga,
      numeroSaga: numeroSaga ?? this.numeroSaga,
      enlaceFilmaffinity: enlaceFilmaffinity ?? this.enlaceFilmaffinity,
      enlaceImdb: enlaceImdb ?? this.enlaceImdb,
      duracionMin: duracionMin ?? this.duracionMin,
      resolucion: resolucion ?? this.resolucion,
      tamanoBytes: tamanoBytes ?? this.tamanoBytes,
      tieneCaratula: tieneCaratula ?? this.tieneCaratula,
      tieneMiniatura: tieneMiniatura ?? this.tieneMiniatura,
      anadida: anadida ?? this.anadida,
      modificado: modificado ?? this.modificado,
      escaneada: escaneada ?? this.escaneada,
      errorLectura: errorLectura ?? this.errorLectura,
      nueva: nueva ?? this.nueva,
      desaparecida: desaparecida ?? this.desaparecida,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (ruta.present) {
      map['ruta'] = Variable<String>(ruta.value);
    }
    if (grupo.present) {
      map['grupo'] = Variable<String>(grupo.value);
    }
    if (generoCarpeta.present) {
      map['genero_carpeta'] = Variable<String>(generoCarpeta.value);
    }
    if (titulo.present) {
      map['titulo'] = Variable<String>(titulo.value);
    }
    if (tituloOriginal.present) {
      map['titulo_original'] = Variable<String>(tituloOriginal.value);
    }
    if (anio.present) {
      map['anio'] = Variable<int>(anio.value);
    }
    if (generos.present) {
      map['generos'] = Variable<String>(generos.value);
    }
    if (temas.present) {
      map['temas'] = Variable<String>(temas.value);
    }
    if (sinopsis.present) {
      map['sinopsis'] = Variable<String>(sinopsis.value);
    }
    if (direccion.present) {
      map['direccion'] = Variable<String>(direccion.value);
    }
    if (guion.present) {
      map['guion'] = Variable<String>(guion.value);
    }
    if (reparto.present) {
      map['reparto'] = Variable<String>(reparto.value);
    }
    if (musica.present) {
      map['musica'] = Variable<String>(musica.value);
    }
    if (fotografia.present) {
      map['fotografia'] = Variable<String>(fotografia.value);
    }
    if (productora.present) {
      map['productora'] = Variable<String>(productora.value);
    }
    if (pais.present) {
      map['pais'] = Variable<String>(pais.value);
    }
    if (premios.present) {
      map['premios'] = Variable<String>(premios.value);
    }
    if (clasificacion.present) {
      map['clasificacion'] = Variable<String>(clasificacion.value);
    }
    if (estrellas.present) {
      map['estrellas'] = Variable<int>(estrellas.value);
    }
    if (saga.present) {
      map['saga'] = Variable<String>(saga.value);
    }
    if (numeroSaga.present) {
      map['numero_saga'] = Variable<int>(numeroSaga.value);
    }
    if (enlaceFilmaffinity.present) {
      map['enlace_filmaffinity'] = Variable<String>(enlaceFilmaffinity.value);
    }
    if (enlaceImdb.present) {
      map['enlace_imdb'] = Variable<String>(enlaceImdb.value);
    }
    if (duracionMin.present) {
      map['duracion_min'] = Variable<int>(duracionMin.value);
    }
    if (resolucion.present) {
      map['resolucion'] = Variable<String>(resolucion.value);
    }
    if (tamanoBytes.present) {
      map['tamano_bytes'] = Variable<int>(tamanoBytes.value);
    }
    if (tieneCaratula.present) {
      map['tiene_caratula'] = Variable<bool>(tieneCaratula.value);
    }
    if (tieneMiniatura.present) {
      map['tiene_miniatura'] = Variable<bool>(tieneMiniatura.value);
    }
    if (anadida.present) {
      map['anadida'] = Variable<DateTime>(anadida.value);
    }
    if (modificado.present) {
      map['modificado'] = Variable<DateTime>(modificado.value);
    }
    if (escaneada.present) {
      map['escaneada'] = Variable<DateTime>(escaneada.value);
    }
    if (errorLectura.present) {
      map['error_lectura'] = Variable<String>(errorLectura.value);
    }
    if (nueva.present) {
      map['nueva'] = Variable<bool>(nueva.value);
    }
    if (desaparecida.present) {
      map['desaparecida'] = Variable<DateTime>(desaparecida.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PeliculasCompanion(')
          ..write('id: $id, ')
          ..write('ruta: $ruta, ')
          ..write('grupo: $grupo, ')
          ..write('generoCarpeta: $generoCarpeta, ')
          ..write('titulo: $titulo, ')
          ..write('tituloOriginal: $tituloOriginal, ')
          ..write('anio: $anio, ')
          ..write('generos: $generos, ')
          ..write('temas: $temas, ')
          ..write('sinopsis: $sinopsis, ')
          ..write('direccion: $direccion, ')
          ..write('guion: $guion, ')
          ..write('reparto: $reparto, ')
          ..write('musica: $musica, ')
          ..write('fotografia: $fotografia, ')
          ..write('productora: $productora, ')
          ..write('pais: $pais, ')
          ..write('premios: $premios, ')
          ..write('clasificacion: $clasificacion, ')
          ..write('estrellas: $estrellas, ')
          ..write('saga: $saga, ')
          ..write('numeroSaga: $numeroSaga, ')
          ..write('enlaceFilmaffinity: $enlaceFilmaffinity, ')
          ..write('enlaceImdb: $enlaceImdb, ')
          ..write('duracionMin: $duracionMin, ')
          ..write('resolucion: $resolucion, ')
          ..write('tamanoBytes: $tamanoBytes, ')
          ..write('tieneCaratula: $tieneCaratula, ')
          ..write('tieneMiniatura: $tieneMiniatura, ')
          ..write('anadida: $anadida, ')
          ..write('modificado: $modificado, ')
          ..write('escaneada: $escaneada, ')
          ..write('errorLectura: $errorLectura, ')
          ..write('nueva: $nueva, ')
          ..write('desaparecida: $desaparecida')
          ..write(')'))
        .toString();
  }
}

class $AjustesTable extends Ajustes with TableInfo<$AjustesTable, Ajuste> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AjustesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _claveMeta = const VerificationMeta('clave');
  @override
  late final GeneratedColumn<String> clave = GeneratedColumn<String>(
    'clave',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valorMeta = const VerificationMeta('valor');
  @override
  late final GeneratedColumn<String> valor = GeneratedColumn<String>(
    'valor',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [clave, valor];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ajustes';
  @override
  VerificationContext validateIntegrity(
    Insertable<Ajuste> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('clave')) {
      context.handle(
        _claveMeta,
        clave.isAcceptableOrUnknown(data['clave']!, _claveMeta),
      );
    } else if (isInserting) {
      context.missing(_claveMeta);
    }
    if (data.containsKey('valor')) {
      context.handle(
        _valorMeta,
        valor.isAcceptableOrUnknown(data['valor']!, _valorMeta),
      );
    } else if (isInserting) {
      context.missing(_valorMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {clave};
  @override
  Ajuste map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Ajuste(
      clave: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}clave'],
      )!,
      valor: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}valor'],
      )!,
    );
  }

  @override
  $AjustesTable createAlias(String alias) {
    return $AjustesTable(attachedDatabase, alias);
  }
}

class Ajuste extends DataClass implements Insertable<Ajuste> {
  final String clave;
  final String valor;
  const Ajuste({required this.clave, required this.valor});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['clave'] = Variable<String>(clave);
    map['valor'] = Variable<String>(valor);
    return map;
  }

  AjustesCompanion toCompanion(bool nullToAbsent) {
    return AjustesCompanion(clave: Value(clave), valor: Value(valor));
  }

  factory Ajuste.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Ajuste(
      clave: serializer.fromJson<String>(json['clave']),
      valor: serializer.fromJson<String>(json['valor']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'clave': serializer.toJson<String>(clave),
      'valor': serializer.toJson<String>(valor),
    };
  }

  Ajuste copyWith({String? clave, String? valor}) =>
      Ajuste(clave: clave ?? this.clave, valor: valor ?? this.valor);
  Ajuste copyWithCompanion(AjustesCompanion data) {
    return Ajuste(
      clave: data.clave.present ? data.clave.value : this.clave,
      valor: data.valor.present ? data.valor.value : this.valor,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Ajuste(')
          ..write('clave: $clave, ')
          ..write('valor: $valor')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(clave, valor);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Ajuste &&
          other.clave == this.clave &&
          other.valor == this.valor);
}

class AjustesCompanion extends UpdateCompanion<Ajuste> {
  final Value<String> clave;
  final Value<String> valor;
  final Value<int> rowid;
  const AjustesCompanion({
    this.clave = const Value.absent(),
    this.valor = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AjustesCompanion.insert({
    required String clave,
    required String valor,
    this.rowid = const Value.absent(),
  }) : clave = Value(clave),
       valor = Value(valor);
  static Insertable<Ajuste> custom({
    Expression<String>? clave,
    Expression<String>? valor,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (clave != null) 'clave': clave,
      if (valor != null) 'valor': valor,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AjustesCompanion copyWith({
    Value<String>? clave,
    Value<String>? valor,
    Value<int>? rowid,
  }) {
    return AjustesCompanion(
      clave: clave ?? this.clave,
      valor: valor ?? this.valor,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (clave.present) {
      map['clave'] = Variable<String>(clave.value);
    }
    if (valor.present) {
      map['valor'] = Variable<String>(valor.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AjustesCompanion(')
          ..write('clave: $clave, ')
          ..write('valor: $valor, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$BaseDatos extends GeneratedDatabase {
  _$BaseDatos(QueryExecutor e) : super(e);
  $BaseDatosManager get managers => $BaseDatosManager(this);
  late final $PeliculasTable peliculas = $PeliculasTable(this);
  late final $AjustesTable ajustes = $AjustesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [peliculas, ajustes];
}

typedef $$PeliculasTableCreateCompanionBuilder = PeliculasCompanion Function({
  Value<int> id,
  required String ruta,
  Value<String> grupo,
  Value<String> generoCarpeta,
  required String titulo,
  Value<String> tituloOriginal,
  Value<int> anio,
  Value<String> generos,
  Value<String> temas,
  Value<String> sinopsis,
  Value<String> direccion,
  Value<String> guion,
  Value<String> reparto,
  Value<String> musica,
  Value<String> fotografia,
  Value<String> productora,
  Value<String> pais,
  Value<String> premios,
  Value<String> clasificacion,
  Value<int> estrellas,
  Value<String> saga,
  Value<int> numeroSaga,
  Value<String> enlaceFilmaffinity,
  Value<String> enlaceImdb,
  Value<int> duracionMin,
  Value<String> resolucion,
  Value<int> tamanoBytes,
  Value<bool> tieneCaratula,
  Value<bool> tieneMiniatura,
  required DateTime anadida,
  required DateTime modificado,
  required DateTime escaneada,
  Value<String?> errorLectura,
  Value<bool> nueva,
  Value<DateTime?> desaparecida,
});
typedef $$PeliculasTableUpdateCompanionBuilder = PeliculasCompanion Function({
  Value<int> id,
  Value<String> ruta,
  Value<String> grupo,
  Value<String> generoCarpeta,
  Value<String> titulo,
  Value<String> tituloOriginal,
  Value<int> anio,
  Value<String> generos,
  Value<String> temas,
  Value<String> sinopsis,
  Value<String> direccion,
  Value<String> guion,
  Value<String> reparto,
  Value<String> musica,
  Value<String> fotografia,
  Value<String> productora,
  Value<String> pais,
  Value<String> premios,
  Value<String> clasificacion,
  Value<int> estrellas,
  Value<String> saga,
  Value<int> numeroSaga,
  Value<String> enlaceFilmaffinity,
  Value<String> enlaceImdb,
  Value<int> duracionMin,
  Value<String> resolucion,
  Value<int> tamanoBytes,
  Value<bool> tieneCaratula,
  Value<bool> tieneMiniatura,
  Value<DateTime> anadida,
  Value<DateTime> modificado,
  Value<DateTime> escaneada,
  Value<String?> errorLectura,
  Value<bool> nueva,
  Value<DateTime?> desaparecida,
});

class $$PeliculasTableFilterComposer
    extends Composer<_$BaseDatos, $PeliculasTable> {
  $$PeliculasTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ruta => $composableBuilder(
    column: $table.ruta,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get grupo => $composableBuilder(
    column: $table.grupo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get generoCarpeta => $composableBuilder(
    column: $table.generoCarpeta,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get titulo => $composableBuilder(
    column: $table.titulo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tituloOriginal => $composableBuilder(
    column: $table.tituloOriginal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get anio => $composableBuilder(
    column: $table.anio,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get generos => $composableBuilder(
    column: $table.generos,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get temas => $composableBuilder(
    column: $table.temas,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sinopsis => $composableBuilder(
    column: $table.sinopsis,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get direccion => $composableBuilder(
    column: $table.direccion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get guion => $composableBuilder(
    column: $table.guion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reparto => $composableBuilder(
    column: $table.reparto,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get musica => $composableBuilder(
    column: $table.musica,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fotografia => $composableBuilder(
    column: $table.fotografia,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get productora => $composableBuilder(
    column: $table.productora,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pais => $composableBuilder(
    column: $table.pais,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get premios => $composableBuilder(
    column: $table.premios,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get clasificacion => $composableBuilder(
    column: $table.clasificacion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get estrellas => $composableBuilder(
    column: $table.estrellas,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get saga => $composableBuilder(
    column: $table.saga,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get numeroSaga => $composableBuilder(
    column: $table.numeroSaga,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get enlaceFilmaffinity => $composableBuilder(
    column: $table.enlaceFilmaffinity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get enlaceImdb => $composableBuilder(
    column: $table.enlaceImdb,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get duracionMin => $composableBuilder(
    column: $table.duracionMin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get resolucion => $composableBuilder(
    column: $table.resolucion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get tamanoBytes => $composableBuilder(
    column: $table.tamanoBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get tieneCaratula => $composableBuilder(
    column: $table.tieneCaratula,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get tieneMiniatura => $composableBuilder(
    column: $table.tieneMiniatura,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get anadida => $composableBuilder(
    column: $table.anadida,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get modificado => $composableBuilder(
    column: $table.modificado,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get escaneada => $composableBuilder(
    column: $table.escaneada,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get errorLectura => $composableBuilder(
    column: $table.errorLectura,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get nueva => $composableBuilder(
    column: $table.nueva,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get desaparecida => $composableBuilder(
    column: $table.desaparecida,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PeliculasTableOrderingComposer
    extends Composer<_$BaseDatos, $PeliculasTable> {
  $$PeliculasTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ruta => $composableBuilder(
    column: $table.ruta,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get grupo => $composableBuilder(
    column: $table.grupo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get generoCarpeta => $composableBuilder(
    column: $table.generoCarpeta,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get titulo => $composableBuilder(
    column: $table.titulo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tituloOriginal => $composableBuilder(
    column: $table.tituloOriginal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get anio => $composableBuilder(
    column: $table.anio,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get generos => $composableBuilder(
    column: $table.generos,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get temas => $composableBuilder(
    column: $table.temas,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sinopsis => $composableBuilder(
    column: $table.sinopsis,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get direccion => $composableBuilder(
    column: $table.direccion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get guion => $composableBuilder(
    column: $table.guion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reparto => $composableBuilder(
    column: $table.reparto,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get musica => $composableBuilder(
    column: $table.musica,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fotografia => $composableBuilder(
    column: $table.fotografia,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get productora => $composableBuilder(
    column: $table.productora,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pais => $composableBuilder(
    column: $table.pais,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get premios => $composableBuilder(
    column: $table.premios,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get clasificacion => $composableBuilder(
    column: $table.clasificacion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get estrellas => $composableBuilder(
    column: $table.estrellas,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get saga => $composableBuilder(
    column: $table.saga,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get numeroSaga => $composableBuilder(
    column: $table.numeroSaga,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get enlaceFilmaffinity => $composableBuilder(
    column: $table.enlaceFilmaffinity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get enlaceImdb => $composableBuilder(
    column: $table.enlaceImdb,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get duracionMin => $composableBuilder(
    column: $table.duracionMin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get resolucion => $composableBuilder(
    column: $table.resolucion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get tamanoBytes => $composableBuilder(
    column: $table.tamanoBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get tieneCaratula => $composableBuilder(
    column: $table.tieneCaratula,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get tieneMiniatura => $composableBuilder(
    column: $table.tieneMiniatura,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get anadida => $composableBuilder(
    column: $table.anadida,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get modificado => $composableBuilder(
    column: $table.modificado,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get escaneada => $composableBuilder(
    column: $table.escaneada,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get errorLectura => $composableBuilder(
    column: $table.errorLectura,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get nueva => $composableBuilder(
    column: $table.nueva,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get desaparecida => $composableBuilder(
    column: $table.desaparecida,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PeliculasTableAnnotationComposer
    extends Composer<_$BaseDatos, $PeliculasTable> {
  $$PeliculasTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get ruta =>
      $composableBuilder(column: $table.ruta, builder: (column) => column);

  GeneratedColumn<String> get grupo =>
      $composableBuilder(column: $table.grupo, builder: (column) => column);

  GeneratedColumn<String> get generoCarpeta => $composableBuilder(
    column: $table.generoCarpeta,
    builder: (column) => column,
  );

  GeneratedColumn<String> get titulo =>
      $composableBuilder(column: $table.titulo, builder: (column) => column);

  GeneratedColumn<String> get tituloOriginal => $composableBuilder(
    column: $table.tituloOriginal,
    builder: (column) => column,
  );

  GeneratedColumn<int> get anio =>
      $composableBuilder(column: $table.anio, builder: (column) => column);

  GeneratedColumn<String> get generos =>
      $composableBuilder(column: $table.generos, builder: (column) => column);

  GeneratedColumn<String> get temas =>
      $composableBuilder(column: $table.temas, builder: (column) => column);

  GeneratedColumn<String> get sinopsis =>
      $composableBuilder(column: $table.sinopsis, builder: (column) => column);

  GeneratedColumn<String> get direccion =>
      $composableBuilder(column: $table.direccion, builder: (column) => column);

  GeneratedColumn<String> get guion =>
      $composableBuilder(column: $table.guion, builder: (column) => column);

  GeneratedColumn<String> get reparto =>
      $composableBuilder(column: $table.reparto, builder: (column) => column);

  GeneratedColumn<String> get musica =>
      $composableBuilder(column: $table.musica, builder: (column) => column);

  GeneratedColumn<String> get fotografia => $composableBuilder(
    column: $table.fotografia,
    builder: (column) => column,
  );

  GeneratedColumn<String> get productora => $composableBuilder(
    column: $table.productora,
    builder: (column) => column,
  );

  GeneratedColumn<String> get pais =>
      $composableBuilder(column: $table.pais, builder: (column) => column);

  GeneratedColumn<String> get premios =>
      $composableBuilder(column: $table.premios, builder: (column) => column);

  GeneratedColumn<String> get clasificacion => $composableBuilder(
    column: $table.clasificacion,
    builder: (column) => column,
  );

  GeneratedColumn<int> get estrellas =>
      $composableBuilder(column: $table.estrellas, builder: (column) => column);

  GeneratedColumn<String> get saga =>
      $composableBuilder(column: $table.saga, builder: (column) => column);

  GeneratedColumn<int> get numeroSaga => $composableBuilder(
    column: $table.numeroSaga,
    builder: (column) => column,
  );

  GeneratedColumn<String> get enlaceFilmaffinity => $composableBuilder(
    column: $table.enlaceFilmaffinity,
    builder: (column) => column,
  );

  GeneratedColumn<String> get enlaceImdb => $composableBuilder(
    column: $table.enlaceImdb,
    builder: (column) => column,
  );

  GeneratedColumn<int> get duracionMin => $composableBuilder(
    column: $table.duracionMin,
    builder: (column) => column,
  );

  GeneratedColumn<String> get resolucion => $composableBuilder(
    column: $table.resolucion,
    builder: (column) => column,
  );

  GeneratedColumn<int> get tamanoBytes => $composableBuilder(
    column: $table.tamanoBytes,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get tieneCaratula => $composableBuilder(
    column: $table.tieneCaratula,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get tieneMiniatura => $composableBuilder(
    column: $table.tieneMiniatura,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get anadida =>
      $composableBuilder(column: $table.anadida, builder: (column) => column);

  GeneratedColumn<DateTime> get modificado => $composableBuilder(
    column: $table.modificado,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get escaneada =>
      $composableBuilder(column: $table.escaneada, builder: (column) => column);

  GeneratedColumn<String> get errorLectura => $composableBuilder(
    column: $table.errorLectura,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get nueva =>
      $composableBuilder(column: $table.nueva, builder: (column) => column);

  GeneratedColumn<DateTime> get desaparecida => $composableBuilder(
    column: $table.desaparecida,
    builder: (column) => column,
  );
}

class $$PeliculasTableTableManager
    extends
        RootTableManager<
          _$BaseDatos,
          $PeliculasTable,
          FilaPelicula,
          $$PeliculasTableFilterComposer,
          $$PeliculasTableOrderingComposer,
          $$PeliculasTableAnnotationComposer,
          $$PeliculasTableCreateCompanionBuilder,
          $$PeliculasTableUpdateCompanionBuilder,
          (
            FilaPelicula,
            BaseReferences<_$BaseDatos, $PeliculasTable, FilaPelicula>,
          ),
          FilaPelicula,
          PrefetchHooks Function()
        > {
  $$PeliculasTableTableManager(_$BaseDatos db, $PeliculasTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PeliculasTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PeliculasTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PeliculasTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> ruta = const Value.absent(),
                Value<String> grupo = const Value.absent(),
                Value<String> generoCarpeta = const Value.absent(),
                Value<String> titulo = const Value.absent(),
                Value<String> tituloOriginal = const Value.absent(),
                Value<int> anio = const Value.absent(),
                Value<String> generos = const Value.absent(),
                Value<String> temas = const Value.absent(),
                Value<String> sinopsis = const Value.absent(),
                Value<String> direccion = const Value.absent(),
                Value<String> guion = const Value.absent(),
                Value<String> reparto = const Value.absent(),
                Value<String> musica = const Value.absent(),
                Value<String> fotografia = const Value.absent(),
                Value<String> productora = const Value.absent(),
                Value<String> pais = const Value.absent(),
                Value<String> premios = const Value.absent(),
                Value<String> clasificacion = const Value.absent(),
                Value<int> estrellas = const Value.absent(),
                Value<String> saga = const Value.absent(),
                Value<int> numeroSaga = const Value.absent(),
                Value<String> enlaceFilmaffinity = const Value.absent(),
                Value<String> enlaceImdb = const Value.absent(),
                Value<int> duracionMin = const Value.absent(),
                Value<String> resolucion = const Value.absent(),
                Value<int> tamanoBytes = const Value.absent(),
                Value<bool> tieneCaratula = const Value.absent(),
                Value<bool> tieneMiniatura = const Value.absent(),
                Value<DateTime> anadida = const Value.absent(),
                Value<DateTime> modificado = const Value.absent(),
                Value<DateTime> escaneada = const Value.absent(),
                Value<String?> errorLectura = const Value.absent(),
                Value<bool> nueva = const Value.absent(),
                Value<DateTime?> desaparecida = const Value.absent(),
              }) => PeliculasCompanion(
                id: id,
                ruta: ruta,
                grupo: grupo,
                generoCarpeta: generoCarpeta,
                titulo: titulo,
                tituloOriginal: tituloOriginal,
                anio: anio,
                generos: generos,
                temas: temas,
                sinopsis: sinopsis,
                direccion: direccion,
                guion: guion,
                reparto: reparto,
                musica: musica,
                fotografia: fotografia,
                productora: productora,
                pais: pais,
                premios: premios,
                clasificacion: clasificacion,
                estrellas: estrellas,
                saga: saga,
                numeroSaga: numeroSaga,
                enlaceFilmaffinity: enlaceFilmaffinity,
                enlaceImdb: enlaceImdb,
                duracionMin: duracionMin,
                resolucion: resolucion,
                tamanoBytes: tamanoBytes,
                tieneCaratula: tieneCaratula,
                tieneMiniatura: tieneMiniatura,
                anadida: anadida,
                modificado: modificado,
                escaneada: escaneada,
                errorLectura: errorLectura,
                nueva: nueva,
                desaparecida: desaparecida,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String ruta,
                Value<String> grupo = const Value.absent(),
                Value<String> generoCarpeta = const Value.absent(),
                required String titulo,
                Value<String> tituloOriginal = const Value.absent(),
                Value<int> anio = const Value.absent(),
                Value<String> generos = const Value.absent(),
                Value<String> temas = const Value.absent(),
                Value<String> sinopsis = const Value.absent(),
                Value<String> direccion = const Value.absent(),
                Value<String> guion = const Value.absent(),
                Value<String> reparto = const Value.absent(),
                Value<String> musica = const Value.absent(),
                Value<String> fotografia = const Value.absent(),
                Value<String> productora = const Value.absent(),
                Value<String> pais = const Value.absent(),
                Value<String> premios = const Value.absent(),
                Value<String> clasificacion = const Value.absent(),
                Value<int> estrellas = const Value.absent(),
                Value<String> saga = const Value.absent(),
                Value<int> numeroSaga = const Value.absent(),
                Value<String> enlaceFilmaffinity = const Value.absent(),
                Value<String> enlaceImdb = const Value.absent(),
                Value<int> duracionMin = const Value.absent(),
                Value<String> resolucion = const Value.absent(),
                Value<int> tamanoBytes = const Value.absent(),
                Value<bool> tieneCaratula = const Value.absent(),
                Value<bool> tieneMiniatura = const Value.absent(),
                required DateTime anadida,
                required DateTime modificado,
                required DateTime escaneada,
                Value<String?> errorLectura = const Value.absent(),
                Value<bool> nueva = const Value.absent(),
                Value<DateTime?> desaparecida = const Value.absent(),
              }) => PeliculasCompanion.insert(
                id: id,
                ruta: ruta,
                grupo: grupo,
                generoCarpeta: generoCarpeta,
                titulo: titulo,
                tituloOriginal: tituloOriginal,
                anio: anio,
                generos: generos,
                temas: temas,
                sinopsis: sinopsis,
                direccion: direccion,
                guion: guion,
                reparto: reparto,
                musica: musica,
                fotografia: fotografia,
                productora: productora,
                pais: pais,
                premios: premios,
                clasificacion: clasificacion,
                estrellas: estrellas,
                saga: saga,
                numeroSaga: numeroSaga,
                enlaceFilmaffinity: enlaceFilmaffinity,
                enlaceImdb: enlaceImdb,
                duracionMin: duracionMin,
                resolucion: resolucion,
                tamanoBytes: tamanoBytes,
                tieneCaratula: tieneCaratula,
                tieneMiniatura: tieneMiniatura,
                anadida: anadida,
                modificado: modificado,
                escaneada: escaneada,
                errorLectura: errorLectura,
                nueva: nueva,
                desaparecida: desaparecida,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PeliculasTable, FilaPelicula>(table),
                  BaseReferences<_$BaseDatos, $PeliculasTable, FilaPelicula>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PeliculasTableProcessedTableManager =
    ProcessedTableManager<
      _$BaseDatos,
      $PeliculasTable,
      FilaPelicula,
      $$PeliculasTableFilterComposer,
      $$PeliculasTableOrderingComposer,
      $$PeliculasTableAnnotationComposer,
      $$PeliculasTableCreateCompanionBuilder,
      $$PeliculasTableUpdateCompanionBuilder,
      (
        FilaPelicula,
        BaseReferences<_$BaseDatos, $PeliculasTable, FilaPelicula>,
      ),
      FilaPelicula,
      PrefetchHooks Function()
    >;
typedef $$AjustesTableCreateCompanionBuilder = AjustesCompanion Function({
  required String clave,
  required String valor,
  Value<int> rowid,
});
typedef $$AjustesTableUpdateCompanionBuilder = AjustesCompanion Function({
  Value<String> clave,
  Value<String> valor,
  Value<int> rowid,
});

class $$AjustesTableFilterComposer
    extends Composer<_$BaseDatos, $AjustesTable> {
  $$AjustesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get clave => $composableBuilder(
    column: $table.clave,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get valor => $composableBuilder(
    column: $table.valor,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AjustesTableOrderingComposer
    extends Composer<_$BaseDatos, $AjustesTable> {
  $$AjustesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get clave => $composableBuilder(
    column: $table.clave,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get valor => $composableBuilder(
    column: $table.valor,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AjustesTableAnnotationComposer
    extends Composer<_$BaseDatos, $AjustesTable> {
  $$AjustesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get clave =>
      $composableBuilder(column: $table.clave, builder: (column) => column);

  GeneratedColumn<String> get valor =>
      $composableBuilder(column: $table.valor, builder: (column) => column);
}

class $$AjustesTableTableManager
    extends
        RootTableManager<
          _$BaseDatos,
          $AjustesTable,
          Ajuste,
          $$AjustesTableFilterComposer,
          $$AjustesTableOrderingComposer,
          $$AjustesTableAnnotationComposer,
          $$AjustesTableCreateCompanionBuilder,
          $$AjustesTableUpdateCompanionBuilder,
          (Ajuste, BaseReferences<_$BaseDatos, $AjustesTable, Ajuste>),
          Ajuste,
          PrefetchHooks Function()
        > {
  $$AjustesTableTableManager(_$BaseDatos db, $AjustesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AjustesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AjustesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AjustesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> clave = const Value.absent(),
            Value<String> valor = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => AjustesCompanion(clave: clave, valor: valor, rowid: rowid),
          createCompanionCallback:
              ({
                required String clave,
                required String valor,
                Value<int> rowid = const Value.absent(),
              }) => AjustesCompanion.insert(
                clave: clave,
                valor: valor,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AjustesTable, Ajuste>(table),
                  BaseReferences<_$BaseDatos, $AjustesTable, Ajuste>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AjustesTableProcessedTableManager =
    ProcessedTableManager<
      _$BaseDatos,
      $AjustesTable,
      Ajuste,
      $$AjustesTableFilterComposer,
      $$AjustesTableOrderingComposer,
      $$AjustesTableAnnotationComposer,
      $$AjustesTableCreateCompanionBuilder,
      $$AjustesTableUpdateCompanionBuilder,
      (Ajuste, BaseReferences<_$BaseDatos, $AjustesTable, Ajuste>),
      Ajuste,
      PrefetchHooks Function()
    >;

class $BaseDatosManager {
  final _$BaseDatos _db;
  $BaseDatosManager(this._db);
  $$PeliculasTableTableManager get peliculas =>
      $$PeliculasTableTableManager(_db, _db.peliculas);
  $$AjustesTableTableManager get ajustes =>
      $$AjustesTableTableManager(_db, _db.ajustes);
}
