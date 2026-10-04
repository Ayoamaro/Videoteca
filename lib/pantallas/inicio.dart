import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../datos/catalogo.dart';
import '../datos/vigilancia.dart';
import '../modelos/pelicula.dart';
import '../tema/colores.dart';
import '../tema/tema.dart';
import '../utilidades.dart';
import '../widgets/buscador_sugerencias.dart';
import '../widgets/caratula.dart';
import '../widgets/comunes.dart';

/// Pantalla de Inicio: buscador, aviso de películas nuevas, añadidas
/// recientemente y géneros.
class PantallaInicio extends ConsumerWidget {
  const PantallaInicio({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colores;
    final tema = Theme.of(context).textTheme;
    final todas = ref.watch(catalogoProvider).value ?? const <Pelicula>[];
    final generos = ref.watch(generosProvider);
    final antiguo = DateTime(1900);
    final recientes = [...todas]
      ..sort((a, b) => (b.anadida ?? antiguo).compareTo(a.anadida ?? antiguo));
    final nuevas = ref.watch(nuevasProvider);

    return LayoutBuilder(
      builder: (context, medidas) {
        final movil = medidas.maxWidth < 600;
        return PaginaBase(
          separacion: movil ? 22 : 36,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.end,
              spacing: 16,
              runSpacing: 8,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fechaLarga(DateTime.now()),
                      style: tema.labelLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: c.textoSecundario,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '¿Qué película buscas?',
                      style: movil ? tema.headlineSmall : tema.displaySmall,
                    ),
                  ],
                ),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: formatoNumero(todas.length),
                        style: TextStyle(
                          fontFamily: fuenteTitulos,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: c.texto,
                        ),
                      ),
                      TextSpan(
                        text: todas.length == 1
                            ? '  película en la colección'
                            : '  películas en la colección',
                      ),
                    ],
                  ),
                  style: TextStyle(fontSize: 15, color: c.textoSecundario),
                ),
              ],
            ),
            BuscadorConSugerencias(
              alto: movil ? 54 : 64,
              indicacion: movil
                  ? '¿Qué película buscas?'
                  : 'Busca por título, título original, actor o director…',
              atajo: movil ? null : 'Ctrl K',
            ),
            if (esAdministrador && nuevas.isNotEmpty) _AvisoNuevas(nuevas),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TituloSeccion(
                  'Añadidas recientemente',
                  accion: 'Ver todas',
                  alPulsar: () => context.go('/catalogo'),
                ),
                const SizedBox(height: 14),
                if (movil)
                  SizedBox(
                    height: 260,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: recientes.length.clamp(0, 6),
                      separatorBuilder: (_, _) => const SizedBox(width: 12),
                      itemBuilder: (_, i) => SizedBox(
                        width: 132,
                        child: TarjetaPelicula(recientes[i]),
                      ),
                    ),
                  )
                else
                  CuadriculaAdaptable(
                    anchoMinimo: 150,
                    children: [
                      for (final p in recientes.take(6)) TarjetaPelicula(p),
                    ],
                  ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TituloSeccion(movil ? 'Géneros' : 'Explorar por género'),
                const SizedBox(height: 16),
                if (movil)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final (nombre, _) in generos)
                        ActionChip(
                          label: Text(nombre),
                          onPressed: () => _abrirGenero(context, nombre),
                        ),
                    ],
                  )
                else
                  CuadriculaAdaptable(
                    anchoMinimo: 200,
                    separacion: 12,
                    children: [
                      for (final (nombre, total) in generos)
                        BotonGenero(
                          nombre: nombre,
                          total: total,
                          alPulsar: () => _abrirGenero(context, nombre),
                        ),
                    ],
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}

void _abrirGenero(BuildContext context, String genero) =>
    context.go('/catalogo?carpeta=${Uri.encodeQueryComponent(genero)}');

/// Botón de género con su número de películas.
class BotonGenero extends StatelessWidget {
  const BotonGenero({
    super.key,
    required this.nombre,
    required this.total,
    required this.alPulsar,
  });

  final String nombre;
  final int total;
  final VoidCallback alPulsar;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    return Material(
      color: c.superficie,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: c.borde),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: alPulsar,
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  nombre,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                formatoNumero(total),
                style: TextStyle(fontSize: 13, color: c.textoSecundario),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Banda dorada "3 películas nuevas detectadas".
class _AvisoNuevas extends StatelessWidget {
  const _AvisoNuevas(this.todas);

  /// Todas las nuevas (se enseñan las 3 más recientes).
  final List<Pelicula> todas;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final nuevas = todas.take(3).toList();
    return Material(
      color: c.doradoFondo,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: c.doradoBorde),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.go('/nuevas'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 18,
            runSpacing: 12,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: c.dorado,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.download_rounded, color: c.sobreDorado),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      todas.length == 1
                          ? '1 película nueva detectada en el disco'
                          : '${formatoNumero(todas.length)} películas nuevas '
                                'detectadas en el disco',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Sin datos todavía · '
                      '${nuevas.map((p) => '${p.titulo} (${p.anio})').join(', ')}'
                      '${todas.length > 3 ? '…' : ''}',
                      style: TextStyle(fontSize: 14, color: c.textoSecundario),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final p in nuevas)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: SizedBox(
                        width: 30,
                        child: Caratula.de(p, mostrarNueva: false),
                      ),
                    ),
                  const SizedBox(width: 10),
                  FilledButton(
                    onPressed: () => context.go('/nuevas'),
                    child: const Text('Ver nuevas'),
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
