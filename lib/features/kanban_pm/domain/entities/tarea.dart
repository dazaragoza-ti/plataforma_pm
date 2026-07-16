import 'package:flutter/material.dart';
import '../../kanban_constants.dart';
import 'actividad.dart';
import 'comentario.dart';

/// Tarea del tablero Kanban.
class Tarea {
  final int id;
  final String titulo;
  final String descripcion;
  final TareaEstatus estatus;
  final TareaPrioridad prioridad;
  final String grupo;
  final String asignadoPor;
  final DateTime? fechaInicio;
  final DateTime? fechaVencimiento;

  /// Fecha real en que la tarea entró a "en proceso" (se registra sola al
  /// moverla de columna). `null` mientras siga sin arrancar de verdad.
  final DateTime? fechaInicioReal;

  /// Fecha real en que la tarea llegó a "terminado"/"revisado" (se registra
  /// sola al moverla de columna). `null` mientras siga sin cerrarse.
  final DateTime? fechaFinReal;
  final (String, Color)? generales;
  final (String, Color)? nivel;
  final (String, Color)? importancia;
  final List<Actividad> actividades;
  final List<Comentario> comentarios;

  /// Posición dentro de su columna (`estatus`), usada para ordenar y para
  /// arrastrar una tarjeta a una posición exacta (estilo Trello).
  final int orden;

  /// Ids de [TareaEtiqueta] del catálogo del tablero asignadas a esta tarea.
  final List<int> etiquetaIds;

  /// Ids de [Miembro] del catálogo del tablero asignados a esta tarea
  /// (multi-asignación, igual que las etiquetas).
  final List<int> miembroIds;

  /// Color de portada de la tarjeta (opcional, estilo Trello).
  final Color? portada;

  /// Ids de tareas predecesoras: esta tarea "depende de" ellas (para Gantt).
  final List<int> dependeDeIds;

  /// Tarjeta archivada: se oculta del tablero/Gantt/gráficas sin borrarla.
  final bool archivada;

  const Tarea({
    required this.id,
    required this.titulo,
    this.descripcion = '',
    required this.estatus,
    this.prioridad = TareaPrioridad.media,
    this.grupo = '',
    this.asignadoPor = '',
    this.fechaInicio,
    this.fechaVencimiento,
    this.fechaInicioReal,
    this.fechaFinReal,
    this.generales,
    this.nivel,
    this.importancia,
    this.actividades = const [],
    this.comentarios = const [],
    this.orden = 0,
    this.etiquetaIds = const [],
    this.miembroIds = const [],
    this.portada,
    this.dependeDeIds = const [],
    this.archivada = false,
  });

  int get actividadesTerminadas => actividades.where((a) => a.terminada).length;

  double get progreso =>
      actividades.isEmpty ? 0 : actividadesTerminadas / actividades.length;

  bool get vencida =>
      fechaVencimiento != null &&
      estatus != TareaEstatus.terminado &&
      fechaVencimiento!.isBefore(DateTime.now());

  Tarea copyWith({
    int? id,
    String? titulo,
    String? descripcion,
    TareaEstatus? estatus,
    TareaPrioridad? prioridad,
    String? grupo,
    String? asignadoPor,
    DateTime? fechaInicio,
    DateTime? fechaVencimiento,
    DateTime? fechaInicioReal,
    DateTime? fechaFinReal,
    (String, Color)? generales,
    (String, Color)? nivel,
    (String, Color)? importancia,
    List<Actividad>? actividades,
    List<Comentario>? comentarios,
    int? orden,
    List<int>? etiquetaIds,
    List<int>? miembroIds,
    Color? portada,
    bool limpiarPortada = false,
    List<int>? dependeDeIds,
    bool? archivada,
  }) {
    return Tarea(
      id: id ?? this.id,
      titulo: titulo ?? this.titulo,
      descripcion: descripcion ?? this.descripcion,
      estatus: estatus ?? this.estatus,
      prioridad: prioridad ?? this.prioridad,
      grupo: grupo ?? this.grupo,
      asignadoPor: asignadoPor ?? this.asignadoPor,
      fechaInicio: fechaInicio ?? this.fechaInicio,
      fechaVencimiento: fechaVencimiento ?? this.fechaVencimiento,
      fechaInicioReal: fechaInicioReal ?? this.fechaInicioReal,
      fechaFinReal: fechaFinReal ?? this.fechaFinReal,
      generales: generales ?? this.generales,
      nivel: nivel ?? this.nivel,
      importancia: importancia ?? this.importancia,
      actividades: actividades ?? this.actividades,
      comentarios: comentarios ?? this.comentarios,
      orden: orden ?? this.orden,
      etiquetaIds: etiquetaIds ?? this.etiquetaIds,
      miembroIds: miembroIds ?? this.miembroIds,
      portada: limpiarPortada ? null : (portada ?? this.portada),
      dependeDeIds: dependeDeIds ?? this.dependeDeIds,
      archivada: archivada ?? this.archivada,
    );
  }
}
