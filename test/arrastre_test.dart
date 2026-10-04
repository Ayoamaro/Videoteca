import 'package:flutter_test/flutter_test.dart';

import 'package:videoteca/disco/arrastre.dart';

// Archivos arrastrados a la ventana: lo recibe la última pantalla que
// escucha. (El arrastre real desde el Explorador se ha probado a mano con la
// app compilada.)

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('lo soltado llega a la última pantalla que escucha', () async {
    final arrastre = ArrastreArchivos.instancia;
    final primera = <String>[];
    final segunda = <String>[];
    void a(List<String> r) => primera.addAll(r);
    void b(List<String> r) => segunda.addAll(r);

    arrastre.escuchar(a);
    arrastre.escuchar(b);
    await simularSoltar([r'C:\caratulas\joy.jpg']);
    expect(segunda, [r'C:\caratulas\joy.jpg']);
    expect(primera, isEmpty);

    arrastre.dejar(b);
    await simularSoltar([r'C:\caratulas\otra.png']);
    expect(primera, [r'C:\caratulas\otra.png']);
    expect(arrastre.encima.value, isFalse);
    arrastre.dejar(a);
  });
}
