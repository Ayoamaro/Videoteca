import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../errores.dart';
import '../arranque.dart';
import '../datos/catalogo.dart';
import '../datos/consulta.dart';
import '../datos/sesion.dart' show largoMinimoContrasena;
import '../datos/fuentes.dart';
import '../datos/publicacion.dart';
import '../disco/acciones_windows.dart';
import '../fuentes/conexion.dart';
import '../fuentes/conversiones.dart';
import '../pantallas/nuevas.dart' show cuandoTexto;
import '../tablon/github.dart';
import '../pantallas/ficha.dart' show InsigniaEdad;
import '../tema/colores.dart';
import '../tema/tema.dart';
import '../utilidades.dart';
import '../widgets/comunes.dart';
import '../widgets/exportar.dart';
import '../widgets/progreso_escaneo.dart';

/// Ajustes de la app. Las secciones marcadas con «Día N» se activan ese día
/// del planning.
class PantallaAjustes extends ConsumerWidget {
  const PantallaAjustes({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modo = ref.watch(modoTemaProvider);
    return PaginaBase(
      separacion: 22,
      children: [
        const CabeceraPagina(titulo: 'Ajustes'),
        CuadriculaAdaptable(
          anchoMinimo: 440,
          separacion: 18,
          children: [
            _Seccion(
              titulo: 'Apariencia',
              children: [
                SegmentedButton<ThemeMode>(
                  // Sin la marca, «Oscuro» cabe en el móvil.
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                      value: ThemeMode.dark,
                      label: Text('Oscuro'),
                      icon: Icon(Icons.dark_mode_outlined),
                    ),
                    ButtonSegment(
                      value: ThemeMode.light,
                      label: Text('Claro'),
                      icon: Icon(Icons.light_mode_outlined),
                    ),
                    ButtonSegment(
                      value: ThemeMode.system,
                      label: Text('Sistema'),
                      icon: Icon(Icons.brightness_auto_outlined),
                    ),
                  ],
                  selected: {modo},
                  onSelectionChanged: (v) =>
                      ref.read(modoTemaProvider.notifier).cambiar(v.first),
                ),
              ],
            ),
            if (esAdministrador) ...[
              const _SeccionColeccion(),
              const _SeccionTablon(),
              const _SeccionServicios(),
              _Seccion(
                titulo: 'Rotten Tomatoes → estrellas',
                children: [
                  Text(
                    'Al buscar datos en internet, la nota de Rotten Tomatoes '
                    '(de OMDb) se pasa a estrellas así:',
                    style: TextStyle(
                      fontSize: 13,
                      color: context.colores.textoSecundario,
                    ),
                  ),
                  for (final t in tramosEstrellas.reversed)
                    Row(
                      children: [
                        SizedBox(
                          width: 110,
                          child: Estrellas(t.estrellas, tam: 17),
                        ),
                        Text(
                          '${t.desde}–${t.hasta} %',
                          style: TextStyle(color: context.colores.textoSuave),
                        ),
                      ],
                    ),
                ],
              ),
              _Seccion(
                titulo: 'Clasificación por edades',
                children: [
                  Text(
                    'Qué frase se pone según la calificación de TMDB: primero la '
                    'de Estados Unidos y, si no la hay, la de España.',
                    style: TextStyle(
                      fontSize: 13,
                      color: context.colores.textoSecundario,
                    ),
                  ),
                  for (final (edad, origen, frase) in reglasEdadParaVer)
                    Row(
                      children: [
                        SizedBox(
                          width: 56,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: InsigniaEdad(edad),
                          ),
                        ),
                        Expanded(
                          child: Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: frase,
                                  style: TextStyle(
                                    color: context.colores.textoSuave,
                                  ),
                                ),
                                TextSpan(
                                  text: '\n$origen',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: context.colores.textoSecundario,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              const _SeccionDatos(),
            ] else
              const _SeccionCopia(),
            const _SeccionSesion(),
          ],
        ),
      ],
    );
  }
}

/// Exportar a Excel, copia de seguridad y restaurar.
class _SeccionDatos extends ConsumerWidget {
  const _SeccionDatos();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colores;
    Widget boton(String texto, IconData icono, VoidCallback? alPulsar) =>
        OutlinedButton.icon(
          onPressed: alPulsar,
          icon: Icon(icono, size: 18),
          label: Text(texto),
          style: OutlinedButton.styleFrom(
            alignment: Alignment.centerLeft,
            minimumSize: const Size.fromHeight(46),
          ),
        );
    return _Seccion(
      titulo: 'Datos',
      children: [
        boton(
          'Exportar catálogo a Excel',
          Icons.table_view_outlined,
          () => exportarExcel(context, ref),
        ),
        boton(
          'Copia de seguridad del catálogo',
          Icons.save_alt_rounded,
          () => hacerCopia(context, ref),
        ),
        boton(
          'Restaurar una copia',
          Icons.settings_backup_restore_rounded,
          ref.watch(sesionProvider) == null
              ? null
              : () => restaurarDesdeCopia(context, ref),
        ),
        Text(
          'La copia guarda las fichas, el registro de cambios (con las '
          'carátulas para deshacerlos), los ajustes y las miniaturas. Tus '
          'claves no van en la copia. Los datos de cada película también '
          'están dentro de su archivo, en el disco.',
          style: TextStyle(fontSize: 13, height: 1.5, color: c.textoSecundario),
        ),
      ],
    );
  }
}

/// Modo consulta: qué versión del catálogo hay descargada.
class _SeccionCopia extends ConsumerWidget {
  const _SeccionCopia();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colores;
    final e = ref.watch(consultaProvider);
    final copia = e.copia;
    final total = ref.watch(catalogoProvider).value?.length ?? 0;
    final (pastilla, color, fondo) = switch (e.fase) {
      FaseCopia.buscando => ('Buscando novedades…', c.azul, c.azulFondo),
      FaseCopia.descargando => ('Descargando…', c.azul, c.azulFondo),
      FaseCopia.contrasenaCambiada => (
        'Hay que volver a entrar',
        c.rojo,
        c.rojoFondo,
      ),
      FaseCopia.error => (
        e.sinInternet ? 'Sin internet' : 'Sin actualizar',
        c.rojo,
        c.rojoFondo,
      ),
      _ when copia.version == 0 => ('Sin descargar', c.naranja, c.naranjaFondo),
      _ => ('Al día', c.verde, c.verdeFondo),
    };
    final progreso = e.progreso;
    final ultimo = e.ultimo;
    final comprobada = e.comprobada;
    return _Seccion(
      titulo: 'Catálogo descargado',
      children: [
        Row(
          children: [
            Icon(Icons.cloud_download_rounded, color: c.doradoTexto),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                copia.repositorio,
                style: TextStyle(
                  fontFamily: fuenteRutas,
                  fontSize: 15,
                  color: c.texto,
                ),
              ),
            ),
            Pastilla(pastilla, color: color, fondo: fondo),
          ],
        ),
        Text(
          copia.version == 0
              ? 'Todavía no se ha descargado el catálogo.'
              : 'Versión ${copia.version} · publicada: '
                    '${cuandoTexto(copia.fecha).toLowerCase()} · '
                    '${formatoNumero(total)} películas. Está guardada en '
                    'este aparato: se puede consultar sin internet.',
          style: TextStyle(fontSize: 14, height: 1.5, color: c.textoSuave),
        ),
        if (e.fase == FaseCopia.descargando && progreso != null) ...[
          LinearProgressIndicator(
            value: progreso.total == 0
                ? null
                : progreso.hechos / progreso.total,
          ),
          Text(
            'Descargando ${progreso.fase}: ${progreso.hechos} de '
            '${progreso.total} paquetes',
            style: TextStyle(fontSize: 13, color: c.textoSecundario),
          ),
        ] else if (e.fase == FaseCopia.error)
          Text(
            e.error ?? 'Error desconocido.',
            style: TextStyle(fontSize: 13, color: c.rojo),
          )
        else if (e.fase == FaseCopia.contrasenaCambiada)
          Text(
            'La contraseña común ha cambiado. Para recibir las novedades, '
            'cierra la sesión y entra con la nueva.',
            style: TextStyle(fontSize: 13, color: c.rojo),
          )
        else if (ultimo != null)
          Text(
            'Última actualización: ${textoNovedades(ultimo).toLowerCase()}.',
            style: TextStyle(fontSize: 13, color: c.textoSecundario),
          )
        else if (comprobada != null)
          Text(
            'Comprobado ${cuandoTexto(comprobada).toLowerCase()}: no hay '
            'novedades.',
            style: TextStyle(fontSize: 13, color: c.textoSecundario),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: e.trabajando || e.fase == FaseCopia.contrasenaCambiada
                ? null
                : () => ref.read(consultaProvider.notifier).comprobar(),
            icon: const Icon(Icons.sync_rounded, size: 18),
            label: const Text('Buscar novedades'),
          ),
        ),
      ],
    );
  }
}

