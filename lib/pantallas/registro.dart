import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../errores.dart';
import '../datos/catalogo.dart';
import '../datos/edicion.dart';
import '../disco/escritor.dart';
import '../tema/colores.dart';
import '../utilidades.dart';
import '../widgets/comunes.dart';

/// Registro de cambios: todo lo que la app ha escrito en los `.mp4`, con lo
/// que había antes, y el botón para deshacerlo.
class PantallaRegistro extends ConsumerWidget {
  const PantallaRegistro({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colores;
    final registro = ref.watch(registroProvider);
    return PaginaBase(
      separacion: 22,
      children: [
        const CabeceraPagina(
          titulo: 'Registro de cambios',
          descripcion:
              'Cada vez que la app escribe en un archivo queda anotado aquí, '
              'con los datos que tenía antes. «Deshacer» los vuelve a poner.',
        ),
        switch (registro) {
          AsyncData(value: final filas) when filas.isEmpty => Text(
            'Todavía no se ha escrito nada en los archivos.',
            style: TextStyle(fontSize: 15, color: c.textoSecundario),
          ),
          AsyncData(value: final filas) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final f in filas) _TarjetaCambio(CambioRegistro(f)),
            ],
          ),
          AsyncError(:final error) => Text(
            'No se pudo leer el registro: ${explicarError(error)}',
          ),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ],
    );
  }
}

class _TarjetaCambio extends ConsumerWidget {
  const _TarjetaCambio(this.cambio);

  final CambioRegistro cambio;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colores;
    final f = cambio.fila;
    final carpetas = ref.watch(carpetasAppProvider);
    final existe = ref.watch(peliculaPorIdProvider(f.pelicula)) != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Tarjeta(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                InkWell(
                  onTap: existe
                      ? () => context.push('/pelicula/${f.pelicula}')
                      : null,
                  child: Text(
                    f.titulo,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text(
                  '${fechaHora(f.fecha)} · ${f.origen}',
                  style: TextStyle(fontSize: 13, color: c.textoSecundario),
                ),
                if (cambio.deshecho)
                  Pastilla(
                    'Deshecho el ${fechaHora(f.deshecho!)}',
                    color: c.textoSecundario,
                    fondo: c.seleccion,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            for (final MapEntry(key: campo, value: nuevo)
                in cambio.despues.entries)
              _Linea(
                campo.nombre,
                _legible(campo, cambio.antes[campo] ?? ''),
                _legible(campo, nuevo),
              ),
            if (f.caratula)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    SizedBox(
                      width: 130,
                      child: Text(
                        'Carátula',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: c.textoSuave,
                        ),
                      ),
                    ),
                    _Miniatura(carpetas.copiaCaratula(f.id, antes: true)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Icon(
                        Icons.arrow_forward_rounded,
                        size: 16,
                        color: c.textoSecundario,
                      ),
                    ),
                    _Miniatura(carpetas.copiaCaratula(f.id, antes: false)),
                  ],
                ),
              ),
            if (!cambio.deshecho && esAdministrador) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: () => deshacerCambio(
                    context,
                    ref.read(edicionProvider),
                    f.id,
                    titulo: f.titulo,
                  ),
                  icon: const Icon(Icons.undo_rounded, size: 16),
                  label: const Text('Deshacer'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// «Campo: antes → después».
class _Linea extends StatelessWidget {
  const _Linea(this.nombre, this.antes, this.despues);

  final String nombre;
  final String antes;
  final String despues;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    String corto(String t) => t.isEmpty
        ? '(vacío)'
        : t.length > 140
        ? '${t.substring(0, 140)}…'
        : t;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              nombre,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: c.textoSuave,
              ),
            ),
          ),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: corto(antes),
                    style: TextStyle(
                      color: c.textoSecundario,
                      decoration: antes.isEmpty
                          ? null
                          : TextDecoration.lineThrough,
                    ),
                  ),
                  TextSpan(
                    text: '  →  ',
                    style: TextStyle(color: c.textoTenue),
                  ),
                  TextSpan(
                    text: corto(despues),
                    style: TextStyle(color: c.texto),
                  ),
                ],
              ),
              style: const TextStyle(fontSize: 13, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}

