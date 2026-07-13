/// Comentario dejado por un usuario sobre una [Tarea].
///
/// Equivale a una fila de `tar_obs`, gestionada vía `getComments` /
/// `updateComentario` / `deleteComentario` en el original.
class Comentario {
  final int id;
  final String autor;
  final String contenido;
  final DateTime fecha;

  const Comentario({
    required this.id,
    required this.autor,
    required this.contenido,
    required this.fecha,
  });
}
