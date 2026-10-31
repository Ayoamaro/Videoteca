import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../datos/fuentes.dart';
import '../disco/escritor.dart' show Campo;
import '../fuentes/datos_automaticos.dart';
import '../fuentes/filmaffinity.dart';
import '../fuentes/identificacion.dart';
import '../tema/colores.dart';
import 'dialogo_datos.dart';

/// Lee los datos de la película [datos] de su ficha de FilmAffinity y deja
/// elegir cuáles pasar a la ficha.
///
/// La app no maneja ningún navegador (Cloudflare bloqueaba la ventana de
/// Edge que abría antes, issue #5): abre la ficha en tu navegador de siempre
/// (el enlace guardado, el de Wikidata o la búsqueda de FilmAffinity), tú la
/// copias entera (Ctrl + A, Ctrl + C) y la app lee lo copiado en cuanto
/// cambia el portapapeles. [actuales] son los valores que tiene ahora el
/// formulario.
///
/// Devuelve los datos elegidos, o `null` si se cancela.
Future<Map<Campo, DatoEncontrado>?> mostrarDatosFilmaffinity(
  BuildContext context, {
  required FuentesDatos? fuentes,
  required DatosIdentificacion datos,
  required Map<Campo, String> actuales,
}) => showDialog<Map<Campo, DatoEncontrado>>(
  context: context,
  barrierDismissible: false,
  builder: (context) =>
      _DialogoFilmaffinity(fuentes: fuentes, datos: datos, actuales: actuales),
);

class _DialogoFilmaffinity extends ConsumerStatefulWidget {
  const _DialogoFilmaffinity({
    required this.fuentes,
    required this.datos,
    required this.actuales,
  });

  final FuentesDatos? fuentes;
  final DatosIdentificacion datos;
  final Map<Campo, String> actuales;

  @override
  ConsumerState<_DialogoFilmaffinity> createState() =>
      _EstadoDialogoFilmaffinity();
}

class _EstadoDialogoFilmaffinity extends ConsumerState<_DialogoFilmaffinity> {
  /// La página que se abre en el navegador (`null` mientras se busca).
  String? _url;
  var _abierta = false;

  /// Lo que había en el portapapeles al abrir la ventana: solo se lee lo
  /// que se copie después.
  late int _visto;
  Timer? _reloj;

  /// La última ficha leída y por qué no sirve lo último copiado.
  FichaFilmaffinity? _ficha;
  FalloCopiado? _fallo;
  final _marcados = <Campo>{};

  @override
  void initState() {
    super.initState();
    _visto = ref.read(portapapelesProvider).cambios();
    _reloj = Timer.periodic(
      const Duration(milliseconds: 700),
      (_) => _mirarPortapapeles(),
    );
    _buscarYAbrir();
  }

  @override
  void dispose() {
    _reloj?.cancel();
    super.dispose();
  }

  /// La ficha guardada o la de Wikidata; si no se sabe, la búsqueda.
  Future<void> _buscarYAbrir() async {
    var url = '';
    final id = idFichaFilmaffinity(
      widget.actuales[Campo.enlaceFilmaffinity] ?? '',
    );
    if (id != null) {
      url = enlaceFichaFilmaffinity(id);
    } else if (widget.fuentes != null) {
      try {
        url =
            await widget.fuentes!.buscarEnlaceFilmaffinity(widget.datos) ?? '';
      } on Exception {
        // Sin enlace: se busca en FilmAffinity.
      }
    }
    if (url.isEmpty) url = busquedaFilmaffinity(widget.datos.titulo);
    if (!mounted) return;
    setState(() => _url = url);
    await _abrir(url);
  }

  Future<void> _abrir(String url) async {
    final bien = await ref.read(abrirEnNavegadorProvider)(url);
    if (mounted) setState(() => _abierta = bien);
  }

  /// Si se ha copiado algo nuevo, lo lee.
  void _mirarPortapapeles() {
    final portapapeles = ref.read(portapapelesProvider);
    final cambios = portapapeles.cambios();
    if (cambios == _visto) return;
    _visto = cambios;
    _leer(portapapeles.html());
  }

  void _leer(Uint8List? bytes) {
    final r = fichaCopiada(bytes);
    final ficha = r.ficha;
    setState(() {
      _fallo = r.fallo;
      if (ficha == null) return;
      final c = ficha.comparar(widget.datos);
      final segura = c.titulo && c.anio && c.director;
      _ficha = ficha;
      _marcados
        ..clear()
        ..addAll([
          if (segura)
            for (final MapEntry(key: campo, value: d) in ficha.datos().entries)
              if (_vacio(campo) ||
                  (campo == Campo.sinopsis &&
                      sinopsisCortada(widget.actuales[campo]!, d.valor)))
                campo,
        ]);
    });
  }

