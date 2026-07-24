/// Sub-tarea/checklist dentro de una [Tarea] — o dentro de otra [Actividad]:
/// el responsable de una subtarea puede a su vez desglosarla y delegar
/// partes a alguien más, sin límite de profundidad ([subActividades]).
///
/// Equivale a una fila de `tar_act` (actividades), gestionada en el
/// original vía `addActividad` / `delActividad` / `estActividad`.
class Actividad {
  final int id;
  final String descripcion;
  final bool terminada;

  /// Persona responsable de resolver esta subtarea — excluyente con
  /// [departamento] (asignar una limpia la otra).
  final int? miembroId;

  /// Departamento/área responsable de resolver esta subtarea — excluyente
  /// con [miembroId].
  final String? departamento;

  /// Fecha y hora planeadas de inicio/fin de esta subtarea — se piden al
  /// asignar el responsable (ver [conResponsable]), igual que una tarea
  /// completa tiene su propia fecha de inicio/vencimiento.
  final DateTime? fechaInicio;
  final DateTime? fechaFin;

  /// Subtareas de esta subtarea, delegadas por su responsable.
  final List<Actividad> subActividades;

  const Actividad({
    required this.id,
    required this.descripcion,
    this.terminada = false,
    this.miembroId,
    this.departamento,
    this.fechaInicio,
    this.fechaFin,
    this.subActividades = const [],
  });

  bool get tieneResponsable => miembroId != null || departamento != null;

  Actividad copyWith({
    int? id,
    String? descripcion,
    bool? terminada,
    List<Actividad>? subActividades,
  }) {
    return Actividad(
      id: id ?? this.id,
      descripcion: descripcion ?? this.descripcion,
      terminada: terminada ?? this.terminada,
      miembroId: miembroId,
      departamento: departamento,
      fechaInicio: fechaInicio,
      fechaFin: fechaFin,
      subActividades: subActividades ?? this.subActividades,
    );
  }

  /// Reemplaza el responsable de esta subtarea (o lo limpia si ambos
  /// argumentos vienen `null`) junto con sus fechas planeadas — aparte de
  /// [copyWith] porque asignar persona/departamento es una sustitución
  /// completa, no un merge campo a campo (elegir una limpia la otra, y
  /// quitar el responsable también quita sus fechas: sin alguien
  /// resolviéndola, esa fecha ya no significa nada).
  Actividad conResponsable({
    int? miembroId,
    String? departamento,
    DateTime? fechaInicio,
    DateTime? fechaFin,
  }) {
    return Actividad(
      id: id,
      descripcion: descripcion,
      terminada: terminada,
      miembroId: miembroId,
      departamento: departamento,
      fechaInicio: fechaInicio,
      fechaFin: fechaFin,
      subActividades: subActividades,
    );
  }
}
