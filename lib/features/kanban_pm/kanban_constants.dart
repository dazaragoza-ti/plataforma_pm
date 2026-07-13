import 'package:flutter/material.dart';

/// Constantes visuales y de dominio del módulo Kanban PM.
///
/// La barra de herramientas y las columnas replican el diseño real del
/// tablero de referencia (captura del sistema en uso): botones
/// KANBAN/CALENDARIO/TAREAS/GRÁFICAS/MIS TAREAS, buscador + filtros, y
/// columnas TAREAS/PROCESO/PAUSA/TERMINADO/REVISADO con su color propio.
class KanbanColors {
  KanbanColors._();

  static const Color accent = Color(0xFFFB8C00);
  static const Color accentLight = Color(0xFFFFF3E0);
  static const Color accentDark = Color(0xFFEF6C00);
  static const Color bg = Color(0xFFF0F4F8);
  static const Color bg2 = Colors.white;
  static const Color bg3 = Color(0xFFF5F7FA);
  static const Color danger = Color(0xFFEF4444);
  static const Color dangerLight = Color(0xFFFEF2F2);
  static const Color ok = Color(0xFF22C55E);
  static const Color texto = Color(0xFF0F172A);
  static const Color tdim = Color(0xFF94A3B8);
  static const Color borde = Color(0xFFE2E8F0);

  // Colores de la barra de herramientas del tablero.
  static const Color toolbarTeal = Color(0xFF17A2B8);
  static const Color toolbarDark = Color(0xFF495057);
  static const Color toolbarGreen = Color(0xFF28A745);
  static const Color toolbarRed = Color(0xFFDC3545);
}

enum TareaEstatus { tareas, proceso, pausa, terminado, revisado }

class KanbanColumna {
  final TareaEstatus estatus;
  final String titulo;
  final IconData icono;
  final Color color;

  const KanbanColumna({
    required this.estatus,
    required this.titulo,
    required this.icono,
    required this.color,
  });
}

const List<KanbanColumna> kColumnas = [
  KanbanColumna(
    estatus: TareaEstatus.tareas,
    titulo: 'TAREAS',
    icono: Icons.bookmark_rounded,
    color: Color(0xFF343A40),
  ),
  KanbanColumna(
    estatus: TareaEstatus.proceso,
    titulo: 'PROCESO',
    icono: Icons.bookmark_rounded,
    color: Color(0xFF2196F3),
  ),
  KanbanColumna(
    estatus: TareaEstatus.pausa,
    titulo: 'PAUSA',
    icono: Icons.bookmark_rounded,
    color: Color(0xFFFD7E14),
  ),
  KanbanColumna(
    estatus: TareaEstatus.terminado,
    titulo: 'TERMINADO',
    icono: Icons.bookmark_rounded,
    color: Color(0xFF17A2B8),
  ),
  KanbanColumna(
    estatus: TareaEstatus.revisado,
    titulo: 'REVISADO',
    icono: Icons.bookmark_rounded,
    color: Color(0xFF28A745),
  ),
];

enum TareaPrioridad { baja, media, alta, urgente }

extension TareaPrioridadX on TareaPrioridad {
  String get etiqueta => switch (this) {
    TareaPrioridad.baja => 'Baja',
    TareaPrioridad.media => 'Media',
    TareaPrioridad.alta => 'Alta',
    TareaPrioridad.urgente => 'Urgente',
  };

  Color get color => switch (this) {
    TareaPrioridad.baja => const Color(0xFF22C55E),
    TareaPrioridad.media => const Color(0xFF2196F3),
    TareaPrioridad.alta => const Color(0xFFF59E0B),
    TareaPrioridad.urgente => const Color(0xFFEF4444),
  };
}

/// Usuario "de sesión" de referencia para la demo (MIS TAREAS, Asignado por).
/// TODO: cuando exista autenticación real, tomar esto del usuario logueado.
const kUsuarioActualDemo = 'J. Salazar';

/// Catálogo estático de áreas para etiquetar tareas.
/// TODO: cuando exista backend, mover a un catálogo consultado por API.
const List<String> kGruposDemo = [
  'Sistemas',
  'Producción',
  'Calidad',
  'Diseño',
  'Ventas',
];

/// Catálogo estático de personal para "Asignado por" / "Persona asignada".
/// TODO: cuando exista backend, sustituir por el directorio real de personal.
const List<String> kIntegrantesDemo = [
  'J. Salazar',
  'A. Martínez',
  'R. Gómez',
  'L. Torres',
  'M. Fernández',
];

/// Las 3 clasificaciones que se asignan a cada tarea en el detalle
/// (Generales / Nivel / Importancia), cada una con su color de referencia.
/// TODO: cuando exista backend, mover a catálogos consultados por API.
const List<(String, Color)> kGeneralesDemo = [
  ('(01) ACTIVIDADES CLIENTE', Color(0xFF60A5FA)),
  ('(02) ACTIVIDADES INTERNAS', Color(0xFFF472B6)),
  ('(03) ACTIVIDADES GENERALES', Color(0xFFA78BFA)),
];

const List<(String, Color)> kNivelDemo = [
  ('(IPR) COORDINACIÓN', Color(0xFFFBBF24)),
  ('(OP) OPERATIVO', Color(0xFF34D399)),
  ('(DIR) DIRECCIÓN', Color(0xFFF87171)),
];

const List<(String, Color)> kImportanciaDemo = [
  ('(AC) ACT CLAVE', Color(0xFF86EFAC)),
  ('(AN) ACT NORMAL', Color(0xFFBAE6FD)),
  ('(AU) ACT URGENTE', Color(0xFFFCA5A5)),
];
