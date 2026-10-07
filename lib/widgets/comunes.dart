import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../modelos/pelicula.dart';
import '../tema/colores.dart';
import '../tema/tema.dart';
import 'caratula.dart';

/// Ancho a partir del cual se usa el diseño de escritorio (menú lateral).
const anchoEscritorio = 900.0;

/// Contenedor de cada pantalla: desplazable y con márgenes que se adaptan
/// al tamaño de la ventana.
class PaginaBase extends StatelessWidget {
  const PaginaBase({super.key, required this.children, this.separacion = 28});

  final List<Widget> children;
  final double separacion;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, medidas) {
        final estrecha = medidas.maxWidth < 700;
        final relleno = estrecha
            ? const EdgeInsets.fromLTRB(20, 24, 20, 32)
            : const EdgeInsets.fromLTRB(48, 36, 48, 56);
        return SafeArea(
          bottom: false,
          child: SingleChildScrollView(
            padding: relleno,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0) SizedBox(height: separacion),
                  children[i],
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Título grande de pantalla con descripción opcional y botones a la derecha.
class CabeceraPagina extends StatelessWidget {
  const CabeceraPagina({
    super.key,
    required this.titulo,
    this.descripcion,
    this.acciones = const [],
  });

  final String titulo;
  final String? descripcion;
  final List<Widget> acciones;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.end,
      spacing: 16,
      runSpacing: 16,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titulo, style: tema.headlineMedium),
              if (descripcion != null) ...[
                const SizedBox(height: 8),
                Text(
                  descripcion!,
                  style: tema.bodyLarge?.copyWith(
                    fontSize: 15,
                    height: 1.5,
                    color: context.colores.textoSecundario,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (acciones.isNotEmpty)
          Wrap(spacing: 10, runSpacing: 10, children: acciones),
      ],
    );
  }
}

/// Título de sección ("Añadidas recientemente") con enlace opcional.
class TituloSeccion extends StatelessWidget {
  const TituloSeccion(this.texto, {super.key, this.accion, this.alPulsar});

  final String texto;
  final String? accion;
  final VoidCallback? alPulsar;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(texto, style: Theme.of(context).textTheme.headlineSmall),
        ),
        if (accion != null)
          TextButton(onPressed: alPulsar, child: Text(accion!)),
      ],
    );
  }
}

/// Etiqueta pequeña en mayúsculas ("SINOPSIS", "GÉNERO").
class Etiqueta extends StatelessWidget {
  const Etiqueta(this.texto, {super.key, this.color});

  final String texto;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Text(
      texto.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
    );
  }
}

/// Panel con fondo y borde suaves.
class Tarjeta extends StatelessWidget {
  const Tarjeta({
    super.key,
    required this.child,
    this.relleno = const EdgeInsets.all(22),
    this.fondo,
    this.borde,
    this.radio = 14,
  });

  final Widget child;
  final EdgeInsetsGeometry relleno;
  final Color? fondo;
  final Color? borde;
  final double radio;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    return Container(
      padding: relleno,
      decoration: BoxDecoration(
        color: fondo ?? c.superficie,
        border: Border.all(color: borde ?? c.borde),
        borderRadius: BorderRadius.circular(radio),
      ),
      child: child,
    );
  }
}

/// Píldora de color para estados ("Lista para revisar", "Conectado").
class Pastilla extends StatelessWidget {
  const Pastilla(
    this.texto, {
    super.key,
    required this.color,
    required this.fondo,
  });

  final String texto;
  final Color color;
  final Color fondo;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        texto,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

/// Insignia pequeña con número (contadores del menú).
class Insignia extends StatelessWidget {
  const Insignia(this.numero, {super.key, this.destacada = false});

  final int numero;
  final bool destacada;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: destacada ? c.dorado : c.seleccion,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$numero',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: destacada ? c.sobreDorado : c.textoSuave,
        ),
      ),
    );
  }
}

/// Fila de 5 estrellas.
class Estrellas extends StatelessWidget {
  const Estrellas(this.numero, {super.key, this.tam = 18});

  final int numero;
  final double tam;

  @override
  Widget build(BuildContext context) {
    final dorado = context.colores.dorado;
    return Semantics(
      label: '$numero de 5 estrellas',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 1; i <= 5; i++)
            Icon(
              i <= numero ? Icons.star_rounded : Icons.star_outline_rounded,
              size: tam,
              color: dorado,
            ),
        ],
      ),
    );
  }
}

/// Buscador grande ("¿Qué película buscas?").
class CampoBusqueda extends StatelessWidget {
  const CampoBusqueda({
    super.key,
    this.controlador,
    this.alCambiar,
    this.alEnviar,
    this.alto = 64,
    this.autofoco = false,
    this.foco,
    this.atajo,
    this.indicacion = 'Busca por título, título original, actor o director…',
  });

  final TextEditingController? controlador;
  final ValueChanged<String>? alCambiar;
  final ValueChanged<String>? alEnviar;
  final double alto;
  final bool autofoco;
  final FocusNode? foco;

