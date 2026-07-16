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

  @override
  Widget build(BuildContext context) {
    final progreso = widget.tarea.progreso.clamp(0.0, 1.0);
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
          child: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: widget.color,
                  borderRadius: BorderRadius.circular(7),
                  border: widget.esCritica
                      ? Border.all(color: const Color(0xFFDC2626), width: 2)
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
                        fontSize: 10.5,
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
    );
  }
}
