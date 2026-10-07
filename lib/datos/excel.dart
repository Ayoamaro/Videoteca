import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../modelos/pelicula.dart';

// Exportar el catálogo a Excel. Un `.xlsx` es un `.zip` con unos cuantos
// archivos XML dentro: se escriben aquí directamente, sin paquetes de Excel.
// Una hoja «Películas» con una fila por película, la primera fila fija, con
// filtros y enlaces a FilmAffinity e IMDb.
//
// No usa nada de Flutter.

/// Una columna de la hoja: título, ancho (en caracteres) y su valor para
/// cada película: un texto, un número o un [_Enlace].
typedef _Columna = (String, double, Object? Function(Pelicula));

class _Enlace {
  const _Enlace(this.direccion, this.texto);
  final String direccion;
  final String texto;
}

final List<_Columna> _columnas = [
  ('Título', 38, (p) => p.titulo),
  ('Título original', 32, (p) => p.tituloOriginal),
  ('Año', 7, (p) => p.anio > 0 ? p.anio : null),
  ('Géneros', 26, (p) => p.generos.join('. ')),
  ('Dirección', 24, (p) => p.direccion),
  ('Reparto', 40, (p) => p.reparto),
  ('Guion', 24, (p) => p.guion),
  ('Música', 20, (p) => p.musica),
  ('Fotografía', 20, (p) => p.fotografia),
  ('Productora', 24, (p) => p.productora),
  ('País', 18, (p) => p.pais),
  ('Duración (min)', 10, (p) => p.duracionMin > 0 ? p.duracionMin : null),
  ('Estrellas', 9, (p) => p.estrellas > 0 ? p.estrellas : null),
  ('Edad', 7, (p) => p.edadCorta),
  ('Saga', 22, (p) => p.saga),
  ('Nº en la saga', 8, (p) => p.numeroSaga > 0 ? p.numeroSaga : null),
  ('Temas', 30, (p) => p.temas.join('; ')),
  ('Premios', 30, (p) => p.premios),
  ('Sinopsis', 60, (p) => p.sinopsis),
  ('Carpeta', 18, (p) => p.grupo),
  ('Subcarpeta', 18, (p) => p.generoCarpeta),
  ('Archivo', 60, (p) => p.ruta),
  (
    'Tamaño (GB)',
    10,
    (p) => p.tamanoBytes > 0
        ? double.parse((p.tamanoBytes / (1 << 30)).toStringAsFixed(2))
        : null,
  ),
  ('Resolución', 11, (p) => p.resolucion),
  (
    'FilmAffinity',
    13,
    (p) => p.enlaceFilmaffinity.isEmpty
        ? null
        : _Enlace(p.enlaceFilmaffinity, 'FilmAffinity'),
  ),
  (
    'IMDb',
    9,
    (p) => p.enlaceImdb.isEmpty ? null : _Enlace(p.enlaceImdb, 'IMDb'),
  ),
];

/// El `.xlsx` con [peliculas] (en el orden en que vienen).
Uint8List crearExcel(List<Pelicula> peliculas) {
  final archivo = Archive();
  void poner(String nombre, String xml) =>
      archivo.addFile(ArchiveFile.string(nombre, xml));

  poner('[Content_Types].xml', _tipos);
  poner('_rels/.rels', _relaciones);
  poner('xl/workbook.xml', _libro(peliculas.length + 1));
  poner('xl/_rels/workbook.xml.rels', _relacionesLibro);
  poner('xl/styles.xml', _estilos);
  poner('xl/worksheets/sheet1.xml', _hoja(peliculas));
  return ZipEncoder().encodeBytes(archivo);
}

String _hoja(List<Pelicula> peliculas) {
  final ultima = _letra(_columnas.length - 1);
  final filas = peliculas.length + 1;
  final s = StringBuffer()
    ..write(_cabeceraXml)
    ..write(
      '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
      'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">',
    )
    ..write('<dimension ref="A1:$ultima$filas"/>')
    // La primera fila se queda fija al bajar.
    ..write(
      '<sheetViews><sheetView workbookViewId="0">'
      '<pane ySplit="1" topLeftCell="A2" activePane="bottomLeft" state="frozen"/>'
      '</sheetView></sheetViews>',
    )
    ..write('<sheetFormatPr defaultRowHeight="15"/><cols>');
  for (var i = 0; i < _columnas.length; i++) {
    s.write(
      '<col min="${i + 1}" max="${i + 1}" width="${_columnas[i].$2}" '
      'customWidth="1"/>',
    );
  }
  s.write('</cols><sheetData><row r="1">');
  for (var i = 0; i < _columnas.length; i++) {
    s.write(_celda('${_letra(i)}1', _columnas[i].$1, estilo: 1));
  }
  s.write('</row>');
  for (var f = 0; f < peliculas.length; f++) {
    final r = f + 2;
    s.write('<row r="$r">');
    for (var i = 0; i < _columnas.length; i++) {
      final valor = _columnas[i].$3(peliculas[f]);
      if (valor == null || valor == '') continue;
      s.write(_celda('${_letra(i)}$r', valor));
    }
    s.write('</row>');
  }
  s
    ..write('</sheetData>')
    ..write('<autoFilter ref="A1:$ultima$filas"/>')
    ..write('</worksheet>');
  return s.toString();
}