  bool _vacio(Campo c) => (widget.actuales[c] ?? '').isEmpty;

  @override
  Widget build(BuildContext context) {
    final ficha = _ficha;
    final datos = ficha?.datos() ?? const <Campo, DatoEncontrado>{};
    return AlertDialog(
      title: const Text('Datos de FilmAffinity'),
      content: SizedBox(
        width: 680,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _pasos(),
              if (ficha != null) ...[
                const SizedBox(height: 14),
                _datos(ficha, datos),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(ficha == null ? 'Cerrar' : 'Cancelar'),
        ),
        if (ficha != null)
          FilledButton(
            onPressed: _marcados.isEmpty
                ? null
                : () => Navigator.pop(context, {
                    for (final campo in _marcados) campo: datos[campo]!,
                  }),
            child: Text('Pasar a la ficha (${_marcados.length})'),
          ),
      ],
    );
  }

  /// Qué tienes que hacer tú, y cómo va.
  Widget _pasos() {
    final c = context.colores;
    final url = _url;
    final fallo = _fallo;
    final (icono, color, texto) = url == null
        ? (
            Icons.hourglass_top_rounded,
            c.textoSuave,
            'Buscando su ficha (TMDB y Wikidata)…',
          )
        : fallo != null
        ? (Icons.info_outline_rounded, c.naranja, fallo.texto)
        : _ficha != null
        ? (
            Icons.check_circle_outline_rounded,
            c.verde,
            'Ficha leída. Si no es la película buena, copia la correcta y la '
                'leeré.',
          )
        : (
            Icons.content_paste_go_rounded,
            c.doradoTexto,
            '${_abierta ? 'He abierto FilmAffinity en tu navegador.' : 'Abre FilmAffinity en tu navegador.'} '
                'Entra en la ficha de la película, pulsa Ctrl + A y después '
                'Ctrl + C, y vuelve aquí: la leeré sola.',
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MensajeDialogo(icono: icono, color: color, texto: texto),
        if (url != null)
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              OutlinedButton.icon(
                onPressed: () => _abrir(url),
                icon: const Icon(Icons.open_in_browser_rounded, size: 18),
                label: Text(
                  idFichaFilmaffinity(url) != null
                      ? 'Abrir su ficha'
                      : 'Abrir la búsqueda',
                ),
              ),
              if (idFichaFilmaffinity(url) != null)
                OutlinedButton.icon(
                  onPressed: () =>
                      _abrir(busquedaFilmaffinity(widget.datos.titulo)),
                  icon: const Icon(Icons.search_rounded, size: 18),
                  label: Text('Buscar «${widget.datos.titulo}»'),
                ),
              OutlinedButton.icon(
                onPressed: () => _leer(ref.read(portapapelesProvider).html()),
                icon: const Icon(Icons.content_paste_rounded, size: 18),
                label: const Text('Leer lo copiado'),
              ),
            ],
          ),
      ],
    );
  }

  /// La película leída y sus datos, para marcar cuáles se pasan.
  Widget _datos(FichaFilmaffinity f, Map<Campo, DatoEncontrado> datos) {
    final c = context.colores;
    final coincide = f.comparar(widget.datos);
    final segura = coincide.titulo && coincide.anio && coincide.director;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(
              segura ? Icons.verified_rounded : Icons.warning_amber_rounded,
              color: segura ? c.verde : c.naranja,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '${f.titulo} (${f.anio})',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    TextSpan(
                      text: '  ·  ${f.explicacion(widget.datos)}',
                      style: TextStyle(fontSize: 13, color: c.textoSecundario),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          segura
              ? 'Marcados: los campos que están vacíos en tu ficha (y la '
                    'sinopsis, si la tuya está cortada). Los que ya tienen '
                    'otro valor solo se cambian si los marcas.'
              : '¿Seguro que es esta película? No hay nada marcado: marca tú '
                    'lo que quieras pasar, o copia otra ficha.',
          style: TextStyle(
            fontSize: 13,
            color: segura ? c.textoSecundario : c.naranja,
          ),
        ),
        const SizedBox(height: 10),
        for (final campo in Campo.values)
          if (datos[campo] case final dato?)
            FilaDato(
              campo: campo,
              dato: dato,
              actual: widget.actuales[campo] ?? '',
              marcado: _marcados.contains(campo),
              alCambiar: (si) => setState(
                () => si ? _marcados.add(campo) : _marcados.remove(campo),
              ),
            ),
      ],
    );
  }
}
