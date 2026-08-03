import 'package:flutter/material.dart';
import 'domain/entities/kanban_columna.dart';
import 'domain/entities/tarea_estatus.dart';

export 'domain/entities/kanban_columna.dart';
export 'domain/entities/tarea_estatus.dart';
export 'domain/entities/tarea_prioridad.dart';

/// Por debajo de este ancho se considera "celular" en todo el módulo Kanban
/// (header, tablero, columnas) — un solo umbral compartido para que un
/// cambio futuro no exija tocarlo en varios archivos por separado.
const kUmbralMovilKanban = 600.0;

/// Nombre y color de la etiqueta reservada para el comité (ver
/// `Usuario.perteneceComite`) — se auto-provisiona sola la primera vez que
/// alguien del comité abre un tablero (`_cargarColumnasYEtiquetas`), y solo
/// alguien del comité puede aplicarla/quitarla o administrarla desde
/// "Etiquetas"; el resto la ve como una etiqueta más de solo lectura en
/// cualquier tarjeta donde ya esté puesta. Comparado aquí (no repetido como
/// texto suelto) para que el auto-provisionamiento y los filtros de la UI
/// nunca puedan desincronizarse sobre cuál etiqueta es "la del comité".
const kNombreEtiquetaComite = 'Comité';
const kColorEtiquetaComite = Color(0xFF3730A3);

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
  // Antes 0xFF94A3B8: contra fondos claros (bg2 blanco, bg3 0xFFF5F7FA) daba
  // ~2.4-2.6:1 de contraste, muy por debajo del 4.5:1 de WCAG AA para texto
  // normal (el modo oscuro sí pasaba, ~6:1). Este tono (slate-600) da ~7:1
  // contra ambos fondos claros.
  tdim: Color(0xFF475569),
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

  /// Color de fondo del tablero elegido con el selector de paleta (ver
  /// `_fondoIdx` en el dashboard) — `null` mientras no se haya tocado ese
  /// selector. Vive aquí, junto a [oscuro], para que cualquier
  /// tarjeta/tile del módulo pueda teñirse con él sin tener que recibirlo
  /// por parámetro desde la pantalla que sí lo controla.
  static Color? fondoTablero;

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

  /// `bg2` mezclado con [fondoTablero], para tarjetas/tiles a las que sí
  /// les toca dejar ver el color de fondo elegido en el selector de
  /// paleta — el mismo lenguaje visual que ya usaban las filas del Gantt
  /// (`bg3.withValues(alpha: 0.4)` sobre el fondo del `Scaffold`, es decir
  /// solo 40% del tono neutro y 60% del color elegido), pero mezclado en
  /// vez de superpuesto para no perder legibilidad del texto. Con el
  /// primer valor probado (72% neutro) el resultado se veía casi blanco:
  /// muy por debajo de lo notorio que se ve en el Gantt. Sin
  /// [fondoTablero] elegido (o en modo oscuro, que no usa
  /// `kFondosTablero`) es idéntico a [bg2].
  static Color get bg2ConFondo {
    final fondo = fondoTablero;
    if (oscuro || fondo == null) return bg2;
    return Color.alphaBlend(bg2.withValues(alpha: 0.4), fondo);
  }

  /// Igual que [bg2ConFondo] pero mezclando sobre [bg3] — para superficies
  /// que normalmente usan ese tono en vez de `bg2` (p. ej. el cuerpo de
  /// una columna del tablero).
  static Color get bg3ConFondo {
    final fondo = fondoTablero;
    if (oscuro || fondo == null) return bg3;
    return Color.alphaBlend(bg3.withValues(alpha: 0.4), fondo);
  }

  /// Variante de [cardDecoration] que deja ver el fondo del tablero (ver
  /// [bg2ConFondo]) — para las tarjetas/tiles de Kanban, Lista y Gráficas
  /// que antes se quedaban blancas/oscuras sin importar qué fondo se
  /// eligiera en el selector de paleta, a diferencia de las filas del
  /// Gantt.
  static BoxDecoration cardDecorationConFondo({double radius = 10}) =>
      BoxDecoration(
        color: bg2ConFondo,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borde),
      );

  /// Estilo de [SegmentedButton] con la paleta propia del módulo (acento
  /// naranja) en vez del azul del `ColorScheme` global de la app — sin
  /// esto, el segmento seleccionado hereda `colorScheme.primary` del tema
  /// ambiente, que no combina con el resto del tablero y, al ser un azul
  /// saturado con texto blanco por defecto, dificulta leer la etiqueta.
  static ButtonStyle segmentedButtonStyle() {
    Color fondo(Set<WidgetState> states) =>
        states.contains(WidgetState.selected)
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
    // Regla del negocio: solo una tarea a la vez en proceso. Antes el
    // límite de WIP era puramente decorativo (solo pintaba la columna en
    // rojo al pasarse) — ver [_moverTarea]/[_moverTareasEnLote] en el
    // dashboard y `_iniciar` en `TareaDetailDialog`, que ahora sí
    // bloquean el movimiento en vez de solo advertirlo.
    limiteWip: 1,
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
  // 6to nombre → usuarioId 'u6' en el seed de `_seed()` (mismo orden que
  // `UsuarioDirectorio`, donde Javier es 'u6') — así "Mi tablero" ya
  // arranca con él como miembro, sin tener que crear un área de trabajo
  // nueva a mano solo para probar la etiqueta/botón exclusivos del comité.
  'Javier',
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
/// tarjeta, estilo Trello. 20 en vez de 10: la mitad original ya cubría un
/// tono por familia (rojo, ámbar, verde...) pero no dejaba elegir entre una
/// variante más clara/oscura o un tono vecino (cian, lima, violeta) sin
/// terminar repitiendo colores ya usados por otra etiqueta.
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
  Color(0xFFDC2626),
  Color(0xFFFB923C),
  Color(0xFF84CC16),
  Color(0xFF10B981),
  Color(0xFF06B6D4),
  Color(0xFF0EA5E9),
  Color(0xFF8B5CF6),
  Color(0xFFD946EF),
  Color(0xFFF43F5E),
  Color(0xFF334155),
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

/// Aviso rápido (SnackBar) con el estilo estándar del módulo — antes cada
/// diálogo (fuera del mixin del dashboard, que ya tenía su propio `_toast`)
/// reconstruía a mano el mismo `ScaffoldMessenger.showSnackBar` con
/// `KanbanColors.ok`/`.danger`.
void kanbanToast(BuildContext context, String msg, {bool ok = true}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(msg, style: const TextStyle(color: Colors.white)),
      backgroundColor: ok ? KanbanColors.ok : KanbanColors.danger,
    ),
  );
}

