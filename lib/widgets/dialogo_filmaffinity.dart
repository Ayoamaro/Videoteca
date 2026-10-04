import 'dart:async';

import 'package:flutter/material.dart';

import '../disco/acciones_windows.dart';
import '../disco/escritor.dart' show Campo;
import '../fuentes/datos_automaticos.dart';
import '../fuentes/filmaffinity.dart';
import '../fuentes/identificacion.dart';
import '../fuentes/navegador.dart';
import '../tema/colores.dart';
import 'dialogo_datos.dart';

/// Lee los datos de la película [datos] de su ficha de FilmAffinity y deja
/// elegir cuáles pasar a la ficha.
///
/// Abre una ventana de Edge en la ficha (si se sabe cuál es: el enlace
/// guardado o el de Wikidata) o en la búsqueda de FilmAffinity. En cuanto
/// la ventana está en la ficha de una película, la lee sola. [actuales] son
/// los valores que tiene ahora el formulario.
///
/// Devuelve los datos elegidos, o `null` si se cancela.
Future<Map<Campo, DatoEncontrado>?> mostrarDatosFilmaffinity(
  BuildContext context, {
  required String perfil,
  required FuentesDatos? fuentes,
  required DatosIdentificacion datos,
  required Map<Campo, String> actuales,
}) => showDialog<Map<Campo, DatoEncontrado>>(
  context: context,
  barrierDismissible: false,
  builder: (context) => _DialogoFilmaffinity(
    perfil: perfil,
    fuentes: fuentes,
    datos: datos,
    actuales: actuales,
  ),
);

enum _Estado {
  /// Buscando el enlace o abriendo Edge.
  abriendo,

  /// La ventana está abierta, pero no en la ficha de una película.
  esperando,

  /// FilmAffinity pide comprobar que eres una persona.
  comprobacion,

  /// Has cerrado la ventana.
  cerrada,
}

class _DialogoFilmaffinity extends StatefulWidget {
  const _DialogoFilmaffinity({
    required this.perfil,
    required this.fuentes,
    required this.datos,
    required this.actuales,
  });

  final String perfil;
  final FuentesDatos? fuentes;
  final DatosIdentificacion datos;
  final Map<Campo, String> actuales;

  @override
  State<_DialogoFilmaffinity> createState() => _EstadoDialogoFilmaffinity();
}

class _EstadoDialogoFilmaffinity extends State<_DialogoFilmaffinity> {
  var _estado = _Estado.abriendo;
  var _paso = 'Abriendo FilmAffinity…';
  String? _error;
  Navegador? _navegador;
  Timer? _reloj;
  var _revisando = false;

  /// La última ficha leída (se sigue enseñando aunque la ventana vaya a
  /// otra página, hasta que abras la ficha de otra película).
  FichaFilmaffinity? _ficha;
  final _marcados = <Campo>{};

  @override
  void initState() {
    super.initState();
    _abrir();
  }

  @override
  void dispose() {
    _reloj?.cancel();
    _navegador?.cerrar();
    super.dispose();
  }

