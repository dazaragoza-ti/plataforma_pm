import 'dart:ui' show Rect;

import '../../../kanban_constants.dart';
import '../../../domain/entities/tarea.dart';

/// Ancho de un día en la línea de tiempo, alto de fila y alto de barra del
/// Gantt. Constantes compartidas por el layout puro y los widgets que lo
/// pintan, para que ambos midan exactamente lo mismo.
const double kGanttDayWidth = 40;
const double kGanttRowHeight = 56;
const double kGanttBarHeight = 30;
const double kGanttHeaderHeight = 52;
const double kGanttTitleColumnWidth = 240;
const double kGanttSeccionEspacio = 28;

/// Niveles de zoom del Gantt: cuánto mide un día en píxeles y con qué
/// granularidad se etiqueta el encabezado.
enum GanttZoom {
  dia(dayWidth: 40),
  semana(dayWidth: 16),
  mes(dayWidth: 6);

  final double dayWidth;
  const GanttZoom({required this.dayWidth});
}

/// Una fila del Gantt: una tarea (con fecha completa) dentro de su columna.
class GanttFila {
  final Tarea tarea;
  final KanbanColumna columna;

  const GanttFila({required this.tarea, required this.columna});
}

/// Resultado del cálculo de layout: límites de la línea de tiempo, filas en
/// el orden en que se dibujan, geometría de cada barra y las tareas que no
/// tienen fecha completa (no se les inventa fecha, se listan aparte).
class GanttLayout {
  final DateTime inicio;
  final DateTime fin;
  final int totalDias;
  final List<GanttFila> filas;
  final Map<int, Rect> barras;

  /// Barra de tiempo *real* por tarea (comparación planeado vs. real):
  /// solo presente cuando la tarea tiene `fechaInicioReal`. Si aún no tiene
  /// `fechaFinReal` (sigue en curso), el rect se extiende hasta hoy.
  final Map<int, Rect> barrasReales;

  /// Ids de tareas cuya barra real sigue abierta (sin `fechaFinReal` aún),
  /// para poder pintarla con un estilo distinto (p. ej. borde punteado).
  final Set<int> realesEnCurso;

  final List<Tarea> sinFechas;

  const GanttLayout({
    required this.inicio,
    required this.fin,
    required this.totalDias,
    required this.filas,
    required this.barras,
    required this.barrasReales,
    required this.realesEnCurso,
    required this.sinFechas,
  });
}

/// Normaliza una fecha a medianoche (sin hora), para que la duración en
/// días de una tarea no dependa de la hora exacta de sus timestamps.
DateTime soloFecha(DateTime d) => DateTime(d.year, d.month, d.day);

/// Duración en días de [t] (inclusiva en ambos extremos), la misma fórmula
/// usada para el ancho de las barras — se comparte desde aquí para que el
/// cálculo de ruta crítica nunca pueda divergir visualmente de las barras.
/// Requiere que `t.fechaInicio`/`t.fechaVencimiento` no sean null.
int duracionDiasDe(Tarea t) {
  final ini = soloFecha(t.fechaInicio!);
  var fin = soloFecha(t.fechaVencimiento!);
  if (fin.isBefore(ini)) fin = ini;
  return fin.difference(ini).inDays + 1;
}

