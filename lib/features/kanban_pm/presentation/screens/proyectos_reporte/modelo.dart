part of '../proyectos_reporte_screen.dart';

/// Estado visual de una tarea del reporte — un vocabulario propio
/// (cerrada/en curso/lista para iniciar/detenida por una dependencia sin
/// resolver) derivado de [TareaEstatus]/`dependeDeIds` del tablero real
/// (ver `_cargarReporteProyectos`), no una copia 1:1 de las 5 columnas.
enum _EstadoReporte { hecho, curso, libre, frena }

/// Referencia mínima a una tarea real para listas de menciones sueltas
/// (las tareas "impactadas" del tapón, las "listas para activar") donde
/// solo hace falta el texto a mostrar y cómo abrir su tarjeta completa al
/// tocarlo — a diferencia de [_TareaReporte], no necesita estado/fechas
/// propios porque no se dibuja como chip completo, solo como mención.
class _RefTarea {
  final String etiqueta;
  final KanbanRepository repo;
  final int tareaIdReal;

  const _RefTarea({
    required this.etiqueta,
    required this.repo,
    required this.tareaIdReal,
  });
}

/// Una tarea dentro de un [_ProyectoReporte].
class _TareaReporte {
  final String id;
  final String nombre;
  final String responsable;
  final _EstadoReporte estado;

  /// Texto ya formateado para mostrar como fecha/estado en el carril
  /// (p. ej. "07 jul", "listo", "espera T09", "Sin fecha").
  final String etiquetaFecha;

  /// Ids de tareas de las que depende (para el aviso "depende de …").
  final List<String> dependeDe;

  /// El repositorio y el id real (no el `"T$id"` de [id]) de la tarea que
  /// esto representa — permite abrir la tarjeta completa de verdad
  /// (`TareaDetailDialog`, la misma del tablero) al tocar su carril en vez
  /// de solo mostrar más texto.
  final KanbanRepository repo;
  final int tareaIdReal;

  /// Su checklist real (a cualquier profundidad, responsables ya resueltos
  /// a texto) — el carril de esta tarjeta en "Los proyectos" lista estas
  /// actividades y sus subtareas en vez de repetir [nombre] otra vez (antes
  /// mostraba un chip con el mismo título de la tarjeta, redundante con el
  /// encabezado del carril).
  final List<_ActividadReporte> actividades;

  const _TareaReporte({
    required this.id,
    required this.nombre,
    required this.responsable,
    required this.estado,
    required this.etiquetaFecha,
    required this.repo,
    required this.tareaIdReal,
    this.dependeDe = const [],
    this.actividades = const [],
  });
}

/// Una fila del checklist de [_TareaReporte.actividades] — mismo árbol que
/// [Actividad]/[Actividad.subActividades], pero con el responsable ya
/// resuelto a un texto (nombre de miembro o departamento) en vez del
/// `miembroId` crudo: este reporte no tiene acceso directo al catálogo de
/// miembros de cada área en el punto donde se dibuja, así que se resuelve
/// una sola vez al cargar los datos (ver `_actividadesReporte`).
class _ActividadReporte {
  final String descripcion;
  final bool terminada;
  final String? responsable;
  final List<_ActividadReporte> subActividades;

  const _ActividadReporte({
    required this.descripcion,
    required this.terminada,
    this.responsable,
    this.subActividades = const [],
  });
}

/// Una fila de la sección "Qué debe cerrar cada quien".
class _PendienteReporte {
  final String tareaId;
  final String nombre;
  final String proyecto;
  final Color color;
  final String rango;
  final _EstadoReporte estado;
  final String etiqueta;

  /// Igual que en [_TareaReporte]: permite abrir la tarjeta completa de
  /// verdad al tocar la fila, no solo la del chip del carril.
  final KanbanRepository repo;
  final int tareaIdReal;

  const _PendienteReporte({
    required this.tareaId,
    required this.nombre,
    required this.proyecto,
    required this.color,
    required this.rango,
    required this.estado,
    required this.etiqueta,
    required this.repo,
    required this.tareaIdReal,
  });
}

class _ProyectoReporte {
  final String numero;
  final String nombre;
  final Color color;
  final int cerradas;
  final int total;
  final String resumenFecha;
  final List<_TareaReporte> tareas;

  /// Rango de fechas de sus actividades (mínima fecha de inicio, máxima
  /// fecha de vencimiento) — `null` cuando ninguna de sus actividades tiene
  /// esa fecha capturada. Usado por el calendario simplificado para ubicar
  /// su franja proporcional dentro del rango global del comité.
  final DateTime? fechaInicio;
  final DateTime? fechaFin;

  const _ProyectoReporte({
    required this.numero,
    required this.nombre,
    required this.color,
    required this.cerradas,
    required this.total,
    required this.resumenFecha,
    required this.tareas,
    this.fechaInicio,
    this.fechaFin,
  });

  double get progreso => total == 0 ? 0 : cerradas / total;
}

/// Borde punteado — Flutter no lo trae de fábrica en `Border`/`BoxDecoration`
/// (`BorderStyle` solo tiene `none`/`solid`), así que se dibuja a mano con
/// un `CustomPainter`. Usado para marcar visualmente lo "detenido" (leyenda
/// y chips bloqueados por una dependencia sin resolver) distinto de lo
/// simplemente "sin empezar".
class _BordePunteado extends StatelessWidget {
  final Widget child;
  final Color color;
  final double radio;

  const _BordePunteado({required this.child, required this.color, this.radio = 6});

  @override
  Widget build(BuildContext context) {
    // `foregroundPainter` (no `painter`): así el trazo punteado se dibuja
    // ENCIMA del contenido/fondo del hijo, no detrás — con un `Container`
    // de fondo opaco como hijo, un `painter` normal quedaría tapado.
    return CustomPaint(
      foregroundPainter: _DashedRRectPainter(color: color, radio: radio),
      child: child,
    );
  }
}

class _DashedRRectPainter extends CustomPainter {
  final Color color;
  final double radio;

  const _DashedRRectPainter({required this.color, required this.radio});

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radio),
    );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final path = Path()..addRRect(rrect);
    const dashLargo = 4.0;
    const dashHueco = 3.0;
    for (final metric in path.computeMetrics()) {
      var distancia = 0.0;
      while (distancia < metric.length) {
        final siguiente = distancia + dashLargo;
        canvas.drawPath(
          metric.extractPath(distancia, siguiente.clamp(0, metric.length)),
          paint,
        );
        distancia = siguiente + dashHueco;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRRectPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radio != radio;
}
