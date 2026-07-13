/// Sub-tarea/checklist dentro de una [Tarea].
///
/// Equivale a una fila de `tar_act` (actividades), gestionada en el
/// original vía `addActividad` / `delActividad` / `estActividad`.
class Actividad {
  final int id;
  final String descripcion;
  final bool terminada;

  const Actividad({
    required this.id,
    required this.descripcion,
    this.terminada = false,
  });

  Actividad copyWith({int? id, String? descripcion, bool? terminada}) {
    return Actividad(
      id: id ?? this.id,
      descripcion: descripcion ?? this.descripcion,
      terminada: terminada ?? this.terminada,
    );
  }
}
