import 'package:flutter/material.dart';

import '../disco/acciones_windows.dart';
import '../disco/escritor.dart' show Campo;
import '../fuentes/conexion.dart';
import '../fuentes/datos_automaticos.dart';
import '../fuentes/identificacion.dart';
import '../tema/colores.dart';
import 'comunes.dart';

/// Busca en internet (TMDB, OMDb, Wikidata) los datos de la película
/// [datos] y deja elegir cuáles pasar a la ficha. [actuales] son los valores
/// que tiene ahora el formulario: los campos vacíos vienen marcados; los que
/// ya tienen otro valor, no.
///
/// Devuelve los datos elegidos, o `null` si se cancela.
Future<Map<Campo, DatoEncontrado>?> mostrarDatosAutomaticos(
  BuildContext context, {
  required FuentesDatos fuentes,
  required DatosIdentificacion datos,
  required Map<Campo, String> actuales,
}) => showDialog<Map<Campo, DatoEncontrado>>(
  context: context,
  builder: (context) =>
      _DialogoDatos(fuentes: fuentes, datos: datos, actuales: actuales),
);

class _DialogoDatos extends StatefulWidget {
  const _DialogoDatos({
    required this.fuentes,
    required this.datos,
    required this.actuales,
  });

  final FuentesDatos fuentes;
  final DatosIdentificacion datos;
  final Map<Campo, String> actuales;

  @override
  State<_DialogoDatos> createState() => _EstadoDialogoDatos();
}

class _EstadoDialogoDatos extends State<_DialogoDatos> {
  ResultadoDatos? _resultado;

  /// La película elegida a mano entre las dudosas.
  Candidato? _elegida;
  String? _error;
  var _buscando = true;
  final _marcados = <Campo>{};

  @override
  void initState() {
    super.initState();
    _buscar(() => widget.fuentes.buscar(widget.datos));
  }

