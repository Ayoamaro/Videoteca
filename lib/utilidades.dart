import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import 'datos/sesion.dart';

/// Con qué modo se ha entrado en la app (lo pone el arranque al abrir la
/// sesión; ver `arranque.dart`).
ModoApp? modoSesion;

/// ¿Se ha entrado como administrador? Sin sesión (en las pruebas), el
/// administrador es el PC y el móvil es de consulta.
bool get esAdministrador =>
    (modoSesion ??
        (defaultTargetPlatform == TargetPlatform.android
            ? ModoApp.consulta
            : ModoApp.administrador)) ==
    ModoApp.administrador;

/// En el móvil solo se puede consultar: el administrador trabaja en el PC.
bool get puedeAdministrar => defaultTargetPlatform != TargetPlatform.android;

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

/// "3 de octubre" (y el año si no es el actual: "3 de octubre de 2025").
String fechaCorta(DateTime fecha) => fecha.year == DateTime.now().year
    ? DateFormat("d 'de' MMMM", 'es').format(fecha)
    : DateFormat("d 'de' MMMM 'de' y", 'es').format(fecha);

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
