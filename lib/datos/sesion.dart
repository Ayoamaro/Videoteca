import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;

import '../tablon/cifrado.dart';

// La sesión: con qué modo se ha entrado en la app en este aparato.
//
// - **Administrador** (solo en el PC): trabaja con el disco y la base de datos
//   de siempre. Se entra con una contraseña propia de este PC.
// - **Consulta** (PC o móvil): ve una copia del catálogo descargada del
//   tablón de GitHub. Se entra con la contraseña común.
//
// Se guarda en `sesion.json`, en la carpeta de datos de la app (fuera de la
// base de datos, porque cada modo tiene la suya). La sesión se queda abierta
// hasta pulsar «Cerrar sesión» en Ajustes.
//
// No usa nada de Flutter.

enum ModoApp { administrador, consulta }

class Sesion {
  Sesion({this.modo, this.contrasenaAdmin, this.tablon = ''});

  /// Lee `sesion.json` de [carpeta] (si no existe o está dañado, una sesión
  /// vacía: hay que entrar).
  factory Sesion.leer(String carpeta) {
    try {
      final archivo = File(_ruta(carpeta));
      if (!archivo.existsSync()) return Sesion();
      final json =
          jsonDecode(archivo.readAsStringSync()) as Map<String, dynamic>;
      final admin = json['administrador'] as Map<String, dynamic>?;
      return Sesion(
        modo: ModoApp.values.asNameMap()[json['modo']],
        contrasenaAdmin: admin == null
            ? null
            : ContrasenaAdmin(
                ParametrosLlave.desdeJson(
                  admin['llave'] as Map<String, dynamic>,
                ),
                admin['huella'] as String,
              ),
        tablon: json['tablon'] as String? ?? '',
      );
    } on Object {
      return Sesion();
    }
  }

  /// Con qué modo se entró (`null` = hay que entrar).
  ModoApp? modo;

  /// La contraseña de administrador de este PC (`null` = aún no se ha
  /// creado).
  ContrasenaAdmin? contrasenaAdmin;

  /// El último tablón con el que se entró en modo consulta («usuario/nombre»).
  String tablon;

  void guardar(String carpeta) {
    Directory(carpeta).createSync(recursive: true);
    File(_ruta(carpeta)).writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert({
        'modo': modo?.name,
        if (contrasenaAdmin != null)
          'administrador': {
            'llave': contrasenaAdmin!.parametros.toJson(),
            'huella': contrasenaAdmin!.huella,
          },
        'tablon': tablon,
      }),
    );
  }

  static String _ruta(String carpeta) =>
      '$carpeta${Platform.pathSeparator}sesion.json';
}

/// La contraseña de administrador, guardada sin la contraseña: solo la
/// huella de la llave que sale de ella con Argon2id (como el tablón). Para
/// comprobarla se vuelve a sacar la llave y se compara la huella.
class ContrasenaAdmin {
  const ContrasenaAdmin(this.parametros, this.huella);

  /// Crea la contraseña (lleva casi un segundo).
  static Future<ContrasenaAdmin> crear(String contrasena) async {
    final p = ParametrosLlave.nuevos();
    return ContrasenaAdmin(p, await _huella(contrasena, p));
  }

  final ParametrosLlave parametros;
  final String huella;

  /// ¿Es esta la contraseña? (Lleva casi un segundo.)
  Future<bool> comprobar(String contrasena) async =>
      await _huella(contrasena, parametros) == huella;

  static Future<String> _huella(String contrasena, ParametrosLlave p) async {
    final llave = await derivarLlaveAparte(contrasena, p);
    return crypto.sha256.convert([
      ...utf8.encode('videoteca-administrador'),
      ...llave.bytes,
    ]).toString();
  }
}

/// Longitud mínima de las contraseñas que se crean en la app.
const largoMinimoContrasena = 6;

/// Acepta «usuario/nombre» o el enlace del repositorio
/// (`https://github.com/usuario/nombre`) y devuelve «usuario/nombre», o `null`
/// si no lo parece.
String? nombreTablon(String texto) {
  var t = texto.trim();
  t = t.replaceFirst(RegExp(r'^(https?://)?(www\.)?github\.com/'), '');
  t = t.replaceFirst(RegExp(r'(\.git)?/*$'), '');
  final partes = t.split('/');
  if (partes.length != 2) return null;
  final valido = RegExp(r'^[A-Za-z0-9_.-]+$');
  return partes.every(valido.hasMatch) ? t : null;
}
