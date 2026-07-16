import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../kanban_constants.dart';
import '../../domain/entities/tarea.dart';

/// Paleta validada (CVD-safe) para la dona de estatus. Distinta de los
/// colores de encabezado de columna (que ya llevan ícono + texto propios):
/// aquí el color ES la identidad, así que debe pasar los checks de la
/// skill de dataviz. Ver `kanban_constants.dart` para los colores de columna.
const Map<TareaEstatus, Color> _kColorGraficaEstatus = {
  TareaEstatus.tareas: Color(0xFF6366F1),
  TareaEstatus.proceso: Color(0xFF2196F3),
  TareaEstatus.pausa: Color(0xFFFD7E14),
  TareaEstatus.terminado: Color(0xFF17A2B8),
  TareaEstatus.revisado: Color(0xFF28A745),
};

/// Vista de "Gráficas": KPIs y distribución de tareas por estatus y por
/// prioridad, calculados sobre la lista de tareas visible en el tablero
/// (respeta los filtros activos).
class KanbanGraficasView extends StatelessWidget {
  final List<Tarea> tareas;
  final List<KanbanColumna> columnas;

  const KanbanGraficasView({
    super.key,
    required this.tareas,
    required this.columnas,
  });

  @override
  Widget build(BuildContext context) {
    final total = tareas.length;
    final completadas = tareas
        .where(
          (t) =>
              t.estatus == TareaEstatus.terminado ||
              t.estatus == TareaEstatus.revisado,
        )
        .length;
    final vencidas = tareas.where((t) => t.vencida).length;
    final enProceso = tareas
        .where((t) => t.estatus == TareaEstatus.proceso)
        .length;
    final porcentaje = total == 0 ? 0 : (completadas / total * 100).round();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _statTile(
                'Total de tareas',
                '$total',
                Icons.view_kanban_rounded,
                KanbanColors.accent,
              ),
              _statTile(
                'Completadas',
                '$porcentaje%',
                Icons.check_circle_rounded,
                KanbanColors.ok,
              ),
              _statTile(
                'En proceso',
                '$enProceso',
                Icons.autorenew_rounded,
                const Color(0xFF2196F3),
              ),
              _statTile(
                'Vencidas',
                '$vencidas',
                Icons.warning_rounded,
                KanbanColors.danger,
              ),
            ],
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final apilar = constraints.maxWidth < 720;
              final donut = _tarjeta('Tareas por estatus', _graficaEstatus());
              final barras = _tarjeta(
                'Tareas por prioridad',
                _graficaPrioridad(),
              );
              if (apilar) {
                return Column(
                  children: [donut, const SizedBox(height: 16), barras],
                );
              }
              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: donut),
                    const SizedBox(width: 16),
                    Expanded(child: barras),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _statTile(String label, String valor, IconData icon, Color color) {
    return Container(
      width: 200,
      padding: const EdgeInsets.all(16),
      decoration: KanbanColors.cardDecoration(radius: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 19, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  valor,
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w600,
                    color: KanbanColors.texto,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(fontSize: 11.5, color: KanbanColors.tdim),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tarjeta(String titulo, Widget child) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: KanbanColors.cardDecoration(radius: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: KanbanColors.texto,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _graficaEstatus() {
    if (tareas.isEmpty) return _sinDatos();
    final conteos = {
      for (final col in columnas)
        col.estatus: tareas.where((t) => t.estatus == col.estatus).length,
    };

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 150,
          height: 150,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 40,
              sections: [
                for (final col in columnas)
                  if (conteos[col.estatus]! > 0)
                    PieChartSectionData(
                      value: conteos[col.estatus]!.toDouble(),
                      color: _kColorGraficaEstatus[col.estatus],
                      radius: 30,
                      title: '${conteos[col.estatus]}',
                      titleStyle: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final col in columnas)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: _kColorGraficaEstatus[col.estatus],
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          col.titulo,
                          style: TextStyle(
                            fontSize: 12,
                            color: KanbanColors.texto,
                          ),
                        ),
                      ),
                      Text(
                        '${conteos[col.estatus]}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: KanbanColors.texto,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _graficaPrioridad() {
    if (tareas.isEmpty) return _sinDatos();
    final conteos = {
      for (final p in TareaPrioridad.values)
        p: tareas.where((t) => t.prioridad == p).length,
    };
    final maxY = conteos.values
        .fold<int>(0, (a, b) => a > b ? a : b)
        .toDouble();

    return SizedBox(
      height: 180,
      child: BarChart(
        BarChartData(
          maxY: maxY == 0 ? 1 : maxY + 1,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final p = TareaPrioridad.values[value.toInt()];
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      p.etiqueta,
                      style: TextStyle(
                        fontSize: 10.5,
                        color: KanbanColors.tdim,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < TareaPrioridad.values.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: conteos[TareaPrioridad.values[i]]!.toDouble(),
                    color: TareaPrioridad.values[i].color,
                    width: 28,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(4),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _sinDatos() {
    return SizedBox(
      height: 150,
      child: Center(
        child: Text(
          'Sin datos para graficar',
          style: TextStyle(fontSize: 12.5, color: KanbanColors.tdim),
        ),
      ),
    );
  }
}