/// Con qué modo se ha entrado, cerrar la sesión y (administrador) cambiar
/// su contraseña.
class _SeccionSesion extends ConsumerWidget {
  const _SeccionSesion();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colores;
    final control = ref.watch(sesionProvider);
    return _Seccion(
      titulo: 'Sesión',
      children: [
        Row(
          children: [
            Icon(
              esAdministrador
                  ? Icons.admin_panel_settings_outlined
                  : Icons.search_rounded,
              color: c.doradoTexto,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                esAdministrador
                    ? 'Has entrado como administrador de este PC.'
                    : 'Has entrado en modo consulta con la contraseña común.',
                style: TextStyle(fontSize: 14, color: c.texto),
              ),
            ),
          ],
        ),
        Text(
          esAdministrador
              ? 'La sesión se queda abierta aunque cierres la app. Al '
                    'cerrarla, se vuelve a la pantalla de entrada.'
              : 'La sesión se queda abierta aunque cierres la app. Al '
                    'cerrarla, se vuelve a la pantalla de entrada (el '
                    'catálogo descargado se conserva).',
          style: TextStyle(fontSize: 13, height: 1.5, color: c.textoSuave),
        ),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            if (esAdministrador)
              OutlinedButton.icon(
                onPressed: control == null
                    ? null
                    : () => showDialog<void>(
                        context: context,
                        builder: (_) => _DialogoContrasenaAdmin(control),
                      ),
                icon: const Icon(Icons.key_rounded, size: 18),
                label: const Text('Cambiar contraseña'),
              ),
            OutlinedButton.icon(
              onPressed: control?.cerrar,
              icon: const Icon(Icons.logout_rounded, size: 18),
              label: const Text('Cerrar sesión'),
            ),
          ],
        ),
      ],
    );
  }
}

