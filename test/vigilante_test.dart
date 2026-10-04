import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:videoteca/disco/vigilante.dart';

void main() {
  final sep = Platform.pathSeparator;

  test('qué cambios merecen una revisión', () {
    expect(esCambioInteresante('D:${sep}Drama${sep}Joy (2015).mp4'), isTrue);
    expect(esCambioInteresante('D:${sep}Drama${sep}Wonka (2023).M4V'), isTrue);
    expect(esCambioInteresante('D:${sep}Drama${sep}Joy.srt'), isFalse);
    expect(esCambioInteresante('D:${sep}Drama', esCarpeta: true), isTrue);
    // Carpeta borrada (Windows ya no puede decir que era carpeta).
    expect(esCambioInteresante('D:${sep}Drama'), isTrue);
    expect(
      esCambioInteresante(r'D:\$RECYCLE.BIN\S-1-5\$R1.mp4'),
      Platform.isWindows ? isFalse : isTrue,
    );
  });

  test('avisa una sola vez por una ráfaga de cambios', () async {
    final raiz = Directory.systemTemp.createTempSync('videoteca_vig_');
    final vigilante = VigilanteCarpeta(
      raiz.path,
      calma: const Duration(milliseconds: 300),
    )..iniciar();
    var avisos = 0;
    final sub = vigilante.cambios.listen((_) => avisos++);
    try {
      // Windows tarda un poco en empezar a vigilar.
      await Future<void>.delayed(const Duration(milliseconds: 300));
      final carpeta = Directory('${raiz.path}${sep}Drama')..createSync();
      for (var i = 0; i < 5; i++) {
        File('${carpeta.path}${sep}Peli $i (2020).mp4').writeAsBytesSync([i]);
      }
      File('${carpeta.path}${sep}notas.txt').writeAsStringSync('hola');
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      expect(avisos, 1);

      // Un archivo que no es vídeo no provoca revisión.
      File('${carpeta.path}${sep}otra.txt').writeAsStringSync('hola');
      await Future<void>.delayed(const Duration(milliseconds: 800));
      expect(avisos, 1);
    } finally {
      await sub.cancel();
      vigilante.cerrar();
      raiz.deleteSync(recursive: true);
    }
  });
}
