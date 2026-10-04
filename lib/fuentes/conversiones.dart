// Reglas para pasar los datos de internet a tu formato.
//
// No usa nada de Flutter.

/// Tramos de la nota de Rotten Tomatoes para cada número de estrellas
/// (decidido el día 10: tramos iguales de 20 %).
const tramosEstrellas = [
  (estrellas: 1, desde: 0, hasta: 19),
  (estrellas: 2, desde: 20, hasta: 39),
  (estrellas: 3, desde: 40, hasta: 59),
  (estrellas: 4, desde: 60, hasta: 79),
  (estrellas: 5, desde: 80, hasta: 100),
];

/// Nota de Rotten Tomatoes (0–100 %) → estrellas (1–5).
int estrellasDeRotten(int porcentaje) {
  for (final t in tramosEstrellas) {
    if (porcentaje <= t.hasta) return t.estrellas;
  }
  return 5;
}

/// Tus frases de edad, por edad mínima («TP» = todos los públicos).
const frasesEdad = {
  'TP': 'Apto para todos los públicos',
  '7': 'No recomendado para menores de 7 años',
  '12': 'No recomendado para menores de 12 años',
  '13': 'No recomendado para menores de 13 años',
  '16': 'No recomendado para menores de 16 años',
  '18': 'No recomendado para menores de 18 años',
};

/// Calificación de EE. UU. → edad (decidido el día 10: es la que más se
/// parece a tus frases, que usan mucho el «13» de PG-13).
const edadesEeuu = {
  'G': 'TP',
  'PG': '7',
  'PG-13': '13',
  'R': '18',
  'NC-17': '18',
};

/// Calificación de España → edad (se usa si no hay la de EE. UU.).
const edadesEspana = {
  'TP': 'TP',
  '7': '7',
  '12': '12',
  '16': '16',
  '18': '18',
  'X': '18',
};

/// Tu frase de edad a partir de las calificaciones de TMDB de EE. UU.
/// ([eeuu]: «PG-13»…) o, si no hay, de España ([espana]: «TP», «12»…), o
/// `null` si no hay ninguna que sirva.
String? fraseEdad({required String espana, required String eeuu}) {
  final edad = edadesEeuu[eeuu.toUpperCase()] ?? edadesEspana[espana];
  return edad == null ? null : frasesEdad[edad];
}

/// Las reglas de edad para enseñarlas en Ajustes: (insignia, de dónde sale,
/// frase), p. ej. ('18', 'EE. UU.: R, NC-17 · España: 18, X', '…').
final reglasEdadParaVer = [
  for (final edad in ['TP', '7', '12', '13', '16', '18'])
    (
      edad,
      [
        for (final (pais, tabla) in [
          ('EE. UU.', edadesEeuu),
          ('España', edadesEspana),
        ])
          if (tabla.entries.where((e) => e.value == edad).toList()
              case final codigos when codigos.isNotEmpty)
            '$pais: ${codigos.map((e) => e.key).join(', ')}',
      ].join(' · '),
      frasesEdad[edad]!,
    ),
];