/// Igual que [kanbanToast] pero con una acción (típicamente "Deshacer") y
/// más tiempo en pantalla para alcanzar a tocarla.
void kanbanToastAccion(
  BuildContext context,
  String msg,
  String etiquetaAccion,
  VoidCallback onAccion,
) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(msg, style: const TextStyle(color: Colors.white)),
      backgroundColor: KanbanColors.ok,
      duration: const Duration(seconds: 5),
      action: SnackBarAction(
        label: etiquetaAccion,
        textColor: Colors.white,
        onPressed: onAccion,
      ),
    ),
  );
}

/// `InputDecoration` estándar del módulo para campos de texto en diálogos
/// (fondo `bg3`, borde `borde`, borde de foco `accent`) — antes cada
/// diálogo (nueva tarea, plantillas, etiquetas, nueva lista, nueva área de
/// trabajo, detalle de tarea, pausar tarea...) repetía este mismo bloque a
/// mano, con radios de esquina inconsistentes (8/9/10) sin ninguna razón
/// real para variar entre uno y otro.
InputDecoration kanbanInputDecoration({String? label, String? hint}) {
  return InputDecoration(
    labelText: label,
    labelStyle: label == null
        ? null
        : TextStyle(fontSize: 12, color: KanbanColors.tdim),
    hintText: hint,
    hintStyle: hint == null ? null : TextStyle(color: KanbanColors.tdim),
    isDense: true,
    filled: true,
    fillColor: KanbanColors.bg3,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: KanbanColors.borde),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: KanbanColors.borde),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: KanbanColors.accent, width: 2),
    ),
  );
}

/// Formato `dd/MM/yyyy` usado en toda la lista/calendario/gantt/detalle de
/// tarea. `null` devuelve `''` (útil para fechas reales que aún no se han
/// registrado) en vez de forzar a cada llamador a comprobarlo antes.
String kanbanFecha(DateTime? d) => d == null
    ? ''
    : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

const _kMesesCortosKanban = [
  'ene',
  'feb',
  'mar',
  'abr',
  'may',
  'jun',
  'jul',
  'ago',
  'sep',
  'oct',
  'nov',
  'dic',
];

/// Formato compacto `27 jul` usado en la tarjeta de tarea del tablero,
/// donde el espacio horizontal es más limitado que en la lista/detalle.
String kanbanFechaCompacta(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')} ${_kMesesCortosKanban[d.month - 1]}';
