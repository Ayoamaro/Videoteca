import 'package:flutter/material.dart';

import '../disco/ventana_windows.dart';
import '../tema/colores.dart';

/// [child] con la barra de la ventana encima (en Windows, como Chrome: la
/// de Windows no está, ver `ventana_windows.dart`). [mostrar], para las
/// pruebas.
class ConBarraVentana extends StatelessWidget {
  const ConBarraVentana({super.key, required this.child, this.mostrar});

  final Widget child;
  final bool? mostrar;

  @override
  Widget build(BuildContext context) {
    if (!(mostrar ?? barraPropia)) return child;
    return Column(
      children: [
        const BarraVentana(),
        Expanded(child: child),
      ],
    );
  }
}

/// Alto de la barra de la ventana.
const altoBarraVentana = 34.0;

/// La barra de arriba: logo y minimizar / maximizar / cerrar con el
/// estilo de la app. Arrastrarla, el doble clic, el menú del sistema y el
/// menú «Ajustar» los pone Windows (código nativo).
class BarraVentana extends StatefulWidget {
  const BarraVentana({super.key});

  @override
  State<BarraVentana> createState() => _EstadoBarraVentana();
}

class _EstadoBarraVentana extends State<BarraVentana> {
  final _minimizar = GlobalKey();
  final _maximizar = GlobalKey();
  final _cerrar = GlobalKey();

  /// Las últimas zonas mandadas (números separados por espacios).
  String? _enviado;

  Ventana get _ventana => Ventana.instancia;

  /// Le dice al código nativo dónde están la barra y los botones (en
  /// píxeles), si ha cambiado algo.
  void _enviarZonas() {
    if (!mounted) return;
    final escala = MediaQuery.devicePixelRatioOf(context);
    Rect? rect(GlobalKey clave) {
      final caja = clave.currentContext?.findRenderObject() as RenderBox?;
      if (caja == null || !caja.hasSize) return null;
      final r = caja.localToGlobal(Offset.zero) & caja.size;
      return Rect.fromLTRB(
        r.left * escala,
        r.top * escala,
        r.right * escala,
        r.bottom * escala,
      );
    }

    final minimizar = rect(_minimizar);
    final maximizar = rect(_maximizar);
    final cerrar = rect(_cerrar);
    if (minimizar == null || maximizar == null || cerrar == null) return;
    final alto = altoBarraVentana * escala;
    // Con los números, no con `Rect.toString()`: en la versión Release,
    // Flutter quita esos textos («Instance of 'Rect'») y todas las zonas
    // parecían iguales; tras maximizar no se volvían a mandar y los botones
    // no respondían (issue #13).
    final huella = [
      alto,
      for (final r in [minimizar, maximizar, cerrar]) ...[
        r.left,
        r.top,
        r.right,
        r.bottom,
      ],
    ].join(' ');
    if (huella == _enviado) return;
    _enviado = huella;
    _ventana.zonas(
      alto: alto,
      botones: [minimizar, cerrar],
      maximizar: maximizar,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Al cambiar el tamaño de la ventana (o al maximizarla), los botones se
    // mueven: se vuelve a dibujar y se le dice al código nativo.
    MediaQuery.sizeOf(context);
    WidgetsBinding.instance.addPostFrameCallback((_) => _enviarZonas());
    final c = context.colores;
    return ValueListenableBuilder(
      valueListenable: _ventana.estado,
      builder: (context, estado, _) {
        final color = estado.activa ? c.texto : c.textoTenue;
        return Material(
          color: c.menu,
          child: Container(
            height: altoBarraVentana,
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: c.borde)),
            ),
            child: Row(
              children: [
                const SizedBox(width: 12),
                Icon(
                  Icons.movie_outlined,
                  size: 16,
                  color: estado.activa ? c.dorado : c.textoTenue,
                ),
                // Solo el icono: el nombre ya está en el menú (y la ventana
                // sigue llamándose «Videoteca» para Windows).
                // El hueco: se arrastra (lo dice Windows, no la app).
                const Spacer(),
                _Boton(
                  key: _minimizar,
                  glifo: _glifoMinimizar,
                  nombre: 'Minimizar',
                  color: color,
                  alPulsar: _ventana.minimizar,
                ),
                _Boton(
                  key: _maximizar,
                  glifo: estado.maximizada ? _glifoRestaurar : _glifoMaximizar,
                  nombre: estado.maximizada ? 'Restaurar' : 'Maximizar',
                  color: color,
                  // Sus clics son de Windows: aquí solo se pinta.
                  estado: estado.maximizar,
                  alPulsar: _ventana.maximizar,
                ),
                _Boton(
                  key: _cerrar,
                  glifo: _glifoCerrar,
                  nombre: 'Cerrar',
                  color: color,
                  cerrar: true,
                  alPulsar: _ventana.cerrar,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// Los iconos de los botones de Windows (fuente «Segoe MDL2 Assets», que
// viene con Windows 10 y 11).
const _fuenteIconos = 'Segoe MDL2 Assets';
const _glifoMinimizar = '';
const _glifoMaximizar = '';
const _glifoRestaurar = '';
const _glifoCerrar = '';

/// Un botón de la barra (46 de ancho, como los de Windows). Con [estado], lo
/// pinta según lo que diga el código nativo (el de maximizar).
class _Boton extends StatefulWidget {
  const _Boton({
    super.key,
    required this.glifo,
    required this.nombre,
    required this.color,
    required this.alPulsar,
    this.estado,
    this.cerrar = false,
  });

  final String glifo;
  final String nombre;
  final Color color;
  final VoidCallback alPulsar;
  final EstadoBoton? estado;
  final bool cerrar;

  @override
  State<_Boton> createState() => _EstadoBoton();
}

class _EstadoBoton extends State<_Boton> {
  var _encima = false;
  var _pulsado = false;

  static const _rojoCerrar = Color(0xFFC42B1C);

  @override
  Widget build(BuildContext context) {
    final nativo = widget.estado;
    final encima = nativo == null ? _encima : nativo != EstadoBoton.normal;
    final pulsado = nativo == null ? _pulsado : nativo == EstadoBoton.pulsado;
    final fondo = widget.cerrar
        ? (pulsado
              ? _rojoCerrar.withValues(alpha: 0.8)
              : encima
              ? _rojoCerrar
              : Colors.transparent)
        : widget.color.withValues(
            alpha: pulsado
                ? 0.14
                : encima
                ? 0.08
                : 0,
          );
    final color = widget.cerrar && encima ? Colors.white : widget.color;
    return Semantics(
      button: true,
      label: widget.nombre,
      onTap: widget.alPulsar,
      excludeSemantics: true,
      child: MouseRegion(
        onEnter: (_) => setState(() => _encima = true),
        onExit: (_) => setState(() {
          _encima = false;
          _pulsado = false;
        }),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => setState(() => _pulsado = true),
          onTapCancel: () => setState(() => _pulsado = false),
          onTap: () {
            setState(() => _pulsado = false);
            widget.alPulsar();
          },
          child: Container(
            width: 46,
            height: altoBarraVentana,
            color: fondo,
            alignment: Alignment.center,
            child: Text(
              widget.glifo,
              style: TextStyle(
                fontFamily: _fuenteIconos,
                fontSize: 10,
                color: color,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