class _DialogoContrasenaAdmin extends StatefulWidget {
  const _DialogoContrasenaAdmin(this.control);

  final ControlSesion control;

  @override
  State<_DialogoContrasenaAdmin> createState() =>
      _DialogoContrasenaAdminState();
}

class _DialogoContrasenaAdminState extends State<_DialogoContrasenaAdmin> {
  final _actual = TextEditingController();
  final _nueva = TextEditingController();
  final _repetida = TextEditingController();
  String? _error;
  var _trabajando = false;

  @override
  void dispose() {
    _actual.dispose();
    _nueva.dispose();
    _repetida.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final actual = widget.control.sesion.contrasenaAdmin;
    if (_nueva.text.length < largoMinimoContrasena) {
      setState(
        () => _error =
            'La contraseña nueva tiene que tener al menos '
            '$largoMinimoContrasena caracteres.',
      );
      return;
    }
    if (_nueva.text != _repetida.text) {
      setState(() => _error = 'Las dos contraseñas nuevas no coinciden.');
      return;
    }
    setState(() {
      _error = null;
      _trabajando = true;
    });
    if (actual != null && !await actual.comprobar(_actual.text)) {
      if (mounted) {
        setState(() {
          _error = 'La contraseña actual no es correcta.';
          _trabajando = false;
        });
      }
      return;
    }
    await widget.control.cambiarContrasenaAdmin(_nueva.text);
    if (!mounted) return;
    final avisos = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    avisos.showSnackBar(
      const SnackBar(content: Text('Contraseña de administrador cambiada.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget campo(TextEditingController controlador, String etiqueta) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controlador,
        obscureText: true,
        enabled: !_trabajando,
        decoration: InputDecoration(labelText: etiqueta),
        onSubmitted: (_) => _guardar(),
      ),
    );
    return AlertDialog(
      title: const Text('Cambiar contraseña de administrador'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            campo(_actual, 'Contraseña actual'),
            campo(_nueva, 'Contraseña nueva'),
            campo(_repetida, 'Repite la nueva'),
            if (_error != null)
              Text(_error!, style: TextStyle(color: context.colores.rojo)),
            if (_trabajando) const LinearProgressIndicator(),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _trabajando ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _trabajando ? null : _guardar,
          child: const Text('Cambiar'),
        ),
      ],
    );
  }
}

