import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import '../datos/sesion.dart';
import '../tablon/cifrado.dart';
import '../tablon/copia_local.dart';
import '../tablon/github.dart' show TablonException;
import '../tablon/lector.dart';
import '../tema/colores.dart';
import '../tema/tema.dart';
import '../utilidades.dart';
import '../widgets/comunes.dart';

/// Tablón que se propone al entrar en modo consulta si no se ha usado
/// ninguno (se puede poner al compilar: `--dart-define=TABLON=usuario/nombre`).
const tablonPorDefecto = String.fromEnvironment('TABLON');

/// Qué hacer al entrar: [modo] y los ajustes que hay que guardar en la base de
/// datos de ese modo.
typedef AlEntrar = Future<void> Function(
  ModoApp modo, {
  Map<String, String> ajustes,
});

/// Pantalla de acceso: consultar el catálogo con la contraseña común o (solo
/// en el PC) administrar con la contraseña de administrador.
class PantallaAcceso extends StatelessWidget {
  const PantallaAcceso({
    super.key,
    required this.sesion,
    required this.carpeta,
    required this.alEntrar,
  });

  /// La sesión guardada (se cambia aquí: tablón, contraseña de
  /// administrador nueva).
  final Sesion sesion;

  /// Carpeta de datos de la app.
  final String carpeta;
  final AlEntrar alEntrar;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final tema = Theme.of(context).textTheme;
    final consulta = _TarjetaConsulta(sesion: sesion, alEntrar: alEntrar);
    final admin = _TarjetaAdmin(
      sesion: sesion,
      carpeta: carpeta,
      alEntrar: alEntrar,
    );
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: puedeAdministrar ? 920 : 460,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.movie_outlined, size: 34, color: c.dorado),
                      const SizedBox(width: 10),
                      Text(
                        'Videoteca',
                        style: TextStyle(
                          fontFamily: fuenteTitulos,
                          fontSize: 30,
                          fontWeight: FontWeight.w700,
                          color: c.texto,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    puedeAdministrar
                        ? '¿Cómo quieres entrar?'
                        : 'Entra con la contraseña común',
                    textAlign: TextAlign.center,
                    style: tema.titleMedium?.copyWith(color: c.textoSuave),
                  ),
                  const SizedBox(height: 28),
                  if (!puedeAdministrar)
                    consulta
                  else
                    LayoutBuilder(
                      builder: (context, medidas) => medidas.maxWidth < 700
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                consulta,
                                const SizedBox(height: 18),
                                admin,
                              ],
                            )
                          : IntrinsicHeight(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Expanded(child: consulta),
                                  const SizedBox(width: 18),
                                  Expanded(child: admin),
                                ],
                              ),
                            ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Esqueleto común de las dos tarjetas.
class _Tarjeta extends StatelessWidget {
  const _Tarjeta({
    required this.icono,
    required this.titulo,
    required this.texto,
    required this.children,
  });

  final IconData icono;
  final String titulo;
  final String texto;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    return Tarjeta(
      relleno: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: c.doradoFondo,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icono, color: c.doradoTexto, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  titulo,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            texto,
            style: TextStyle(fontSize: 14, height: 1.5, color: c.textoSuave),
          ),
          const SizedBox(height: 22),
          ...children,
        ],
      ),
    );
  }
}

/// Mensaje de error (en rojo) o de lo que se está haciendo.
Widget _mensaje(BuildContext context, String? error, String? trabajando) {
  final c = context.colores;
  if (trabajando != null) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: c.dorado),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(trabajando, style: TextStyle(color: c.textoSuave)),
          ),
        ],
      ),
    );
  }
  if (error == null) return const SizedBox.shrink();
  return Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Text(error, style: TextStyle(color: c.rojo, height: 1.4)),
  );
}

/// Campo de contraseña con el botón del ojo para verla.
class _CampoContrasena extends StatefulWidget {
  const _CampoContrasena({
    required this.controlador,
    required this.etiqueta,
    this.alEnviar,
    this.autofocus = false,
  });

  final TextEditingController controlador;
  final String etiqueta;
  final VoidCallback? alEnviar;
  final bool autofocus;

