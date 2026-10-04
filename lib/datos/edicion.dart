import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../disco/escaner.dart';
import '../disco/escritor.dart';
import '../disco/lector_archivo.dart';
import '../modelos/pelicula.dart';
import 'base_datos.dart';
import 'catalogo.dart';

// Guardar cambios de una ficha en su `.mp4`, con registro y deshacer.
//
// La escritura (lenta: Windows reescribe el archivo) se hace en segundo
// plano. Después se anota en el registro de cambios y se vuelve a leer el
// archivo para que el catálogo quede al día sin esperar al escáner.

final edicionProvider = Provider<Edicion>(Edicion.new);

/// Los últimos cambios escritos en los archivos (pantalla Registro).
final registroProvider = FutureProvider<List<FilaCambio>>(
  (ref) => ref.watch(baseDatosProvider).ultimosCambios(),
);

/// Un cambio del registro ya interpretado.
class CambioRegistro {
  CambioRegistro(this.fila)
    : antes = _decodificar(fila.antes),
      despues = _decodificar(fila.despues);

  final FilaCambio fila;
  final Map<Campo, String> antes;
  final Map<Campo, String> despues;

  bool get deshecho => fila.deshecho != null;

  static Map<Campo, String> _decodificar(String json) => {
    for (final MapEntry(:key, :value)
        in (jsonDecode(json) as Map<String, dynamic>).entries)
      ?Campo.porNombre(key): value as String,
  };
}

class Edicion {
  Edicion(this.ref);

  final Ref ref;

  /// Escribe los [cambios] (y la [caratula], si se da) en el archivo de [p].
  /// Devuelve el número del cambio en el registro, o `null` si no había
  /// nada distinto que guardar. Lanza [EscrituraException] si falla.
  ///
  /// Con [soloVacios] solo se escriben los campos vacíos en el archivo (ver
  /// `escribirFicha`). Con [recargar] en `false` no se vuelve a cargar el
  /// catálogo entero (el lote lo hace de vez en cuando con
  /// [recargarCatalogo]).
  Future<int?> guardar(
    Pelicula p,
    Map<Campo, String> cambios, {
    CaratulaNueva? caratula,
    String origen = 'Editar ficha',
    bool soloVacios = false,
    bool recargar = true,
  }) async {
    final ruta = p.ruta;
    final r = await _escribir(ruta, cambios, caratula, soloVacios);
    if (r.sinCambios) return null;
    final bd = ref.read(baseDatosProvider);
    final id = await bd.anotarCambio(
      CambiosCompanion.insert(
        pelicula: p.id,
        ruta: ruta,
        titulo: p.titulo,
        fecha: DateTime.now(),
        origen: origen,
        antes: _codificar(r.antes),
        despues: _codificar(r.despues),
        caratula: Value(r.caratulaCambiada),
      ),
    );
    if (r.caratulaCambiada) {
      final carpetas = ref.read(carpetasAppProvider);
      for (final (antes, imagen) in [
        (true, r.caratulaAntes),
        (false, r.caratulaDespues),
      ]) {
        if (imagen != null) {
          await File(carpetas.copiaCaratula(id, antes: antes))
              .writeAsBytes(imagen);
        }
      }
    }
    await _actualizarCatalogo(ruta, recargar: recargar);
    return id;
  }

  /// Qué campos del cambio [id] ya no están como se dejaron (porque se han
  /// vuelto a cambiar después). Deshacerlo pisaría esos cambios.
  Future<List<String>> conflictos(int id) async {
    final (cambio, ruta, _, despuesImagen) = await _preparar(id);
    final actual = await _leer(ruta);
    final valores = valoresFicha(actual);
    return [
      for (final MapEntry(key: c, value: texto) in cambio.despues.entries)
        if (valores[c] != texto) c.nombre,
      if (cambio.fila.caratula && !mismaImagen(actual.caratula, despuesImagen))
        'Carátula',
    ];
  }

