// Import condicional: en web dispara la descarga real vía `dart:html`; en
// cualquier otra plataforma cae al stub, que solo lanza un error legible —
// evita que `dart:html` (no disponible fuera de web) rompa la compilación
// de los targets de escritorio/móvil del mismo código fuente.
import 'descargar_csv_stub.dart'
    if (dart.library.html) 'descargar_csv_web.dart'
    as impl;

/// Dispara la descarga de [contenido] como archivo [nombreArchivo] en el
/// navegador. Lanza [UnsupportedError] fuera de web.
void descargarCsv(String nombreArchivo, String contenido) =>
    impl.descargarCsv(nombreArchivo, contenido);
