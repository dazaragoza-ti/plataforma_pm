import 'package:flutter/material.dart';
import 'tarea_estatus.dart';

/// Una lista/columna del tablero (TAREAS, PROCESO, PAUSA... o una creada
/// por el usuario vía [TareaEstatus.personalizado]).
class KanbanColumna {
  final TareaEstatus estatus;
  final String titulo;
  final IconData icono;
  final Color color;
  final bool archivada;

  /// Límite de tarjetas (WIP) sugerido para esta columna — `null` significa
  /// sin límite. Es solo un aviso visual: no bloquea soltar una tarjeta de
  /// más.
  final int? limiteWip;

  const KanbanColumna({
    required this.estatus,
    required this.titulo,
    required this.icono,
    required this.color,
    this.archivada = false,
    this.limiteWip,
  });

  KanbanColumna copyWith({
    String? titulo,
    bool? archivada,
    int? limiteWip,
    bool limpiarLimiteWip = false,
  }) => KanbanColumna(
    estatus: estatus,
    titulo: titulo ?? this.titulo,
    icono: icono,
    color: color,
    archivada: archivada ?? this.archivada,
    limiteWip: limpiarLimiteWip ? null : (limiteWip ?? this.limiteWip),
  );
}
