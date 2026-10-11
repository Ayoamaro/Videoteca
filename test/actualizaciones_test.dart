import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:videoteca/fuentes/actualizaciones.dart';
import 'package:videoteca/fuentes/conexion.dart';

void main() {
  test('qué versión es más nueva', () {
    expect(esMasNueva('v1.0', '0.9.0'), isTrue);
    expect(esMasNueva('v0.10', '0.9.0'), isTrue);
    expect(esMasNueva('v1.0.1', '1.0.0'), isTrue);
    expect(esMasNueva('v1.0', '1.0.0'), isFalse);
    expect(esMasNueva('v0.3', '0.9.0'), isFalse);
    expect(esMasNueva('V2', '1.9.9'), isTrue);
    expect(esMasNueva('v1.1-beta', '1.0.0'), isTrue);
  });

  test('las novedades se leen sin las marcas de Markdown', () {
    const v = VersionPublicada(
      etiqueta: 'v1.0',
      enlace: 'x',
      notas:
          '## Novedades\r\n'
          '- **Revisar dudosas** una a una\r\n'
          '* Ver [el README](https://github.com/a/b) y `Ajustes`\r\n'
          'Pulsa *Novedades y descarga* o _Más tarde_ en mi_versión.',
    );
    expect(v.numero, '1.0');
    expect(
      v.notasLimpias,
      'Novedades\n• Revisar dudosas una a una\n• Ver el README y Ajustes\n'
      'Pulsa Novedades y descarga o Más tarde en mi_versión.',
    );
  });

  test('la última versión publicada en GitHub, con sus descargas', () async {
    final pedidas = <Uri>[];
    final cliente = MockClient((peticion) async {
      pedidas.add(peticion.url);
      expect(peticion.headers['User-Agent'], agenteVideoteca);
      return http.Response.bytes(
        utf8.encode(
          jsonEncode({
            'tag_name': 'v1.0',
            'html_url': 'https://github.com/a/b/releases/tag/v1.0',
            'body': 'Versión **1.0**',
            'published_at': '2026-10-20T10:00:00Z',
            'assets': [
              {
                'name': 'Videoteca-1.0.0.apk',
                'browser_download_url': 'https://x/Videoteca-1.0.0.apk',
              },
              {
                'name': 'Videoteca-1.0.0-instalador.exe',
                'browser_download_url': 'https://x/instalador.exe',
              },
              {'name': 'SHA256SUMS.txt', 'browser_download_url': 'https://x/s'},
            ],
          }),
        ),
        200,
      );
    });
    final v = await ultimaVersion('a/b', cliente: cliente);
    expect(
      pedidas.single.toString(),
      'https://api.github.com/repos/a/b/releases/latest',
    );
    expect(v!.etiqueta, 'v1.0');
    expect(v.instaladorWindows, 'https://x/instalador.exe');
    expect(v.apkAndroid, 'https://x/Videoteca-1.0.0.apk');
    expect(v.fecha, DateTime.utc(2026, 10, 20, 10));
    expect(v.notasLimpias, 'Versión 1.0');
  });

  test(
    'sin versiones (o repositorio privado) no hay nada que avisar',
    () async {
      final cliente = MockClient(
        (_) async => http.Response('{"message":"Not Found"}', 404),
      );
      expect(await ultimaVersion('a/b', cliente: cliente), isNull);
    },
  );

  test('demasiadas consultas: error claro, sin romper nada', () async {
    final cliente = MockClient(
      (_) async => http.Response('{"message":"API rate limit exceeded"}', 403),
    );
    await expectLater(
      ultimaVersion('a/b', cliente: cliente),
      throwsA(isA<FuenteException>().having((e) => e.limite, 'limite', isTrue)),
    );
  });
}