class _Seccion extends StatelessWidget {
  const _Seccion({required this.titulo, required this.children});

  final String titulo;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Tarjeta(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(titulo, style: Theme.of(context).textTheme.titleMedium),
          for (final hijo in children) ...[const SizedBox(height: 14), hijo],
        ],
      ),
    );
  }
}

/// Carpeta de la colección, qué se ha detectado y botones para escanear.
class _SeccionColeccion extends ConsumerWidget {
  const _SeccionColeccion();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colores;
    final raiz = ref.watch(carpetaRaizProvider) ?? '—';
    final peliculas = ref.watch(catalogoProvider).value ?? const [];
    final generos = ref.watch(generosProvider);
    final grupos = {
      for (final p in peliculas)
        if (p.grupo.isNotEmpty) p.grupo,
    };
    final escaneo = ref.watch(escaneoProvider);
    final enMarcha = escaneo?.enMarcha ?? false;
    final ultimo = ref.watch(ultimoEscaneoProvider);
    final notificador = ref.read(escaneoProvider.notifier);

    return _Seccion(
      titulo: 'Colección',
      children: [
        Row(
          children: [
            Icon(Icons.folder_rounded, color: c.doradoTexto),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                raiz,
                style: TextStyle(
                  fontFamily: fuenteRutas,
                  fontSize: 15,
                  color: c.texto,
                ),
              ),
            ),
            TextButton(
              onPressed: enMarcha ? null : () => context.go('/bienvenida'),
              child: const Text('Cambiar…'),
            ),
          ],
        ),
        Text(
          '${formatoNumero(peliculas.length)} películas · '
          '${grupos.length} carpetas · ${generos.length} géneros'
          '${ultimo == null || escaneo != null ? '' : '\nÚltimo escaneo: ${fechaLarga(ultimo)}'}',
          style: TextStyle(fontSize: 14, height: 1.6, color: c.textoSuave),
        ),
        if (escaneo != null)
          ProgresoEscaneoVista(escaneo, alCancelar: notificador.cancelar),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            FilledButton.icon(
              onPressed: enMarcha ? null : () => notificador.iniciar(),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Buscar cambios'),
            ),
            OutlinedButton(
              onPressed: enMarcha
                  ? null
                  : () => notificador.iniciar(completo: true),
              child: const Text('Volver a leer todo'),
            ),
            OutlinedButton.icon(
              onPressed: () => context.go('/lectura'),
              icon: const Icon(Icons.manage_search_rounded, size: 18),
              label: const Text('Leer un archivo .mp4'),
            ),
            OutlinedButton.icon(
              onPressed: () => context.push('/registro'),
              icon: const Icon(Icons.history_rounded, size: 18),
              label: const Text('Registro de cambios'),
            ),
          ],
        ),
      ],
    );
  }
}

