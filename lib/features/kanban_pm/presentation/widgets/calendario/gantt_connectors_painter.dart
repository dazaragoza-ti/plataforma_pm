import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../domain/entities/tarea.dart';

/// Un enlace de dependencia ya resuelto a geometría: quién depende de quién
/// y los 4 puntos de su línea "codo" (origen → codo → codo → destino).
/// Fuente única de verdad compartida entre [GanttConnectorsPainter] (que
/// solo dibuja estos puntos) y el hit-test de [conectorBajoPunto] (que
/// mide distancia contra los mismos segmentos) — así nunca pueden
/// desalinearse "lo que se ve" y "lo que se puede tocar".
class GanttConector {
  final int origenId;
  final int destinoId;
  final Offset p1;
  final Offset p2;
  final Offset p3;
  final Offset p4;

  const GanttConector({
    required this.origenId,
    required this.destinoId,
    required this.p1,
    required this.p2,
    required this.p3,
    required this.p4,
  });
}

/// Calcula la geometría de cada enlace de dependencia visible (ambas
/// tareas con barra en [barras]) a partir de [tareas].
List<GanttConector> calcularConectores(
  List<Tarea> tareas,
  Map<int, Rect> barras,
) {
  final resultado = <GanttConector>[];
  for (final t in tareas) {
    final destino = barras[t.id];
    if (destino == null) continue;
    for (final depId in t.dependeDeIds) {
      final origen = barras[depId];
      if (origen == null) continue;
      final start = Offset(origen.right, origen.center.dy);
      final end = Offset(destino.left, destino.center.dy);
      final midX = start.dx + 14;
      resultado.add(
        GanttConector(
          origenId: depId,
          destinoId: t.id,
          p1: start,
          p2: Offset(midX, start.dy),
          p3: Offset(midX, end.dy),
          p4: Offset(end.dx - 6, end.dy),
        ),
      );
    }
  }
  return resultado;
}

double _distanciaPuntoSegmento(Offset p, Offset a, Offset b) {
  final ab = b - a;
  final largoCuadrado = ab.dx * ab.dx + ab.dy * ab.dy;
  final t = largoCuadrado == 0
      ? 0.0
      : (((p.dx - a.dx) * ab.dx + (p.dy - a.dy) * ab.dy) / largoCuadrado).clamp(
          0.0,
          1.0,
        );
  final proyeccion = Offset(a.dx + ab.dx * t, a.dy + ab.dy * t);
  return (p - proyeccion).distance;
}

/// El conector cuya línea pasa más cerca de [punto] (dentro de
/// [tolerancia] px de alguno de sus 3 segmentos), o `null` si ninguno está
/// suficientemente cerca — usado para "toca la flecha para borrar la
/// dependencia" en el Gantt.
GanttConector? conectorBajoPunto(
  List<GanttConector> conectores,
  Offset punto, {
  double tolerancia = 6,
}) {
  for (final c in conectores) {
    final d1 = _distanciaPuntoSegmento(punto, c.p1, c.p2);
    final d2 = _distanciaPuntoSegmento(punto, c.p2, c.p3);
    final d3 = _distanciaPuntoSegmento(punto, c.p3, c.p4);
    if (d1 <= tolerancia || d2 <= tolerancia || d3 <= tolerancia) return c;
  }
  return null;
}

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

    for (final c in calcularConectores(tareas, barras)) {
      final path = Path()
        ..moveTo(c.p1.dx, c.p1.dy)
        ..lineTo(c.p2.dx, c.p2.dy)
        ..lineTo(c.p3.dx, c.p3.dy)
        ..lineTo(c.p4.dx, c.p4.dy);
      canvas.drawPath(path, linea);

      final punta = Path()
        ..moveTo(c.p4.dx + 6, c.p4.dy)
        ..lineTo(c.p4.dx - 1, c.p4.dy - 4)
        ..lineTo(c.p4.dx - 1, c.p4.dy + 4)
        ..close();
      canvas.drawPath(punta, flecha);
    }
  }

  @override
  bool shouldRepaint(covariant GanttConnectorsPainter oldDelegate) {
    // `barras`/`tareas` son objetos nuevos en cada build (el estado se
    // reconstruye con `copyWith`), así que comparar por `!=` (identidad)
    // siempre daba `true` y este painter repintaba en cada frame aunque
    // nada relevante hubiera cambiado. Se compara solo lo que `paint()`
    // realmente usa: las posiciones y los enlaces de dependencia.
    if (!mapEquals(oldDelegate.barras, barras)) return true;
    if (oldDelegate.tareas.length != tareas.length) return true;
    for (var i = 0; i < tareas.length; i++) {
      final antes = oldDelegate.tareas[i];
      final ahora = tareas[i];
      if (antes.id != ahora.id ||
          !listEquals(antes.dependeDeIds, ahora.dependeDeIds)) {
        return true;
      }
    }
    return false;
  }
}
