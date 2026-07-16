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

  const GanttBar({
    super.key,
    required this.tarea,
    required this.rect,
    required this.color,
    this.dayWidth = kGanttDayWidth,
    this.esCritica = false,
    required this.onTap,
    required this.onFechasCambiadas,
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

    return Positioned(
      left: left,
      top: widget.rect.top,
      width: width,
      height: widget.rect.height,
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
            onHorizontalDragUpdate: (d) =>
                setState(() => _deltaCuerpo += d.delta.dx),
            onHorizontalDragEnd: (_) => _confirmarCuerpo(),
            child: esHito
                ? _cuerpoHito()
                : Stack(
                    children: [
                      Container(
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
                        child: progreso > 0
                            ? FractionallySizedBox(
                                alignment: Alignment.centerLeft,
                                widthFactor: progreso,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                              )
                            : null,
                      ),
                      Positioned.fill(
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
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
                      Positioned(
                        left: 0,
                        top: 0,
                        bottom: 0,
                        width: 8,
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
                        width: 8,
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
    );
  }
}
