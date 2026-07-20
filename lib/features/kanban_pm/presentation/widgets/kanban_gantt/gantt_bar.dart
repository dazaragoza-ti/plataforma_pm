import 'package:flutter/material.dart';

import '../../../domain/entities/tarea.dart';
import 'gantt_layout.dart';

typedef GanttFechasCallback = void Function(DateTime inicio, DateTime fin);

/// Barra de una tarea en el Gantt: arrastrar el cuerpo mueve ambas fechas
/// juntas, arrastrar un borde redimensiona solo esa fecha. El feedback
/// visual es en vivo (por frame) pero solo se confirma —llamando
/// [onFechasCambiadas]— al soltar, con snapping a día completo.
class GanttBar extends StatefulWidget {
  final Tarea tarea;
  final Rect rect;
  final Color color;
  final double dayWidth;
  final bool esCritica;
  final VoidCallback onTap;
  final GanttFechasCallback onFechasCambiadas;

  /// Posición global del puntero mientras se arrastra el *cuerpo* de la
  /// barra (no los bordes de resize) — el padre lo usa para autoscrollear
  /// el cronograma cuando el arrastre se acerca al borde del viewport,
  /// igual que ya hace el tablero Kanban al arrastrar una tarjeta.
  final void Function(Offset globalPos)? onArrastreCuerpoEnCurso;
  final VoidCallback? onArrastreCuerpoTerminado;

  const GanttBar({
    super.key,
    required this.tarea,
    required this.rect,
    required this.color,
    this.dayWidth = kGanttDayWidth,
    this.esCritica = false,
    required this.onTap,
    required this.onFechasCambiadas,
    this.onArrastreCuerpoEnCurso,
    this.onArrastreCuerpoTerminado,
  });

  @override
  State<GanttBar> createState() => _GanttBarState();
}

class _GanttBarState extends State<GanttBar> {
  double _deltaCuerpo = 0;
  double _deltaIzq = 0;
  double _deltaDer = 0;
  bool _arrastrandoCuerpo = false;
  bool _arrastrandoIzq = false;
  bool _arrastrandoDer = false;

  int _snapDias(double deltaPx) => (deltaPx / widget.dayWidth).round();

  void _confirmarCuerpo() {
    final dias = _snapDias(_deltaCuerpo);
    setState(() {
      _arrastrandoCuerpo = false;
      _deltaCuerpo = 0;
    });
    if (dias == 0) return;
    widget.onFechasCambiadas(
      widget.tarea.fechaInicio!.add(Duration(days: dias)),
      widget.tarea.fechaVencimiento!.add(Duration(days: dias)),
    );
  }

  void _confirmarIzquierda() {
    final dias = _snapDias(_deltaIzq);
    setState(() {
      _arrastrandoIzq = false;
      _deltaIzq = 0;
    });
    if (dias == 0) return;
    final fin = widget.tarea.fechaVencimiento!;
    var inicio = widget.tarea.fechaInicio!.add(Duration(days: dias));
    if (inicio.isAfter(fin)) inicio = fin;
    widget.onFechasCambiadas(inicio, fin);
  }

  void _confirmarDerecha() {
    final dias = _snapDias(_deltaDer);
    setState(() {
      _arrastrandoDer = false;
      _deltaDer = 0;
    });
    if (dias == 0) return;
    final inicio = widget.tarea.fechaInicio!;
    var fin = widget.tarea.fechaVencimiento!.add(Duration(days: dias));
    if (fin.isBefore(inicio)) fin = inicio;
    widget.onFechasCambiadas(inicio, fin);
  }

