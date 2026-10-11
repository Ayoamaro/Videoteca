import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../datos/catalogo.dart';
import '../datos/copia_pelicula.dart';
import '../datos/red_casa.dart';
import '../disco/copiador.dart';
import '../modelos/pelicula.dart';
import '../tema/colores.dart';
import '../tema/tema.dart';
import '../utilidades.dart';
import 'comunes.dart';

// Copiar película: la ventana «¿Dónde quieres guardarla?», la barra de
// progreso de la ficha y el aviso del menú.

/// Dónde se ha elegido guardar la película.
class _Destino {
  const _Destino(this.carpeta, this.volumen, this.existente);

  final String carpeta;
  final Volumen volumen;

  /// Lo que ocupa la película que ya está ahí con el mismo nombre.
  final int? existente;
}

/// Pregunta dónde guardar [p] (que desde este aparato está en [origen]) y
/// empieza a copiarla en segundo plano.
Future<void> copiarPelicula(
  BuildContext context,
  WidgetRef ref,
  Pelicula p,
  String origen,
) async {
  final servicio = ref.read(servicioCopiaProvider);
  final tamano = p.tamanoBytes > 0
      ? p.tamanoBytes
      : await servicio.existente(origen) ?? 0;
  if (!context.mounted) return;
  final destino = await showDialog<_Destino>(
    context: context,
    builder: (_) => _DialogoDestino(p, tamano),
  );
  if (destino == null || !context.mounted) return;
  final existente = destino.existente;
  if (existente != null) {
    final si = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ya está copiada ahí'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ya hay un archivo «${p.archivo}» '
                '(${textoBytes(existente)}) en la carpeta',
              ),
              const SizedBox(height: 6),
              // La ruta en su línea, para que no se corte por la mitad.
              Text(
                destino.carpeta,
                style: const TextStyle(fontFamily: fuenteRutas),
              ),
              const SizedBox(height: 12),
              Text(
                '${existente == tamano ? 'Ocupa lo mismo que esta: seguramente es la misma película. ' : ''}'
                '¿Quieres reemplazarlo por esta copia?',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reemplazar'),
          ),
        ],
      ),
    );
    if (si != true || !context.mounted) return;
  }
  ref
      .read(copiaPeliculaProvider.notifier)
      .empezar(
        p,
        origen: origen,
        carpeta: destino.carpeta,
        reemplazar: existente != null,
        borrarAntes:
            existente != null &&
            hayQueBorrarAntes(destino.volumen, tamano, existente: existente),
      );
}

/// Ventana «¿Dónde quieres guardarla?» con las unidades de este PC.
class _DialogoDestino extends ConsumerStatefulWidget {
  const _DialogoDestino(this.p, this.tamano);

  final Pelicula p;
  final int tamano;

  @override
  ConsumerState<_DialogoDestino> createState() => _EstadoDialogoDestino();
}

class _EstadoDialogoDestino extends ConsumerState<_DialogoDestino> {
  List<Unidad>? _unidades;
  var _cargando = false;
  Timer? _temporizador;

  /// Por qué no vale la carpeta elegida con «Elegir otra carpeta…».
  String? _aviso;

  /// Mirando la carpeta elegida.
  var _mirando = false;

