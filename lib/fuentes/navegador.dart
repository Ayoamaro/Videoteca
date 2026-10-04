import 'dart:async';
import 'dart:convert';
import 'dart:io';

// Una ventana de Microsoft Edge (el navegador que trae Windows) controlada
// por la app, para leer FilmAffinity, que no deja leer sus páginas con
// peticiones automáticas: se ve en pantalla, la manejas tú (buscar, aceptar
// o rechazar las cookies…) y la app solo lee la página que tienes abierta.
//
// Se usa el protocolo de depuración de Chromium (DevTools) por WebSocket,
// sin plugins de Flutter. Edge se abre con un perfil propio de la app
// (`%LOCALAPPDATA%\Videoteca\navegador`), separado del tuyo.
//
// No usa nada de Flutter.

class NavegadorException implements Exception {
  const NavegadorException(this.mensaje);
  final String mensaje;

  @override
  String toString() => mensaje;
}

/// Una página abierta en el navegador.
typedef PaginaNavegador = ({String id, String url, String titulo});

class Navegador {
  Navegador._(this._perfil, this._puerto);

  final String _perfil;
  final int _puerto;

  /// Dónde está `msedge.exe`, o `null` si no está instalado.
  static String? rutaEdge() {
    final candidatos = [
      for (final v in ['ProgramFiles(x86)', 'ProgramFiles', 'LOCALAPPDATA'])
        if (Platform.environment[v] case final base?)
          '$base\\Microsoft\\Edge\\Application\\msedge.exe',
    ];
    for (final c in candidatos) {
      if (File(c).existsSync()) return c;
    }
    return null;
  }

