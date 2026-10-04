import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../datos/catalogo.dart';
import '../datos/fuentes.dart';
import '../fuentes/conexion.dart';
import '../fuentes/conversiones.dart';
import '../pantallas/ficha.dart' show InsigniaEdad;
import '../tema/colores.dart';
import '../tema/tema.dart';
import '../utilidades.dart';
import '../widgets/comunes.dart';
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
              _Seccion(
                titulo: 'Publicación (tablón en GitHub)',
                dia: 14,
                children: [
                  _campo(
                    context,
                    'Repositorio del tablón',
                    '[TU-USUARIO]/videoteca-tablon',
                    monoespacio: true,
                  ),
                  _campo(
                    context,
                    'Llave de acceso de GitHub',
                    'Se guarda solo en este PC',
                  ),
                  _campo(
                    context,
                    'Contraseña común para los usuarios',
                    'Se elige el día 14',
                  ),
                ],
              ),
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
              _Seccion(
                titulo: 'Datos',
                children: [
                  for (final (texto, dia) in const [
                    ('Exportar catálogo a Excel', 17),
                    ('Copia de seguridad del catálogo', 17),
                  ])
                    OutlinedButton(
                      onPressed: () => avisoProximamente(context, texto, dia),
                      style: OutlinedButton.styleFrom(
                        alignment: Alignment.centerLeft,
                        minimumSize: const Size.fromHeight(46),
                      ),
                      child: Text(texto),
                    ),
                ],
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _campo(
    BuildContext context,
    String etiqueta,
    String valor, {
    bool monoespacio = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          etiqueta,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: context.colores.textoSuave,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          initialValue: valor,
          readOnly: true,
          style: TextStyle(
            fontSize: 14,
            fontFamily: monoespacio ? fuenteRutas : null,
            color: context.colores.textoSecundario,
          ),
        ),
      ],
    );
  }
}

class _Seccion extends StatelessWidget {
  const _Seccion({required this.titulo, required this.children, this.dia});

  final String titulo;
  final List<Widget> children;

  /// Día del planning en que esta sección empieza a funcionar.
  final int? dia;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    return Tarjeta(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  titulo,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (dia != null)
                Text(
                  'Día $dia',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: c.textoTenue,
                  ),
                ),
            ],
          ),
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
    return Row(
      children: [
        Expanded(
          child: Column(
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
        ),
        const SizedBox(width: 10),
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
      if (mounted) setState(() => _error = 'No se ha podido comprobar: $e');
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
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                hay
                    ? Pastilla('Funciona', color: c.verde, fondo: c.verdeFondo)
                    : Pastilla(
                        'Sin configurar',
                        color: c.naranja,
                        fondo: c.naranjaFondo,
                      ),
                const SizedBox(width: 6),
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