  @override
  void initState() {
    super.initState();
    _cargar();
    // Si se conecta un pendrive con la ventana abierta, aparece solo.
    _temporizador = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _cargar(),
    );
  }

  @override
  void dispose() {
    _temporizador?.cancel();
    super.dispose();
  }

  Future<void> _cargar() async {
    if (_cargando) return;
    _cargando = true;
    List<Unidad> unidades;
    try {
      unidades = await ref
          .read(servicioCopiaProvider)
          .unidades(archivo: widget.p.archivo)
          .timeout(const Duration(seconds: 20));
    } on Object {
      unidades = _unidades ?? const [];
    }
    _cargando = false;
    if (mounted) setState(() => _unidades = unidades);
  }

  /// Donde no se puede guardar nada: en el PC del administrador, el disco
  /// de la colección; en un PC de la red, la carpeta de las películas.
  String? get _protegida {
    final ruta = esAdministrador
        ? ref.read(carpetaRaizProvider)
        : ref.read(redCasaProvider).ruta;
    return ruta == null || ruta.isEmpty ? null : ruta;
  }

  void _elegir(String carpeta, Volumen volumen, int? existente) =>
      Navigator.pop(context, _Destino(carpeta, volumen, existente));

  Future<void> _elegirOtra() async {
    final servicio = ref.read(servicioCopiaProvider);
    final carpeta = servicio.elegirCarpeta();
    if (carpeta == null || !mounted) return;
    final protegida = _protegida;
    if (protegida != null && mismoDisco(carpeta, protegida)) {
      setState(
        () => _aviso = esAdministrador
            ? 'Esa carpeta está en ${nombreDisco(protegida)}, el de la '
                  'colección: en él no se escribe nada. Elige otro disco.'
            : 'Esa carpeta está en el PC de las películas: elige una de este '
                  'PC.',
      );
      return;
    }
    setState(() {
      _mirando = true;
      _aviso = null;
    });
    final volumen = await servicio.volumen(carpeta);
    final base = carpeta.endsWith(r'\') ? carpeta : '$carpeta\\';
    final existente = await servicio.existente('$base${widget.p.archivo}');
    if (!mounted) return;
    setState(() => _mirando = false);
    if (volumen == null) {
      setState(
        () => _aviso =
            'No se puede usar esa carpeta: Windows no dice cuánto espacio le '
            'queda.',
      );
      return;
    }
    final impedimento = impedimentoCopia(
      volumen,
      widget.tamano,
      existente: existente ?? 0,
    );
    if (impedimento != null) {
      setState(
        () => _aviso = _explicacion(
          impedimento,
          volumen,
          widget.tamano,
          existente: existente,
        ),
      );
      return;
    }
    _elegir(carpeta, volumen, existente);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final tema = Theme.of(context).textTheme;
    final protegida = _protegida;
    final todas = _unidades;
    final unidades = [
      for (final u in todas ?? const <Unidad>[])
        if (protegida == null || !mismoDisco(u.carpeta, protegida)) u,
    ];
    final escondida = esAdministrador && protegida != null
        ? todas?.where((u) => mismoDisco(u.carpeta, protegida)).firstOrNull
        : null;
    final notas = TextStyle(
      fontSize: 13,
      height: 1.45,
      color: c.textoSecundario,
    );

    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 760),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 24, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Etiqueta('Copiar película', color: c.doradoTexto),
                        const SizedBox(height: 4),
                        Text(
                          '¿Dónde quieres guardarla?',
                          style: tema.headlineSmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${widget.p.titulo} · ${textoBytes(widget.tamano)}',
                          style: TextStyle(
                            fontSize: 14,
                            color: c.textoSecundario,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cerrar',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(right: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (todas == null)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const _Girando(),
                              const SizedBox(width: 12),
                              Text(
                                'Buscando discos y pendrives…',
                                style: notas,
                              ),
                            ],
                          ),
                        )
                      else if (unidades.isEmpty)
                        Text(
                          'No hay ningún disco ni pendrive donde guardarla. '
                          'Conecta un pendrive (aparece aquí solo) o elige '
                          'otra carpeta.',
                          style: notas,
                        )
                      else
                        for (final u in unidades) ...[
                          _TarjetaUnidad(
                            u,
                            tamano: widget.tamano,
                            alPulsar: () => _elegir(u.carpeta, u, u.existente),
                          ),
                          const SizedBox(height: 10),
                        ],
                      if (todas != null && unidades.isNotEmpty)
                        Text(
                          '¿No sale tu pendrive? Conéctalo: aparece aquí solo '
                          'en unos segundos.',
                          style: notas,
                        ),
                      if (escondida != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          'No sale ${nombreDisco(escondida.letra)} porque es '
                          'el de la colección: en él no se escribe nada.',
                          style: notas,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (_aviso != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: c.rojoFondo,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.error_outline_rounded,
                        size: 18,
                        color: c.rojo,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _aviso!,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.45,
                            color: c.texto,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: 10,
                runSpacing: 10,
                children: [
                  OutlinedButton.icon(
                    onPressed: _mirando ? null : _elegirOtra,
                    icon: _mirando
                        ? const _Girando()
                        : const Icon(Icons.folder_open_outlined, size: 16),
                    label: const Text('Elegir otra carpeta…'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancelar'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Explicación larga de por qué no se puede guardar ahí.
String _explicacion(
  Impedimento i,
  Volumen v,
  int tamano, {
  int? existente,
}) => switch (i) {
  Impedimento.soloLectura =>
    'Ese disco está protegido contra escritura: solo se puede leer. Si es '
        'una tarjeta o un pendrive con pestaña de bloqueo, muévela y vuelve a '
        'probar.',
  Impedimento.formato =>
    'Ese disco está en formato ${v.sistema}, que no admite archivos de más '
        'de ${_maximo(v)}, y esta película ocupa ${textoBytes(tamano)}. Elige '
        'otro o, si no tiene nada que quieras conservar, formatéalo en exFAT '
        'desde el Explorador (se borra todo lo que tenga).',
  Impedimento.noCabe =>
    'No cabe: la película ocupa ${textoBytes(tamano)} y en ese disco quedan '
        '${textoBytes(v.libre + (existente ?? 0))} libres.',
};

/// Explicación corta (en la tarjeta de cada unidad).
String _corta(Impedimento i, Volumen v, int tamano, {int? existente}) =>
    switch (i) {
      Impedimento.soloLectura => 'Protegido contra escritura',
      Impedimento.formato =>
        'Formato ${v.sistema}: no admite archivos de más de ${_maximo(v)}',
      Impedimento.noCabe =>
        'No cabe: faltan '
            '${textoBytes(tamano + margenLibre - v.libre - (existente ?? 0))}',
    };

String _maximo(Volumen v) =>
    (maximoArchivo(v.sistema) ?? 0) > 0x7FFFFFFF ? '4 GB' : '2 GB';

/// Una unidad en la ventana «¿Dónde quieres guardarla?». Si no vale, sale
/// apagada y dice por qué.
class _TarjetaUnidad extends StatelessWidget {
  const _TarjetaUnidad(this.u, {required this.tamano, required this.alPulsar});

  final Unidad u;
  final int tamano;
  final VoidCallback alPulsar;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final impedimento = impedimentoCopia(
      u,
      tamano,
      existente: u.existente ?? 0,
    );
    final usado = u.total <= 0 ? 0.0 : (1 - u.libre / u.total).clamp(0.0, 1.0);
    final icono = switch (u.conexion) {
      Conexion.usb || Conexion.extraible => Icons.usb_rounded,
      Conexion.tarjeta => Icons.sd_card_outlined,
      Conexion.interna => Icons.storage_rounded,
    };
    final (nota, colorNota) = impedimento != null
        ? (_corta(impedimento, u, tamano, existente: u.existente), c.rojo)
        : u.existente != null
        ? ('Ya está copiada aquí: se puede reemplazar', c.naranja)
        : ('Se guarda en ${u.carpeta}', c.textoSecundario);
    return Opacity(
      opacity: impedimento == null ? 1 : 0.6,
      child: Material(
        color: c.superficie,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: c.borde),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: impedimento == null ? alPulsar : null,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
            child: Row(
              children: [
                Icon(
                  icono,
                  size: 26,
                  color: impedimento == null ? c.doradoTexto : c.textoTenue,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 10,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            u.nombre,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: c.texto,
                            ),
                          ),
                          Text(
                            '${u.tipo} · ${u.sistema}',
                            style: TextStyle(
                              fontSize: 12,
                              color: c.textoSecundario,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: usado,
                          minHeight: 4,
                          color: usado > 0.9 ? c.rojo : c.dorado,
                          backgroundColor: c.seleccion,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${textoBytes(u.libre)} libres de '
                        '${textoBytes(u.total)}',
                        style: TextStyle(fontSize: 13, color: c.textoSuave),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        nota,
                        style: TextStyle(fontSize: 13, color: colorNota),
                      ),
                    ],
                  ),
                ),
                if (impedimento == null) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.chevron_right_rounded, color: c.textoSecundario),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Mientras se copia ────────────────────────────────────────────────────

/// «620 MB de 1,4 GB · 38 MB/s · faltan unos 20 s».
String lineaAvanceCopia(CopiaPelicula c) {
  final restante = c.restante;
  final velocidad = c.velocidad;
  return [
    '${textoBytes(c.copiados)} de ${textoBytes(c.total)}',
    if (c.parada)
      'esperando: no llega nada desde hace unos segundos'
    else if (velocidad == null)
      'calculando el tiempo…'
    else ...[
      '${textoBytes(velocidad.round())}/s',
      if (restante != null) 'faltan ${textoRestante(restante)}',
    ],
  ].join(' · ');
}

/// Pregunta antes de cancelar (se borra lo copiado).
Future<void> confirmarCancelarCopia(BuildContext context, WidgetRef ref) async {
  final c = ref.read(copiaPeliculaProvider);
  if (c == null || !c.enMarcha) return;
  final si = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('¿Cancelar la copia?'),
      content: Text(
        'Se para la copia de «${c.titulo}» y se borra lo que lleva copiado '
        '(${c.porcentaje} %).',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Seguir copiando'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Cancelar la copia'),
        ),
      ],
    ),
  );
  if (si == true) ref.read(copiaPeliculaProvider.notifier).cancelar();
}

/// Al cerrar la app con una copia en marcha: ¿cerrar igualmente (y cancelar
/// la copia)?
Future<bool> preguntarCerrarConCopia(BuildContext context, CopiaPelicula c) =>
    showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Cerrar Videoteca?'),
        content: Text(
          'Se está copiando «${c.titulo}» (${c.porcentaje} %). Si cierras '
          'ahora, la copia se cancela y se borra lo copiado.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Seguir copiando'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    ).then((si) => si ?? false);

/// Cómo va la copia de esta película (en «Dónde está», en la ficha).
class ProgresoCopia extends ConsumerWidget {
  const ProgresoCopia(this.copia, {super.key, required this.alAbrirCarpeta});

  final CopiaPelicula copia;

  /// Abre la carpeta de la copia con la película ya seleccionada.
  final VoidCallback alAbrirCarpeta;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colores;
    final k = copia;
    final cerrar = TextButton(
      onPressed: ref.read(copiaPeliculaProvider.notifier).cerrar,
      child: const Text('Cerrar aviso'),
    );
    final (
      Widget? icono,
      String titulo,
      List<Widget> botones,
    ) = switch (k.etapa) {
      EtapaCopia.copiando => (
        null,
        'Copiando a ${k.carpeta}',
        [
          TextButton(
            onPressed: () => confirmarCancelarCopia(context, ref),
            child: const Text('Cancelar'),
          ),
        ],
      ),
      EtapaCopia.comprobando => (
        null,
        'Comprobando que la copia está completa…',
        <Widget>[],
      ),
      EtapaCopia.cancelando => (
        null,
        'Cancelando y borrando lo copiado…',
        <Widget>[],
      ),
      EtapaCopia.hecha => (
        Icon(Icons.check_circle_rounded, size: 18, color: c.verde),
        'Copiada en ${k.carpeta}',
        [
          FilledButton.icon(
            onPressed: alAbrirCarpeta,
            icon: const Icon(Icons.folder_open_outlined, size: 16),
            label: const Text('Abrir carpeta'),
          ),
          cerrar,
        ],
      ),
      EtapaCopia.cancelada => (
        Icon(Icons.info_outline_rounded, size: 18, color: c.textoSecundario),
        'Copia cancelada: no ha quedado nada a medias.',
        [cerrar],
      ),
      EtapaCopia.fallo => (
        Icon(Icons.error_outline_rounded, size: 18, color: c.rojo),
        'No se ha podido copiar',
        [cerrar],
      ),
    };
    final detalle = switch (k.etapa) {
      EtapaCopia.copiando => lineaAvanceCopia(k),
      EtapaCopia.hecha => k.destino.substring(k.destino.lastIndexOf(r'\') + 1),
      EtapaCopia.fallo when k.resultado != null => textoFalloCopia(
        k.resultado!,
        carpeta: k.carpeta,
        disco: esAdministrador
            ? nombreDisco(ref.watch(carpetaRaizProvider))
            : null,
      ),
      _ => null,
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: k.etapa == EtapaCopia.fallo ? c.rojoFondo : c.superficie,
        border: Border.all(
          color: k.etapa == EtapaCopia.fallo ? c.rojoFondo : c.borde,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              icono ??
                  Icon(Icons.save_alt_rounded, size: 18, color: c.doradoTexto),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  titulo,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: c.texto,
                  ),
                ),
              ),
              if (k.etapa == EtapaCopia.copiando)
                Text(
                  '${k.porcentaje} %',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: c.doradoTexto,
                  ),
                ),
            ],
          ),
          if (k.enMarcha) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: k.etapa == EtapaCopia.copiando ? k.fraccion : null,
                minHeight: 6,
                color: c.dorado,
                backgroundColor: c.seleccion,
              ),
            ),
          ],
          if (detalle != null) ...[
            const SizedBox(height: 8),
            Text(
              detalle,
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                fontFamily: k.etapa == EtapaCopia.hecha ? fuenteRutas : null,
                color: k.etapa == EtapaCopia.fallo ? c.texto : c.textoSuave,
              ),
            ),
          ],
          if (botones.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: botones),
          ],
        ],
      ),
    );
  }
}

