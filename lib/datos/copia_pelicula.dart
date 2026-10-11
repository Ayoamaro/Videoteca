import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../disco/copiador.dart';
import '../disco/dialogo_abrir.dart' as dialogos;
import '../modelos/pelicula.dart';

// Copiar una película a un disco o pendrive del PC donde se está: una cada
// vez, en segundo plano (se puede seguir usando la app), con la barra de
// progreso en la ficha y en el menú. Ver `disco/copiador.dart`.

/// Lo que se hace de verdad con las unidades y los archivos (en las pruebas
/// se cambia por uno de mentira).
class ServicioCopia {
  const ServicioCopia();

  /// Unidades de este PC; con [archivo], cada una dice si ya lo tiene.
  Future<List<Unidad>> unidades({String? archivo}) => _unidadesAparte(archivo);

  /// Formato y espacio libre del disco de [carpeta].
  Future<Volumen?> volumen(String carpeta) => _volumenAparte(carpeta);

  /// Lo que ocupa [ruta] si ya existe; `null` si no está.
  Future<int?> existente(String ruta) async {
    try {
      final f = File(ruta);
      return await f.exists().timeout(const Duration(seconds: 8))
          ? await f.length()
          : null;
    } on Object {
      return null;
    }
  }

  /// El diálogo de Windows para elegir una carpeta (`null` si se cancela).
  String? elegirCarpeta() =>
      dialogos.elegirCarpeta(titulo: '¿Dónde quieres guardar la película?');

  TrabajoCopia copiar(
    String origen,
    String destino, {
    bool reemplazar = false,
    bool borrarAntes = false,
  }) => copiarAparte(
    origen,
    destino,
    reemplazar: reemplazar,
    borrarAntes: borrarAntes,
  );
}

final servicioCopiaProvider = Provider<ServicioCopia>(
  (ref) => const ServicioCopia(),
);

enum EtapaCopia { copiando, comprobando, cancelando, hecha, cancelada, fallo }

/// La copia en marcha (o la última, hasta que se cierra su aviso).
class CopiaPelicula {
  const CopiaPelicula({
    required this.id,
    required this.titulo,
    required this.origen,
    required this.destino,
    this.etapa = EtapaCopia.copiando,
    this.copiados = 0,
    this.total = 0,
    this.velocidad,
    this.parada = false,
    this.resultado,
  });

  /// La película (su id en el catálogo).
  final int id;
  final String titulo;
  final String origen;

  /// Ruta completa de la copia: `E:\Películas\Joy (2015).mp4`.
  final String destino;
  final EtapaCopia etapa;
  final int copiados;
  final int total;

  /// Bytes por segundo en los últimos segundos (`null` mientras se calcula).
  final double? velocidad;

  /// Hace un rato que no llega nada (el PC de las películas no contesta, el
  /// pendrive se ha quedado parado…).
  final bool parada;
  final ResultadoCopia? resultado;

  bool get enMarcha =>
      etapa == EtapaCopia.copiando ||
      etapa == EtapaCopia.comprobando ||
      etapa == EtapaCopia.cancelando;

