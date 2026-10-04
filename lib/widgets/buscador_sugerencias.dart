import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../datos/buscador.dart';
import '../datos/catalogo.dart';
import '../modelos/pelicula.dart';
import '../tema/colores.dart';
import '../utilidades.dart';
import 'caratula.dart';
import 'comunes.dart';

/// Lo que se puede elegir en la lista de sugerencias.
sealed class _Opcion {}

class _OpcionPelicula extends _Opcion {
  _OpcionPelicula(this.pelicula, this.coincidencia);
  final Pelicula pelicula;
  final Coincidencia coincidencia;
}

class _OpcionPersona extends _Opcion {
  _OpcionPersona(this.persona);
  final SugerenciaPersona persona;
}

class _OpcionVerTodas extends _Opcion {}

/// Buscador con autocompletado: mientras escribes, debajo aparecen las
/// películas que encajan y los actores o directores con ese nombre.
///
/// Con el teclado: ↑ ↓ para moverse, Intro para abrir y Esc para cerrar.
/// Intro sin nada marcado lleva al catálogo con todos los resultados.
class BuscadorConSugerencias extends ConsumerStatefulWidget {
  const BuscadorConSugerencias({
    super.key,
    this.alto = 64,
    this.indicacion = 'Busca por título, título original, actor o director…',
    this.atajo,
  });

  final double alto;
  final String indicacion;
  final String? atajo;

  /// Películas que se sugieren como máximo.
  static const maxPeliculas = 6;

  @override
  ConsumerState<BuscadorConSugerencias> createState() =>
      _BuscadorConSugerenciasState();
}

class _BuscadorConSugerenciasState
    extends ConsumerState<BuscadorConSugerencias> {
  final _texto = TextEditingController();
  final _enlace = LayerLink();
  final _lista = OverlayPortalController();
  late final FocusNode _foco = ref.read(focoBusquedaProvider);

  /// Opción marcada con las flechas (-1 = ninguna).
  int _marcada = -1;
  List<_Opcion> _opciones = const [];

  @override
  void initState() {
    super.initState();
    _foco.addListener(_alCambiarFoco);
  }

  @override
  void dispose() {
    _foco.removeListener(_alCambiarFoco);
    _texto.dispose();
    super.dispose();
  }

  void _alCambiarFoco() {
    if (_foco.hasFocus) {
      _texto.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _texto.text.length,
      );
      if (_texto.text.trim().isNotEmpty) _lista.show();
    } else {
      _lista.hide();
    }
  }

  void _alEscribir(String texto) {
    setState(() => _marcada = -1);
    texto.trim().isEmpty ? _lista.hide() : _lista.show();
  }

  void _abrir(_Opcion opcion) {
    final consulta = _texto.text.trim();
    _lista.hide();
    _foco.unfocus();
    switch (opcion) {
      case _OpcionPelicula(:final pelicula):
        context.push('/pelicula/${pelicula.id}');
      case _OpcionPersona(:final persona):
        final en = persona.rol == Rol.director ? 'directores' : 'actores';
        context.go(
          '/catalogo?q=${Uri.encodeQueryComponent(persona.nombre)}&en=$en',
        );
      case _OpcionVerTodas():
        context.go('/catalogo?q=${Uri.encodeQueryComponent(consulta)}');
    }
  }

  void _alPulsarIntro(String _) {
    if (_texto.text.trim().isEmpty) return;
    if (_marcada >= 0 && _marcada < _opciones.length) {
      _abrir(_opciones[_marcada]);
    } else {
      _abrir(_OpcionVerTodas());
    }
  }

  KeyEventResult _alPulsarTecla(FocusNode _, KeyEvent evento) {
    if (evento is KeyUpEvent || !_lista.isShowing) {
      return KeyEventResult.ignored;
    }
    final tecla = evento.logicalKey;
    if (tecla == LogicalKeyboardKey.arrowDown) {
      setState(() => _marcada = (_marcada + 1).clamp(0, _opciones.length - 1));
    } else if (tecla == LogicalKeyboardKey.arrowUp) {
      setState(() => _marcada = (_marcada - 1).clamp(-1, _opciones.length - 1));
    } else if (tecla == LogicalKeyboardKey.escape) {
      _lista.hide();
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final consulta = _texto.text.trim();
    final buscador = ref.watch(buscadorProvider);
    final porId = ref.watch(peliculasPorIdProvider);
    final coincidencias = consulta.isEmpty
        ? const <Coincidencia>[]
        : buscador.buscar(consulta);
    final personas = consulta.isEmpty
        ? const <SugerenciaPersona>[]
        : buscador.personas(consulta);
    _opciones = [
      for (final c in coincidencias.take(BuscadorConSugerencias.maxPeliculas))
        if (porId[c.id] case final p?) _OpcionPelicula(p, c),
      for (final p in personas) _OpcionPersona(p),
      if (coincidencias.isNotEmpty) _OpcionVerTodas(),
    ];

    return LayoutBuilder(
      builder: (context, medidas) => OverlayPortal(
        controller: _lista,
        overlayChildBuilder: (_) => Positioned(
          left: 0,
          top: 0,
          width: medidas.maxWidth,
          child: CompositedTransformFollower(
            link: _enlace,
            showWhenUnlinked: false,
            targetAnchor: Alignment.bottomLeft,
            offset: const Offset(0, 8),
            // Forma parte del cuadro de texto: pulsar aquí no le quita el
            // cursor.
            child: TextFieldTapRegion(
              child: _ListaSugerencias(
                consulta: consulta,
                opciones: _opciones,
                total: coincidencias.length,
                marcada: _marcada,
                alElegir: _abrir,
              ),
            ),
          ),
        ),
        child: CompositedTransformTarget(
          link: _enlace,
          child: Focus(
            onKeyEvent: _alPulsarTecla,
            child: CampoBusqueda(
              controlador: _texto,
              foco: _foco,
              alto: widget.alto,
              indicacion: widget.indicacion,
              atajo: widget.atajo,
              alCambiar: _alEscribir,
              alEnviar: _alPulsarIntro,
            ),
          ),
        ),
      ),
    );
  }
}

