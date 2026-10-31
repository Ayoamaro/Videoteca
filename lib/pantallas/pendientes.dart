import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../datos/catalogo.dart';
import '../datos/pendientes.dart';
import '../datos/vigilancia.dart';
import '../disco/acciones_windows.dart';
import '../modelos/pelicula.dart';
import '../tema/colores.dart';
import '../tema/tema.dart';
import '../utilidades.dart';
import '../widgets/caratula.dart';
import '../widgets/comunes.dart';
import '../widgets/avisos.dart';

/// Todo lo que necesita atención en la colección.
class PantallaPendientes extends ConsumerStatefulWidget {
  const PantallaPendientes({super.key});

  @override
  ConsumerState<PantallaPendientes> createState() => _PantallaPendientesState();
}

class _PantallaPendientesState extends ConsumerState<PantallaPendientes> {
  TipoPendiente? _tipo;
  bool _verRevisados = false;

  /// Cuántos se enseñan (las listas largas se van mostrando por partes).
  int _mostrar = _porTanda;
  static const _porTanda = 40;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final todos = ref.watch(pendientesProvider);
    // Al entrar se abre el primer tipo que tenga algo.
    final tipo = _tipo ??= TipoPendiente.values.firstWhere(
      (t) => todos.pendientes[t]!.isNotEmpty,
      orElse: () => TipoPendiente.duplicadas,
    );
    final lista = todos.pendientes[tipo]!;
    final revisados = todos.revisados[tipo]!;