  @override
  State<_CampoContrasena> createState() => _CampoContrasenaState();
}

class _CampoContrasenaState extends State<_CampoContrasena> {
  var _oculta = true;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: TextField(
      controller: widget.controlador,
      obscureText: _oculta,
      autofocus: widget.autofocus,
      enableSuggestions: false,
      autocorrect: false,
      onSubmitted: (_) => widget.alEnviar?.call(),
      decoration: InputDecoration(
        labelText: widget.etiqueta,
        suffixIcon: IconButton(
          tooltip: _oculta ? 'Ver la contraseña' : 'Ocultar la contraseña',
          icon: Icon(
            _oculta ? Icons.visibility_outlined : Icons.visibility_off_outlined,
            size: 20,
          ),
          onPressed: () => setState(() => _oculta = !_oculta),
        ),
      ),
    ),
  );
}

// ── Consulta ─────────────────────────────────────────────────────────────

class _TarjetaConsulta extends StatefulWidget {
  const _TarjetaConsulta({required this.sesion, required this.alEntrar});

  final Sesion sesion;
  final AlEntrar alEntrar;

  @override
  State<_TarjetaConsulta> createState() => _TarjetaConsultaState();
}

class _TarjetaConsultaState extends State<_TarjetaConsulta> {
  late final _tablon = TextEditingController(
    text: widget.sesion.tablon.isNotEmpty
        ? widget.sesion.tablon
        : tablonPorDefecto,
  );
  final _contrasena = TextEditingController();
  String? _error;
  String? _trabajando;

  @override
  void dispose() {
    _tablon.dispose();
    _contrasena.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    if (_trabajando != null) return;
    final repositorio = nombreTablon(_tablon.text);
    if (repositorio == null) {
      setState(
        () => _error =
            'El tablón se escribe «usuario/nombre» (p. ej. '
            '«Ana/Videoteca_Tablon») o con su enlace de GitHub.',
      );
      return;
    }
    if (_contrasena.text.isEmpty) {
      setState(() => _error = 'Escribe la contraseña común.');
      return;
    }
    setState(() {
      _error = null;
      _trabajando = 'Comprobando la contraseña…';
    });
    final lector = LectorTablon(repositorio);
    try {
      final r = await comprobarContrasena(lector, _contrasena.text);
      widget.sesion.tablon = repositorio;
      await widget.alEntrar(
        ModoApp.consulta,
        ajustes: {
          AjusteConsulta.repositorio: repositorio,
          AjusteConsulta.llave: r.llave.aTexto(),
          AjusteConsulta.parametros: jsonEncode(r.parametros.toJson()),
        },
      );
      return;
    } on ContrasenaIncorrecta {
      _error = 'La contraseña no es correcta.';
      _contrasena.clear();
    } on TablonException catch (e) {
      _error = e.mensaje;
    } on Object catch (e) {
      _error = 'No se ha podido entrar: $e';
    } finally {
      lector.cerrar();
    }
    if (mounted) setState(() => _trabajando = null);
  }

  @override
  Widget build(BuildContext context) {
    final ocupado = _trabajando != null;
    return _Tarjeta(
      icono: Icons.search_rounded,
      titulo: 'Consultar el catálogo',
      texto:
          'Busca películas y mira sus fichas. La primera vez se descarga el '
          'catálogo; después funciona también sin internet y se pone al día '
          'solo.',
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: TextField(
            controller: _tablon,
            enabled: !ocupado,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'Tablón',
              hintText: 'usuario/nombre',
            ),
          ),
        ),
        _CampoContrasena(
          controlador: _contrasena,
          etiqueta: 'Contraseña común',
          alEnviar: _entrar,
          autofocus: !puedeAdministrar && _tablon.text.isNotEmpty,
        ),
        _mensaje(context, _error, _trabajando),
        FilledButton.icon(
          onPressed: ocupado ? null : _entrar,
          icon: const Icon(Icons.login_rounded, size: 18),
          label: const Text('Entrar'),
        ),
      ],
    );
  }
}

