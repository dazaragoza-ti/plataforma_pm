import '../../../domain/entities/tarea.dart';
import 'gantt_layout.dart';

/// Calcula la ruta crítica de un conjunto de tareas con fecha completa:
/// el camino de mayor duración total a través de las dependencias
/// (`dependeDeIds`). Es un CPM simplificado (sin nivelación de recursos),
/// suficiente para resaltar visualmente qué tareas no tienen holgura.
///
/// Guard de ciclos por *camino* (no confía en que la UI ya los evitó — un
/// futuro repositorio real podría escribir datos con un ciclo por otra
/// vía). Desempate determinista por id ascendente para que el resaltado no
/// "parpadee" entre dos caminos empatados en distintos renders.
Set<int> calcularRutaCritica(List<Tarea> tareas) {
  final conFechas = tareas
      .where((t) => t.fechaInicio != null && t.fechaVencimiento != null)
      .toList();
  if (conFechas.isEmpty) return {};

  final porId = {for (final t in conFechas) t.id: t};
  final memo = <int, int>{};
  final prev = <int, int?>{};

  int calcular(int id, Set<int> enCamino) {
    if (memo.containsKey(id)) return memo[id]!;
    if (enCamino.contains(id)) return 0; // ciclo: no aporta más holgura
    final t = porId[id];
    if (t == null) return 0;
    final duracion = duracionDiasDe(t);
    var mejor = duracion;
    int? mejorPrev;
    final siguienteCamino = {...enCamino, id};
    for (final depId in t.dependeDeIds) {
      if (!porId.containsKey(depId)) continue;
      final candidato = calcular(depId, siguienteCamino) + duracion;
      if (candidato > mejor) {
        mejor = candidato;
        mejorPrev = depId;
      }
    }
    memo[id] = mejor;
    prev[id] = mejorPrev;
    return mejor;
  }

  for (final t in conFechas) {
    calcular(t.id, {});
  }

  final idsOrdenados = memo.keys.toList()..sort();
  var finalId = idsOrdenados.first;
  for (final id in idsOrdenados) {
    if (memo[id]! > memo[finalId]!) finalId = id;
  }

  final ruta = <int>{};
  int? cursor = finalId;
  while (cursor != null && ruta.add(cursor)) {
    cursor = prev[cursor];
  }
  return ruta;
}