/// Claves de TMDB y OMDb (se comprueban antes de guardarlas) y Wikidata,
/// que no necesita clave.
class _SeccionServicios extends ConsumerWidget {
  const _SeccionServicios();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colores;
    final claves = ref.watch(clavesProvider);
    return _Seccion(
      titulo: 'Servicios de datos',
      children: [
        Text(
          'Las claves son gratuitas y se guardan solo en este PC.',
          style: TextStyle(fontSize: 13, color: c.textoSecundario),
        ),
        _CampoClave(
          servicio: Servicio.tmdb,
          uso:
              'Identifica la película. País, guion, fotografía, saga, edad '
              'e IMDb.',
          clave: claves[Servicio.tmdb]!,
        ),
        _CampoClave(
          servicio: Servicio.omdb,
          uso: 'Nota de Rotten Tomatoes (1.000 consultas al día).',
          clave: claves[Servicio.omdb]!,
        ),
        _FilaServicio(
          nombre: 'Wikidata',
          uso: 'Enlace a FilmAffinity. No necesita clave.',
          estado: Pastilla('Listo', color: c.verde, fondo: c.verdeFondo),
        ),
        _FilaServicio(
          nombre: 'FilmAffinity',
          uso: 'Lectura semiautomática con navegador integrado.',
          estado: Text(
            'Día 11',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: c.textoTenue,
            ),
          ),
        ),
      ],
    );
  }
}

class _FilaServicio extends StatelessWidget {
  const _FilaServicio({
    required this.nombre,
    required this.uso,
    required this.estado,
  });

  final String nombre;
  final String uso;
  final Widget estado;

  @override
  Widget build(BuildContext context) {
    // Si no cabe en una línea (letra grande), el estado baja debajo.
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 10,
      runSpacing: 8,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(nombre, style: const TextStyle(fontWeight: FontWeight.w700)),
            Text(
              uso,
              style: TextStyle(
                fontSize: 12,
                color: context.colores.textoSecundario,
              ),
            ),
          ],
        ),
        estado,
      ],
    );
  }
}

/// Una clave: no se enseña; «Cambiar» abre el campo para pegar otra, que se
/// comprueba con el servicio antes de guardarla.
class _CampoClave extends ConsumerStatefulWidget {
  const _CampoClave({
    required this.servicio,
    required this.uso,
    required this.clave,
  });

  final Servicio servicio;
  final String uso;
  final String clave;

  @override
  ConsumerState<_CampoClave> createState() => _EstadoCampoClave();
}

class _EstadoCampoClave extends ConsumerState<_CampoClave> {
  final _texto = TextEditingController();
  var _editando = false;
  var _probando = false;
  String? _error;

  @override
  void dispose() {
    _texto.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    setState(() {
      _probando = true;
      _error = null;
    });
    try {
      await ref
          .read(clavesProvider.notifier)
          .probarYGuardar(widget.servicio, _texto.text);
      if (!mounted) return;
      setState(() => _editando = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              _texto.text.trim().isEmpty
                  ? 'Clave de ${widget.servicio.nombre} borrada.'
                  : 'La clave de ${widget.servicio.nombre} funciona y se ha '
                        'guardado.',
            ),
          ),
        );
    } on FuenteException catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    } catch (e) {
      // Cualquier otro fallo también se enseña (nunca en silencio).
      if (mounted) {
        setState(
          () => _error = 'No se ha podido comprobar: ${explicarError(e)}',
        );
      }
    } finally {
      if (mounted) setState(() => _probando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final hay = widget.clave.isNotEmpty;
    final fila = _FilaServicio(
      nombre: widget.servicio.nombre,
      uso: widget.uso,
      estado: _editando
          ? const SizedBox.shrink()
          : Wrap(
              spacing: 6,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                hay
                    ? Pastilla('Funciona', color: c.verde, fondo: c.verdeFondo)
                    : Pastilla(
                        'Sin configurar',
                        color: c.naranja,
                        fondo: c.naranjaFondo,
                      ),
                TextButton(
                  onPressed: () => setState(() {
                    _editando = true;
                    _error = null;
                    _texto.text = '';
                  }),
                  child: Text(hay ? 'Cambiar' : 'Poner clave'),
                ),
              ],
            ),
    );
    if (!_editando) return fila;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        fila,
        const SizedBox(height: 8),
        TextField(
          controller: _texto,
          autofocus: true,
          enabled: !_probando,
          style: const TextStyle(fontFamily: fuenteRutas, fontSize: 13),
          decoration: InputDecoration(
            hintText: 'Pega aquí la clave de ${widget.servicio.nombre}',
            errorText: _error,
            errorMaxLines: 3,
          ),
          onSubmitted: (_) => _guardar(),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: _probando
                  ? null
                  : () => setState(() => _editando = false),
              child: const Text('Cancelar'),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _probando ? null : _guardar,
              child: Text(_probando ? 'Comprobando…' : 'Comprobar y guardar'),
            ),
          ],
        ),
      ],
    );
  }
}