  Widget _asaResize({
    required VoidCallback onStart,
    required void Function(double dx) onUpdate,
    required VoidCallback onEnd,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeLeftRight,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragStart: (_) => onStart(),
        onHorizontalDragUpdate: (d) => onUpdate(d.delta.dx),
        onHorizontalDragEnd: (_) => onEnd(),
      ),
    );
  }

  /// Un hito (fecha clave sin duración) en vez de una barra: tareas cuyo
  /// inicio y vencimiento caen el mismo día se dibujan como un diamante,
  /// con el título como etiqueta al lado — la convención habitual de
  /// Gantt para una fecha puntual, no un rango de trabajo.
  bool get _esHito =>
      widget.tarea.fechaInicio != null &&
      widget.tarea.fechaVencimiento != null &&
      duracionDiasDe(widget.tarea) == 1;

  Widget _cuerpoHito() {
    final lado = widget.rect.height * 0.7;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Center(
          child: Transform.rotate(
            angle: 0.785398163, // 45°
            child: Container(
              width: lado,
              height: lado,
              decoration: BoxDecoration(
                color: widget.color,
                border: widget.esCritica
                    ? Border.all(color: const Color(0xFFDC2626), width: 2)
                    : null,
              ),
            ),
          ),
        ),
        Positioned(
          left: widget.rect.width,
          top: 0,
          bottom: 0,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 5),
              child: Text(
                widget.tarea.titulo,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: widget.color,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final progreso = widget.tarea.progreso.clamp(0.0, 1.0);
    final esHito = _esHito;
    var left = widget.rect.left;
    var width = widget.rect.width;

    if (_arrastrandoCuerpo) {
      left += _snapDias(_deltaCuerpo) * widget.dayWidth;
    } else if (_arrastrandoIzq) {
      final nuevoAncho = width - _snapDias(_deltaIzq) * widget.dayWidth;
      if (nuevoAncho >= widget.dayWidth) {
        left += _snapDias(_deltaIzq) * widget.dayWidth;
        width = nuevoAncho;
      }
    } else if (_arrastrandoDer) {
      final nuevoAncho = width + _snapDias(_deltaDer) * widget.dayWidth;
      if (nuevoAncho >= widget.dayWidth) {
        width = nuevoAncho;
      }
    }

    // Ancho de asa proporcional, no fijo: a 8px fijos, dos tareas cortas en
    // zoom "Mes" (dayWidth chico) terminaban con las dos asas superpuestas
    // cubriendo la barra entera, sin dejar cuerpo para arrastrar-mover —
    // solo se podía redimensionar. Con esto, el cuerpo siempre conserva al
    // menos un tercio del ancho.
    final anchoAsa = (width / 3).clamp(0.0, 8.0);

    return Positioned(
      left: left,
      top: widget.rect.top,
      width: width,
      height: widget.rect.height,
      // Todo lo demás en esta barra es un `CustomPainter`/`Positioned` sin
      // ningún texto real de por medio — sin este `Semantics`, un lector
      // de pantalla no tiene forma de saber qué tarea es esta ni sus
      // fechas (la vista Lista sí es texto real y ya es accesible).
      child: Semantics(
        label: _etiquetaAccesible(),
        button: true,
        onTap: widget.onTap,
        child: Tooltip(
          message: widget.tarea.titulo,
          waitDuration: const Duration(milliseconds: 300),
          child: MouseRegion(
            cursor: SystemMouseCursors.grab,
            child: GestureDetector(
              onTap: widget.onTap,
              onHorizontalDragStart: (_) => setState(() {
                _arrastrandoCuerpo = true;
                _deltaCuerpo = 0;
              }),
              onHorizontalDragUpdate: (d) {
                setState(() => _deltaCuerpo += d.delta.dx);
                widget.onArrastreCuerpoEnCurso?.call(d.globalPosition);
              },
              onHorizontalDragEnd: (_) {
                _confirmarCuerpo();
                widget.onArrastreCuerpoTerminado?.call();
              },
              child: esHito
                  ? _cuerpoHito()
                  : Stack(
                      children: [
                        // `Positioned.fill` (no un `Container` suelto): sin
                        // esto, como el `Container` no tenía ancho propio, se
                        // encogía para ajustarse al `FractionallySizedBox` del
                        // relleno de progreso — el fondo entero de la barra
                        // se reducía a solo el % de avance en vez de quedarse
                        // a ancho completo con el relleno adentro.
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              color: widget.color,
                              borderRadius: BorderRadius.circular(7),
                              border: widget.esCritica
                                  ? Border.all(
                                      color: const Color(0xFFDC2626),
                                      width: 2,
                                    )
                                  : null,
                            ),
                          ),
                        ),
                        if (progreso > 0)
                          Positioned.fill(
                            child: FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: progreso,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                            ),
                          ),
                        Positioned.fill(
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                              ),
                              child: Text(
                                widget.tarea.titulo,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Ícono además del borde rojo: el borde solo (una
                        // señal de puro color) puede confundirse con el
                        // naranja de la columna PAUSA para quien tiene
                        // daltonismo — con el ícono, "está en la ruta
                        // crítica" no depende de distinguir el tono exacto.
                        if (widget.esCritica)
                          const Positioned(
                            top: 1,
                            right: 1,
                            child: Icon(
                              Icons.bolt_rounded,
                              size: 13,
                              color: Colors.white,
                              shadows: [
                                Shadow(color: Colors.black45, blurRadius: 2),
                              ],
                            ),
                          ),
                        Positioned(
                          left: 0,
                          top: 0,
                          bottom: 0,
                          width: anchoAsa,
                          child: _asaResize(
                            onStart: () => setState(() {
                              _arrastrandoIzq = true;
                              _deltaIzq = 0;
                            }),
                            onUpdate: (dx) => setState(() => _deltaIzq += dx),
                            onEnd: _confirmarIzquierda,
                          ),
                        ),
                        Positioned(
                          right: 0,
                          top: 0,
                          bottom: 0,
                          width: anchoAsa,
                          child: _asaResize(
                            onStart: () => setState(() {
                              _arrastrandoDer = true;
                              _deltaDer = 0;
                            }),
                            onUpdate: (dx) => setState(() => _deltaDer += dx),
                            onEnd: _confirmarDerecha,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  /// Descripción textual de la barra para lectores de pantalla: el resto
  /// del contenido es puro `CustomPainter`/`Positioned`, así que sin esto
  /// no habría ninguna forma de saber qué tarea es ni sus fechas.
  String _etiquetaAccesible() {
    String fmt(DateTime d) =>
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    final ini = widget.tarea.fechaInicio;
    final fin = widget.tarea.fechaVencimiento;
    final rango = (ini != null && fin != null)
        ? (_esHito ? fmt(ini) : 'del ${fmt(ini)} al ${fmt(fin)}')
        : 'sin fecha';
    final critica = widget.esCritica ? ', en la ruta crítica' : '';
    return '${widget.tarea.titulo}, $rango$critica';
  }
}
