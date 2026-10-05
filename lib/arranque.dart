import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'datos/base_datos.dart';
import 'datos/carpetas_app.dart';
import 'datos/catalogo.dart';
import 'datos/sesion.dart';
import 'main.dart';
import 'pantallas/acceso.dart';
import 'tema/tema.dart';
import 'utilidades.dart';

// El arranque de la app: si no hay sesión abierta, la pantalla de acceso; si
// la hay, abre la base de datos de ese modo (la del administrador o la copia
// del modo consulta) y arranca la app con ella.
//
// Al cerrar la sesión se cierra todo y se vuelve a la pantalla de acceso.

/// Para cerrar la sesión o cambiar la contraseña de administrador desde
/// Ajustes. `null` en las pruebas.
final sesionProvider = Provider<ControlSesion?>((ref) => null);

class ControlSesion {
  const ControlSesion(this.sesion, this._guardar, this.cerrar);

  final Sesion sesion;
  final void Function() _guardar;

  /// Vuelve a la pantalla de acceso.
  final Future<void> Function() cerrar;

  Future<void> cambiarContrasenaAdmin(String nueva) async {
    sesion.contrasenaAdmin = await ContrasenaAdmin.crear(nueva);
    _guardar();
  }
}

/// La app con su sesión abierta.
typedef _Abierta = ({
  ModoApp modo,
  BaseDatos bd,
  CarpetasApp carpetas,
  Map<String, String> ajustes,
});

class Arranque extends StatefulWidget {
  const Arranque({super.key, required this.carpeta});

  /// Carpeta de datos de la app (ver `carpetaDatosApp`).
  final String carpeta;

  @override
  State<Arranque> createState() => _ArranqueState();
}

class _ArranqueState extends State<Arranque> {
  late final Sesion _sesion = Sesion.leer(widget.carpeta);
  _Abierta? _abierta;
  var _abriendo = false;

  @override
  void initState() {
    super.initState();
    final modo = _sesion.modo;
    // La sesión se queda abierta entre una vez y otra.
    final valida = switch (modo) {
      ModoApp.consulta => true,
      ModoApp.administrador =>
        puedeAdministrar && _sesion.contrasenaAdmin != null,
      null => false,
    };
    if (valida) {
      _abriendo = true;
      _abrir(modo!);
    }
  }

  void _guardar() => _sesion.guardar(widget.carpeta);

  Future<void> _entrar(
    ModoApp modo, {
    Map<String, String> ajustes = const {},
  }) async {
    _sesion.modo = modo;
    _guardar();
    await _abrir(modo, ajustes);
  }

  Future<void> _abrir(
    ModoApp modo, [
    Map<String, String> ajustesNuevos = const {},
  ]) async {
    if (!_abriendo) setState(() => _abriendo = true);
    final carpetas = modo == ModoApp.administrador
        ? CarpetasApp.preparar(widget.carpeta)
        : CarpetasApp.consulta(widget.carpeta);
    final bd = BaseDatos.abrir(carpetas.baseDatos);
    for (final MapEntry(:key, :value) in ajustesNuevos.entries) {
      await bd.guardarAjuste(key, value);
    }
    final ajustes = await bd.todosLosAjustes();
    modoSesion = modo;
    setState(() {
      _abriendo = false;
      _abierta = (modo: modo, bd: bd, carpetas: carpetas, ajustes: ajustes);
    });
  }

  Future<void> _cerrar() async {
    final abierta = _abierta;
    _sesion.modo = null;
    _guardar();
    setState(() => _abierta = null);
    modoSesion = null;
    // La base de datos se cierra cuando la app ya no está en pantalla.
    if (abierta != null) {
      await WidgetsBinding.instance.endOfFrame;
      await abierta.bd.close();
    }
  }

  @override
  Widget build(BuildContext context) {
    final abierta = _abierta;
    if (abierta != null) {
      return ProviderScope(
        key: ObjectKey(abierta),
        overrides: [
          baseDatosProvider.overrideWithValue(abierta.bd),
          carpetasAppProvider.overrideWithValue(abierta.carpetas),
          ajustesInicialesProvider.overrideWithValue(abierta.ajustes),
          sesionProvider.overrideWithValue(
            ControlSesion(_sesion, _guardar, _cerrar),
          ),
        ],
        child: const VideotecaApp(),
      );
    }
    return MaterialApp(
      title: 'Videoteca',
      debugShowCheckedModeBanner: false,
      theme: construirTema(Brightness.dark),
      locale: const Locale('es', 'ES'),
      supportedLocales: const [Locale('es', 'ES')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      scrollBehavior: const DesplazamientoApp(),
      builder: (context, hijo) => BarrasSistema(child: hijo!),
      home: _abriendo
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : PantallaAcceso(
              sesion: _sesion,
              carpeta: widget.carpeta,
              alEntrar: _entrar,
            ),
    );
  }
}