/// Aviso del menú lateral mientras se copia una película (y al terminar,
/// hasta que se cierra). Pulsándolo, se va a su ficha.
class CopiaEnMenu extends ConsumerWidget {
  const CopiaEnMenu({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final k = ref.watch(copiaPeliculaProvider);
    if (k == null) return const SizedBox.shrink();
    final c = context.colores;
    final (icono, color, titulo) = switch (k.etapa) {
      EtapaCopia.copiando => (
        Icons.save_alt_rounded,
        c.doradoTexto,
        'Copiando',
      ),
      EtapaCopia.comprobando => (
        Icons.save_alt_rounded,
        c.doradoTexto,
        'Comprobando la copia',
      ),
      EtapaCopia.cancelando => (
        Icons.save_alt_rounded,
        c.textoSecundario,
        'Cancelando',
      ),
      EtapaCopia.hecha => (Icons.check_circle_rounded, c.verde, 'Copiada'),
      EtapaCopia.cancelada => (
        Icons.info_outline_rounded,
        c.textoSecundario,
        'Copia cancelada',
      ),
      EtapaCopia.fallo => (
        Icons.error_outline_rounded,
        c.rojo,
        'No se ha podido copiar',
      ),
    };
    final restante = k.restante;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: c.superficie,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: c.borde),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: k.id > 0 ? () => context.go('/pelicula/${k.id}') : null,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 6, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icono, size: 16, color: color),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        titulo,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                    ),
                    if (!k.enMarcha)
                      IconButton(
                        tooltip: 'Cerrar aviso',
                        visualDensity: VisualDensity.compact,
                        iconSize: 16,
                        onPressed: ref
                            .read(copiaPeliculaProvider.notifier)
                            .cerrar,
                        icon: const Icon(Icons.close_rounded),
                      )
                    else
                      const SizedBox(height: 40),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    k.titulo,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: c.texto),
                  ),
                ),
                if (k.enMarcha) ...[
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: k.etapa == EtapaCopia.copiando
                            ? k.fraccion
                            : null,
                        minHeight: 4,
                        color: c.dorado,
                        backgroundColor: c.seleccion,
                      ),
                    ),
                  ),
                  if (k.etapa == EtapaCopia.copiando) ...[
                    const SizedBox(height: 6),
                    Text(
                      [
                        '${k.porcentaje} %',
                        if (restante != null)
                          'faltan ${textoRestante(restante)}',
                      ].join(' · '),
                      style: TextStyle(fontSize: 12, color: c.textoSecundario),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Ruedita del tamaño de un icono pequeño.
class _Girando extends StatelessWidget {
  const _Girando();

  @override
  Widget build(BuildContext context) => const SizedBox.square(
    dimension: 16,
    child: CircularProgressIndicator(strokeWidth: 2),
  );
}
