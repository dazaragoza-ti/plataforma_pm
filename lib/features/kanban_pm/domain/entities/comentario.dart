/// Comentario dejado por un usuario sobre una [Tarea].
///
/// Equivale a una fila de `tar_obs`, gestionada vía `getComments` /
/// `updateComentario` / `deleteComentario` en el original.
class Comentario {
  final int id;
  final String autor;
  final String contenido;
  final DateTime fecha;

  /// Ruta de la imagen adjunta (URL `blob:` en web, ruta de archivo en
  /// desktop/móvil) — `null` si el comentario no lleva adjunto.
  final String? adjuntoPath;

  /// Nombre original del archivo adjunto, para mostrarlo junto a la
  /// miniatura.
  final String? adjuntoNombre;

  const Comentario({
    required this.id,
    required this.autor,
    required this.contenido,
    required this.fecha,
    this.adjuntoPath,
    this.adjuntoNombre,
  });
}
