import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image/image.dart' as img;

import '../errores.dart';
import '../datos/catalogo.dart';
import '../datos/edicion.dart';
import '../datos/fuentes.dart';
import '../datos/lote.dart';
import '../datos/nuevas.dart';
import '../disco/arrastre.dart';
import '../disco/dialogo_abrir.dart';
import '../disco/escritor.dart';
import '../disco/lector_archivo.dart';
import '../fuentes/datos_automaticos.dart';
import '../fuentes/identificacion.dart' show DatosIdentificacion;
import '../fuentes/lote.dart' show TipoRepaso;
import '../modelos/pelicula.dart';
import '../tema/colores.dart';
import '../utilidades.dart';
import '../widgets/caratula.dart';
import '../widgets/comunes.dart';
import '../widgets/completar.dart';
import '../widgets/dialogo_datos.dart';
import '../widgets/dialogo_filmaffinity.dart';
import 'registro.dart';

/// "Editar ficha": cambiar a mano los datos y la carátula de una película y
/// guardarlos dentro de su `.mp4`.
///
/// Los valores de partida se leen del propio archivo (no de la base de
/// datos), para editar exactamente lo que hay en él.
///
/// Con [completar] es la pantalla «Completar ficha» de las películas nuevas:
/// el título y el año salen del nombre del archivo, los datos encontrados
/// en internet (ver `datos/nuevas.dart`) se ponen solos en los campos
/// vacíos, y si hay dudas se elige la película en «¿Cuál es?».
///
/// Con [repaso] es el «Repaso con FilmAffinity» de Completar mi colección:
/// se abre FilmAffinity nada más entrar y, al guardar o saltar, se pasa a la
/// siguiente película de ese tipo.
///
/// Con [dudosa] es «Revisar dudosa», también de Completar mi colección: como
/// Completar ficha (búsqueda automática, «¿Cuál es?» y datos en los campos
/// vacíos) para las películas que el lote dejó sin tocar; al guardar o
/// saltar se pasa a la siguiente dudosa.
class PantallaEditarFicha extends ConsumerStatefulWidget {
  const PantallaEditarFicha({
    super.key,
    required this.id,
    this.completar = false,
    this.repaso,
    this.dudosa = false,
  });

  final int id;
  final bool completar;
  final TipoRepaso? repaso;
  final bool dudosa;

  @override
  ConsumerState<PantallaEditarFicha> createState() => _EstadoEditarFicha();
}

class _EstadoEditarFicha extends ConsumerState<PantallaEditarFicha> {
  /// Lo que hay ahora en el archivo (`null` mientras se lee).
  Map<Campo, String>? _original;
  Uint8List? _caratulaOriginal;
  String? _errorLectura;

  final _textos = {
    for (final c in Campo.values)
      if (c != Campo.estrellas) c: TextEditingController(),
  };
  var _estrellas = 0;

  /// Carátula nueva elegida (o quitada); `null` = sin cambios.
  CaratulaNueva? _caratula;

  /// Frases de edad más usadas en la colección, para elegirlas de un toque.
  var _frasesEdad = <String>[];

  /// Datos traídos de internet: de dónde salen («TMDB»…) y su valor. La
  /// etiqueta de origen se ve mientras el campo siga con ese valor.
  final _deInternet = <Campo, DatoEncontrado>{};

  String? _origen(Campo c) {
    final dato = _deInternet[c];
    return dato != null && dato.valor == _actual(c) ? dato.origen : null;
  }

  /// Completar ficha: el resultado de la búsqueda ya pasado a los campos
  /// (para no volver a pasarlo) y si se enseña el selector «¿Cuál es?».
  ResultadoDatos? _aplicado;
  var _verCandidatas = false;

  /// Completar ficha y Revisar dudosa: con búsqueda automática en TMDB.
  bool get _conBusqueda => widget.completar || widget.dudosa;

  @override
  void initState() {
    super.initState();
    for (final t in _textos.values) {
      t.addListener(() => setState(() {}));
    }
    ArrastreArchivos.instancia.escuchar(_alSoltar);
    if (widget.dudosa) {
      // Se busca esta y, mientras la revisas, la siguiente.
      final p = _pelicula;
      final siguiente = p == null
          ? null
          : siguienteDudosa(ref.read(colaDudosasProvider), p);
      ref.read(busquedasNuevasProvider.notifier).pedir([
        widget.id,
        ?siguiente?.id,
      ]);
    }
    _cargar();
  }

  @override
  void dispose() {
    ArrastreArchivos.instancia.dejar(_alSoltar);
    for (final t in _textos.values) {
      t.dispose();
    }
    super.dispose();
  }

  /// Se ha soltado un archivo en la ventana: si es una imagen, es la
  /// carátula nueva.
  void _alSoltar(List<String> rutas) {
    if (_original == null) return;
    final imagen = rutas.firstWhere(
      (r) => RegExp(r'\.(jpe?g|png)$', caseSensitive: false).hasMatch(r),
      orElse: () => '',
    );
    if (imagen.isEmpty) {
      _aviso('Eso no es una imagen: la carátula tiene que ser JPEG o PNG.');
      return;
    }
    _usarImagen(imagen);
  }

