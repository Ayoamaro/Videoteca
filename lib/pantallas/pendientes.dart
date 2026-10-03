import 'package:flutter/material.dart';

import '../tema/colores.dart';
import '../tema/tema.dart';
import '../utilidades.dart';
import '../widgets/caratula.dart';
import '../widgets/comunes.dart';

class _Pendiente {
  const _Pendiente(
    this.titulo,
    this.detalle,
    this.tono,
    this.accion1,
    this.accion2,
  );

  final String titulo;
  final String detalle;
  final Color tono;
  final String accion1;
  final String accion2;
}

class _Tipo {
  const _Tipo(this.nombre, this.total, this.descripcion, this.elementos);

  final String nombre;
  final int total;
  final String descripcion;
  final List<_Pendiente> elementos;
}

// Datos de ejemplo; la detección real llega el día 8.
const _tipos = [
  _Tipo(
    'Dudosas',
    41,
    'La búsqueda automática no estuvo segura. No se ha escrito nada en estos archivos.',
    [
      _Pendiente(
        'Crash (Colisión) (2004)',
        'Drama\\Crash (Colisión) (2004).mp4\nDos coincidencias del mismo año',
        Color(0xFF3B2E22),
        'Ignorar',
        'Elegir la correcta',
      ),
      _Pendiente(
        'El Atardecer (2007)',
        'Drama\\El Atardecer (2007).mp4\nEl director no coincide',
        Color(0xFF4A3426),
        'Ignorar',
        'Elegir la correcta',
      ),
    ],
  ),
  _Tipo('Sin carátula', 2, 'Películas que no tienen carátula incrustada.', [
    _Pendiente(
      'Patoaventuras: La Película (1990)',
      'Animación\\Patoaventuras꞉ La Película - El Tesoro…-1.mp4',
      Color(0xFF2E4A3C),
      'Abrir carpeta',
      'Añadir carátula',
    ),
  ]),
  _Tipo(
    'Incompletas',
    8,
    'Les faltan campos importantes (sinopsis, reparto…).',
    [
      _Pendiente(
        'Casi Navidad (2016)',
        'Comedia\\Casi Navidad (2016).mp4\nFalta: Subtítulo, Productores',
        Color(0xFF3E2F55),
        'Ver ficha',
        'Completar',
      ),
    ],
  ),
  _Tipo(
    'Duplicadas',
    12,
    'La misma película está en dos carpetas distintas. Elige cuál conservar; '
        'la app no borra nada por su cuenta.',
    [
      _Pendiente(
        'Liberad a Willy 2 (1995)',
        'D:\\Animación y Cine Familiar\\Infantil & Familiar\\\nD:\\Aventuras y Fantasía\\Aventuras\\',
        Color(0xFF2C3E3E),
        'Abrir carpetas',
        'Marcar como revisada',
      ),
      _Pendiente(
        'Sin Límites (2011)',
        'D:\\Suspense, Terror y Thriller\\Thriller\\\nD:\\Ciencia Ficción\\Ciencia Ficción\\',
        Color(0xFF1F3A4D),
        'Abrir carpetas',
        'Marcar como revisada',
      ),
    ],
  ),
  _Tipo(
    'Desaparecidas',
    0,
    'Estaban en el catálogo pero ya no están en el disco.',
    [],
  ),
  _Tipo(
    'Nombre fuera de formato',
    1,
    'No siguen el formato «Título (Año).mp4».',
    [
      _Pendiente(
        'Patoaventuras: La Película - El Tesoro de la Lámpara Perdida (1990)-1',
        'Animación\\…(1990)-1.mp4\nSobra «-1» al final',
        Color(0xFF2E4A3C),
        'Ignorar',
        'Renombrar…',
      ),
    ],
  ),
];

/// Todo lo que necesita atención en la colección.
class PantallaPendientes extends StatefulWidget {
  const PantallaPendientes({super.key});

  @override
  State<PantallaPendientes> createState() => _PantallaPendientesState();
}

class _PantallaPendientesState extends State<PantallaPendientes> {
  int _tipo = 3;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final tipo = _tipos[_tipo];
    return PaginaBase(
      separacion: 24,
      children: [
        const CabeceraPagina(
          titulo: 'Pendientes',
          descripcion: 'Todo lo que necesita tu atención en la colección.',
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < _tipos.length; i++) _pestana(context, i),
          ],
        ),
        Text(
          tipo.descripcion,
          style: TextStyle(fontSize: 14, height: 1.5, color: c.textoSuave),
        ),
        if (tipo.elementos.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Column(
              children: [
                Icon(
                  Icons.check_circle_outline_rounded,
                  size: 44,
                  color: c.verde,
                ),
                const SizedBox(height: 10),
                Text(
                  'Nada pendiente aquí.',
                  style: TextStyle(color: c.textoSecundario),
                ),
              ],
            ),
          ),
        for (final e in tipo.elementos) _elemento(context, e),
      ],
    );
  }

  Widget _pestana(BuildContext context, int i) {
    final c = context.colores;
    final t = _tipos[i];
    final marcada = i == _tipo;
    return Material(
      color: marcada ? c.doradoFondo : c.superficie,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: marcada ? c.dorado : c.borde),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => setState(() => _tipo = i),
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                t.nombre,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: marcada ? c.texto : c.textoSuave,
                ),
              ),
              const SizedBox(width: 8),
              Insignia(t.total, destacada: marcada),
            ],
          ),
        ),
      ),
    );
  }

  Widget _elemento(BuildContext context, _Pendiente e) {
    final c = context.colores;
    return Tarjeta(
      radio: 12,
      relleno: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 16,
        runSpacing: 12,
        children: [
          SizedBox(width: 44, child: Caratula(tono: e.tono)),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 280, maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  e.titulo,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  e.detalle,
                  style: TextStyle(
                    fontFamily: fuenteRutas,
                    fontSize: 12,
                    height: 1.5,
                    color: c.textoSecundario,
                  ),
                ),
              ],
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: () => avisoProximamente(context, e.accion1, 8),
                child: Text(e.accion1),
              ),
              FilledButton(
                onPressed: () => avisoProximamente(context, e.accion2, 8),
                child: Text(e.accion2),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
