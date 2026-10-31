import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../datos/red_casa.dart';
import '../disco/red.dart';
import '../tema/colores.dart';
import 'avisos.dart';

// Entrar en el PC de las películas con usuario y contraseña, para los PC de
// la red de casa que no pueden entrar como invitado (Windows 11 reciente):
// ahí el Explorador no pide la contraseña, solo dice que «las directivas de
// seguridad bloquean el acceso de invitados». La app la pide, entra con ella
// y la deja guardada en Windows (como «Recordar mis credenciales»); ella no
// la guarda.

/// Pide el usuario y la contraseña del PC de [ruta] (la carpeta de las
/// películas en la red), entra y, si se ha podido, vuelve a mirar la red.
Future<void> entrarConContrasena(BuildContext context, String ruta) async {
  final avisos = ScaffoldMessenger.of(context);
  final resultado = await showDialog<ResultadoCredenciales>(
    context: context,
    builder: (context) => _DialogoCredenciales(ruta: ruta),
  );
  if (resultado == null) return;
  final equipo = _nombreEquipo(ruta);
  avisos.avisar(
    resultado == ResultadoCredenciales.hecho
        ? 'Hecho: este PC ya entra en $equipo y lo recordará.'
        : 'Ya se entra en $equipo, pero Windows no ha dejado guardar la '
              'contraseña: al reiniciar el PC habrá que escribirla otra '
              'vez.',
    largo: resultado != ResultadoCredenciales.hecho,
  );
}

/// El nombre del PC de [ruta] (`\\AYO-PC\…` → `AYO-PC`) para los textos.
String _nombreEquipo(String ruta) =>
    (ruta.startsWith(r'\\') ? equipoDeRuta(ruta) : null) ??
    'el PC de las películas';

class _DialogoCredenciales extends ConsumerStatefulWidget {
  const _DialogoCredenciales({required this.ruta});

  final String ruta;

  @override
  ConsumerState<_DialogoCredenciales> createState() =>
      _EstadoDialogoCredenciales();
}

class _EstadoDialogoCredenciales extends ConsumerState<_DialogoCredenciales> {
  final _usuario = TextEditingController();
  final _contrasena = TextEditingController();
  var _oculta = true;
  var _entrando = false;
  String? _error;

  @override
  void dispose() {
    _usuario.dispose();
    _contrasena.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    if (_entrando) return;
    if (_usuario.text.trim().isEmpty || _contrasena.text.isEmpty) {
      setState(() => _error = 'Escribe el usuario y la contraseña.');
      return;
    }
    setState(() {
      _entrando = true;
      _error = null;
    });
    final resultado = await ref
        .read(servicioRedProvider)
        .entrar(widget.ruta, _usuario.text, _contrasena.text);
    if (!mounted) return;
    if (resultado == ResultadoCredenciales.hecho ||
        resultado == ResultadoCredenciales.sinGuardar) {
      ref.read(redCasaProvider.notifier).comprobar();
      Navigator.pop(context, resultado);
      return;
    }
    setState(() {
      _entrando = false;
      _error = _explicar(resultado);
    });
  }

  String _explicar(ResultadoCredenciales r) {
    final equipo = _nombreEquipo(widget.ruta);
    return switch (r) {
      ResultadoCredenciales.incorrectos =>
        'El usuario o la contraseña no son correctos. Fíjate en las '
            'mayúsculas: es la contraseña de la cuenta, no el PIN.',
      ResultadoCredenciales.cuentaSinContrasena =>
        'Esa cuenta no tiene contraseña y Windows no deja entrar por la red '
            'sin ella. Usa otra cuenta de $equipo o ponle una contraseña.',
      ResultadoCredenciales.cuentaNoValida =>
        'Windows no deja entrar con esa cuenta: está desactivada, bloqueada o '
            'con la contraseña caducada. Usa otra o arréglala en $equipo.',
      ResultadoCredenciales.noExiste =>
        'Ese usuario no existe en $equipo. Escribe el nombre de una cuenta de '
            'ese PC o, si es una cuenta de Microsoft, su correo.',
      ResultadoCredenciales.sinPermiso =>
        'Esa cuenta no tiene permiso para entrar en la carpeta compartida de '
            '$equipo.',
      ResultadoCredenciales.otroUsuario =>
        'Este PC ya está conectado a $equipo con otro usuario. Reinicia este '
            'PC y vuelve a probar.',
      ResultadoCredenciales.sinConexion =>
        'No se llega a $equipo: puede que esté apagado o que este PC no esté '
            'en la red de casa.',
      ResultadoCredenciales.noEsRed =>
        r'La carpeta de las películas no es una carpeta de red (\\PC\Carpeta): '
            'revísala en Ajustes → Películas en la red.',
      _ => 'Windows no ha dejado entrar en $equipo.',
    };
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final equipo = _nombreEquipo(widget.ruta);
    return AlertDialog(
      title: Text('Entrar en $equipo'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Escribe el usuario y la contraseña de una cuenta de $equipo, '
                'el PC de las películas. Windows los guarda en este PC y no '
                'habrá que volver a escribirlos (la app no guarda la '
                'contraseña).',
                style: TextStyle(fontSize: 14, height: 1.5, color: c.texto),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _usuario,
                autofocus: true,
                enabled: !_entrando,
                autocorrect: false,
                enableSuggestions: false,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Usuario',
                  helperText:
                      'El nombre de la cuenta o, si es una cuenta de '
                      'Microsoft, su correo.',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _contrasena,
                obscureText: _oculta,
                enabled: !_entrando,
                autocorrect: false,
                enableSuggestions: false,
                onSubmitted: (_) => _entrar(),
                decoration: InputDecoration(
                  labelText: 'Contraseña',
                  helperText: 'La de la cuenta, no el PIN.',
                  suffixIcon: IconButton(
                    tooltip: _oculta
                        ? 'Ver la contraseña'
                        : 'Ocultar la contraseña',
                    icon: Icon(
                      _oculta
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 20,
                    ),
                    onPressed: () => setState(() => _oculta = !_oculta),
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 14),
                Text(
                  _error!,
                  style: TextStyle(fontSize: 13, height: 1.5, color: c.rojo),
                ),
              ],
              if (_entrando) ...[
                const SizedBox(height: 14),
                const LinearProgressIndicator(),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _entrando ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _entrando ? null : _entrar,
          child: const Text('Entrar'),
        ),
      ],
    );
  }
}
