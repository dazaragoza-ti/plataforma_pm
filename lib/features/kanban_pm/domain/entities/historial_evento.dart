/// Entrada del historial de actividad de una [Tarea]: quién hizo qué y
/// cuándo — cambios de estatus, prioridad, asignaciones, comentarios,
/// subtareas, etc. Se registra sola desde el repositorio, nunca a mano
/// desde la UI.
class HistorialEvento {
  final int id;
  final String autor;
  final String mensaje;
  final DateTime fecha;

  const HistorialEvento({
    required this.id,
    required this.autor,
    required this.mensaje,
    required this.fecha,
  });
}
