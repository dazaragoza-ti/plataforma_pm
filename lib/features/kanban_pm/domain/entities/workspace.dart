import 'package:flutter/material.dart';

/// Área de trabajo: un tablero Kanban completo e independiente (sus propias
/// columnas, tareas, etiquetas, miembros y plantillas). Antes de entrar al
/// Kanban, la persona usuaria elige o crea una — ver `WorkspaceSelectorScreen`.
class Workspace {
  final String id;
  final String nombre;
  final Color color;
  final DateTime fechaCreacion;

  /// Cuántas tarjetas (no archivadas) tiene el tablero de esta área — solo
  /// lo llena [WorkspaceRepository.listarWorkspaces] (consulta su propio
  /// [KanbanRepository] al listar); en cualquier otro punto vale `0` por
  /// defecto, no "en verdad no tiene tareas".
  final int tareasCount;

  const Workspace({
    required this.id,
    required this.nombre,
    required this.color,
    required this.fechaCreacion,
    this.tareasCount = 0,
  });

  Workspace copyWith({String? nombre, Color? color, int? tareasCount}) {
    return Workspace(
      id: id,
      nombre: nombre ?? this.nombre,
      color: color ?? this.color,
      fechaCreacion: fechaCreacion,
      tareasCount: tareasCount ?? this.tareasCount,
    );
  }
}
