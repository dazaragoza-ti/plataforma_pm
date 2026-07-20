/// Escapa [valor] para una celda CSV — comillas dobles duplicadas más un
/// apóstrofe inicial si el valor podría interpretarse como fórmula al
/// abrir el archivo en Excel/Sheets (empieza con `=`, `+`, `-`, `@`, tab o
/// retorno de carro). Sin el apóstrofe, un título de tarea como
/// `=HYPERLINK(...)` se ejecuta como fórmula viva al abrir el CSV
/// exportado — el apóstrofe fuerza a que se lea como texto literal.
String campoCsv(String valor) {
  final texto = RegExp(r'^[=+\-@\t\r]').hasMatch(valor) ? "'$valor" : valor;
  return '"${texto.replaceAll('"', '""')}"';
}
