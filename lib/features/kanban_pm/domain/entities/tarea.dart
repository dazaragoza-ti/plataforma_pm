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
  final String responsable;
  final DateTime? fechaInicio;
  final DateTime? fechaVencimiento;
  final (String, Color)? generales;
  final (String, Color)? nivel;
  final (String, Color)? importancia;
  final List<Actividad> actividades;
  final List<Comentario> comentarios;

  const Tarea({
    required this.id,
    required this.titulo,
    this.descripcion = '',
    required this.estatus,
    this.prioridad = TareaPrioridad.media,
    this.grupo = '',
    this.asignadoPor = '',
    this.responsable = '',
    this.fechaInicio,
    this.fechaVencimiento,
    this.generales,
    this.nivel,
    this.importancia,
    this.actividades = const [],
    this.comentarios = const [],
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
    String? responsable,
    DateTime? fechaInicio,
    DateTime? fechaVencimiento,
    (String, Color)? generales,
    (String, Color)? nivel,
    (String, Color)? importancia,
    List<Actividad>? actividades,
    List<Comentario>? comentarios,
  }) {
    return Tarea(
      id: id ?? this.id,
      titulo: titulo ?? this.titulo,
      descripcion: descripcion ?? this.descripcion,
      estatus: estatus ?? this.estatus,
      prioridad: prioridad ?? this.prioridad,
      grupo: grupo ?? this.grupo,
      asignadoPor: asignadoPor ?? this.asignadoPor,
      responsable: responsable ?? this.responsable,
      fechaInicio: fechaInicio ?? this.fechaInicio,
      fechaVencimiento: fechaVencimiento ?? this.fechaVencimiento,
      generales: generales ?? this.generales,
      nivel: nivel ?? this.nivel,
      importancia: importancia ?? this.importancia,
      actividades: actividades ?? this.actividades,
      comentarios: comentarios ?? this.comentarios,
    );
  }
}
