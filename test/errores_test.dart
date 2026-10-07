import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:videoteca/disco/propiedades_windows.dart';
import 'package:videoteca/errores.dart';

void main() {
  test('Los fallos de archivos se explican en español', () {
    FileSystemException fallo(int codigo) => FileSystemException(
      'Cannot open file',
      r'D:\Comedias\Romance\Notting Hill (1999).mp4',
      OSError('El proceso no tiene acceso al archivo', codigo),
    );
    expect(
      explicarError(fallo(32)),
      'El archivo está abierto en otro programa (Notting Hill (1999).mp4). '
      'Ciérralo y vuelve a intentarlo.',
    );
    expect(explicarError(fallo(5)), contains('falta permiso'));
    expect(explicarError(fallo(2)), startsWith('No se encuentra'));
    expect(explicarError(fallo(21)), contains('Comprueba que está conectado'));
    expect(explicarError(fallo(112)), startsWith('No queda espacio'));
    // Un código desconocido: el mensaje de Windows, sin la ruta entera.
    expect(
      explicarError(fallo(999)),
      'No se ha podido usar el archivo (Notting Hill (1999).mp4): '
      'El proceso no tiene acceso al archivo',
    );
  });

  test('Internet, tiempos y mensajes propios', () {
    expect(
      explicarError(const SocketException('Failed host lookup')),
      startsWith('Sin conexión a internet'),
    );
    expect(
      explicarError(TimeoutException('x')),
      startsWith('Ha tardado demasiado'),
    );
    expect(explicarError(const FormatException('x')), contains('formato'));
    expect(explicarError(Exception('Algo concreto')), 'Algo concreto');
    expect(explicarError(StateError('raro')), 'Bad state: raro');
  });

  test('Los fallos de Windows al leer propiedades dicen el motivo', () {
    expect(
      '${PropiedadesException(r'D:\Dramas\Drama\Origen (2010).mp4', 0x80070020)}',
      'Windows no pudo leer las propiedades de «Origen (2010).mp4»: lo está '
          'usando otro programa.',
    );
    expect(
      '${PropiedadesException(r'D:\x.mp4', 0x80004005)}',
      'Windows no pudo leer las propiedades de «x.mp4» (código 0x80004005).',
    );
  });
}
