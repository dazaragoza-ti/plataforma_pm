import 'package:flutter/material.dart';
import '../../kanban_constants.dart';

/// Plantilla editable para crear tarjetas rápido con valores por defecto
/// ya cargados (título sugerido, prioridad, área, checklist típico,
/// etiquetas, miembros sugeridos y color de portada...), gestionada por el
/// usuario desde el tablero (crear/editar/eliminar).
class TareaPlantilla {
  final int id;
  final String nombre;
  final String tituloSugerido;
  final String descripcion;
  final TareaPrioridad prioridad;
  final String grupo;
  final List<String> actividades;

  /// Ids de [TareaEtiqueta] del catálogo del tablero que se aplican solas
  /// al crear una tarjeta desde esta plantilla.
  final List<int> etiquetaIds;

  /// Ids de [Miembro] sugeridos como responsables por defecto.
  final List<int> miembroIds;

  /// Color de portada sugerido para las tarjetas creadas desde esta
  /// plantilla (estilo Trello).
  final Color? portada;

  const TareaPlantilla({
    required this.id,
    required this.nombre,
    this.tituloSugerido = '',
    this.descripcion = '',
    this.prioridad = TareaPrioridad.media,
    this.grupo = '',
    this.actividades = const [],
    this.etiquetaIds = const [],
    this.miembroIds = const [],
    this.portada,
  });

  TareaPlantilla copyWith({
    String? nombre,
    String? tituloSugerido,
    String? descripcion,
    TareaPrioridad? prioridad,
    String? grupo,
    List<String>? actividades,
    List<int>? etiquetaIds,
    List<int>? miembroIds,
    Color? portada,
    bool limpiarPortada = false,
  }) {
    return TareaPlantilla(
      id: id,
      nombre: nombre ?? this.nombre,
      tituloSugerido: tituloSugerido ?? this.tituloSugerido,
      descripcion: descripcion ?? this.descripcion,
      prioridad: prioridad ?? this.prioridad,
      grupo: grupo ?? this.grupo,
      actividades: actividades ?? this.actividades,
      etiquetaIds: etiquetaIds ?? this.etiquetaIds,
      miembroIds: miembroIds ?? this.miembroIds,
      portada: limpiarPortada ? null : (portada ?? this.portada),
    );
  }
}