/// Calcula el layout completo del Gantt a partir de las tareas visibles y
/// el orden de columnas del tablero. Función pura: no depende de
/// `BuildContext` ni de nada que requiera un frame ya construido, así que
/// puede alimentar tanto las barras (`Positioned`) como el `CustomPainter`
/// de conectores con la misma fuente de geometría.
GanttLayout calcularGanttLayout({
  required List<Tarea> tareas,
  required List<KanbanColumna> columnas,
  double dayWidth = kGanttDayWidth,
}) {
  final conFechas = tareas
      .where((t) => t.fechaInicio != null && t.fechaVencimiento != null)
      .toList();
  final sinFechas = tareas
      .where((t) => t.fechaInicio == null || t.fechaVencimiento == null)
      .toList();

  final hoy = soloFecha(DateTime.now());
  var minFecha = hoy.subtract(const Duration(days: 3));
  var maxFecha = hoy.add(const Duration(days: 10));
  for (final t in conFechas) {
    final ini = soloFecha(t.fechaInicio!);
    var fin = soloFecha(t.fechaVencimiento!);
    if (fin.isBefore(ini)) fin = ini;
    if (ini.isBefore(minFecha)) minFecha = ini;
    if (fin.isAfter(maxFecha)) maxFecha = fin;
    if (t.fechaInicioReal != null) {
      final iniReal = soloFecha(t.fechaInicioReal!);
      final finReal = soloFecha(t.fechaFinReal ?? hoy);
      if (iniReal.isBefore(minFecha)) minFecha = iniReal;
      if (finReal.isAfter(maxFecha)) maxFecha = finReal;
    }
  }
  minFecha = minFecha.subtract(const Duration(days: 2));
  maxFecha = maxFecha.add(const Duration(days: 2));
  final totalDias = maxFecha.difference(minFecha).inDays + 1;

  final filas = <GanttFila>[];
  for (final col in columnas) {
    final enColumna = conFechas.where((t) => t.estatus == col.estatus).toList()
      ..sort((a, b) => a.fechaInicio!.compareTo(b.fechaInicio!));
    for (final t in enColumna) {
      filas.add(GanttFila(tarea: t, columna: col));
    }
  }

  // Dos cronogramas independientes (planeado / real) comparten el mismo
  // orden de filas y la misma escala de días, pero cada uno es su propio
  // bloque de una barra por fila — nada de apilar dos barras en una misma
  // fila. `margenSuperior` centra esa única barra dentro de su fila.
  final margenSuperior = (kGanttRowHeight - kGanttBarHeight) / 2;
  final barras = <int, Rect>{};
  final barrasReales = <int, Rect>{};
  final realesEnCurso = <int>{};
  for (var i = 0; i < filas.length; i++) {
    final t = filas[i].tarea;
    final ini = soloFecha(t.fechaInicio!);
    final diasDesdeInicio = ini.difference(minFecha).inDays;
    final duracionDias = duracionDiasDe(t);
    final x = diasDesdeInicio * dayWidth;
    final y = i * kGanttRowHeight + margenSuperior;
    final width = duracionDias * dayWidth;
    barras[t.id] = Rect.fromLTWH(x, y, width, kGanttBarHeight);

    if (t.fechaInicioReal != null) {
      final enCurso = t.fechaFinReal == null;
      final iniReal = soloFecha(t.fechaInicioReal!);
      var finReal = soloFecha(t.fechaFinReal ?? hoy);
      if (finReal.isBefore(iniReal)) finReal = iniReal;
      final xReal = iniReal.difference(minFecha).inDays * dayWidth;
      final duracionReal = finReal.difference(iniReal).inDays + 1;
      barrasReales[t.id] = Rect.fromLTWH(
        xReal,
        y,
        duracionReal * dayWidth,
        kGanttBarHeight,
      );
      if (enCurso) realesEnCurso.add(t.id);
    }
  }

  return GanttLayout(
    inicio: minFecha,
    fin: maxFecha,
    totalDias: totalDias,
    filas: filas,
    barras: barras,
    barrasReales: barrasReales,
    realesEnCurso: realesEnCurso,
    sinFechas: sinFechas,
  );
}

/// `true` si dejar que [dependienteId] dependa de [predecesoraId] (i.e.
/// agregar `predecesoraId` a `dependeDeIds` de la tarea [dependienteId])
/// cerraría un ciclo — o sea, si `predecesoraId` ya depende, directa o
/// transitivamente, de `dependienteId`. Se usa tanto al elegir
/// dependencias desde el detalle de la tarea como al arrastrar un
/// conector entre barras del Gantt.
///
/// Guard de ciclos por *camino* (no un `Set` global de visitados): un
/// grafo en diamante (dos ramas llegando al mismo ancestro) no debe
/// cortar la búsqueda antes de tiempo solo porque esa tarea ya se visitó
/// por la otra rama.
bool creariaCicloDependencia(
  List<Tarea> tareas, {
  required int dependienteId,
  required int predecesoraId,
}) {
  final visitados = <int>{};
  bool dfs(int actualId) {
    if (actualId == dependienteId) return true;
    if (!visitados.add(actualId)) return false;
    final idx = tareas.indexWhere((x) => x.id == actualId);
    if (idx == -1) return false;
    for (final depId in tareas[idx].dependeDeIds) {
      if (dfs(depId)) return true;
    }
    return false;
  }

  return dfs(predecesoraId);
}