// ── Administrador ────────────────────────────────────────────────────────

class _TarjetaAdmin extends StatefulWidget {
  const _TarjetaAdmin({
    required this.sesion,
    required this.carpeta,
    required this.alEntrar,
  });

  final Sesion sesion;
  final String carpeta;
  final AlEntrar alEntrar;

  @override
  State<_TarjetaAdmin> createState() => _TarjetaAdminState();
}

class _TarjetaAdminState extends State<_TarjetaAdmin> {
  final _contrasena = TextEditingController();
  final _repetida = TextEditingController();
  String? _error;
  String? _trabajando;

  bool get _crear => widget.sesion.contrasenaAdmin == null;

  @override
  void dispose() {
    _contrasena.dispose();
    _repetida.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    if (_trabajando != null) return;
    final texto = _contrasena.text;
    if (_crear) {
      if (texto.length < largoMinimoContrasena) {
        setState(
          () => _error =
              'La contraseña tiene que tener al menos '
              '$largoMinimoContrasena caracteres.',
        );
        return;
      }
      if (texto != _repetida.text) {
        setState(() => _error = 'Las dos contraseñas no coinciden.');
        return;
      }
    }
    setState(() {
      _error = null;
      _trabajando = _crear
          ? 'Guardando la contraseña…'
          : 'Comprobando la contraseña…';
    });
    try {
      if (_crear) {
        widget.sesion.contrasenaAdmin = await ContrasenaAdmin.crear(texto);
      } else if (!await widget.sesion.contrasenaAdmin!.comprobar(texto)) {
        _error = 'La contraseña no es correcta.';
        _contrasena.clear();
        if (mounted) setState(() => _trabajando = null);
        return;
      }
      await widget.alEntrar(ModoApp.administrador);
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          _error = 'No se ha podido entrar: $e';
          _trabajando = null;
        });
      }
    }
  }

  void _olvidada() {
    final ruta = '${widget.carpeta}${Platform.pathSeparator}sesion.json';
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Has olvidado la contraseña?'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: SelectableText(
            'La contraseña de administrador solo está en este PC y no se '
            'puede recuperar. Para crear otra, cierra la app y borra este '
            'archivo:\n\n$ruta\n\nTu colección, las fichas y la publicación '
            'no se pierden.',
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final ocupado = _trabajando != null;
    // ¿Ya hay una colección en este PC (de antes de que hubiera contraseña)?
    final hayColeccion = File(
      '${widget.carpeta}${Platform.pathSeparator}videoteca.sqlite',
    ).existsSync();
    return _Tarjeta(
      icono: Icons.admin_panel_settings_outlined,
      titulo: 'Administrar este PC',
      texto: _crear
          ? hayColeccion
                ? 'Tu colección ya está en este PC. Crea una contraseña de '
                      'administrador: se pedirá al entrar en este modo.'
                : 'Lee las películas del disco, completa sus fichas y publica '
                      'el catálogo. Crea una contraseña de administrador para '
                      'este PC.'
          : 'Lee las películas del disco, completa sus fichas y publica el '
                'catálogo.',
      children: [
        _CampoContrasena(
          controlador: _contrasena,
          etiqueta: _crear ? 'Nueva contraseña' : 'Contraseña de administrador',
          alEnviar: _crear ? null : _entrar,
        ),
        if (_crear)
          _CampoContrasena(
            controlador: _repetida,
            etiqueta: 'Repite la contraseña',
            alEnviar: _entrar,
          ),
        _mensaje(context, _error, _trabajando),
        FilledButton.icon(
          onPressed: ocupado ? null : _entrar,
          icon: Icon(
            _crear ? Icons.key_rounded : Icons.login_rounded,
            size: 18,
          ),
          label: Text(_crear ? 'Crear y entrar' : 'Entrar'),
        ),
        if (!_crear) ...[
          const SizedBox(height: 6),
          TextButton(
            onPressed: _olvidada,
            child: Text(
              '¿La has olvidado?',
              style: TextStyle(color: c.textoSecundario),
            ),
          ),
        ],
      ],
    );
  }
}