  Future<void> _abrir({bool buscar = false}) async {
    setState(() {
      _estado = _Estado.abriendo;
      _error = null;
    });
    try {
      var url = '';
      final guardado = widget.actuales[Campo.enlaceFilmaffinity] ?? '';
      final id = idFichaFilmaffinity(guardado);
      if (!buscar && id != null) {
        url = enlaceFichaFilmaffinity(id);
      } else if (!buscar && widget.fuentes != null) {
        setState(() => _paso = 'Buscando su ficha (TMDB y Wikidata)…');
        try {
          url =
              await widget.fuentes!.buscarEnlaceFilmaffinity(widget.datos) ??
              '';
        } on Exception {
          // Sin enlace: se busca en FilmAffinity.
        }
      }
      if (url.isEmpty) url = busquedaFilmaffinity(widget.datos.titulo);
      if (!mounted) return;
      setState(() => _paso = 'Abriendo FilmAffinity en una ventana de Edge…');
      final navegador = _navegador;
      if (navegador != null && await navegador.abierto()) {
        await navegador.ir(url);
      } else {
        _navegador = await Navegador.abrir(url, perfil: widget.perfil);
      }
      if (!mounted) return;
      setState(() => _estado = _Estado.esperando);
      _reloj ??= Timer.periodic(
        const Duration(milliseconds: 800),
        (_) => _revisar(),
      );
    } on NavegadorException catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    }
  }

  /// Mira qué hay en la ventana y, si es la ficha de otra película, la lee.
  Future<void> _revisar() async {
    final navegador = _navegador;
    if (_revisando || navegador == null || _estado == _Estado.abriendo) return;
    _revisando = true;
    try {
      if (!await navegador.abierto()) {
        if (mounted) setState(() => _estado = _Estado.cerrada);
        return;
      }
      final pagina = await navegador.paginaActual();
      if (pagina == null || !mounted) return;
      final id = idFichaFilmaffinity(pagina.url);
      final codigo = await navegador.html(pagina.id);
      if (!mounted) return;
      if (codigo == null) return; // Cargando.
      if (_esComprobacion(pagina.titulo, codigo)) {
        setState(() => _estado = _Estado.comprobacion);
        return;
      }
      if (id == null || id == _ficha?.id) {
        setState(() => _estado = _Estado.esperando);
        return;
      }
      if (!fichaEnEspanol(pagina.url)) {
        // Se lee la versión española (los nombres de los datos van en
        // español).
        await navegador.ir(enlaceFichaFilmaffinity(id));
        return;
      }
      final ficha = leerFichaFilmaffinity(codigo, pagina.url);
      if (ficha == null) return;
      final c = ficha.comparar(widget.datos);
      final segura = c.titulo && c.anio && c.director;
      setState(() {
        _ficha = ficha;
        _estado = _Estado.esperando;
        _marcados
          ..clear()
          ..addAll([
            if (segura)
              for (final MapEntry(key: campo, value: d)
                  in ficha.datos().entries)
                if (_vacio(campo) ||
                    (campo == Campo.sinopsis &&
                        sinopsisCortada(widget.actuales[campo]!, d.valor)))
                  campo,
          ]);
      });
      // Ya está leída: se aparta la ventana para ver la app.
      if (segura) await navegador.minimizar();
    } on Exception {
      // La ventana se está cerrando o cambiando de página: a la próxima.
    } finally {
      _revisando = false;
    }
  }

  bool _vacio(Campo c) => (widget.actuales[c] ?? '').isEmpty;

  static bool _esComprobacion(String titulo, String codigo) =>
      !codigo.contains('id="main-title"') &&
      (codigo.contains('challenges.cloudflare.com') ||
          titulo.startsWith('Un momento') ||
          titulo.startsWith('Just a moment'));

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
              _estadoVentana(),
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

  /// Qué pasa con la ventana de Edge y qué tienes que hacer tú.
  Widget _estadoVentana() {
    final c = context.colores;
    if (_error != null) {
      return MensajeDialogo(
        icono: Icons.error_outline_rounded,
        color: c.rojo,
        texto: _error!,
      );
    }
    final hayFicha = _ficha != null;
    final (icono, color, texto) = switch (_estado) {
      _Estado.abriendo => (Icons.hourglass_top_rounded, c.textoSuave, _paso),
      _Estado.comprobacion => (
        Icons.front_hand_rounded,
        c.naranja,
        'FilmAffinity quiere comprobar que eres una persona. Hazlo en la '
            'ventana de Edge y sigo yo.',
      ),
      _Estado.cerrada => (
        Icons.web_asset_off_rounded,
        c.textoSuave,
        'Has cerrado la ventana de FilmAffinity.',
      ),
      _Estado.esperando when hayFicha => (
        Icons.check_circle_outline_rounded,
        c.verde,
        'Ficha leída. Si no es la película buena, abre la correcta en la '
            'ventana de FilmAffinity y la leeré.',
      ),
      _Estado.esperando => (
        Icons.travel_explore_rounded,
        c.doradoTexto,
        'Busca la película en la ventana de FilmAffinity y entra en su '
            'ficha: la leeré en cuanto la abras.',
      ),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MensajeDialogo(icono: icono, color: color, texto: texto),
        if (_estado != _Estado.abriendo)
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if (_estado == _Estado.cerrada)
                OutlinedButton.icon(
                  onPressed: _abrir,
                  icon: const Icon(Icons.open_in_browser_rounded, size: 18),
                  label: const Text('Abrir otra vez'),
                )
              else
                OutlinedButton.icon(
                  onPressed: () => _navegador?.mostrar(),
                  icon: const Icon(Icons.open_in_browser_rounded, size: 18),
                  label: const Text('Ver la ventana'),
                ),
              OutlinedButton.icon(
                onPressed: () => _abrir(buscar: true),
                icon: const Icon(Icons.search_rounded, size: 18),
                label: Text('Buscar «${widget.datos.titulo}»'),
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
            TextButton.icon(
              onPressed: () => abrirConWindows(f.enlace),
              icon: const Icon(Icons.open_in_new_rounded, size: 16),
              label: const Text('FilmAffinity'),
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
                    'lo que quieras pasar, o abre otra ficha en la ventana.',
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