  Pelicula? get _pelicula => ref.read(peliculaPorIdProvider(widget.id));

  Future<void> _cargar() async {
    final p = _pelicula;
    if (p == null) return;
    final cuenta = <String, int>{};
    for (final o in ref.read(catalogoProvider).value ?? const <Pelicula>[]) {
      if (o.clasificacion.isNotEmpty) {
        cuenta[o.clasificacion] = (cuenta[o.clasificacion] ?? 0) + 1;
      }
    }
    _frasesEdad =
        (cuenta.entries.where((e) => e.value >= 5).toList()
              ..sort((a, b) => b.value.compareTo(a.value)))
            .take(7)
            .map((e) => e.key)
            .toList();
    try {
      final ruta = p.ruta;
      final datos = await leerEnSegundoPlano(ruta);
      if (!mounted) return;
      final valores = valoresFicha(datos);
      setState(() {
        _original = valores;
        _caratulaOriginal = datos.caratula;
        for (final MapEntry(key: c, value: t) in _textos.entries) {
          t.text = valores[c]!;
        }
        _estrellas = int.tryParse(valores[Campo.estrellas]!) ?? 0;
        if (_conBusqueda) {
          // Título y año del nombre del archivo, si el archivo no los tiene.
          for (final (campo, valor) in [
            (Campo.titulo, datos.titulo),
            (Campo.anio, datos.anio == 0 ? '' : '${datos.anio}'),
          ]) {
            if (_actual(campo).isEmpty && valor.isNotEmpty) {
              _textos[campo]!.text = valor;
              _deInternet[campo] = DatoEncontrado(valor, origenArchivo);
            }
          }
        }
      });
      if (_conBusqueda) {
        _aplicarBusqueda(ref.read(busquedasNuevasProvider)[widget.id]);
      }
      // Repaso: FilmAffinity se abre solo.
      if (widget.repaso != null && esAdministrador) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _leerFilmaffinity();
        });
      }
    } catch (e) {
      if (mounted) setState(() => _errorLectura = explicarError(e));
    }
  }

  String _actual(Campo c) => c == Campo.estrellas
      ? (_estrellas == 0 ? '' : '$_estrellas')
      : _textos[c]!.text.trim();

  /// Campos que se han cambiado (campo → texto nuevo).
  Map<Campo, String> get _cambios {
    final original = _original;
    if (original == null) return const {};
    return {
      for (final c in Campo.values)
        if (_actual(c) != original[c]) c: _actual(c),
    };
  }

  bool get _hayCambios => _cambios.isNotEmpty || _caratula != null;

  Map<Campo, String> get _errores => {
    if (_original != null)
      for (final c in Campo.values) c: ?validarCampo(c, _actual(c)),
  };

  void _restaurar(Campo c) {
    final valor = _original![c]!;
    if (c == Campo.estrellas) {
      setState(() => _estrellas = int.tryParse(valor) ?? 0);
    } else {
      _textos[c]!.text = valor;
    }
  }

  /// Pasa a los campos los datos de la búsqueda automática (Completar
  /// ficha): los vacíos y los que aún tienen el valor de una búsqueda
  /// anterior (si has elegido otra película). Los que has escrito tú no se
  /// tocan.
  void _aplicarBusqueda(BusquedaNueva? b) {
    final r = b?.resultado;
    if (_original == null ||
        r == null ||
        b!.estado != EstadoBusqueda.lista ||
        identical(r, _aplicado)) {
      return;
    }
    final anterior = _aplicado;
    var pasados = 0;
    setState(() {
      _aplicado = r;
      _verCandidatas = false;
      // Lo que puso la búsqueda anterior y no está en la nueva se quita.
      if (anterior != null) {
        for (final c in anterior.datos.keys) {
          if (!r.datos.containsKey(c) && _origen(c) != null) {
            _ponerValor(c, _original![c]!);
            _deInternet.remove(c);
          }
        }
      }
      for (final MapEntry(key: c, value: dato) in r.datos.entries) {
        final automatico =
            _origen(c) != null && _deInternet[c]!.origen != origenArchivo;
        if (_actual(c).isEmpty || automatico) {
          _ponerValor(c, dato.valor);
          _deInternet[c] = dato;
          pasados++;
        }
      }
    });
    if (pasados > 0) {
      _aviso(
        '$pasados ${pasados == 1 ? 'dato rellenado' : 'datos rellenados'} '
        'con lo encontrado en internet. Revísalos antes de guardar.',
      );
    }
  }

  void _ponerValor(Campo c, String valor) {
    if (c == Campo.estrellas) {
      _estrellas = int.tryParse(valor) ?? 0;
    } else {
      _textos[c]!.text = valor;
    }
  }

  Future<void> _elegirCaratula() async {
    final ruta = elegirImagen();
    if (ruta == null) return;
    await _usarImagen(ruta);
  }

  Future<void> _usarImagen(String ruta) async {
    final Uint8List bytes;
    try {
      bytes = await File(ruta).readAsBytes();
    } on FileSystemException {
      _aviso('No se ha podido abrir esa imagen.');
      return;
    }
    final esJpeg = bytes.length > 3 && bytes[0] == 0xFF && bytes[1] == 0xD8;
    final esPng = bytes.length > 8 && bytes[0] == 0x89 && bytes[1] == 0x50;
    if ((!esJpeg && !esPng) || img.decodeImage(bytes) == null) {
      _aviso('Esa imagen no se puede usar: tiene que ser JPEG o PNG.');
      return;
    }
    setState(() {
      _caratula = mismaImagen(bytes, _caratulaOriginal)
          ? null
          : CaratulaNueva(bytes);
    });
  }

  /// Busca los datos en internet y pasa al formulario los que se elijan.
  Future<void> _buscarDatos() async {
    final fuentes = ref.read(fuentesDatosProvider);
    if (fuentes == null) {
      final ir = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Falta la clave de TMDB'),
          content: const Text(
            'Para buscar datos en internet hace falta la clave gratuita de '
            'TMDB. Se pone en Ajustes → Servicios de datos.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Ahora no'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Ir a Ajustes'),
            ),
          ],
        ),
      );
      if ((ir ?? false) && mounted) context.go('/ajustes');
      return;
    }
    final elegidos = await mostrarDatosAutomaticos(
      context,
      fuentes: fuentes,
      datos: _datosIdentificacion,
      actuales: {for (final c in Campo.values) c: _actual(c)},
    );
    _pasarDatos(elegidos);
  }

  /// Lee los datos de la ficha de FilmAffinity (en una ventana de Edge) y
  /// pasa al formulario los que se elijan.
  Future<void> _leerFilmaffinity() async {
    final elegidos = await mostrarDatosFilmaffinity(
      context,
      perfil: ref.read(carpetasAppProvider).navegador,
      fuentes: ref.read(fuentesDatosProvider),
      datos: _datosIdentificacion,
      actuales: {for (final c in Campo.values) c: _actual(c)},
    );
    _pasarDatos(elegidos);
  }

  DatosIdentificacion get _datosIdentificacion => (
    titulo: _actual(Campo.titulo),
    tituloOriginal: _actual(Campo.tituloOriginal),
    anio: int.tryParse(_actual(Campo.anio)) ?? 0,
    direccion: _actual(Campo.direccion),
  );

  void _pasarDatos(Map<Campo, DatoEncontrado>? elegidos) {
    if (elegidos == null || !mounted) return;
    setState(() {
      for (final MapEntry(key: c, value: dato) in elegidos.entries) {
        if (c == Campo.estrellas) {
          _estrellas = int.tryParse(dato.valor) ?? _estrellas;
        } else {
          _textos[c]!.text = dato.valor;
        }
        _deInternet[c] = dato;
      }
    });
    _aviso(
      '${elegidos.length} ${elegidos.length == 1 ? 'dato pasado' : 'datos pasados'} '
      'a la ficha. Revísalos y pulsa «Guardar en el archivo».',
    );
  }

  /// Los avisos salen por encima de la barra de abajo, para que no tapen
  /// «Guardar en el archivo».
  static const _margenAviso = EdgeInsets.fromLTRB(24, 0, 24, 80);

  void _aviso(String texto) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(texto), margin: _margenAviso));

  Future<void> _guardar() async {
    final p = _pelicula;
    if (p == null) return;
    final cambios = _cambios;
    final caratula = _caratula;
    final completar = widget.completar;
    final repaso = widget.repaso;
    final dudosa = widget.dudosa;
    if (completar && !await _confirmarSinCaratula()) return;
    if (!mounted) return;
    final mensajero = ScaffoldMessenger.of(context);
    final navegador = Navigator.of(context, rootNavigator: true);
    final enrutador = GoRouter.of(context);
    final edicion = ref.read(edicionProvider);
    final catalogo = ref.read(catalogoProvider.notifier);
    mostrarGuardando(context, 'Guardando en el archivo…');
    try {
      final id = await edicion.guardar(
        p,
        cambios,
        caratula: caratula,
        origen: completar
            ? 'Completar ficha'
            : repaso != null
            ? 'Repaso con FilmAffinity'
            : dudosa
            ? 'Revisar dudosa'
            : 'Editar ficha',
      );
      if (completar) await catalogo.marcarCompletada(p.id);
      if (repaso != null) {
        await ref.read(repasadasProvider.notifier).marcar(p.id);
      }
      // Si era una dudosa (o no encontrada) del lote, ya está resuelta.
      await ref.read(coleccionProvider.notifier).marcarRevisada(p.id);
      navegador.pop();
      if (!mounted) return;
      // Ya no hay cambios pendientes: se puede salir sin preguntar.
      setState(() {
        _original = {..._original!, ...cambios};
        _caratula = null;
      });
      // Completar ficha: se pasa a la siguiente nueva sin guardar (o a la
      // bandeja si no quedan). Repaso y dudosas: a la siguiente por revisar.
      final siguiente = completar
          ? ref
                .read(nuevasSinGuardarProvider)
                .where((o) => o.id != p.id)
                .firstOrNull
          : repaso != null
          ? _siguienteRepaso(p.id)
          : dudosa
          ? siguienteDudosa(ref.read(colaDudosasProvider), p)
          : null;
      // Las que quedan por revisar (las saltadas, si no hay siguiente).
      final saltadas = dudosa ? ref.read(colaDudosasProvider).length : 0;
      if (repaso != null) {
        enrutador.go(
          siguiente == null
              ? '/coleccion'
              : '/repaso/${repaso.name}/${siguiente.id}',
        );
      } else if (dudosa) {
        enrutador.go(
          siguiente == null ? '/coleccion' : '/dudosas/${siguiente.id}',
        );
      } else if (!completar) {
        enrutador.pop();
      } else if (siguiente != null) {
        enrutador.go('/nuevas/${siguiente.id}');
      } else {
        enrutador.go('/nuevas');
      }
      final n = cambios.length + (caratula == null ? 0 : 1);
      final hecho = id == null
          ? (completar
                ? '«${p.titulo}» marcada como guardada (el archivo ya estaba '
                      'así).'
                : repaso != null
                ? '«${p.titulo}» repasada (sin cambios).'
                : dudosa
                ? '«${p.titulo}» marcada como revisada (sin cambios).'
                : 'No había nada distinto que guardar.')
          : 'Guardado en el archivo y comprobado '
                '($n ${n == 1 ? 'cambio' : 'cambios'}).';
      mensajero
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 8),
            // Con botón, Flutter lo dejaría fijo hasta cerrarlo a mano.
            persist: false,
            // Si se pasa a la siguiente película, también hay barra abajo.
            margin: completar || repaso != null || dudosa ? _margenAviso : null,
            content: Text(
              siguiente == null
                  ? (repaso != null
                        ? '$hecho No quedan más por repasar.'
                        : dudosa && saltadas == 0
                        ? '$hecho No quedan más dudosas.'
                        : dudosa
                        ? '$hecho Era la última de la lista (quedan '
                              '$saltadas que has saltado).'
                        : hecho)
                  : '$hecho Siguiente: «${siguiente.titulo}».',
            ),
            action: id == null
                ? null
                : SnackBarAction(
                    label: 'Deshacer',
                    onPressed: () => deshacerCambio(
                      navegador.context,
                      edicion,
                      id,
                      titulo: p.titulo,
                    ),
                  ),
          ),
        );
    } on Exception catch (e) {
      navegador.pop();
      if (mounted) {
        await mostrarError(
          context,
          'No se ha guardado',
          e is EscrituraException ? e.mensaje : explicarError(e),
        );
      }
    }
  }

  /// Completar ficha sin carátula: se pregunta antes (la carátula siempre
  /// la pones tú).
  Future<bool> _confirmarSinCaratula() async {
    final sinCaratula = _caratula != null
        ? _caratula!.imagen == null
        : _caratulaOriginal == null;
    if (!sinCaratula) return true;
    final si = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Guardar sin carátula?'),
        content: const Text(
          'La película todavía no tiene carátula. Puedes arrastrarla ahora '
          'a la pantalla, o guardar los datos y ponerla más adelante desde '
          'Editar ficha.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Poner la carátula'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Guardar sin carátula'),
          ),
        ],
      ),
    );
    return si ?? false;
  }

  Future<bool> _descartar() async {
    if (!_hayCambios) return true;
    final si = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Salir sin guardar?'),
        content: const Text('Los cambios que has hecho se perderán.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Seguir editando'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Salir sin guardar'),
          ),
        ],
      ),
    );
    return si ?? false;
  }

  /// Revisar dudosa: por qué el lote la dejó sin tocar y qué hacer.
  String _explicacionDudosa() {
    final motivo = ref.watch(
      coleccionProvider.select((e) => e.filas[widget.id]?.mensaje ?? ''),
    );
    final quedan = ref.watch(colaDudosasProvider).length;
    return '${motivo.isEmpty ? '' : '$motivo '}'
        'Comprueba cuál es (o elígela en «¿Cuál es?»), revisa los datos y '
        'guarda: se pasa a la siguiente. «Saltar» la deja como está. '
        '${quedan == 1 ? 'Queda 1' : 'Quedan ${formatoNumero(quedan)}'} '
        'por revisar.';
  }

  /// La siguiente película por repasar (sin contar [id]).
  Pelicula? _siguienteRepaso(int id) => ref
      .read(colaRepasoProvider(widget.repaso!))
      .where((o) => o.id != id)
      .firstOrNull;

  /// Repaso: deja esta película sin tocar (no se vuelve a proponer) y pasa
  /// a la siguiente. Dudosas: la deja como está (sigue en la lista) y pasa
  /// a la siguiente.
  Future<void> _saltar() async {
    if (!await _descartar() || !mounted) return;
    final enrutador = GoRouter.of(context);
    final String destino;
    if (widget.dudosa) {
      final p = _pelicula;
      final siguiente = p == null
          ? null
          : siguienteDudosa(ref.read(colaDudosasProvider), p);
      destino = siguiente == null ? '/coleccion' : '/dudosas/${siguiente.id}';
    } else {
      final repaso = widget.repaso!;
      final siguiente = _siguienteRepaso(widget.id);
      await ref.read(repasadasProvider.notifier).marcar(widget.id);
      destino = siguiente == null
          ? '/coleccion'
          : '/repaso/${repaso.name}/${siguiente.id}';
    }
    if (!mounted) return;
    // Ya no hay cambios pendientes: se puede salir sin preguntar.
    setState(() => _caratula = null);
    _original = {for (final c in Campo.values) c: _actual(c)};
    enrutador.go(destino);
  }

  Future<void> _salir() async {
    if (await _descartar() && mounted) {
      if (widget.repaso != null || widget.dudosa) {
        context.go('/coleccion');
      } else if (widget.completar) {
        context.go('/nuevas');
      } else {
        context.canPop() ? context.pop() : context.go('/pelicula/${widget.id}');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final p = ref.watch(peliculaPorIdProvider(widget.id));
    if (p == null) {
      return const PaginaBase(
        children: [Text('No se ha encontrado la película.')],
      );
    }
    final conectado = ref.watch(discoConectadoProvider).value ?? true;
    final existe = ref.watch(archivoExisteProvider(p.ruta)).value ?? true;
    final cargado = _original != null;
    final errores = _errores;
    final cambios = _cambios;
    final numCambios = cambios.length + (_caratula == null ? 0 : 1);
    final problema = !conectado
        ? '${nombreDisco(ref.watch(carpetaRaizProvider))} no está conectado: '
              'no se puede leer ni guardar el archivo.'
        : !existe
        ? 'No se encuentra el archivo en su ruta: puede que se haya movido o '
              'borrado.'
        : _errorLectura;
    final completar = widget.completar;
    final repaso = widget.repaso;
    final dudosa = widget.dudosa;
    // En Completar ficha (y en el repaso y las dudosas) se puede «guardar»
    // sin cambios: si el archivo ya estaba bien, solo se marca como hecha.
    final puedeGuardar =
        cargado &&
        problema == null &&
        errores.isEmpty &&
        (_hayCambios || completar || repaso != null || dudosa);
    final busqueda = _conBusqueda
        ? ref.watch(busquedasNuevasProvider)[widget.id]
        : null;
    if (_conBusqueda) {
      ref.listen(
        busquedasNuevasProvider.select((b) => b[widget.id]),
        (_, b) => _aplicarBusqueda(b),
      );
    }

    return PopScope(
      canPop: !_hayCambios,
      onPopInvokedWithResult: (salio, _) {
        if (!salio) _salir();
      },
      child: Column(
        children: [
          Expanded(
            child: PaginaBase(
              separacion: 22,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _salir,
                    icon: const Icon(Icons.chevron_left_rounded),
                    label: Text(
                      repaso != null || dudosa
                          ? 'Completar mi colección'
                          : completar
                          ? 'Películas nuevas'
                          : 'Volver a la ficha',
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: c.textoSecundario,
                      minimumSize: const Size(0, 44),
                    ),
                  ),
                ),
                if (repaso != null)
                  CabeceraPagina(
                    titulo: 'Repaso con FilmAffinity',
                    descripcion:
                        '${repaso.nombre}: quedan '
                        '${formatoNumero(ref.watch(colaRepasoProvider(repaso)).length)}. '
                        'FilmAffinity se abre solo con «${p.titulo}»: revisa '
                        'lo que trae, pulsa «Guardar en el archivo» y se pasa '
                        'a la siguiente. «Saltar» la deja sin tocar.',
                    acciones: [
                      OutlinedButton.icon(
                        onPressed: _saltar,
                        icon: const Icon(Icons.skip_next_rounded, size: 18),
                        label: const Text('Saltar'),
                      ),
                    ],
                  )
                else if (completar)
                  CabeceraCompletar(
                    pelicula: p,
                    titulo: _actual(Campo.titulo),
                    busqueda: busqueda,
                    hayClave: ref.watch(fuentesDatosProvider) != null,
                    alVerCandidatas: () =>
                        setState(() => _verCandidatas = !_verCandidatas),
                  )
                else if (dudosa)
                  CabeceraCompletar(
                    pelicula: p,
                    titulo: _actual(Campo.titulo),
                    busqueda: busqueda,
                    hayClave: ref.watch(fuentesDatosProvider) != null,
                    alVerCandidatas: () =>
                        setState(() => _verCandidatas = !_verCandidatas),
                    encabezado: 'Revisar dudosa',
                    explicacion: _explicacionDudosa(),
                    acciones: [
                      OutlinedButton.icon(
                        onPressed: _saltar,
                        icon: const Icon(Icons.skip_next_rounded, size: 18),
                        label: const Text('Saltar'),
                      ),
                    ],
                  )
                else
                  CabeceraPagina(
                    titulo: 'Editar ficha',
                    descripcion:
                        'Los cambios se guardan dentro de «${p.archivo}», en '
                        'el mismo formato que usa Windows en Propiedades → '
                        'Detalles. Después se comprueba que el vídeo y la '
                        'carátula quedan intactos, y todo queda en el '
                        'Registro de cambios para poder deshacerlo.',
                  ),
                if (_conBusqueda &&
                    busqueda?.identificacion != null &&
                    (busqueda!.estado == EstadoBusqueda.elegir ||
                        busqueda.estado == EstadoBusqueda.noEncontrada ||
                        _verCandidatas))
                  SelectorCandidatas(
                    titulo: _actual(Campo.titulo),
                    anio: int.tryParse(_actual(Campo.anio)) ?? 0,
                    busqueda: busqueda,
                    alElegir: (candidata) => ref
                        .read(busquedasNuevasProvider.notifier)
                        .elegir(widget.id, candidata),
                    alBuscar: (titulo, anio) {
                      setState(() => _verCandidatas = true);
                      ref.read(busquedasNuevasProvider.notifier).buscarDeNuevo(
                        widget.id,
                        (
                          titulo: titulo,
                          tituloOriginal: '',
                          anio: anio,
                          direccion: '',
                        ),
                      );
                    },
                    alCerrar: busqueda.estado == EstadoBusqueda.lista
                        ? () => setState(() => _verCandidatas = false)
                        : null,
                  ),
                if (cargado && esAdministrador)
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (completar) ...[
                        // Lo siguiente en Completar ficha: sinopsis, reparto,
                        // géneros… salen de FilmAffinity.
                        FilledButton.icon(
                          onPressed: _leerFilmaffinity,
                          icon: const Icon(
                            Icons.movie_filter_rounded,
                            size: 18,
                          ),
                          label: const Text('Leer de FilmAffinity'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _buscarDatos,
                          icon: const Icon(
                            Icons.travel_explore_rounded,
                            size: 18,
                          ),
                          label: const Text('Buscar datos en internet'),
                        ),
                        Text(
                          'Sinopsis, reparto, géneros, música y productora '
                          'salen de FilmAffinity.',
                          style: TextStyle(
                            fontSize: 13,
                            color: c.textoSecundario,
                          ),
                        ),
                      ] else ...[
                        FilledButton.tonalIcon(
                          onPressed: _buscarDatos,
                          icon: const Icon(
                            Icons.travel_explore_rounded,
                            size: 18,
                          ),
                          label: const Text('Buscar datos en internet'),
                        ),
                        FilledButton.tonalIcon(
                          onPressed: _leerFilmaffinity,
                          icon: const Icon(
                            Icons.movie_filter_rounded,
                            size: 18,
                          ),
                          label: const Text('Leer de FilmAffinity'),
                        ),
                      ],
                    ],
                  ),
                if (problema != null) _Aviso(problema),
                if (!cargado && problema == null)
                  const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                if (cargado)
                  LayoutBuilder(
                    builder: (context, medidas) {
                      final ancha = medidas.maxWidth >= 860;
                      final caratula = _ColumnaCaratula(
                        pelicula: p,
                        original: _caratulaOriginal,
                        nueva: _caratula,
                        alCambiar: problema == null ? _elegirCaratula : null,
                        alQuitar: problema == null && _caratulaOriginal != null
                            ? () => setState(
                                () => _caratula = const CaratulaNueva(null),
                              )
                            : null,
                        alRestaurar: () => setState(() => _caratula = null),
                      );
                      final campos = _formulario(errores);
                      if (!ancha) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Center(
                              child: SizedBox(width: 220, child: caratula),
                            ),
                            const SizedBox(height: 24),
                            campos,
                          ],
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(width: 250, child: caratula),
                          const SizedBox(width: 36),
                          Expanded(child: campos),
                        ],
                      );
                    },
                  ),
              ],
            ),
          ),
          // Barra fija abajo con los botones.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: c.superficie,
              border: Border(top: BorderSide(color: c.borde)),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      errores.isNotEmpty
                          ? 'Revisa los campos marcados en rojo.'
                          : numCambios == 0
                          ? (completar
                                ? 'Sin cambios: al guardar solo se marca como '
                                      'guardada'
                                : repaso != null
                                ? 'Sin cambios: al guardar se marca como '
                                      'repasada'
                                : dudosa
                                ? 'Sin cambios: al guardar se marca como '
                                      'revisada'
                                : 'Sin cambios')
                          : '$numCambios ${numCambios == 1 ? 'cambio' : 'cambios'} sin guardar',
                      style: TextStyle(
                        fontSize: 14,
                        color: errores.isNotEmpty
                            ? c.rojo
                            : numCambios == 0
                            ? c.textoSecundario
                            : c.doradoTexto,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _salir,
                    child: Text(
                      repaso != null
                          ? 'Terminar el repaso'
                          : dudosa
                          ? 'Terminar la revisión'
                          : completar
                          ? 'Descartar'
                          : 'Cancelar',
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    onPressed: puedeGuardar ? _guardar : null,
                    icon: const Icon(Icons.save_outlined, size: 18),
                    label: const Text('Guardar en el archivo'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _formulario(Map<Campo, String> errores) {
    Widget campo(Campo c, {int lineas = 1, String? ayuda, String? ejemplo}) =>
        _CampoTexto(
          campo: c,
          control: _textos[c]!,
          lineas: lineas,
          ayuda: ayuda,
          ejemplo: ejemplo,
          error: errores[c],
          cambiado: _actual(c) != _original![c],
          origen: _origen(c),
          alRestaurar: () => _restaurar(c),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Grupo('Títulos', [
          campo(Campo.titulo, ayuda: 'El nombre del archivo no cambia.'),
          campo(Campo.tituloOriginal),
          Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
              width: 160,
              child: campo(Campo.anio, ejemplo: '1995'),
            ),
          ),
        ]),
        _Grupo('Valoración y edad', [
          _CampoEstrellas(
            estrellas: _estrellas,
            cambiado: _actual(Campo.estrellas) != _original![Campo.estrellas],
            origen: _origen(Campo.estrellas),
            alCambiar: (n) => setState(() => _estrellas = n),
            alRestaurar: () => _restaurar(Campo.estrellas),
          ),
          campo(Campo.clasificacion),
          if (_frasesEdad.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final frase in _frasesEdad)
                  ActionChip(
                    label: Text(frase, style: const TextStyle(fontSize: 12)),
                    onPressed: () => _textos[Campo.clasificacion]!.text = frase,
                  ),
              ],
            ),
        ]),
        _Grupo('Géneros y temas', [
          campo(
            Campo.generos,
            ayuda: 'Separados por puntos.',
            ejemplo: 'Drama. Comedia. Romance',
          ),
          campo(
            Campo.temas,
            ayuda: 'Separados por punto y coma.',
            ejemplo: 'Navidad; Fantasmas',
          ),
        ]),
        _Grupo('Sinopsis', [campo(Campo.sinopsis, lineas: 6)]),
        _Grupo('Equipo', [
          campo(Campo.direccion),
          campo(Campo.reparto, lineas: 3, ayuda: 'Separado por comas.'),
          campo(Campo.guion),
          campo(Campo.musica),
          campo(Campo.fotografia),
          campo(Campo.productora),
          campo(Campo.pais),
        ]),
        _Grupo('Más datos', [
          campo(Campo.premios),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: campo(Campo.saga)),
              const SizedBox(width: 14),
              SizedBox(width: 150, child: campo(Campo.numeroSaga)),
            ],
          ),
          campo(Campo.enlaceFilmaffinity),
          campo(Campo.enlaceImdb),
        ]),
      ],
    );
  }
}

