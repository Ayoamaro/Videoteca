import 'package:flutter/material.dart';

import '../disco/escaner.dart';
import '../tema/colores.dart';
import '../utilidades.dart';

/// Barra de progreso del escaneo con sus explicaciones.
class ProgresoEscaneoVista extends StatelessWidget {
  const ProgresoEscaneoVista(this.progreso, {super.key, this.alCancelar});

  final ProgresoEscaneo progreso;
  final VoidCallback? alCancelar;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final p = progreso;
    final (titulo, detalle, color) = switch (p.fase) {
      FaseEscaneo.buscando => (
        'Buscando películas en el disco…',
        'Recorriendo las carpetas.',
        c.texto,
      ),
      FaseEscaneo.leyendo => (
        'Leyendo ${formatoNumero(p.leidas)} de ${formatoNumero(p.porLeer)}',
        p.actual.isEmpty ? 'Empezando…' : p.actual,
        c.texto,
      ),
      FaseEscaneo.terminado => (
        p.porLeer == 0
            ? (p.hayCambios
                  ? 'Catálogo al día'
                  : 'Todo al día: no había cambios')
            : 'Listo: ${formatoNumero(p.leidas)} '
                  '${p.leidas == 1 ? 'película leída' : 'películas leídas'}',
        '${formatoNumero(p.encontradas)} películas en el disco · '
            '${duracionTexto(p.transcurrido)}',
        c.verde,
      ),
      FaseEscaneo.cancelado => (
        'Escaneo detenido',
        'Lo leído (${formatoNumero(p.leidas)}) queda guardado. La próxima vez '
            'sigue por donde iba.',
        c.naranja,
      ),
      FaseEscaneo.error => ('No se ha podido escanear', p.mensaje, c.rojo),
    };
    final restante = p.restante;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Text(
                titulo,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
            if (p.fase == FaseEscaneo.leyendo && p.porLeer > 0)
              Text(
                '${(p.fraccion! * 100).floor()} %',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: c.doradoTexto,
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: p.enMarcha ? p.fraccion : 1,
            minHeight: 8,
            color: p.enMarcha ? c.dorado : color,
            backgroundColor: c.seleccion,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          detalle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 14, color: c.textoSecundario),
        ),
        if (_detalles(p, restante) case final detalles?) ...[
          const SizedBox(height: 4),
          Text(detalles, style: TextStyle(fontSize: 13, color: c.textoTenue)),
        ],
        if (p.enMarcha && alCancelar != null) ...[
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton(
              onPressed: alCancelar,
              child: const Text('Detener'),
            ),
          ),
        ],
      ],
    );
  }
}

/// Línea pequeña con el tiempo restante y lo que ha cambiado.
String? _detalles(ProgresoEscaneo p, Duration? restante) {
  final n = formatoNumero;
  final partes = [
    if (restante != null) 'Faltan ${duracionTexto(restante)}',
    if (p.fase != FaseEscaneo.buscando) ...[
      if (p.nuevas > 0) '${n(p.nuevas)} ${p.nuevas == 1 ? 'nueva' : 'nuevas'}',
      if (p.movidas > 0)
        '${n(p.movidas)} ${p.movidas == 1 ? 'movida' : 'movidas'}',
      if (p.recuperadas > 0) '${n(p.recuperadas)} de vuelta en el disco',
      if (p.desaparecidas > 0)
        '${n(p.desaparecidas)} ya no ${p.desaparecidas == 1 ? 'está' : 'están'}'
            ' en el disco (ver Pendientes)',
      if (p.enUso > 0)
        '${n(p.enUso)} copiándose todavía (se leerán al terminar)',
    ],
    if (p.errores > 0) '${n(p.errores)} sin poder leer (se reintentarán)',
  ];
  return partes.isEmpty ? null : partes.join(' · ');
}

/// "unos 4 min", "menos de 1 min", "1 h 5 min".
String duracionTexto(Duration d) {
  final minutos = (d.inSeconds / 60).round();
  if (d.inSeconds < 60) return 'menos de 1 min';
  if (minutos < 60) return 'unos $minutos min';
  return '${minutos ~/ 60} h ${minutos % 60} min';
}
