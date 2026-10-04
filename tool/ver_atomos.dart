// Diagnóstico (solo lectura): enseña las cajas de primer nivel de unos `.mp4`
// y cómo guarda Windows cada propiedad (texto suelto o lista de valores).
//
//     dart run tool/ver_atomos.dart D:\ [cuántos]
import 'dart:io';
import 'dart:typed_data';

import 'package:videoteca/disco/escaner.dart';
import 'package:videoteca/disco/lector_archivo.dart';
import 'package:videoteca/disco/propiedades_windows.dart';

void main(List<String> args) {
  final raiz = args.isEmpty ? r'D:\' : args[0];
  final cuantos = args.length > 1 ? int.parse(args[1]) : 8;
  final archivos = [for (final a in buscarMp4(raiz)) File(a.ruta)]..shuffle();
  for (final f in archivos.take(cuantos)) {
    stdout.writeln('\n${f.path}  (${f.lengthSync() ~/ 1048576} MB)');
    stdout.writeln('  cajas: ${cajas(f.path).join('  ')}');
    final props = leerPropiedadesWindows(
      f.path,
      propiedadesLeidas.keys.toList(),
    );
    for (final MapEntry(:key, :value) in props.entries) {
      final tipo = value is List
          ? 'lista(${value.length})'
          : '${value.runtimeType}';
      var texto = '$value';
      if (texto.length > 70) texto = '${texto.substring(0, 70)}…';
      stdout.writeln('  $key [$tipo] $texto');
    }
  }
}

List<String> cajas(String ruta) {
  final a = File(ruta).openSync();
  try {
    final total = a.lengthSync();
    final lista = <String>[];
    var pos = 0;
    while (pos + 8 <= total) {
      a.setPositionSync(pos);
      final c = a.readSync(16);
      final d = ByteData.sublistView(c);
      var tam = d.getUint32(0);
      if (tam == 1) tam = d.getUint64(8);
      if (tam == 0) tam = total - pos;
      lista.add('${String.fromCharCodes(c, 4, 8)}@$pos(${tam ~/ 1024}K)');
      if (tam < 8) break;
      pos += tam;
    }
    return lista;
  } finally {
    a.closeSync();
  }
}