    return PaginaBase(
      separacion: 24,
      children: [
        CabeceraPagina(
          titulo: 'Pendientes',
          descripcion:
              'Todo lo que necesita tu atención en la colección. La app solo '
              'avisa: no cambia ni borra nada del disco.',
          acciones: [
            if (tipo == TipoPendiente.desaparecidas && lista.length > 1)
              OutlinedButton.icon(
                onPressed: () => _quitarDelCatalogo(lista),
                icon: const Icon(Icons.playlist_remove_rounded, size: 18),
                label: const Text('Quitar todas del catálogo'),
              ),
          ],
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final t in TipoPendiente.values)
              _pestana(context, t, todos.pendientes[t]!.length),
          ],
        ),
        Text(
          tipo.descripcion,
          style: TextStyle(fontSize: 14, height: 1.5, color: c.textoSuave),
        ),
        if (lista.isEmpty)
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
        for (final p in lista.take(_mostrar)) _elemento(context, p),
        if (lista.length > _mostrar)
          Center(
            child: OutlinedButton(
              onPressed: () => setState(() => _mostrar += _porTanda * 2),
              child: Text(
                'Ver más (quedan ${formatoNumero(lista.length - _mostrar)})',
              ),
            ),
          ),
        if (revisados.isNotEmpty) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() => _verRevisados = !_verRevisados),
              icon: Icon(
                _verRevisados
                    ? Icons.expand_less_rounded
                    : Icons.expand_more_rounded,
              ),
              label: Text(
                '${_verRevisados ? 'Ocultar' : 'Ver'} '
                '${revisados.length == 1 ? 'la marcada' : 'las ${formatoNumero(revisados.length)} marcadas'}'
                ' como revisada${revisados.length == 1 ? '' : 's'}',
              ),
            ),
          ),
          if (_verRevisados)
            for (final p in revisados) _elemento(context, p, revisado: true),
        ],
      ],
    );
  }

  Widget _pestana(BuildContext context, TipoPendiente t, int total) {
    final c = context.colores;
    final marcada = t == _tipo;
    return Material(
      color: marcada ? c.doradoFondo : c.superficie,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: marcada ? c.dorado : c.borde),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => setState(() {
          _tipo = t;
          _mostrar = _porTanda;
          _verRevisados = false;
        }),
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
              Insignia(total, destacada: marcada),
            ],
          ),
        ),
      ),
    );
  }

  Widget _elemento(
    BuildContext context,
    Pendiente pendiente, {
    bool revisado = false,
  }) {
    final c = context.colores;
    final p = pendiente.pelicula;
    final conectado = ref.watch(discoConectadoProvider).value ?? true;
    final esDuplicada = pendiente.tipo == TipoPendiente.duplicadas;
    final esDesaparecida = pendiente.tipo == TipoPendiente.desaparecidas;
    final estiloRuta = TextStyle(
      fontFamily: fuenteRutas,
      fontSize: 12,
      height: 1.5,
      color: c.textoSecundario,
    );

    final botones = <Widget>[
      if (revisado)
        OutlinedButton(
          onPressed: () => ref
              .read(revisadosProvider.notifier)
              .marcar(pendiente.clave, revisado: false),
          child: const Text('Volver a mostrar'),
        )
      else if (esDesaparecida)
        FilledButton(
          onPressed: () => _quitarDelCatalogo([pendiente]),
          child: const Text('Quitar del catálogo'),
        )
      else ...[
        if (!esDuplicada) ...[
          if (pendiente.tipo == TipoPendiente.sinCaratula ||
              pendiente.tipo == TipoPendiente.fueraDeFormato)
            OutlinedButton(
              onPressed: conectado ? () => _abrirCarpeta(p) : null,
              child: const Text('Abrir carpeta'),
            ),
          OutlinedButton(
            onPressed: () => context.push('/pelicula/${p.id}'),
            child: const Text('Ver ficha'),
          ),
        ],
        FilledButton.tonal(
          onPressed: () =>
              ref.read(revisadosProvider.notifier).marcar(pendiente.clave),
          child: Text(esDuplicada ? 'Marcar como revisada' : 'Ignorar'),
        ),
      ],
    ];

    return Opacity(
      opacity: revisado ? 0.7 : 1,
      child: Tarjeta(
        radio: 12,
        relleno: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 16,
              runSpacing: 12,
              children: [
                SizedBox(width: 44, child: Caratula.de(p, mostrarNueva: false)),
                ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: 280,
                    maxWidth: 560,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.anio > 0 ? '${p.titulo} (${p.anio})' : p.titulo,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      for (final m in pendiente.motivos) ...[
                        const SizedBox(height: 3),
                        Text(
                          m,
                          style: TextStyle(
                            fontSize: 13,
                            color: esDesaparecida || esDuplicada
                                ? c.textoSuave
                                : c.doradoTexto,
                          ),
                        ),
                      ],
                      if (!esDuplicada) ...[
                        const SizedBox(height: 3),
                        SelectableText(p.ruta, style: estiloRuta),
                      ],
                    ],
                  ),
                ),
                Wrap(spacing: 8, runSpacing: 8, children: botones),
              ],
            ),
            if (esDuplicada)
              for (final copia in pendiente.peliculas)
                _copia(context, copia, conectado, estiloRuta),
          ],
        ),
      ),
    );
  }

  /// Una de las copias de una película duplicada.
  Widget _copia(
    BuildContext context,
    Pelicula copia,
    bool conectado,
    TextStyle estiloRuta,
  ) {
    final c = context.colores;
    final datos = [
      if (copia.resolucion.isNotEmpty) copia.resolucion,
      if (copia.tamanoTexto.isNotEmpty) copia.tamanoTexto,
      if (copia.duracionTexto.isNotEmpty) copia.duracionTexto,
    ].join(' · ');
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      decoration: BoxDecoration(
        color: c.superficieAlta,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        spacing: 12,
        runSpacing: 8,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText(copia.ruta, style: estiloRuta),
                if (datos.isNotEmpty)
                  Text(
                    datos,
                    style: TextStyle(fontSize: 12, color: c.textoTenue),
                  ),
              ],
            ),
          ),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton(
                onPressed: conectado ? () => _abrirCarpeta(copia) : null,
                child: const Text('Abrir carpeta'),
              ),
              OutlinedButton(
                onPressed: () => context.push('/pelicula/${copia.id}'),
                child: const Text('Ver ficha'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _abrirCarpeta(Pelicula p) {
    if (!mostrarEnCarpeta(p.ruta)) {
      avisar(context, 'No se ha podido abrir la carpeta.');
    }
  }

  /// Quita del catálogo películas que ya no están en el disco (con
  /// confirmación). El disco no se toca.
  Future<void> _quitarDelCatalogo(List<Pendiente> pendientes) async {
    final n = pendientes.length;
    final titulo = n == 1
        ? '¿Quitar «${pendientes.single.pelicula.titulo}» del catálogo?'
        : '¿Quitar ${formatoNumero(n)} películas del catálogo?';
    final si = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(titulo),
        content: const Text(
          'Ya no están en el disco. Si vuelven a aparecer, se añadirán otra '
          'vez como nuevas. No se borra ningún archivo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Quitar'),
          ),
        ],
      ),
    );
    if (si != true) return;
    await ref.read(catalogoProvider.notifier).quitar([
      for (final p in pendientes) p.pelicula.id,
    ]);
  }
}
