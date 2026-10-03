import 'package:flutter_test/flutter_test.dart';

import 'package:videoteca/main.dart';

void main() {
  testWidgets('La app arranca y muestra el título', (tester) async {
    await tester.pumpWidget(const VideotecaApp());

    expect(find.text('Videoteca'), findsOneWidget);
  });
}