/// Publicación en el tablón de GitHub: configurarla y ver cómo va.
class _SeccionTablon extends ConsumerStatefulWidget {
  const _SeccionTablon();

  @override
  ConsumerState<_SeccionTablon> createState() => _EstadoSeccionTablon();
}

/// Qué se está cambiando en la sección del tablón.
enum _Edicion { nada, todo, contrasena, llave }

class _EstadoSeccionTablon extends ConsumerState<_SeccionTablon> {
  final _repositorio = TextEditingController();
  final _llave = TextEditingController();
  final _contrasena = TextEditingController();
  final _repetida = TextEditingController();
  var _edicion = _Edicion.nada;
  var _probando = false;
  String? _error;

  /// Aviso tras configurar (p. ej. repositorio privado).
  String? _aviso;

  @override
  void dispose() {
    for (final c in [_repositorio, _llave, _contrasena, _repetida]) {
      c.dispose();
    }
    super.dispose();
  }

  void _editar(_Edicion que) {
    final estado = ref.read(tablonProvider);
    setState(() {
      _edicion = que;
      _error = null;
      _aviso = null;
      _repositorio.text = estado.repositorio;
      _llave.clear();
      _contrasena.clear();
      _repetida.clear();
    });
  }

  Future<void> _guardar() async {
    final estado = ref.read(tablonProvider);
    final pideContrasena =
        _edicion == _Edicion.contrasena ||
        (_edicion == _Edicion.todo && estado.llave == null);
    final pideLlave = _edicion != _Edicion.contrasena;
    String? error;
    if (pideLlave && _llave.text.trim().isEmpty) {
      error = 'Pega la llave de acceso de GitHub.';
    } else if (pideContrasena && _contrasena.text.length < 8) {
      error = 'La contraseña común tiene que tener al menos 8 letras.';
    } else if (pideContrasena && _contrasena.text != _repetida.text) {
      error = 'Las dos contraseñas no coinciden.';
    }
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    setState(() {
      _probando = true;
      _error = null;
    });
    try {
      final info = await ref
          .read(tablonProvider.notifier)
          .configurar(
            repositorio: _edicion == _Edicion.todo
                ? _repositorio.text
                : estado.repositorio,
            llaveGithub: pideLlave ? _llave.text : estado.llaveGithub,
            contrasena: pideContrasena ? _contrasena.text : null,
          );
      if (!mounted) return;
      setState(() {
        _edicion = _Edicion.nada;
        _aviso = info.privado
            ? 'El repositorio «${info.nombre}» es privado: los móviles no '
                  'podrán descargar el catálogo. Hazlo público en GitHub '
                  '(Settings → Danger Zone → Change visibility); todo lo que '
                  'hay dentro va cifrado.'
            : null;
      });
    } on TablonException catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = 'No se ha podido comprobar: ${explicarError(e)}',
        );
      }
    } finally {
      if (mounted) setState(() => _probando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final estado = ref.watch(tablonProvider);
    final notificador = ref.read(tablonProvider.notifier);
    final explicacion = Text(
      'El catálogo y las carátulas se suben cifrados a un repositorio de '
      'GitHub. Los móviles los descargan y entran con la contraseña común.',
      style: TextStyle(fontSize: 13, color: c.textoSecundario),
    );

    if (!estado.configurado && _edicion == _Edicion.nada) {
      return _Seccion(
        titulo: 'Publicación (tablón en GitHub)',
        children: [
          explicacion,
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 10,
            runSpacing: 10,
            children: [
              Pastilla(
                'Sin configurar',
                color: c.naranja,
                fondo: c.naranjaFondo,
              ),
              FilledButton(
                onPressed: () => _editar(_Edicion.todo),
                child: const Text('Configurar'),
              ),
            ],
          ),
        ],
      );
    }
    if (_edicion != _Edicion.nada) {
      return _Seccion(
        titulo: 'Publicación (tablón en GitHub)',
        children: _formulario(context, estado),
      );
    }

    final (pastilla, color, fondo) = switch (estado.fase) {
      FasePublicacion.publicando => ('Publicando…', c.azul, c.azulFondo),
      FasePublicacion.esperando => (
        'Cambios por publicar',
        c.naranja,
        c.naranjaFondo,
      ),
      FasePublicacion.error => ('No publicado', c.rojo, c.rojoFondo),
      _ when estado.version == 0 => ('Sin publicar', c.naranja, c.naranjaFondo),
      _ => ('Al día', c.verde, c.verdeFondo),
    };
    final progreso = estado.progreso;
    final ultimo = estado.ultimo;
    return _Seccion(
      titulo: 'Publicación (tablón en GitHub)',
      children: [
        Row(
          children: [
            Icon(Icons.cloud_upload_rounded, color: c.doradoTexto),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                estado.repositorio,
                style: TextStyle(
                  fontFamily: fuenteRutas,
                  fontSize: 15,
                  color: c.texto,
                ),
              ),
            ),
            Pastilla(pastilla, color: color, fondo: fondo),
          ],
        ),
        Text(
          estado.version == 0
              ? 'Todavía no se ha publicado ninguna versión.'
              : 'Versión ${estado.version} · publicada: '
                    '${cuandoTexto(estado.fecha).toLowerCase()}'
                    '${ultimo == null ? '' : ' · ${formatoNumero(ultimo.peliculas)} películas'}',
          style: TextStyle(fontSize: 14, height: 1.5, color: c.textoSuave),
        ),
        if (estado.fase == FasePublicacion.publicando) ...[
          LinearProgressIndicator(
            value: progreso == null || progreso.total == 0
                ? null
                : progreso.hechos / progreso.total,
          ),
          Text(
            progreso == null
                ? 'Empezando…'
                : progreso.total == 0
                ? '${progreso.fase}…'
                : '${progreso.fase}: ${formatoNumero(progreso.hechos)} de '
                      '${formatoNumero(progreso.total)}',
            style: TextStyle(fontSize: 13, color: c.textoSecundario),
          ),
        ] else if (estado.fase == FasePublicacion.error)
          Text(
            estado.error ?? 'Error desconocido.',
            style: TextStyle(fontSize: 13, color: c.rojo),
          )
        else if (ultimo != null)
          Text(
            ultimo.sinCambios
                ? 'Comprobado: no había nada nuevo que publicar.'
                : 'Última publicación: ${ultimo.subidos} '
                      '${ultimo.subidos == 1 ? 'archivo subido' : 'archivos subidos'} '
                      '(${_tamano(ultimo.bytes)}).',
            style: TextStyle(fontSize: 13, color: c.textoSecundario),
          ),
        if (_aviso != null)
          Text(_aviso!, style: TextStyle(fontSize: 13, color: c.naranja)),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: estado.automatico,
          onChanged: notificador.cambiarAutomatico,
          title: const Text('Publicar solo al cambiar el catálogo'),
          subtitle: Text(
            'Medio minuto después de guardar una ficha o de llegar una película.',
            style: TextStyle(fontSize: 12, color: c.textoSecundario),
          ),
        ),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            FilledButton.icon(
              onPressed: estado.fase == FasePublicacion.publicando
                  ? null
                  : notificador.publicarAhora,
              icon: const Icon(Icons.publish_rounded, size: 18),
              label: const Text('Publicar ahora'),
            ),
            OutlinedButton(
              onPressed: estado.fase == FasePublicacion.publicando
                  ? null
                  : () => _editar(_Edicion.contrasena),
              child: const Text('Cambiar contraseña común'),
            ),
            OutlinedButton(
              onPressed: estado.fase == FasePublicacion.publicando
                  ? null
                  : () => _editar(_Edicion.llave),
              child: const Text('Cambiar llave de GitHub'),
            ),
            TextButton.icon(
              onPressed: () =>
                  abrirConWindows('https://github.com/${estado.repositorio}'),
              icon: const Icon(Icons.open_in_new_rounded, size: 16),
              label: const Text('Ver en GitHub'),
            ),
          ],
        ),
      ],
    );
  }

  List<Widget> _formulario(BuildContext context, EstadoTablon estado) {
    final c = context.colores;
    final todo = _edicion == _Edicion.todo;
    final pideContrasena =
        _edicion == _Edicion.contrasena || (todo && estado.llave == null);
    final pideLlave = _edicion != _Edicion.contrasena;
    Widget etiqueta(String texto) => Text(
      texto,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: c.textoSuave,
      ),
    );
    Widget ayuda(String texto) =>
        Text(texto, style: TextStyle(fontSize: 12, color: c.textoSecundario));

    return [
      if (_edicion == _Edicion.contrasena)
        Text(
          'Con una contraseña nueva se vuelve a cifrar y subir todo, y en los '
          'móviles habrá que entrar con la nueva.',
          style: TextStyle(fontSize: 13, color: c.naranja),
        )
      else
        Text(
          'El catálogo y las carátulas se suben cifrados a un repositorio de '
          'GitHub. Los móviles los descargan y entran con la contraseña común.',
          style: TextStyle(fontSize: 13, color: c.textoSecundario),
        ),
      if (todo) ...[
        etiqueta('Repositorio del tablón'),
        TextField(
          controller: _repositorio,
          enabled: !_probando,
          style: const TextStyle(fontFamily: fuenteRutas, fontSize: 14),
          decoration: const InputDecoration(
            hintText: 'usuario/Videoteca_Tablon',
          ),
        ),
        ayuda(
          'Un repositorio aparte del código, público (lo de dentro va '
          'cifrado). Se escribe «usuario/nombre».',
        ),
      ],
      if (pideLlave) ...[
        Row(
          children: [
            Expanded(child: etiqueta('Llave de acceso de GitHub')),
            TextButton.icon(
              onPressed: () => abrirConWindows(_direccionNuevaLlave),
              icon: const Icon(Icons.open_in_new_rounded, size: 16),
              label: const Text('Crear una llave'),
            ),
          ],
        ),
        TextField(
          controller: _llave,
          enabled: !_probando,
          obscureText: true,
          style: const TextStyle(fontFamily: fuenteRutas, fontSize: 14),
          decoration: const InputDecoration(hintText: 'github_pat_…'),
        ),
        ayuda(
          'Una llave «fine-grained» solo para el repositorio del tablón, con '
          'permiso «Contents: Read and write». Se guarda solo en este PC.',
        ),
      ],
      if (pideContrasena) ...[
        etiqueta(
          _edicion == _Edicion.contrasena
              ? 'Contraseña común nueva'
              : 'Contraseña común para los usuarios',
        ),
        TextField(
          controller: _contrasena,
          enabled: !_probando,
          obscureText: true,
          decoration: const InputDecoration(hintText: 'Al menos 8 letras'),
        ),
        TextField(
          controller: _repetida,
          enabled: !_probando,
          obscureText: true,
          decoration: const InputDecoration(hintText: 'Repítela'),
          onSubmitted: (_) => _guardar(),
        ),
        ayuda(
          'Es la que pondrán en los móviles. No se guarda en ningún sitio: '
          'apúntala.',
        ),
      ],
      if (_error != null)
        Text(_error!, style: TextStyle(fontSize: 13, color: c.rojo)),
      Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: _probando
                ? null
                : () => setState(() => _edicion = _Edicion.nada),
            child: const Text('Cancelar'),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: _probando ? null : _guardar,
            child: Text(_probando ? 'Comprobando…' : 'Comprobar y publicar'),
          ),
        ],
      ),
    ];
  }
}

/// Página de GitHub para crear una llave «fine-grained», ya rellena con el
/// nombre y el permiso que hace falta (el repositorio se elige allí).
const _direccionNuevaLlave =
    'https://github.com/settings/personal-access-tokens/new'
    '?name=Videoteca%20-%20tabl%C3%B3n'
    '&description=Publicar%20el%20cat%C3%A1logo%20desde%20la%20app%20Videoteca'
    '&expires_in=none'
    '&contents=write';

/// 215.000 bytes → «210 KB».
String _tamano(int bytes) {
  if (bytes < 1024 * 1024) return '${(bytes / 1024).ceil()} KB';
  return '${(bytes / 1024 / 1024).toStringAsFixed(1).replaceAll('.', ',')} MB';
}
