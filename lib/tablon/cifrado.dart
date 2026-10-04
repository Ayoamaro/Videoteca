import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:cryptography/cryptography.dart';
import 'package:cryptography/dart.dart';

// El cifrado del tablón: todo lo que se sube a GitHub (catálogo y carátulas)
// va cifrado con la contraseña común, para que solo lo lea quien la sepa.
//
// - De la contraseña sale una llave de 32 bytes con **Argon2id** (a propósito
//   lento y con mucha memoria: probar contraseñas a ciegas cuesta muchísimo).
//   La «sal» (16 bytes al azar) y los parámetros van sin cifrar en
//   `tablon.json`, porque los móviles los necesitan para llegar a la misma
//   llave.
// - Cada archivo se cifra con **AES-256-GCM**, que además detecta cualquier
//   cambio: con otra contraseña, o si alguien toca un byte, no se descifra.
// - El «nonce» (número de un solo uso de AES-GCM) se saca del propio
//   contenido. Así, el mismo archivo cifrado dos veces da exactamente los
//   mismos bytes y Git ve que no ha cambiado (no se vuelve a subir), y dos
//   contenidos distintos nunca comparten nonce.
//
// No usa nada de Flutter (también sirve en el móvil).

/// Formato de los archivos cifrados: «VTB1» + nonce (12) + datos + sello (16).
const _cabecera = [0x56, 0x54, 0x42, 0x31];
const _largoNonce = 12;
const _largoSello = 16;

/// La contraseña no es la buena (o el archivo está dañado).
class ContrasenaIncorrecta implements Exception {
  const ContrasenaIncorrecta();

  @override
  String toString() => 'La contraseña no es correcta.';
}

/// Parámetros para sacar la llave de la contraseña (van en `tablon.json`).
class ParametrosLlave {
  const ParametrosLlave({
    required this.sal,
    this.memoria = 65536,
    this.iteraciones = 3,
    this.paralelismo = 1,
  });

  /// Parámetros nuevos con una sal al azar. Con 64 MB y 3 pasadas tarda
  /// ~0,7 s en el PC (en el móvil algo más, y solo al entrar).
  factory ParametrosLlave.nuevos() {
    final azar = Random.secure();
    return ParametrosLlave(
      sal: Uint8List.fromList([for (var i = 0; i < 16; i++) azar.nextInt(256)]),
    );
  }

  factory ParametrosLlave.desdeJson(Map<String, dynamic> json) {
    if (json['tipo'] != 'Argon2id') {
      throw const FormatException('Tipo de llave desconocido');
    }
    return ParametrosLlave(
      sal: base64.decode(json['sal'] as String),
      memoria: json['memoria'] as int,
      iteraciones: json['iteraciones'] as int,
      paralelismo: json['paralelismo'] as int,
    );
  }

  final Uint8List sal;

  /// Memoria en KiB.
  final int memoria;
  final int iteraciones;
  final int paralelismo;

  Map<String, Object> toJson() => {
    'tipo': 'Argon2id',
    'sal': base64.encode(sal),
    'memoria': memoria,
    'iteraciones': iteraciones,
    'paralelismo': paralelismo,
  };
}

/// Saca la llave del tablón a partir de la [contrasena]. Es lento a
/// propósito (ver [ParametrosLlave]).
Future<LlaveTablon> derivarLlave(String contrasena, ParametrosLlave p) async {
  final argon = DartArgon2id(
    memory: p.memoria,
    iterations: p.iteraciones,
    parallelism: p.paralelismo,
    hashLength: 32,
  );
  final llave = await argon.deriveKeyFromPassword(
    password: contrasena,
    nonce: p.sal,
  );
  return LlaveTablon(Uint8List.fromList(await llave.extractBytes()));
}

/// La llave ya sacada de la contraseña: cifra y descifra los archivos.
class LlaveTablon {
  LlaveTablon(this.bytes)
    : _cifrar = SecretKeyData(_derivada(bytes, 'videoteca-cifrar')),
      _nonce = crypto.Hmac(crypto.sha256, _derivada(bytes, 'videoteca-nonce'));

  /// La llave guardada como texto (ver [aTexto]).
  factory LlaveTablon.desdeTexto(String texto) =>
      LlaveTablon(base64.decode(texto));

  final Uint8List bytes;
  final SecretKeyData _cifrar;
  final crypto.Hmac _nonce;

  static final _aes = DartAesGcm(secretKeyLength: 32);

  /// Para guardarla en los ajustes de este PC (así no hay que guardar la
  /// contraseña).
  String aTexto() => base64.encode(bytes);

  /// Una huella corta de la llave: si cambia la contraseña, cambia.
  String get huella => crypto.sha256.convert(bytes).toString().substring(0, 16);

  /// Cifra [datos] del archivo [ruta] del tablón. La ruta va «atada» al
  /// cifrado: el mismo contenido no se puede hacer pasar por otro archivo.
  Uint8List cifrar(String ruta, List<int> datos) {
    final rutaBytes = utf8.encode(ruta);
    final huella = _Huella();
    _nonce.startChunkedConversion(huella)
      ..add(rutaBytes)
      ..add(const [0])
      ..add(datos)
      ..close();
    final nonce = huella.valor.bytes.sublist(0, _largoNonce);
    final caja = _aes.encryptSync(
      datos,
      secretKeyData: _cifrar,
      nonce: nonce,
      aad: rutaBytes,
    );
    return (BytesBuilder(copy: false)
          ..add(_cabecera)
          ..add(nonce)
          ..add(caja.cipherText)
          ..add(caja.mac.bytes))
        .takeBytes();
  }

  /// Descifra el archivo [ruta]. Lanza [ContrasenaIncorrecta] si no se puede.
  Uint8List descifrar(String ruta, Uint8List sobre) {
    final minimo = _cabecera.length + _largoNonce + _largoSello;
    if (sobre.length < minimo) throw const ContrasenaIncorrecta();
    for (var i = 0; i < _cabecera.length; i++) {
      if (sobre[i] != _cabecera[i]) throw const ContrasenaIncorrecta();
    }
    final inicio = _cabecera.length + _largoNonce;
    final fin = sobre.length - _largoSello;
    try {
      return Uint8List.fromList(
        _aes.decryptSync(
          SecretBox(
            Uint8List.sublistView(sobre, inicio, fin),
            nonce: Uint8List.sublistView(sobre, _cabecera.length, inicio),
            mac: Mac(Uint8List.sublistView(sobre, fin)),
          ),
          secretKeyData: _cifrar,
          aad: utf8.encode(ruta),
        ),
      );
    } on SecretBoxAuthenticationError {
      throw const ContrasenaIncorrecta();
    }
  }

  /// Llaves distintas para cifrar y para los nonces, sacadas de la principal.
  static List<int> _derivada(List<int> llave, String uso) =>
      crypto.Hmac(crypto.sha256, llave).convert(utf8.encode(uso)).bytes;
}

/// Recoge el resultado de un HMAC calculado por trozos.
class _Huella implements Sink<crypto.Digest> {
  late crypto.Digest valor;

  @override
  void add(crypto.Digest data) => valor = data;

  @override
  void close() {}
}
