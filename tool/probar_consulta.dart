// Prueba el modo consulta desde la terminal: descarga (o pone al día) la
// copia del tablón en una carpeta, como hará la app en el móvil.
//
//   dart run tool/probar_consulta.dart <carpeta> [usuario/repositorio] [contraseña]
//
// Sin contraseña usa la llave guardada en este PC (la que usa la app para
// publicar). Deja en <carpeta> una sesión de consulta abierta: lanzando la
// app con LOCALAPPDATA apuntando a la carpeta de encima, entra directamente
// en modo consulta con esa copia. Repetirlo enseña cuánto se baja cuando no
// ha cambiado nada (o solo un poco).

// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

import 'package:videoteca/datos/base_datos.dart';
import 'package:videoteca/datos/carpetas_app.dart';
import 'package:videoteca/datos/sesion.dart';
import 'package:videoteca/tablon/cifrado.dart';
import 'package:videoteca/tablon/copia_local.dart';
import 'package:videoteca/tablon/lector.dart';

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    stderr.writeln(
      'Uso: dart run tool/probar_consulta.dart <carpeta> '
      '[usuario/repositorio] [contraseña]',
    );
    exit(64);
  }
  final carpeta = args[0];

  // Lo guardado en este PC por el administrador.
  final pc = BaseDatos.abrir(CarpetasApp(carpetaDatosApp()).baseDatos);
  final ajustesPc = await pc.todosLosAjustes();
  await pc.close();
  final repositorio = args.length > 1 ? args[1] : ajustesPc['repoTablon'];
  if (repositorio == null || repositorio.isEmpty) {
    stderr.writeln('No hay tablón configurado en este PC: pásalo.');
    exit(1);
  }

  final lector = LectorTablon(repositorio);
  final reloj = Stopwatch()..start();
  final LlaveTablon llave;
  final ParametrosLlave parametros;
  if (args.length > 2) {
    try {
      final r = await comprobarContrasena(lector, args[2]);
      llave = r.llave;
      parametros = r.parametros;
    } on ContrasenaIncorrecta {
      stderr.writeln('La contraseña no es correcta.');
      exit(1);
    }
    print('Contraseña comprobada en ${reloj.elapsedMilliseconds} ms');
  } else {
    llave = LlaveTablon.desdeTexto(ajustesPc['llaveTablon'] ?? '');
    parametros = ParametrosLlave.desdeJson(
      jsonDecode(ajustesPc['parametrosTablon']!) as Map<String, dynamic>,
    );
    print('Usando la llave guardada en este PC');
  }

  final carpetas = CarpetasApp.consulta(carpeta);
  final bd = BaseDatos.abrir(carpetas.baseDatos);
  await bd.guardarAjuste(AjusteConsulta.repositorio, repositorio);
  await bd.guardarAjuste(AjusteConsulta.llave, llave.aTexto());
  await bd.guardarAjuste(
    AjusteConsulta.parametros,
    jsonEncode(parametros.toJson()),
  );
  Sesion(modo: ModoApp.consulta, tablon: repositorio).guardar(carpeta);

  reloj.reset();
  var ultimaFase = '';
  final r = await actualizarCopia(
    lector: lector,
    llave: llave,
    parametros: parametros,
    bd: bd,
    carpetas: carpetas,
    alAvanzar: (p) {
      if (p.fase != ultimaFase || p.hechos == p.total) {
        ultimaFase = p.fase;
        print(
          '  ${p.fase}: ${p.hechos} de ${p.total} '
          '(${(reloj.elapsedMilliseconds / 1000).toStringAsFixed(1)} s)',
        );
      }
    },
  );
  lector.cerrar();
  final filas = await bd.todasLasPeliculas();
  await bd.close();
  final caratulas = Directory(carpetas.miniaturas)
      .listSync()
      .whereType<File>()
      .toList();
  final bytes = caratulas.fold(0, (s, f) => s + f.lengthSync());
  print(
    r.alDia
        ? 'Ya estaba al día (versión ${r.estado.version}).'
        : 'Versión ${r.estado.version}: ${r.primera ? 'primera descarga' : '${r.nuevas} nuevas, ${r.cambiadas} cambiadas, ${r.quitadas} quitadas'} '
              'en ${(reloj.elapsedMilliseconds / 1000).toStringAsFixed(1)} s',
  );
  print(
    'En la copia: ${filas.length} películas y ${caratulas.length} carátulas '
    '(${(bytes / 1024 / 1024).toStringAsFixed(1)} MB)',
  );
}