/// El recuadro desplegable con las sugerencias.
class _ListaSugerencias extends StatelessWidget {
  const _ListaSugerencias({
    required this.consulta,
    required this.opciones,
    required this.total,
    required this.marcada,
    required this.alElegir,
  });

  final String consulta;
  final List<_Opcion> opciones;
  final int total;
  final int marcada;
  final ValueChanged<_Opcion> alElegir;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final hijos = <Widget>[];
    var hayPersonas = false;
    for (var i = 0; i < opciones.length; i++) {
      final opcion = opciones[i];
      if (opcion is _OpcionPersona && !hayPersonas) {
        hayPersonas = true;
        hijos.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: const Etiqueta('Actores y directores'),
          ),
        );
      }
      hijos.add(
        _Fila(
          marcada: i == marcada,
          alPulsar: () => alElegir(opcion),
          child: switch (opcion) {
            _OpcionPelicula() => _FilaPelicula(opcion),
            _OpcionPersona(:final persona) => _FilaPersona(persona),
            _OpcionVerTodas() => _FilaVerTodas(total),
          },
        ),
      );
    }
    if (opciones.isEmpty) hijos.add(_SinCoincidencias(consulta));

    return Material(
      color: c.superficieAlta,
      elevation: 12,
      shadowColor: Colors.black54,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: c.bordeFuerte),
      ),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: (MediaQuery.sizeOf(context).height * 0.6).clamp(200, 560),
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 6),
          children: hijos,
        ),
      ),
    );
  }
}

class _Fila extends StatelessWidget {
  const _Fila({
    required this.marcada,
    required this.alPulsar,
    required this.child,
  });

  final bool marcada;
  final VoidCallback alPulsar;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: marcada ? context.colores.seleccion : Colors.transparent,
      child: InkWell(
        onTap: alPulsar,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: child,
        ),
      ),
    );
  }
}

class _FilaPelicula extends StatelessWidget {
  const _FilaPelicula(this.opcion);

  final _OpcionPelicula opcion;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final p = opcion.pelicula;
    final persona = opcion.coincidencia.persona;
    // Por qué sale: si es por una persona, quién; si no, el título original
    // (cuando es distinto).
    final motivo = persona == null
        ? (p.tituloOriginal.isNotEmpty &&
                  normalizar(p.tituloOriginal) != normalizar(p.titulo)
              ? p.tituloOriginal
              : '')
        : opcion.coincidencia.rol == Rol.director
        ? 'Dirigida por $persona'
        : 'Con $persona';
    return Row(
      children: [
        SizedBox(width: 34, child: Caratula.de(p, mostrarNueva: false)),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                p.titulo,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                [
                  motivo,
                  if (p.anio > 0) '${p.anio}',
                  p.generoCarpeta,
                ].where((t) => t.isNotEmpty).join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: c.textoSecundario),
              ),
            ],
          ),
        ),
        if (p.estrellas > 0) ...[
          const SizedBox(width: 12),
          Estrellas(p.estrellas, tam: 14),
        ],
      ],
    );
  }
}

class _FilaPersona extends StatelessWidget {
  const _FilaPersona(this.persona);

  final SugerenciaPersona persona;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final director = persona.rol == Rol.director;
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(color: c.seleccion, shape: BoxShape.circle),
          child: Icon(
            director ? Icons.videocam_outlined : Icons.person_outline_rounded,
            size: 18,
            color: c.doradoTexto,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            persona.nombre,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          '${director ? 'Dirección' : 'Reparto'} · '
          '${formatoNumero(persona.total)} '
          '${persona.total == 1 ? 'película' : 'películas'}',
          style: TextStyle(fontSize: 13, color: c.textoSecundario),
        ),
      ],
    );
  }
}

class _FilaVerTodas extends StatelessWidget {
  const _FilaVerTodas(this.total);

  final int total;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    return Row(
      children: [
        Expanded(
          child: Text(
            total == 1
                ? 'Ver el resultado en el catálogo'
                : 'Ver los ${formatoNumero(total)} resultados en el catálogo',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: c.doradoTexto,
            ),
          ),
        ),
        Icon(Icons.arrow_forward_rounded, size: 18, color: c.doradoTexto),
      ],
    );
  }
}

/// "No tienes esta película" (como en el diseño).
class _SinCoincidencias extends StatelessWidget {
  const _SinCoincidencias(this.consulta);

  final String consulta;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: Row(
        children: [
          Icon(Icons.search_off_rounded, color: c.textoTenue),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'No tienes esta película',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  'Nada en la colección coincide con «$consulta».',
                  style: TextStyle(fontSize: 13, color: c.textoSecundario),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
