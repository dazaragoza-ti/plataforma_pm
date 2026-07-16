import 'package:flutter/material.dart';

import '../../../domain/entities/tarea.dart';

/// Dibuja líneas "codo" con flecha entre las barras de tareas dependientes,
/// usando el mismo `Map<int, Rect>` que posiciona las barras (fuente única
/// de verdad para la geometría). Si falta alguna de las dos tareas de un
/// enlace, esa línea simplemente se omite en vez de fallar.
class GanttConnectorsPainter extends CustomPainter {
  final List<Tarea> tareas;
  final Map<int, Rect> barras;

  const GanttConnectorsPainter({required this.tareas, required this.barras});

  @override
  void paint(Canvas canvas, Size size) {
    final linea = Paint()
      ..color = const Color(0xFF94A3B8)
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;
    final flecha = Paint()..color = const Color(0xFF94A3B8);

    for (final t in tareas) {
      final destino = barras[t.id];
      if (destino == null) continue;
      for (final depId in t.dependeDeIds) {
        final origen = barras[depId];
        if (origen == null) continue;
        _dibujarConector(canvas, linea, flecha, origen, destino);
      }
    }
  }

  void _dibujarConector(
    Canvas canvas,
    Paint linea,
    Paint flecha,
    Rect origen,
    Rect destino,
  ) {
    final start = Offset(origen.right, origen.center.dy);
    final end = Offset(destino.left, destino.center.dy);
    final midX = start.dx + 14;
    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..lineTo(midX, start.dy)
      ..lineTo(midX, end.dy)
      ..lineTo(end.dx - 6, end.dy);
    canvas.drawPath(path, linea);

    final punta = Path()
      ..moveTo(end.dx, end.dy)
      ..lineTo(end.dx - 7, end.dy - 4)
      ..lineTo(end.dx - 7, end.dy + 4)
      ..close();
    canvas.drawPath(punta, flecha);
  }

  @override
  bool shouldRepaint(covariant GanttConnectorsPainter oldDelegate) {
    return oldDelegate.barras != barras || oldDelegate.tareas != tareas;
  }
}