  /// Deja el archivo como estaba antes del cambio [id]. Lanza
  /// [EscrituraException] si falla.
  Future<void> deshacer(int id, {bool recargar = true}) async {
    final (cambio, ruta, antesImagen, _) = await _preparar(id);
    final caratula = cambio.fila.caratula ? CaratulaNueva(antesImagen) : null;
    final antes = cambio.antes;
    await _escribir(ruta, antes, caratula, false);
    await ref.read(baseDatosProvider).marcarDeshecho(id, DateTime.now());
    await _actualizarCatalogo(ruta, recargar: recargar);
  }

  /// Vuelve a cargar el catálogo (después de guardar varias con
  /// `recargar: false`).
  Future<void> recargarCatalogo() async {
    ref.invalidate(registroProvider);
    await ref.read(catalogoProvider.notifier).recargar(olvidarImagenes: true);
  }

  /// El cambio, dónde está ahora su archivo y las carátulas guardadas.
  Future<(CambioRegistro, String, Uint8List?, Uint8List?)> _preparar(
    int id,
  ) async {
    final fila = await ref.read(baseDatosProvider).cambio(id);
    if (fila == null) throw EscrituraException('Ese cambio ya no existe.');
    if (fila.deshecho != null) {
      throw EscrituraException('Ese cambio ya estaba deshecho.');
    }
    // Si la película se ha movido desde entonces, se sigue a su ruta nueva.
    final ruta =
        ref.read(peliculasPorIdProvider)[fila.pelicula]?.ruta ?? fila.ruta;
    if (!File(ruta).existsSync()) {
      throw EscrituraException(
        'No se encuentra el archivo de «${fila.titulo}» (¿disco '
        'desconectado?).',
      );
    }
    final carpetas = ref.read(carpetasAppProvider);
    Uint8List? leer(bool antes) {
      final f = File(carpetas.copiaCaratula(id, antes: antes));
      return f.existsSync() ? f.readAsBytesSync() : null;
    }

    return (CambioRegistro(fila), ruta, leer(true), leer(false));
  }

  /// Vuelve a leer el archivo y guarda en el catálogo cómo ha quedado (con
  /// su tamaño y fecha nuevos, para que el escáner no lo lea otra vez).
  Future<void> _actualizarCatalogo(String ruta, {bool recargar = true}) async {
    final raiz = ref.read(carpetaRaizProvider) ?? '';
    final datos = File(ruta).statSync();
    final ArchivoEncontrado archivo = (
      ruta: ruta,
      tamano: datos.size,
      modificado: datos.modified,
      creado: datos.changed,
    );
    final lectura = await _leerParaCatalogo(raiz, archivo);
    final id = await ref.read(baseDatosProvider).guardarPelicula(lectura.fila);
    final miniatura = File(ref.read(carpetasAppProvider).miniatura(id));
    if (lectura.miniatura != null) {
      await miniatura.writeAsBytes(lectura.miniatura!);
    } else if (miniatura.existsSync()) {
      await miniatura.delete();
    }
    ref.invalidate(caratulaCompletaProvider(ruta));
    if (recargar) await recargarCatalogo();
  }

  static String _codificar(Map<Campo, String> valores) => jsonEncode({
    for (final MapEntry(:key, :value) in valores.entries) key.name: value,
  });
}

// Trabajos en segundo plano (isolates). Van en funciones sueltas porque lo
// que se lanza a otro hilo no puede llevarse nada de la app (como `ref`),
// y una función dentro de un método se lo llevaría sin querer.

Future<ResultadoEscritura> _escribir(
  String ruta,
  Map<Campo, String> cambios,
  CaratulaNueva? caratula,
  bool soloVacios,
) => Isolate.run(
  () =>
      escribirFicha(ruta, cambios, caratula: caratula, soloVacios: soloVacios),
);

Future<DatosArchivo> _leer(String ruta) => Isolate.run(() => leerArchivo(ruta));

Future<LecturaCatalogo> _leerParaCatalogo(
  String raiz,
  ArchivoEncontrado archivo,
) => Isolate.run(() => leerParaCatalogo(raiz, archivo));