/// Un bloque del formulario con su título.
class _Grupo extends StatelessWidget {
  const _Grupo(this.titulo, this.children);

  final String titulo;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Tarjeta(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(titulo, style: Theme.of(context).textTheme.titleMedium),
            for (final hijo in children) ...[const SizedBox(height: 14), hijo],
          ],
        ),
      ),
    );
  }
}

/// Nombre de un campo, con la marca «Cambiado» y el botón para volver al
/// valor del archivo.
class _NombreCampo extends StatelessWidget {
  const _NombreCampo(
    this.nombre, {
    required this.cambiado,
    this.alRestaurar,
    this.origen,
  });

  final String nombre;
  final bool cambiado;
  final VoidCallback? alRestaurar;

  /// De dónde ha salido el valor nuevo, si se ha traído de internet.
  final String? origen;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    return SizedBox(
      height: 28,
      child: Row(
        children: [
          Text(
            nombre,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: c.textoSuave,
            ),
          ),
          if (cambiado) ...[
            const SizedBox(width: 8),
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: c.dorado,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              'Cambiado',
              style: TextStyle(fontSize: 12, color: c.doradoTexto),
            ),
            if (origen != null) ...[
              const SizedBox(width: 8),
              EtiquetaOrigen(origen!),
            ],
            const Spacer(),
            Tooltip(
              message: 'Volver al valor del archivo',
              child: IconButton(
                onPressed: alRestaurar,
                icon: const Icon(Icons.undo_rounded, size: 16),
                visualDensity: VisualDensity.compact,
                color: c.textoSecundario,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CampoTexto extends StatelessWidget {
  const _CampoTexto({
    required this.campo,
    required this.control,
    required this.cambiado,
    required this.alRestaurar,
    this.lineas = 1,
    this.ayuda,
    this.ejemplo,
    this.error,
    this.origen,
  });

  final String? origen;
  final Campo campo;
  final TextEditingController control;
  final bool cambiado;
  final VoidCallback alRestaurar;
  final int lineas;
  final String? ayuda;
  final String? ejemplo;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _NombreCampo(
          campo.nombre,
          cambiado: cambiado,
          alRestaurar: alRestaurar,
          origen: origen,
        ),
        const SizedBox(height: 4),
        TextField(
          controller: control,
          minLines: lineas,
          maxLines: lineas == 1 ? 1 : lineas + 6,
          keyboardType: campo.numero ? TextInputType.number : null,
          style: TextStyle(fontSize: 14, height: 1.45, color: c.texto),
          decoration: InputDecoration(
            hintText: ejemplo,
            helperText: ayuda,
            errorText: error,
            enabledBorder: cambiado
                ? OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: c.doradoBorde),
                  )
                : null,
          ),
        ),
      ],
    );
  }
}