  /// Abre (o reutiliza, si ya está abierta) la ventana del navegador con el
  /// perfil de la carpeta [perfil], y va a [url].
  static Future<Navegador> abrir(String url, {required String perfil}) async {
    final existente = await _conectar(perfil);
    if (existente != null) {
      await existente.ir(url);
      return existente;
    }
    final edge = rutaEdge();
    if (edge == null) {
      throw const NavegadorException(
        'No encuentro Microsoft Edge en este PC. Hace falta para leer '
        'FilmAffinity.',
      );
    }
    Directory(perfil).createSync(recursive: true);
    final puertoArchivo = File('$perfil\\DevToolsActivePort');
    if (puertoArchivo.existsSync()) puertoArchivo.deleteSync();
    await Process.start(edge, [
      // Puerto 0: Edge elige uno libre y lo apunta en DevToolsActivePort.
      '--remote-debugging-port=0',
      '--user-data-dir=$perfil',
      '--no-first-run',
      '--no-default-browser-check',
      '--window-size=1100,950',
      // Ventana sencilla, sin pestañas ni barra de direcciones.
      '--app=$url',
    ], mode: ProcessStartMode.detached);
    for (var i = 0; i < 100; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 150));
      final n = await _conectar(perfil);
      if (n != null) return n;
    }
    throw const NavegadorException(
      'Edge no ha arrancado (o no deja controlar la ventana).',
    );
  }

  /// El navegador del perfil [perfil] si está abierto y responde.
  static Future<Navegador?> _conectar(String perfil) async {
    final archivo = File('$perfil\\DevToolsActivePort');
    if (!archivo.existsSync()) return null;
    final puerto = int.tryParse(
      archivo.readAsLinesSync().firstOrNull?.trim() ?? '',
    );
    if (puerto == null) return null;
    final n = Navegador._(perfil, puerto);
    return await n.abierto() ? n : null;
  }

  /// Sigue abierto (no has cerrado la ventana).
  Future<bool> abierto() async {
    try {
      await _pedir('/json/version');
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<Object?> _pedir(String ruta, {String metodo = 'GET'}) async {
    final cliente = HttpClient()
      ..connectionTimeout = const Duration(seconds: 2);
    try {
      final peticion = await cliente.openUrl(
        metodo,
        Uri.parse('http://127.0.0.1:$_puerto$ruta'),
      );
      final respuesta = await peticion.close().timeout(
        const Duration(seconds: 5),
      );
      final texto = await respuesta.transform(utf8.decoder).join();
      if (respuesta.statusCode != 200) {
        throw NavegadorException('Edge ha respondido ${respuesta.statusCode}');
      }
      return texto.isEmpty ? null : jsonDecode(texto);
    } finally {
      cliente.close(force: true);
    }
  }

  /// Las páginas abiertas (sin las internas de Edge).
  Future<List<PaginaNavegador>> paginas() async {
    final lista = await _pedir('/json/list') as List;
    return [
      for (final p in lista.cast<Map>())
        if (p['type'] == 'page' &&
            '${p['url']}'.startsWith(RegExp('https?://')))
          (id: '${p['id']}', url: '${p['url']}', titulo: '${p['title']}'),
    ];
  }

  /// La página que estás viendo (la primera de la lista: Edge pone delante
  /// la última activada), o `null` si no hay ninguna.
  Future<PaginaNavegador?> paginaActual() async =>
      (await paginas()).firstOrNull;

  /// Lleva la página actual a [url] y pone la ventana delante.
  Future<void> ir(String url) async {
    final pagina = await paginaActual();
    if (pagina == null) {
      await _pedir('/json/new?${Uri.encodeFull(url)}', metodo: 'PUT');
      return;
    }
    await _orden(pagina.id, 'Page.navigate', {'url': url});
    await mostrar();
  }

  /// El HTML de la página [id] tal como está ahora (con lo que haya añadido
  /// la propia página), o `null` si todavía está cargando.
  Future<String?> html(String id) async {
    final r = await _orden(id, 'Runtime.evaluate', {
      'expression':
          "document.readyState === 'loading' ? null : "
          'document.documentElement.outerHTML',
      'returnByValue': true,
    });
    final valor = (r['result'] as Map?)?['value'];
    return valor is String ? valor : null;
  }

  /// Minimiza la ventana (para volver a ver la app).
  Future<void> minimizar() => _estadoVentana('minimized');

  /// Vuelve a enseñar la ventana, delante de todo.
  Future<void> mostrar() async {
    await _estadoVentana('normal');
    if (await paginaActual() case final pagina?) {
      await _orden(pagina.id, 'Page.bringToFront');
    }
  }

  Future<void> _estadoVentana(String estado) async {
    final pagina = await paginaActual();
    if (pagina == null) return;
    final ventana = await _orden(null, 'Browser.getWindowForTarget', {
      'targetId': pagina.id,
    });
    await _orden(null, 'Browser.setWindowBounds', {
      'windowId': ventana['windowId'],
      'bounds': {'windowState': estado},
    });
  }

  /// Cierra la ventana.
  Future<void> cerrar() async {
    try {
      await _orden(null, 'Browser.close');
    } catch (_) {
      // Ya estaba cerrada.
    }
  }

  /// Manda una orden de DevTools a la página [id] (o al navegador entero si
  /// es `null`) y espera la respuesta.
  Future<Map> _orden(
    String? id,
    String metodo, [
    Map<String, Object?> parametros = const {},
  ]) async {
    final direccion = id == null
        ? '${(await _pedir('/json/version') as Map)['webSocketDebuggerUrl']}'
        : 'ws://127.0.0.1:$_puerto/devtools/page/$id';
    final ws = await WebSocket.connect(direccion)
        .timeout(const Duration(seconds: 5));
    try {
      ws.add(jsonEncode({'id': 1, 'method': metodo, 'params': parametros}));
      await for (final mensaje in ws.timeout(const Duration(seconds: 15))) {
        final json = jsonDecode(mensaje as String) as Map;
        if (json['id'] != 1) continue;
        if (json['error'] case final Map error) {
          throw NavegadorException('Edge: ${error['message']}');
        }
        return (json['result'] as Map?) ?? const {};
      }
      throw const NavegadorException('Edge no ha contestado.');
    } on TimeoutException {
      throw const NavegadorException('Edge no ha contestado a tiempo.');
    } finally {
      await ws.close();
    }
  }

  @override
  String toString() => 'Navegador($_perfil, puerto $_puerto)';
}
