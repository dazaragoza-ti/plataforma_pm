/// Implementación de respaldo para plataformas sin `dart:html` (desktop,
/// móvil): esta app aún no tiene un flujo de guardado de archivos fuera de
/// web, así que solo informa con un error legible en vez de fallar en
/// silencio.
void descargarCsv(String nombreArchivo, String contenido) {
  throw UnsupportedError(
    'Exportar a CSV solo está disponible en la versión web por ahora.',
  );
}