  /// Tecla rápida que se muestra a la derecha (p. ej. "Ctrl K").
  final String? atajo;
  final String indicacion;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final borde = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: c.bordeFuerte),
    );
    final controlador = this.controlador;
    // A la derecha: una ✕ para borrar si hay texto escrito o, si no, la
    // tecla rápida.
    final derecha = controlador == null
        ? null
        : ValueListenableBuilder(
            valueListenable: controlador,
            builder: (context, valor, _) {
              if (valor.text.isNotEmpty) {
                return IconButton(
                  tooltip: 'Borrar',
                  icon: Icon(Icons.close_rounded, color: c.textoSecundario),
                  onPressed: () {
                    controlador.clear();
                    alCambiar?.call('');
                    foco?.requestFocus();
                  },
                );
              }
              if (atajo == null) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: c.bordeFuerte),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    atajo!,
                    style: TextStyle(fontSize: 12, color: c.textoTenue),
                  ),
                ),
              );
            },
          );
    return TextField(
      controller: controlador,
      focusNode: foco,
      autofocus: autofoco,
      onChanged: alCambiar,
      onSubmitted: alEnviar,
      textInputAction: TextInputAction.search,
      textAlignVertical: TextAlignVertical.center,
      style: TextStyle(fontSize: alto > 56 ? 18 : 16, color: c.texto),
      decoration: InputDecoration(
        hintText: indicacion,
        constraints: BoxConstraints.tightFor(height: alto),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 18, right: 10),
          child: Icon(Icons.search_rounded, size: 24, color: c.textoSecundario),
        ),
        suffixIcon: derecha == null
            ? null
            : Padding(padding: const EdgeInsets.only(right: 6), child: derecha),
        suffixIconConstraints: const BoxConstraints(minWidth: 0),
        contentPadding: EdgeInsets.zero,
        border: borde,
        enabledBorder: borde,
        focusedBorder: borde.copyWith(
          borderSide: BorderSide(color: c.dorado, width: 1.5),
        ),
      ),
    );
  }
}

/// Coloca sus hijos en columnas del mismo ancho, tantas como quepan
/// respetando un ancho mínimo (como `grid auto-fill` en una web).
class CuadriculaAdaptable extends StatelessWidget {
  const CuadriculaAdaptable({
    super.key,
    required this.anchoMinimo,
    required this.children,
    this.separacion = 22,
    this.separacionVertical,
  });

  final double anchoMinimo;
  final double separacion;
  final double? separacionVertical;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, medidas) {
        final ancho = medidas.maxWidth;
        final columnas = ((ancho + separacion) / (anchoMinimo + separacion))
            .floor()
            .clamp(1, 99);
        final anchoHijo = (ancho - separacion * (columnas - 1)) / columnas;
        return Wrap(
          spacing: separacion,
          runSpacing: separacionVertical ?? separacion,
          children: [
            for (final hijo in children)
              SizedBox(width: anchoHijo, child: hijo),
          ],
        );
      },
    );
  }
}

/// Carátula + título + dato secundario. Al pulsarla abre la ficha.
class TarjetaPelicula extends StatelessWidget {
  const TarjetaPelicula(this.pelicula, {super.key, this.detalle});

  final Pelicula pelicula;

  /// Texto bajo el título; por defecto "Año · Género".
  final String? detalle;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;
    final p = pelicula;
    final texto = detalle ?? '${p.anio} · ${p.generoCarpeta}';
    // El lector de pantalla dice «Origen, 2010 · Ciencia ficción, botón».
    return Semantics(
      button: true,
      label: '${p.titulo}, $texto${p.nueva ? ', nueva' : ''}',
      excludeSemantics: true,
      onTap: () => context.push('/pelicula/${p.id}'),
      child: _tarjeta(context, tema, p, texto),
    );
  }

  Widget _tarjeta(
    BuildContext context,
    TextTheme tema,
    Pelicula p,
    String texto,
  ) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => context.push('/pelicula/${p.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Caratula.de(p),
          const SizedBox(height: 10),
          Text(
            p.titulo,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: tema.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            texto,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: tema.bodySmall,
          ),
        ],
      ),
    );
  }
}

/// Recuadro con un número grande y su descripción.
class Contador extends StatelessWidget {
  const Contador({
    super.key,
    required this.valor,
    required this.texto,
    this.color,
    this.fondo,
    this.colorTexto,
  });

  final String valor;
  final String texto;
  final Color? color;
  final Color? fondo;
  final Color? colorTexto;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    return Tarjeta(
      relleno: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      fondo: fondo,
      borde: fondo,
      radio: 12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            valor,
            style: TextStyle(
              fontFamily: fuenteTitulos,
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: color ?? c.texto,
            ),
          ),
          Text(
            texto,
            style: TextStyle(
              fontSize: 13,
              color: colorTexto ?? c.textoSecundario,
            ),
          ),
        ],
      ),
    );
  }
}

/// Aviso centrado para cuando una pantalla no tiene nada que enseñar
/// (colección vacía, búsqueda sin resultados…), con un botón opcional.
class AvisoVacio extends StatelessWidget {
  const AvisoVacio({
    super.key,
    required this.icono,
    required this.titulo,
    this.texto,
    this.accion,
    this.alPulsar,
    this.enTarjeta = false,
  });

  final IconData icono;
  final String titulo;
  final String? texto;
  final String? accion;
  final VoidCallback? alPulsar;

  /// Con fondo y borde (dentro de una página) o sin ellos (en una lista).
  final bool enTarjeta;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final contenido = Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        // Se lee de una vez con el lector de pantalla.
        child: MergeSemantics(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ExcludeSemantics(
                child: Icon(icono, size: 48, color: c.textoTenue),
              ),
              const SizedBox(height: 14),
              Text(
                titulo,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: c.texto,
                ),
              ),
              if (texto != null) ...[
                const SizedBox(height: 6),
                Text(
                  texto!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: c.textoSecundario,
                  ),
                ),
              ],
              if (accion != null) ...[
                const SizedBox(height: 16),
                OutlinedButton(onPressed: alPulsar, child: Text(accion!)),
              ],
            ],
          ),
        ),
      ),
    );
    return enTarjeta
        ? Tarjeta(
            relleno: const EdgeInsets.symmetric(vertical: 56, horizontal: 24),
            child: contenido,
          )
        : Padding(
            padding: const EdgeInsets.symmetric(vertical: 56, horizontal: 8),
            child: contenido,
          );
  }
}
