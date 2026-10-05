// Comprueba si una contraseña es la contraseña común del tablón, sin
// enseñarla ni guardarla en ningún sitio (no se escribe en la terminal ni
// queda en el historial).
//
//   dart run tool/comprobar_contrasena.dart [usuario/repositorio]
//
// Prueba a abrir el índice del tablón, igual que hace el móvil al entrar.
// No necesita nada más: se puede compilar como un .exe suelto con
// `dart compile exe tool/comprobar_contrasena.dart`.

// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

import 'package:videoteca/tablon/cifrado.dart';
import 'package:videoteca/tablon/lector.dart';

Future<void> main(List<String> args) async {
  final repositorio = args.isNotEmpty ? args[0] : 'Ayoamaro/Videoteca_Tablon';

  stdout.write('Escribe la contraseña común (no se verá) y pulsa Intro: ');
  if (stdin.hasTerminal) stdin.echoMode = false;
  final contrasena = stdin.readLineSync(encoding: utf8) ?? '';
  if (stdin.hasTerminal) stdin.echoMode = true;
  print('');

  // Pistas que no desvelan la contraseña.
  print('Has escrito ${contrasena.runes.length} caracteres.');
  if (contrasena != contrasena.trim()) {
    print('  Ojo: empieza o acaba con un espacio.');
  }
  final raros = contrasena.runes.where((r) => r > 127).length;
  if (raros > 0) print('  Lleva $raros letras con tilde, ñ u otros signos.');

  print('Comprobando con el tablón $repositorio…');
  final lector = LectorTablon(repositorio);
  try {
    // Lo mismo que `comprobarContrasena` (copia_local.dart), sin la base de
    // datos.
    final commit = await lector.ultimoCommit();
    final llave = await derivarLlaveAparte(
      contrasena,
      await lector.parametros(commit),
    );
    final indice = await lector.indice(commit, llave);
    print('✔ Es la contraseña buena (versión ${indice.version} del tablón).');
  } on ContrasenaIncorrecta {
    print('✘ No es la contraseña del tablón.');
  } finally {
    lector.cerrar();
  }
  if (stdin.hasTerminal) {
    stdout.write('Pulsa Intro para cerrar.');
    stdin.readLineSync();
  }
}
