import 'dart:convert';
// Este archivo solo se compila para el target web (import condicional en
// `descargar_csv.dart`), así que `dart:html` aquí es seguro pese al lint
// general de evitar librerías web-only en código Flutter multiplataforma.
// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

/// Implementación web: crea un `Blob` y dispara la descarga con un
/// `<a download>` sintético, sin necesidad de subir nada a un servidor.
void descargarCsv(String nombreArchivo, String contenido) {
  // BOM UTF-8 al inicio: sin esto Excel abre acentos/ñ como caracteres
  // corruptos al detectar la codificación por defecto del sistema.
  final bytes = utf8.encode('﻿$contenido');
  final blob = html.Blob([bytes], 'text/csv;charset=utf-8');
  final url = html.Url.createObjectUrlFromBlob(blob);
  // Insertar el `<a>` en el DOM antes del `click()` (y quitarlo después):
  // algunos navegadores (Firefox, Safari con política estricta de "user
  // gesture") no disparan la descarga de un ancla desconectada del árbol,
  // así que sin esto la exportación fallaba en silencio ahí.
  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', nombreArchivo);
  html.document.body!.append(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
}