class _Miniatura extends StatelessWidget {
  const _Miniatura(this.ruta);

  final String ruta;

  @override
  Widget build(BuildContext context) {
    final archivo = File(ruta);
    return Container(
      width: 42,
      height: 60,
      decoration: BoxDecoration(
        color: context.colores.superficieAlta,
        borderRadius: BorderRadius.circular(4),
      ),
      clipBehavior: Clip.antiAlias,
      child: archivo.existsSync()
          ? Image.file(archivo, fit: BoxFit.cover, cacheWidth: 84)
          : Center(
              child: Text(
                'sin',
                style: TextStyle(
                  fontSize: 11,
                  color: context.colores.textoTenue,
                ),
              ),
            ),
    );
  }
}

/// Las estrellas se enseñan como estrellas: «3» → «★★★».
String _legible(Campo c, String valor) =>
    c == Campo.estrellas && valor.isNotEmpty
    ? '★' * (int.tryParse(valor) ?? 0)
    : valor;

/// "4/10/2026 13:05"
String fechaHora(DateTime f) =>
    '${f.day}/${f.month}/${f.year} ${f.hour}:${f.minute.toString().padLeft(2, '0')}';

/// Ventana de espera mientras se escribe en un archivo (no se puede cerrar).
/// Se cierra con `Navigator.of(context, rootNavigator: true).pop()`.
void mostrarGuardando(BuildContext context, String texto) {
  showDialog<void>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: false,
    builder: (context) => PopScope(
      canPop: false,
      child: AlertDialog(
        content: Row(
          children: [
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(texto, style: const TextStyle(fontSize: 15)),
                  const SizedBox(height: 6),
                  Text(
                    'Windows reescribe el archivo entero y después se '
                    'comprueba: en el disco duro tarda unos segundos.',
                    style: TextStyle(
                      fontSize: 13,
                      color: context.colores.textoSecundario,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Future<void> mostrarError(BuildContext context, String titulo, String texto) =>
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(Icons.error_outline_rounded, color: context.colores.rojo),
        title: Text(titulo),
        content: Text(texto),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );

/// Pide confirmación y deshace el cambio [id] del registro. Si la ficha ha
/// vuelto a cambiar después, lo avisa antes.
Future<void> deshacerCambio(
  BuildContext context,
  Edicion edicion,
  int id, {
  required String titulo,
}) async {
  final mensajero = ScaffoldMessenger.of(context);
  final navegador = Navigator.of(context, rootNavigator: true);
  var esperando = false;
  try {
    final conflictos = await edicion.conflictos(id);
    if (!context.mounted) return;
    final si = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Deshacer este cambio?'),
        content: Text(
          conflictos.isEmpty
              ? 'Se volverán a escribir en «$titulo» los datos que tenía antes.'
              : 'Después de este cambio se ha vuelto a modificar: '
                    '${conflictos.join(', ')}. Si lo deshaces, esos campos '
                    'también vuelven a como estaban antes de este cambio.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Deshacer'),
          ),
        ],
      ),
    );
    if (si != true || !context.mounted) return;
    mostrarGuardando(context, 'Deshaciendo el cambio…');
    esperando = true;
    await edicion.deshacer(id);
    navegador.pop();
    esperando = false;
    mensajero
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text('Hecho: «$titulo» vuelve a estar como antes.')),
      );
  } on Exception catch (e) {
    if (esperando) navegador.pop();
    final contexto = navegador.context;
    if (contexto.mounted) {
      await mostrarError(
        contexto,
        'No se ha podido deshacer',
        e is EscrituraException ? e.mensaje : explicarError(e),
      );
    }
  }
}