  /// Carpeta de la copia: `E:\Películas`.
  String get carpeta => destino.substring(0, destino.lastIndexOf(r'\'));

  double? get fraccion =>
      total <= 0 ? null : (copiados / total).clamp(0, 1).toDouble();

  int get porcentaje => ((fraccion ?? 0) * 100).floor();

  Duration? get restante {
    final v = velocidad;
    if (v == null || v <= 0 || parada) return null;
    return Duration(seconds: ((total - copiados) / v).ceil());
  }

  CopiaPelicula _con({
    EtapaCopia? etapa,
    int? copiados,
    int? total,
    double? velocidad,
    bool sinVelocidad = false,
    bool? parada,
    ResultadoCopia? resultado,
  }) => CopiaPelicula(
    id: id,
    titulo: titulo,
    origen: origen,
    destino: destino,
    etapa: etapa ?? this.etapa,
    copiados: copiados ?? this.copiados,
    total: total ?? this.total,
    velocidad: sinVelocidad ? null : velocidad ?? this.velocidad,
    parada: parada ?? this.parada,
    resultado: resultado ?? this.resultado,
  );
}

final copiaPeliculaProvider = NotifierProvider<CopiaEnCurso, CopiaPelicula?>(
  CopiaEnCurso.new,
);

class CopiaEnCurso extends Notifier<CopiaPelicula?> {
  /// La velocidad se calcula con lo copiado en estos últimos segundos.
  static const ventana = Duration(seconds: 6);

  /// Sin recibir nada durante este rato, la copia se da por parada.
  static const sinDatos = Duration(seconds: 6);

  TrabajoCopia? _trabajo;
  StreamSubscription<AvanceCopia>? _avance;
  Timer? _reloj;
  final _muestras = <(DateTime, int)>[];
  Completer<void>? _terminada;

  @override
  CopiaPelicula? build() {
    // Al cerrar la sesión (o la app) no se deja nada a medias.
    ref.onDispose(() {
      _trabajo?.cancelar();
      _avance?.cancel();
      _reloj?.cancel();
    });
    return null;
  }

  bool get ocupada => state?.enMarcha ?? false;

  /// Empieza a copiar [p] (que desde aquí está en [origen]) a [carpeta].
  /// Si ya hay una copia en marcha, no hace nada: una película cada vez.
  void empezar(
    Pelicula p, {
    required String origen,
    required String carpeta,
    bool reemplazar = false,
    bool borrarAntes = false,
  }) {
    if (ocupada) return;
    final base = carpeta.endsWith(r'\') ? carpeta : '$carpeta\\';
    final destino = '$base${p.archivo}';
    final trabajo = ref
        .read(servicioCopiaProvider)
        .copiar(
          origen,
          destino,
          reemplazar: reemplazar,
          borrarAntes: borrarAntes,
        );
    _trabajo = trabajo;
    _muestras
      ..clear()
      ..add((DateTime.now(), 0));
    state = CopiaPelicula(
      id: p.id,
      titulo: p.titulo,
      origen: origen,
      destino: destino,
      total: p.tamanoBytes,
    );
    _avance = trabajo.avance.listen(_alAvanzar);
    _reloj?.cancel();
    _reloj = Timer.periodic(const Duration(seconds: 1), (_) => _calcular());
    trabajo.resultado.then((r) => _alTerminar(trabajo, r));
  }

  void _alAvanzar(AvanceCopia a) {
    final c = state;
    if (c == null || !c.enMarcha) return;
    _muestras.add((DateTime.now(), a.copiados));
    state = c._con(
      copiados: a.copiados,
      total: a.total,
      etapa: c.etapa == EtapaCopia.cancelando
          ? EtapaCopia.cancelando
          : a.comprobando
          ? EtapaCopia.comprobando
          : EtapaCopia.copiando,
      parada: false,
    );
  }

  /// Velocidad y si está parada, con lo que ha llegado en los últimos
  /// segundos.
  void _calcular() {
    final c = state;
    if (c == null || c.etapa != EtapaCopia.copiando) return;
    final ahora = DateTime.now();
    while (_muestras.length > 1 &&
        ahora.difference(_muestras.first.$1) > ventana) {
      _muestras.removeAt(0);
    }
    final (desde, alPrincipio) = _muestras.first;
    final (ultima, _) = _muestras.last;
    if (ahora.difference(ultima) > sinDatos) {
      state = c._con(parada: true, velocidad: 0);
      return;
    }
    final segundos = ahora.difference(desde).inMilliseconds / 1000;
    state = segundos < 1.5
        ? c._con(sinVelocidad: true)
        : c._con(velocidad: (c.copiados - alPrincipio) / segundos);
  }

  void _alTerminar(TrabajoCopia trabajo, ResultadoCopia r) {
    if (!ref.mounted || _trabajo != trabajo) return;
    _trabajo = null;
    _avance?.cancel();
    _reloj?.cancel();
    final c = state;
    if (c != null) {
      state = c._con(
        etapa: switch (r.fin) {
          FinCopia.hecha => EtapaCopia.hecha,
          FinCopia.cancelada => EtapaCopia.cancelada,
          FinCopia.yaExiste || FinCopia.fallo => EtapaCopia.fallo,
        },
        copiados: r.fin == FinCopia.hecha ? c.total : null,
        resultado: r,
      );
    }
    _terminada?.complete();
    _terminada = null;
  }

  /// Para la copia y borra lo copiado.
  void cancelar() {
    final c = state;
    if (c == null || !c.enMarcha) return;
    state = c._con(etapa: EtapaCopia.cancelando);
    _trabajo?.cancelar();
  }

  /// Cancela y espera (como mucho [limite]) a que se haya borrado lo
  /// copiado: al cerrar la app.
  Future<void> cancelarYEsperar({
    Duration limite = const Duration(seconds: 10),
  }) async {
    if (!ocupada) return;
    final terminada = _terminada ??= Completer<void>();
    cancelar();
    await terminada.future.timeout(limite, onTimeout: () {});
  }

  /// Quita el aviso de la última copia (cuando ya ha terminado).
  void cerrar() {
    if (!ocupada) state = null;
  }
}

/// Por qué no se ha podido copiar, para enseñarlo. [disco] es el disco de
/// la colección en el PC del administrador («el disco D:»); en un PC de la
/// red de casa, `null`.
String textoFalloCopia(
  ResultadoCopia r, {
  required String carpeta,
  String? disco,
}) {
  final texto = switch (r.fallo) {
    FalloCopia.origenSinConexion when disco != null =>
      'Se ha desconectado $disco (el de las películas) antes de terminar.',
    FalloCopia.origenSinConexion =>
      'Se ha perdido la conexión con el PC de las películas antes de '
          'terminar: puede que se haya apagado o que se haya cortado la red.',
    FalloCopia.origenNoEsta when disco != null =>
      'La película ya no está en el disco: puede que se haya movido o '
          'borrado.',
    FalloCopia.origenNoEsta =>
      'La película ya no está en el PC de las películas: puede que se haya '
          'movido o borrado.',
    FalloCopia.origenIlegible =>
      'No se ha podido leer la película. ${r.detalle ?? ''}',
    FalloCopia.destinoQuitado =>
      'Se ha quitado el pendrive (o el disco) antes de terminar.',
    FalloCopia.sinEspacio => 'No cabe: se ha llenado el disco de destino.',
    FalloCopia.sinPermiso =>
      'Windows no deja guardar en $carpeta. Elige otra carpeta.',
    FalloCopia.protegido =>
      'El pendrive (o la tarjeta) está protegido contra escritura.',
    FalloCopia.formato =>
      'Ese disco está en formato FAT32, que no admite archivos de más de '
          '4 GB.',
    FalloCopia.distinta =>
      'La copia no ha salido igual que la original. Vuelve a intentarlo.',
    _ when r.fin == FinCopia.yaExiste =>
      'Ya hay un archivo con ese nombre en $carpeta.',
    _ => 'No se ha podido copiar. ${r.detalle ?? ''}',
  };
  final restos = r.restos;
  final final_ = restos == null
      ? 'No ha quedado nada a medias.'
      : 'Ha quedado un trozo a medias '
            '(«${restos.substring(restos.lastIndexOf(r'\') + 1)}»): se borra '
            'solo en la próxima copia a esa carpeta, o puedes borrarlo tú.';
  return '${texto.trim()} $final_';
}

// Lo que se lanza a otro hilo va en funciones sueltas (ver `edicion.dart`).

Future<List<Unidad>> _unidadesAparte(String? archivo) =>
    Isolate.run(() => unidadesDeEstePc(archivo: archivo));

Future<Volumen?> _volumenAparte(String carpeta) =>
    Isolate.run(() => volumenDe(carpeta));