String _celda(String ref, Object valor, {int estilo = 0}) {
  final s = estilo == 0 ? '' : ' s="$estilo"';
  if (valor is num) return '<c r="$ref"$s><v>$valor</v></c>';
  if (valor is _Enlace) {
    // Excel solo admite 255 caracteres por texto dentro de una fórmula.
    final direccion = valor.direccion.replaceAll('"', '""');
    if (direccion.length <= 255) {
      return '<c r="$ref" s="2" t="str"><f>'
          '${_xml('HYPERLINK("$direccion","${valor.texto}")')}'
          '</f><v>${_xml(valor.texto)}</v></c>';
    }
    valor = valor.direccion;
  }
  var texto = '$valor';
  // Lo máximo que cabe en una celda.
  if (texto.length > 32767) texto = texto.substring(0, 32767);
  return '<c r="$ref"$s t="inlineStr"><is><t xml:space="preserve">'
      '${_xml(texto)}</t></is></c>';
}

/// 0 → A, 25 → Z, 26 → AA…
String _letra(int i) {
  var n = i + 1;
  var letras = '';
  while (n > 0) {
    final resto = (n - 1) % 26;
    letras = String.fromCharCode(65 + resto) + letras;
    n = (n - 1) ~/ 26;
  }
  return letras;
}

/// Texto listo para ir dentro del XML: sin los caracteres que el XML no
/// admite (de control) y con `& < > "` escritos como entidades.
String _xml(String texto) {
  final s = StringBuffer();
  for (final r in texto.runes) {
    if (r < 0x20 && r != 0x09 && r != 0x0A && r != 0x0D) continue;
    if (r == 0xFFFE || r == 0xFFFF || (r >= 0xD800 && r <= 0xDFFF)) continue;
    switch (r) {
      case 0x26:
        s.write('&amp;');
      case 0x3C:
        s.write('&lt;');
      case 0x3E:
        s.write('&gt;');
      case 0x22:
        s.write('&quot;');
      default:
        s.writeCharCode(r);
    }
  }
  return s.toString();
}

const _cabeceraXml =
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n';

const _tipos =
    '$_cabeceraXml'
    '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
    '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
    '<Default Extension="xml" ContentType="application/xml"/>'
    '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
    '<Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'
    '<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>'
    '</Types>';

const _relaciones =
    '$_cabeceraXml'
    '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
    '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>'
    '</Relationships>';

String _libro(int filas) =>
    '$_cabeceraXml'
    '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
    'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
    '<sheets><sheet name="Películas" sheetId="1" r:id="rId1"/></sheets>'
    '<definedNames><definedName name="_xlnm._FilterDatabase" localSheetId="0" hidden="1">'
    "'Películas'!\$A\$1:\$${_letra(_columnas.length - 1)}\$$filas"
    '</definedName></definedNames>'
    '</workbook>';

const _relacionesLibro =
    '$_cabeceraXml'
    '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
    '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>'
    '<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>'
    '</Relationships>';

/// Estilos: 0 = normal, 1 = cabecera (negrita sobre dorado), 2 = enlace.
const _estilos =
    '$_cabeceraXml'
    '<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
    '<fonts count="3">'
    '<font><sz val="11"/><name val="Calibri"/><family val="2"/></font>'
    '<font><b/><sz val="11"/><name val="Calibri"/><family val="2"/></font>'
    '<font><u/><sz val="11"/><color rgb="FF0563C1"/><name val="Calibri"/><family val="2"/></font>'
    '</fonts>'
    '<fills count="3">'
    '<fill><patternFill patternType="none"/></fill>'
    '<fill><patternFill patternType="gray125"/></fill>'
    '<fill><patternFill patternType="solid"><fgColor rgb="FFE2AE4F"/><bgColor indexed="64"/></patternFill></fill>'
    '</fills>'
    '<borders count="1"><border><left/><right/><top/><bottom/><diagonal/></border></borders>'
    '<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>'
    '<cellXfs count="3">'
    '<xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>'
    '<xf numFmtId="0" fontId="1" fillId="2" borderId="0" xfId="0" applyFont="1" applyFill="1"/>'
    '<xf numFmtId="0" fontId="2" fillId="0" borderId="0" xfId="0" applyFont="1"/>'
    '</cellXfs>'
    '<cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles>'
    '</styleSheet>';
