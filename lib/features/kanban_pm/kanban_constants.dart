import 'package:flutter/material.dart';

/// Paleta de colores del módulo (un valor por rol visual). Dos instancias
/// constantes (clara/oscura) viven detrás de [KanbanColors].
class _KanbanPaleta {
  final Color accent;
  final Color accentLight;
  final Color accentDark;
  final Color bg;
  final Color bg2;
  final Color bg3;
  final Color danger;
  final Color dangerLight;
  final Color ok;
  final Color texto;
  final Color tdim;
  final Color borde;
  final Color toolbarTeal;
  final Color toolbarDark;
  final Color toolbarGreen;
  final Color toolbarRed;

  const _KanbanPaleta({
    required this.accent,
    required this.accentLight,
    required this.accentDark,
    required this.bg,
    required this.bg2,
    required this.bg3,
    required this.danger,
    required this.dangerLight,
    required this.ok,
    required this.texto,
    required this.tdim,
    required this.borde,
    required this.toolbarTeal,
    required this.toolbarDark,
    required this.toolbarGreen,
    required this.toolbarRed,
  });
}

const _paletaClara = _KanbanPaleta(
  accent: Color(0xFFFB8C00),
  accentLight: Color(0xFFFFF3E0),
  accentDark: Color(0xFFEF6C00),
  bg: Color(0xFFF0F4F8),
  bg2: Colors.white,
  bg3: Color(0xFFF5F7FA),
  danger: Color(0xFFEF4444),
  dangerLight: Color(0xFFFEF2F2),
  ok: Color(0xFF22C55E),
  texto: Color(0xFF0F172A),
  tdim: Color(0xFF94A3B8),
  borde: Color(0xFFE2E8F0),
  toolbarTeal: Color(0xFF17A2B8),
  toolbarDark: Color(0xFF495057),
  toolbarGreen: Color(0xFF28A745),
  toolbarRed: Color(0xFFDC3545),
);

const _paletaOscura = _KanbanPaleta(
  accent: Color(0xFFFB8C00),
  accentLight: Color(0xFF3D2B12),
  accentDark: Color(0xFFFFB74D),
  bg: Color(0xFF10151C),
  bg2: Color(0xFF1B222C),
  bg3: Color(0xFF141A22),
  danger: Color(0xFFF87171),
  dangerLight: Color(0xFF3B1D1D),
  ok: Color(0xFF4ADE80),
  texto: Color(0xFFE2E8F0),
  tdim: Color(0xFF8B98AC),
  borde: Color(0xFF2A323D),
  toolbarTeal: Color(0xFF22D3EE),
  toolbarDark: Color(0xFF0B0F14),
  toolbarGreen: Color(0xFF34D399),
  toolbarRed: Color(0xFFF87171),
);

/// Constantes visuales y de dominio del módulo Kanban PM.
///
/// Los colores se resuelven contra una paleta activa mutable (clara u
/// oscura) para soportar el interruptor de modo oscuro manual del tablero
/// — ver [establecerOscuro]. No hay Theme/InheritedWidget de por medio:
/// alcanza con volver a construir el árbol (un `setState` en la pantalla)
/// tras cambiar la paleta activa.
class KanbanColors {
  KanbanColors._();

  static _KanbanPaleta _activa = _paletaClara;
  static bool oscuro = false;

  static void establecerOscuro(bool valor) {
    oscuro = valor;
    _activa = valor ? _paletaOscura : _paletaClara;
  }

  static Color get accent => _activa.accent;
  static Color get accentLight => _activa.accentLight;
  static Color get accentDark => _activa.accentDark;
  static Color get bg => _activa.bg;
  static Color get bg2 => _activa.bg2;
  static Color get bg3 => _activa.bg3;
  static Color get danger => _activa.danger;
  static Color get dangerLight => _activa.dangerLight;
  static Color get ok => _activa.ok;
  static Color get texto => _activa.texto;
  static Color get tdim => _activa.tdim;
  static Color get borde => _activa.borde;

  // Colores de la barra de herramientas del tablero.
  static Color get toolbarTeal => _activa.toolbarTeal;
  static Color get toolbarDark => _activa.toolbarDark;
  static Color get toolbarGreen => _activa.toolbarGreen;
  static Color get toolbarRed => _activa.toolbarRed;

  /// Decoración plana compartida por tarjetas, paneles y tiles del módulo:
  /// borde sutil en vez de sombra, look minimal consistente entre tablero,
  /// gráficas y Gantt.
  static BoxDecoration cardDecoration({double radius = 10}) => BoxDecoration(
    color: bg2,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: borde),
  );

  /// Estilo de [SegmentedButton] con la paleta propia del módulo (acento
  /// naranja) en vez del azul del `ColorScheme` global de la app — sin
  /// esto, el segmento seleccionado hereda `colorScheme.primary` del tema
  /// ambiente, que no combina con el resto del tablero y, al ser un azul
  /// saturado con texto blanco por defecto, dificulta leer la etiqueta.
  static ButtonStyle segmentedButtonStyle() {
    Color fondo(Set<WidgetState> states) => states.contains(WidgetState.selected)
        ? accentLight
        : Colors.transparent;
    Color texto2(Set<WidgetState> states) =>
        states.contains(WidgetState.selected) ? accentDark : texto;
    BorderSide borde2(Set<WidgetState> states) => BorderSide(
      color: states.contains(WidgetState.selected) ? accent : borde,
    );
    return ButtonStyle(
      visualDensity: VisualDensity.compact,
      backgroundColor: WidgetStateProperty.resolveWith(fondo),
      foregroundColor: WidgetStateProperty.resolveWith(texto2),
      iconColor: WidgetStateProperty.resolveWith(texto2),
      side: WidgetStateProperty.resolveWith(borde2),
    );
  }
}

enum TareaEstatus { tareas, proceso, pausa, terminado, revisado }

class KanbanColumna {
  final TareaEstatus estatus;
  final String titulo;
  final IconData icono;
  final Color color;
  final bool archivada;

  const KanbanColumna({
    required this.estatus,
    required this.titulo,
    required this.icono,
    required this.color,
    this.archivada = false,
  });

  KanbanColumna copyWith({String? titulo, bool? archivada}) => KanbanColumna(
    estatus: estatus,
    titulo: titulo ?? this.titulo,
    icono: icono,
    color: color,
    archivada: archivada ?? this.archivada,
  );
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

/// Paleta de colores para crear etiquetas nuevas y para elegir portada de
/// tarjeta, estilo Trello.
const List<Color> kColorPaletteEtiquetas = [
  Color(0xFFEF4444),
  Color(0xFFF59E0B),
  Color(0xFFEAB308),
  Color(0xFF22C55E),
  Color(0xFF14B8A6),
  Color(0xFF3B82F6),
  Color(0xFF6366F1),
  Color(0xFFA855F7),
  Color(0xFFEC4899),
  Color(0xFF64748B),
];

/// Colores predefinidos para el fondo del tablero (estilo Trello).
const List<Color> kFondosTablero = [
  Color(0xFFF0F4F8),
  Color(0xFFE0F2FE),
  Color(0xFFFEF3C7),
  Color(0xFFDCFCE7),
  Color(0xFFFCE7F3),
  Color(0xFFEDE9FE),
];