class _CampoEstrellas extends StatelessWidget {
  const _CampoEstrellas({
    required this.estrellas,
    required this.cambiado,
    required this.alCambiar,
    required this.alRestaurar,
    this.origen,
  });

  final String? origen;
  final int estrellas;
  final bool cambiado;
  final ValueChanged<int> alCambiar;
  final VoidCallback alRestaurar;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _NombreCampo(
          'Estrellas (Rotten Tomatoes)',
          cambiado: cambiado,
          alRestaurar: alRestaurar,
          origen: origen,
        ),
        Row(
          children: [
            for (var n = 1; n <= 5; n++)
              IconButton(
                tooltip: '$n ${n == 1 ? 'estrella' : 'estrellas'}',
                // Pulsar la estrella ya marcada la quita.
                onPressed: () => alCambiar(n == estrellas ? 0 : n),
                icon: Icon(
                  n <= estrellas
                      ? Icons.star_rounded
                      : Icons.star_border_rounded,
                  color: n <= estrellas ? c.dorado : c.textoTenue,
                  size: 28,
                ),
              ),
            const SizedBox(width: 8),
            if (estrellas > 0)
              TextButton(
                onPressed: () => alCambiar(0),
                child: const Text('Quitar estrellas'),
              )
            else
              Text(
                'Sin estrellas',
                style: TextStyle(fontSize: 13, color: c.textoSecundario),
              ),
          ],
        ),
      ],
    );
  }
}

