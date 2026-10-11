import 'package:http/http.dart' as http;

import 'conexion.dart';

// ¿Hay una versión nueva de la app? Se mira la última versión publicada en
// GitHub → Releases (la API pública de GitHub, sin llave: el repositorio del
// código tiene que ser público).
//
// No usa nada de Flutter.

/// La versión de esta compilación («0.9.0»): Flutter la pasa sola desde
/// `pubspec.yaml`. Vacía en las pruebas.
const versionApp = String.fromEnvironment('FLUTTER_BUILD_NAME');

/// Dónde se publican las versiones («usuario/nombre»). Lo pone GitHub Actions
/// al compilar (`--dart-define=REPO_APP=…`, ver `publicar.yml`); en una
/// compilación hecha a mano está vacío y no se comprueba nada.
const repoApp = String.fromEnvironment('REPO_APP');

/// Una versión publicada en GitHub → Releases.
class VersionPublicada {
  const VersionPublicada({
    required this.etiqueta,
    required this.enlace,
    this.notas = '',
    this.fecha,
    this.instaladorWindows,
    this.apkAndroid,
  });

  /// «v1.0».
  final String etiqueta;

  /// La página de la versión en GitHub.
  final String enlace;

  /// Las novedades (en Markdown, como se escribieron).
  final String notas;
  final DateTime? fecha;

  /// Descarga directa del instalador (`…-instalador.exe`) y de la APK.
  final String? instaladorWindows;
  final String? apkAndroid;

  /// «1.0» (sin la «v»).
  String get numero => etiqueta.replaceFirst(RegExp('^[vV]'), '');

  /// Las novedades sin las marcas de Markdown, para leerlas tal cual.
  String get notasLimpias => notas
      .replaceAll('\r', '')
      .replaceAll(RegExp(r'\*\*|__|`'), '')
      .replaceAll(RegExp(r'^\s*[-*] ', multiLine: true), '• ')
      // Cursivas: *así* o _así_ (sin tocar «mi_versión»).
      .replaceAllMapped(RegExp(r'\*([^*\n]+)\*'), (m) => m.group(1)!)
      .replaceAllMapped(
        RegExp(r'(?<!\w)_([^_\n]+)_(?!\w)', unicode: true),
        (m) => m.group(1)!,
      )
      .replaceAll(RegExp(r'^#+\s*', multiLine: true), '')
      .replaceAllMapped(RegExp(r'\[([^\]]+)\]\([^)]+\)'), (m) => m.group(1)!)
      .trim();
}

/// `true` si [publicada] («v1.0») es más nueva que [actual] («0.9.0»). Se
/// comparan los números uno a uno (lo que falta cuenta como 0).
bool esMasNueva(String publicada, String actual) {
  List<int> numeros(String v) => [
    for (final parte in v.replaceFirst(RegExp('^[vV]'), '').split('.'))
      int.tryParse(RegExp(r'^\d+').stringMatch(parte) ?? '') ?? 0,
  ];
  final a = numeros(publicada);
  final b = numeros(actual);
  for (var i = 0; i < a.length || i < b.length; i++) {
    final x = i < a.length ? a[i] : 0;
    final y = i < b.length ? b[i] : 0;
    if (x != y) return x > y;
  }
  return false;
}

/// La última versión publicada en [repo], o `null` si no hay ninguna (o el
/// repositorio no es público).
Future<VersionPublicada?> ultimaVersion(
  String repo, {
  http.Client? cliente,
}) async {
  final propio = cliente == null;
  final c = cliente ?? http.Client();
  try {
    final json = await pedirJson(
      c,
      'GitHub',
      Uri.https('api.github.com', '/repos/$repo/releases/latest'),
      cabeceras: {
        'Accept': 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
      },
      interpretar: (codigo, _) => switch (codigo) {
        // Sin versiones publicadas, o repositorio privado.
        404 => _SinVersiones(),
        403 || 429 => FuenteException(
          'GitHub',
          'Demasiadas consultas seguidas: se volverá a mirar más tarde.',
          limite: true,
        ),
        _ => null,
      },
    );
    if (json is! Map<String, Object?>) return null;
    String? descarga(bool Function(String nombre) es) {
      for (final a in (json['assets'] as List?) ?? const []) {
        if (a is Map && es('${a['name']}'.toLowerCase())) {
          return a['browser_download_url'] as String?;
        }
      }
      return null;
    }

    return VersionPublicada(
      etiqueta: json['tag_name'] as String? ?? '',
      enlace:
          json['html_url'] as String? ?? 'https://github.com/$repo/releases',
      notas: json['body'] as String? ?? '',
      fecha: DateTime.tryParse(json['published_at'] as String? ?? ''),
      instaladorWindows: descarga((n) => n.endsWith('.exe')),
      apkAndroid: descarga((n) => n.endsWith('.apk')),
    );
  } on _SinVersiones {
    return null;
  } finally {
    if (propio) c.close();
  }
}

class _SinVersiones extends FuenteException {
  _SinVersiones() : super('GitHub', 'No hay versiones publicadas.');
}