  Future<void> _buscar(Future<ResultadoDatos> Function() buscar) async {
    setState(() {
      _buscando = true;
      _error = null;
    });
    try {
      final r = await buscar();
      if (!mounted) return;
      setState(() {
        _resultado = r;
        _marcados
          ..clear()
          ..addAll([
            for (final MapEntry(key: c, value: d) in r.datos.entries)
              if ((widget.actuales[c] ?? '').isEmpty && d.valor.isNotEmpty) c,
          ]);
      });
    } on FuenteException catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    } catch (e) {
      if (mounted) setState(() => _error = 'Ha fallado la búsqueda: $e');
    } finally {
      if (mounted) setState(() => _buscando = false);
    }
  }

  void _elegir(Candidato c) {
    _elegida = c;
    final identificacion = _resultado!.identificacion;
    _buscar(() => widget.fuentes.completar(identificacion, c.ficha));
  }

  /// La película de la que se enseñan los datos.
  Candidato? get _pelicula {
    final r = _resultado;
    if (r == null) return null;
    if (_elegida != null) return _elegida;
    return r.identificacion.seguridad == Seguridad.segura
        ? r.identificacion.candidatos.first
        : null;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final pelicula = _pelicula;
    final r = _resultado;
    final Widget contenido;
    if (_buscando) {
      contenido = const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Buscando en TMDB, OMDb y Wikidata…'),
          ],
        ),
      );
    } else if (_error != null) {
      contenido = MensajeDialogo(
        icono: Icons.cloud_off_rounded,
        color: c.rojo,
        texto: _error!,
      );
    } else if (pelicula != null) {
      contenido = _datos(pelicula, r!);
    } else if (r!.identificacion.seguridad == Seguridad.noEncontrada) {
      contenido = MensajeDialogo(
        icono: Icons.search_off_rounded,
        color: c.naranja,
        texto:
            '${r.identificacion.motivo} Revisa el título y el año (o '
            'escribe el título original) y vuelve a probar.',
      );
    } else {
      contenido = _dudas(r.identificacion);
    }

    final hayDatos = pelicula != null && !_buscando && _error == null;
    return AlertDialog(
      title: const Text('Datos de internet'),
      content: SizedBox(
        width: 640,
        child: SingleChildScrollView(child: contenido),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(hayDatos ? 'Cancelar' : 'Cerrar'),
        ),
        if (hayDatos)
          FilledButton(
            onPressed: _marcados.isEmpty
                ? null
                : () => Navigator.pop(context, {
                    for (final campo in _marcados) campo: r!.datos[campo]!,
                  }),
            child: Text('Pasar a la ficha (${_marcados.length})'),
          ),
      ],
    );
  }

  /// Hay dudas: se enseñan las parecidas para elegir.
  Widget _dudas(Identificacion id) {
    final c = context.colores;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MensajeDialogo(
          icono: Icons.help_outline_rounded,
          color: c.naranja,
          texto:
              'No estoy seguro de cuál es. ${id.motivo}\n'
              'Si una de estas es la tuya, elígela.',
        ),
        const SizedBox(height: 12),
        for (final candidato in id.candidatos)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Tarjeta(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${candidato.ficha.titulo} (${candidato.ficha.anio})',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          [
                            if (candidato.ficha.tituloOriginal !=
                                candidato.ficha.titulo)
                              candidato.ficha.tituloOriginal,
                            if (candidato.ficha.directores.isNotEmpty)
                              'Dirección: ${candidato.ficha.directores.join(', ')}',
                          ].join(' · '),
                          style: TextStyle(fontSize: 13, color: c.textoSuave),
                        ),
                        Text(
                          candidato.explicacion,
                          style: TextStyle(
                            fontSize: 12,
                            color: c.textoSecundario,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Ver en TMDB',
                    onPressed: () => abrirConWindows(candidato.ficha.enlace),
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  ),
                  const SizedBox(width: 4),
                  OutlinedButton(
                    onPressed: () => _elegir(candidato),
                    child: const Text('Es esta'),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  /// La película identificada y sus datos, para marcar cuáles se pasan.
  Widget _datos(Candidato pelicula, ResultadoDatos r) {
    final c = context.colores;
    final f = pelicula.ficha;
    final segura = _elegida == null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(
              segura ? Icons.verified_rounded : Icons.touch_app_rounded,
              color: segura ? c.verde : c.doradoTexto,
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
                      text: segura
                          ? '  ·  Identificada: ${pelicula.explicacion[0].toLowerCase()}${pelicula.explicacion.substring(1)}'
                          : '  ·  Elegida por ti',
                      style: TextStyle(fontSize: 13, color: c.textoSecundario),
                    ),
                  ],
                ),
              ),
            ),
            TextButton.icon(
              onPressed: () => abrirConWindows(f.enlace),
              icon: const Icon(Icons.open_in_new_rounded, size: 16),
              label: const Text('TMDB'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Marcados: los campos que están vacíos en tu ficha. Los que ya '
          'tienen otro valor solo se cambian si los marcas.',
          style: TextStyle(fontSize: 13, color: c.textoSecundario),
        ),
        const SizedBox(height: 10),
        if (r.datos.isEmpty)
          const Text('TMDB no tiene más datos de esta película.'),
        for (final campo in Campo.values)
          if (r.datos[campo] case final dato?)
            FilaDato(
              campo: campo,
              dato: dato,
              actual: widget.actuales[campo] ?? '',
              marcado: _marcados.contains(campo),
              alCambiar: (si) => setState(
                () => si ? _marcados.add(campo) : _marcados.remove(campo),
              ),
            ),
        for (final aviso in r.avisos)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                Icon(Icons.warning_amber_rounded, size: 16, color: c.naranja),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    aviso,
                    style: TextStyle(fontSize: 13, color: c.textoSuave),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// [actual] y [nuevo] dicen lo mismo para el campo [campo]: el mismo
/// texto, las mismas personas escritas un poco distinto, o solo cambia un
/// punto final («Miramax, STX Entertainment.»).
bool mismoDato(Campo campo, String actual, String nuevo) {
  if (actual == nuevo) return true;
  String sinPunto(String t) => t.trim().replaceAll(RegExp(r'[.\s]+$'), '');
  if (sinPunto(actual) == sinPunto(nuevo)) return true;
  return FilaDato._personas.contains(campo) && mismasPersonas(actual, nuevo);
}

/// La sinopsis [actual] es el principio de [nueva], cortada (las editadas en
/// el Explorador de Windows se quedan en 255 letras).
bool sinopsisCortada(String actual, String nueva) {
  final a = actual.trim();
  return a.length >= 40 && nueva.length > a.length && nueva.startsWith(a);
}

/// Un dato encontrado, con su casilla para pasarlo a la ficha.
class FilaDato extends StatelessWidget {
  const FilaDato({
    super.key,
    required this.campo,
    required this.dato,
    required this.actual,
    required this.marcado,
    required this.alCambiar,
  });

  final Campo campo;
  final DatoEncontrado dato;
  final String actual;
  final bool marcado;
  final ValueChanged<bool> alCambiar;

  static const _personas = {
    Campo.direccion,
    Campo.guion,
    Campo.fotografia,
    Campo.musica,
  };

  String _ver(String valor) =>
      campo == Campo.estrellas && valor.isNotEmpty ? '$valor ★' : valor;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final igual = mismoDato(campo, actual, dato.valor);
    final cortada =
        campo == Campo.sinopsis && sinopsisCortada(actual, dato.valor);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: igual ? true : marcado,
            onChanged: igual ? null : (v) => alCambiar(v ?? false),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        campo.nombre,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: c.textoSuave,
                        ),
                      ),
                      const SizedBox(width: 8),
                      EtiquetaOrigen(dato.origen),
                      if (igual) ...[
                        const SizedBox(width: 8),
                        Text(
                          'Ya lo tienes',
                          style: TextStyle(fontSize: 12, color: c.verde),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  SelectableText(
                    _ver(dato.valor),
                    style: TextStyle(fontSize: 14, color: c.texto),
                  ),
                  if (dato.detalle.isNotEmpty)
                    Text(
                      dato.detalle,
                      style: TextStyle(fontSize: 12, color: c.textoSecundario),
                    ),
                  if (cortada)
                    Text(
                      'La tuya está cortada a las ${actual.length} letras: '
                      'esta es la completa.',
                      style: TextStyle(fontSize: 12, color: c.naranja),
                    )
                  else if (actual.isNotEmpty && !igual)
                    Text(
                      'Ahora: ${_ver(actual)}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: c.naranja),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Origen de los datos que salen del nombre del archivo.
const origenArchivo = 'Nombre del archivo';

/// Pastilla pequeña con el origen de un dato («TMDB», «OMDb»…), con el
/// color de cada fuente (como en la leyenda del diseño).
class EtiquetaOrigen extends StatelessWidget {
  const EtiquetaOrigen(this.origen, {super.key});

  final String origen;

  /// Color del texto y del fondo de cada origen.
  static (Color, Color) colores(BuildContext context, String origen) {
    final c = context.colores;
    return switch (origen) {
      'FilmAffinity' => (c.doradoTexto, c.doradoFondo),
      'OMDb' => (c.rojo, c.rojoFondo),
      'Wikidata' => (c.morado, c.moradoFondo),
      origenArchivo => (c.textoSecundario, c.seleccion),
      _ => (c.azul, c.azulFondo),
    };
  }

  @override
  Widget build(BuildContext context) {
    final (texto, fondo) = colores(context, origen);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        origen,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: texto,
        ),
      ),
    );
  }
}

/// Un mensaje con icono dentro de un diálogo.
class MensajeDialogo extends StatelessWidget {
  const MensajeDialogo({
    super.key,
    required this.icono,
    required this.color,
    required this.texto,
  });

  final IconData icono;
  final Color color;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, color: color),
          const SizedBox(width: 10),
          Expanded(child: Text(texto, style: const TextStyle(height: 1.45))),
        ],
      ),
    );
  }
}