/// La carátula actual (o la nueva elegida) con sus botones.
class _ColumnaCaratula extends StatelessWidget {
  const _ColumnaCaratula({
    required this.pelicula,
    required this.original,
    required this.nueva,
    required this.alCambiar,
    required this.alQuitar,
    required this.alRestaurar,
  });

  final Pelicula pelicula;
  final Uint8List? original;
  final CaratulaNueva? nueva;
  final VoidCallback? alCambiar;
  final VoidCallback? alQuitar;
  final VoidCallback alRestaurar;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final imagen = nueva != null ? nueva!.imagen : original;
    final descripcion = imagen == null
        ? (nueva != null ? 'Se quitará la carátula' : 'Sin carátula')
        : _describir(imagen);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Se puede arrastrar una imagen desde el Explorador encima.
        ZonaSoltarCaratula(
          activa: alCambiar != null,
          child: imagen == null
              ? null
              : Caratula(
                  titulo: pelicula.titulo,
                  anio: pelicula.anio,
                  tono: pelicula.tono,
                  imagen: imagen,
                ),
        ),
        const SizedBox(height: 12),
        _NombreCampo(
          'Carátula',
          cambiado: nueva != null,
          alRestaurar: alRestaurar,
        ),
        Text(
          descripcion,
          style: TextStyle(fontSize: 13, color: c.textoSecundario),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: alCambiar,
          icon: const Icon(Icons.image_outlined, size: 16),
          label: Text(imagen == null ? 'Elegir imagen…' : 'Cambiar carátula…'),
        ),
        const SizedBox(height: 8),
        if (imagen != null)
          TextButton(onPressed: alQuitar, child: const Text('Quitar carátula')),
        Text(
          'La carátula la pones tú: la app nunca descarga carátulas por su '
          'cuenta. También puedes arrastrarla desde el Explorador.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, height: 1.5, color: c.textoTenue),
        ),
      ],
    );
  }

  static String _describir(Uint8List imagen) {
    final tipo = imagen[0] == 0x89 ? 'PNG' : 'JPEG';
    final kb = (imagen.length / 1024).round();
    final decodificador = img.findDecoderForData(imagen);
    final info = decodificador?.startDecode(imagen);
    final medidas = info == null ? '' : '${info.width} × ${info.height} · ';
    return '$medidas$tipo · $kb KB';
  }
}

class _Aviso extends StatelessWidget {
  const _Aviso(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: c.rojoFondo,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, size: 18, color: c.rojo),
          const SizedBox(width: 10),
          Expanded(
            child: Text(texto, style: TextStyle(fontSize: 14, color: c.texto)),
          ),
        ],
      ),
    );
  }
}

/// Lee un `.mp4` sin frenar la pantalla. (Función suelta: ver `edicion.dart`.)
Future<DatosArchivo> leerEnSegundoPlano(String ruta) =>
    Isolate.run(() => leerArchivo(ruta));
