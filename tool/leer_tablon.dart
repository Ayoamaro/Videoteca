// Lee el tablón publicado como lo hará el móvil: sin llave de GitHub,
// descargando el último commit y descifrándolo.
//
//   dart run tool/leer_tablon.dart usuario/repositorio [contraseña]
//
// Sin contraseña usa la llave guardada en este PC (la que usa la app para
// publicar). Comprueba que todos los paquetes se descifran y enseña unos
// números.

// ignore_for_file: avoid_print

import 'dart:io';

import 'package:videoteca/datos/base_datos.dart';
import 'package:videoteca/datos/carpetas_app.dart';
import 'package:videoteca/tablon/cifrado.dart';
import 'package:videoteca/tablon/formato.dart';
import 'package:videoteca/tablon/lector.dart';

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    stderr.writeln(
      'Uso: dart run tool/leer_tablon.dart usuario/repositorio [contraseña]',
    );
    exit(64);
  }
  final lector = LectorTablon(args[0]);
  final reloj = Stopwatch()..start();
  final commit = await lector.ultimoCommit();
  print('Último commit: $commit');
  final parametros = await lector.parametros(commit);

  final LlaveTablon llave;
  if (args.length > 1) {
    llave = await derivarLlave(args[1], parametros);
    print('Llave sacada de la contraseña en ${reloj.elapsedMilliseconds} ms');
  } else {
    final bd = BaseDatos.abrir(CarpetasApp(carpetaDatosApp()).baseDatos);
    final texto = (await bd.todosLosAjustes())['llaveTablon'] ?? '';
    await bd.close();
    if (texto.isEmpty) {
      stderr.writeln('No hay llave guardada en este PC: pasa la contraseña.');
      exit(1);
    }
    llave = LlaveTablon.desdeTexto(texto);
    print('Usando la llave guardada en este PC');
  }

  final IndiceTablon indice;
  try {
    indice = await lector.indice(commit, llave);
  } on ContrasenaIncorrecta {
    stderr.writeln('La contraseña no es correcta.');
    exit(1);
  }
  print(
    'Versión ${indice.version} del ${indice.fecha.toLocal()} · '
    '${indice.peliculas} películas · ${indice.catalogo.length} paquetes de '
    'fichas y ${indice.caratulas.length} de carátulas',
  );

  var fichas = 0, caratulas = 0, bytes = 0;
  Map<String, dynamic>? ejemplo;
  for (final grupo in indice.catalogo.keys) {
    final lista = await lector.catalogo(commit, grupo, llave);
    fichas += lista.length;
    ejemplo ??= lista.first;
  }
  for (final grupo in indice.caratulas.keys) {
    final imagenes = await lector.caratulas(commit, grupo, llave);
    caratulas += imagenes.length;
    bytes += imagenes.values.fold(0, (s, i) => s + i.length);
  }
  lector.cerrar();
  print(
    'Descifradas $fichas fichas y $caratulas carátulas '
    '(${(bytes / 1024 / 1024).toStringAsFixed(1)} MB de imágenes) en '
    '${(reloj.elapsedMilliseconds / 1000).toStringAsFixed(1)} s',
  );
  if (fichas != indice.peliculas) {
    stderr.writeln('¡Faltan fichas! ($fichas de ${indice.peliculas})');
    exit(1);
  }
  print(
    'Ejemplo: ${ejemplo?['titulo']} (${ejemplo?['anio']}) · '
    '${ejemplo?['direccion']} · ${ejemplo?['ruta']}',
  );
}
