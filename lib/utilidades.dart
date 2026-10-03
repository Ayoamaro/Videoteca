import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// El administrador solo trabaja desde el PC; en Android la app es de consulta.
/// (El inicio de sesión real con contraseñas llega el día 15.)
bool get esAdministrador => defaultTargetPlatform != TargetPlatform.android;

/// 5541 → "5.541" (con punto de miles también en números de 4 cifras).
String formatoNumero(int n) {
  final s = n.abs().toString();
  final grupos = <String>[];
  for (var fin = s.length; fin > 0; fin -= 3) {
    grupos.insert(0, s.substring(fin < 3 ? 0 : fin - 3, fin));
  }
  return '${n < 0 ? '-' : ''}${grupos.join('.')}';
}

/// "Viernes, 3 de octubre"
String fechaLarga(DateTime fecha) {
  final texto = DateFormat("EEEE, d 'de' MMMM", 'es').format(fecha);
  return texto[0].toUpperCase() + texto.substring(1);
}

/// Quita tildes y pasa a minúsculas para buscar sin importar cómo se escriba.
String normalizar(String texto) {
  const con = 'áàäâéèëêíìïîóòöôúùüûñç';
  const sin = 'aaaaeeeeiiiioooouuuunc';
  final buffer = StringBuffer();
  for (final letra in texto.toLowerCase().split('')) {
    final i = con.indexOf(letra);
    buffer.write(i < 0 ? letra : sin[i]);
  }
  return buffer.toString();
}

/// Aviso para los botones que todavía no hacen nada.
void avisoProximamente(BuildContext context, String que, int dia) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text('$que llega el día $dia.')));
}
