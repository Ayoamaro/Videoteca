import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image/image.dart' as img;

import '../datos/catalogo.dart';
import '../datos/edicion.dart';
import '../disco/dialogo_abrir.dart';
import '../disco/escritor.dart';
import '../disco/lector_archivo.dart';
import '../modelos/pelicula.dart';
import '../tema/colores.dart';
import '../widgets/caratula.dart';
import '../widgets/comunes.dart';
import 'registro.dart';

/// "Editar ficha": cambiar a mano los datos y la carátula de una película y
/// guardarlos dentro de su `.mp4`.
///
/// Los valores de partida se leen del propio archivo (no de la base de
/// datos), para editar exactamente lo que hay en él.
class PantallaEditarFicha extends ConsumerStatefulWidget {
  const PantallaEditarFicha({super.key, required this.id});

  final int id;

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

  @override
  void initState() {
    super.initState();
    for (final t in _textos.values) {
      t.addListener(() => setState(() {}));
    }
    _cargar();
  }

  @override
  void dispose() {
    for (final t in _textos.values) {
      t.dispose();
    }
    super.dispose();
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
      });
    } catch (e) {
      if (mounted) setState(() => _errorLectura = '$e');
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

  Future<void> _elegirCaratula() async {
    final ruta = elegirImagen();
    if (ruta == null) return;
    final bytes = await File(ruta).readAsBytes();
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

  void _aviso(String texto) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(texto)));

  Future<void> _guardar() async {
    final p = _pelicula;
    if (p == null) return;
    final cambios = _cambios;
    final caratula = _caratula;
    final mensajero = ScaffoldMessenger.of(context);
    final navegador = Navigator.of(context, rootNavigator: true);
    final enrutador = GoRouter.of(context);
    final edicion = ref.read(edicionProvider);
    mostrarGuardando(context, 'Guardando en el archivo…');
    try {
      final id = await edicion.guardar(p, cambios, caratula: caratula);
      navegador.pop();
      if (!mounted) return;
      // Ya no hay cambios pendientes: se puede salir sin preguntar.
      setState(() {
        _original = {..._original!, ...cambios};
        _caratula = null;
      });
      enrutador.pop();
      final n = cambios.length + (caratula == null ? 0 : 1);
      mensajero
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 8),
            content: Text(
              id == null
                  ? 'No había nada distinto que guardar.'
                  : 'Guardado en el archivo y comprobado '
                        '($n ${n == 1 ? 'cambio' : 'cambios'}).',
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
          e is EscrituraException ? e.mensaje : '$e',
        );
      }
    }
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

  Future<void> _salir() async {
    if (await _descartar() && mounted) {
      context.canPop() ? context.pop() : context.go('/pelicula/${widget.id}');
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
    final puedeGuardar =
        cargado && problema == null && errores.isEmpty && _hayCambios;

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
                    label: const Text('Volver a la ficha'),
                    style: TextButton.styleFrom(
                      foregroundColor: c.textoSecundario,
                      minimumSize: const Size(0, 44),
                    ),
                  ),
                ),
                CabeceraPagina(
                  titulo: 'Editar ficha',
                  descripcion:
                      'Los cambios se guardan dentro de «${p.archivo}», en el '
                      'mismo formato que usa Windows en Propiedades → '
                      'Detalles. Después se comprueba que el vídeo y la '
                      'carátula quedan intactos, y todo queda en el Registro '
                      'de cambios para poder deshacerlo.',
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
                          ? 'Sin cambios'
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
                  TextButton(onPressed: _salir, child: const Text('Cancelar')),
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
  const _NombreCampo(this.nombre, {required this.cambiado, this.alRestaurar});

  final String nombre;
  final bool cambiado;
  final VoidCallback? alRestaurar;

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
  });

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
  });

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
                child: const Text('Sin estrellas'),
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
        Caratula(
          titulo: pelicula.titulo,
          anio: pelicula.anio,
          tono: pelicula.tono,
          imagen: imagen,
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
          label: const Text('Cambiar carátula…'),
        ),
        const SizedBox(height: 8),
        if (imagen != null)
          TextButton(onPressed: alQuitar, child: const Text('Quitar carátula')),
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
