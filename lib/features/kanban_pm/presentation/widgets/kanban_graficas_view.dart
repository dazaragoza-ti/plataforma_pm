import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../kanban_constants.dart';
import '../../domain/entities/actividad.dart';
import '../../domain/entities/miembro.dart';
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

const _kAnimDuracion = Duration(milliseconds: 450);
const _kAnimCurva = Curves.easeOutCubic;

/// Vista de "Gráficas": KPIs y distribución de tareas por estatus,
/// prioridad, carga por integrante, cumplimiento de fechas (planeado vs.
/// real) y subtareas delegadas, calculados sobre la lista de tareas visible
/// en el tablero (respeta los filtros activos). Los valores se animan al
/// cambiar para que un refresco se sienta como una actualización, no un
/// parpadeo, y toda la vista entra con un fundido suave la primera vez que
/// se monta (p. ej. al cambiar a esta pestaña).
class KanbanGraficasView extends StatefulWidget {
  final List<Tarea> tareas;
  final List<KanbanColumna> columnas;
  final List<Miembro> miembros;

  const KanbanGraficasView({
    super.key,
    required this.tareas,
    required this.columnas,
    this.miembros = const [],
  });

  @override
  State<KanbanGraficasView> createState() => _KanbanGraficasViewState();
}

class _KanbanGraficasViewState extends State<KanbanGraficasView>
    with SingleTickerProviderStateMixin {
  late final _entrada = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  )..forward();
  late final _fundido = CurvedAnimation(
    parent: _entrada,
    curve: Curves.easeOut,
  );
  late final _deslizamiento = Tween(
    begin: const Offset(0, 0.04),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _entrada, curve: Curves.easeOutCubic));

  /// Rango de fechas propio de esta vista (independiente de los filtros
  /// del tablero): si está activo, todas las gráficas y KPIs de abajo
  /// (menos la tendencia semanal, que siempre mira las últimas 8 semanas)
  /// solo consideran tareas cuya `fechaInicio` cae dentro del rango.
  DateTimeRange? _rango;

  @override
  void dispose() {
    _entrada.dispose();
    super.dispose();
  }

  Future<void> _elegirRango() async {
    final ahora = DateTime.now();
    final elegido = await showDateRangePicker(
      context: context,
      firstDate: ahora.subtract(const Duration(days: 365 * 2)),
      lastDate: ahora.add(const Duration(days: 365 * 2)),
      initialDateRange: _rango,
    );
    if (elegido != null) setState(() => _rango = elegido);
  }

  String _fecha(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  /// Mismo lenguaje visual que los chips activables del header del tablero
  /// (`_headerToggleChip`): fondo/borde de acento cuando hay un rango
  /// elegido, transparente cuando no — para que "hay un filtro aplicado"
  /// se note de un vistazo, no solo por el texto del botón.
  Widget _filtroRango() {
    final rango = _rango;
    final activo = rango != null;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(9),
          onTap: _elegirRango,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: activo ? KanbanColors.accentLight : Colors.transparent,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(
                color: activo ? KanbanColors.accent : KanbanColors.borde,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.date_range_rounded,
                  size: 15,
                  color: activo ? KanbanColors.accentDark : KanbanColors.texto,
                ),
                const SizedBox(width: 7),
                Text(
                  activo
                      ? '${_fecha(rango.start)} – ${_fecha(rango.end)}'
                      : 'Filtrar por fecha de inicio',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: activo ? FontWeight.w600 : FontWeight.normal,
                    color: activo
                        ? KanbanColors.accentDark
                        : KanbanColors.texto,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (activo) ...[
          const SizedBox(width: 6),
          Tooltip(
            message: 'Quitar filtro de fecha',
            child: InkWell(
              borderRadius: BorderRadius.circular(9),
              onTap: () => setState(() => _rango = null),
              child: Container(
                padding: const EdgeInsets.all(8.5),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: KanbanColors.borde),
                ),
                child: Icon(
                  Icons.close_rounded,
                  size: 15,
                  color: KanbanColors.tdim,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final rango = _rango;
    final tareas = rango == null
        ? widget.tareas
        : widget.tareas.where((t) {
            final f = t.fechaInicio;
            if (f == null) return false;
            return !f.isBefore(rango.start) &&
                !f.isAfter(rango.end.add(const Duration(days: 1)));
          }).toList();
    final columnas = widget.columnas;
    final miembros = widget.miembros;

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
    final bloqueadas = tareas.where((t) => t.pausadaPorSubtarea).length;
    final porcentaje = total == 0 ? 0.0 : (completadas / total * 100);

    return FadeTransition(
      opacity: _fundido,
      child: SlideTransition(
        position: _deslizamiento,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _filtroRango(),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _statTile(
                    'Total de tareas',
                    total.toDouble(),
                    Icons.view_kanban_rounded,
                    KanbanColors.accent,
                  ),
                  _statTile(
                    'Completadas',
                    porcentaje,
                    Icons.check_circle_rounded,
                    KanbanColors.ok,
                    sufijo: '%',
                  ),
                  _statTile(
                    'En proceso',
                    enProceso.toDouble(),
                    Icons.autorenew_rounded,
                    const Color(0xFF2196F3),
                  ),
                  _statTile(
                    'Vencidas',
                    vencidas.toDouble(),
                    Icons.warning_rounded,
                    KanbanColors.danger,
                  ),
                  _statTile(
                    'Bloqueadas por subtarea',
                    bloqueadas.toDouble(),
                    Icons.pause_circle_outline_rounded,
                    const Color(0xFFFD7E14),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              LayoutBuilder(
                builder: (context, constraints) {
                  final apilar = constraints.maxWidth < 720;
                  final donut = _tarjeta(
                    'Tareas por estatus',
                    _graficaEstatus(tareas, columnas),
                  );
                  final barras = _tarjeta(
                    'Tareas por prioridad',
                    _graficaPrioridad(tareas),
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
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final apilar = constraints.maxWidth < 720;
                  final carga = _tarjeta(
                    'Carga por integrante',
                    _graficaCargaMiembros(tareas, miembros),
                  );
                  final cumplimiento = _tarjeta(
                    'Cumplimiento de fechas (planeado vs. real)',
                    _graficaCumplimiento(tareas),
                  );
                  if (apilar) {
                    return Column(
                      children: [
                        carga,
                        const SizedBox(height: 16),
                        cumplimiento,
                      ],
                    );
                  }
                  return IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: carga),
                        const SizedBox(width: 16),
                        Expanded(child: cumplimiento),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              _tarjeta(
                'Subtareas delegadas por responsable',
                _graficaSubtareasDelegadas(tareas, miembros),
              ),
              const SizedBox(height: 16),
              _tarjeta(
                'Tendencia: creadas vs. completadas (últimas 8 semanas)',
                _graficaTendencia(widget.tareas),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statTile(
    String label,
    double valor,
    IconData icon,
    Color color, {
    String sufijo = '',
  }) {
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
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: valor),
                  duration: _kAnimDuracion,
                  curve: _kAnimCurva,
                  builder: (context, animado, _) => Text(
                    '${animado.round()}$sufijo',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w600,
                      color: KanbanColors.texto,
                    ),
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

  Widget _graficaEstatus(List<Tarea> tareas, List<KanbanColumna> columnas) {
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
            duration: _kAnimDuracion,
            curve: _kAnimCurva,
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

  Widget _graficaPrioridad(List<Tarea> tareas) {
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
        duration: _kAnimDuracion,
        curve: _kAnimCurva,
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

  /// Cuántas tareas (no archivadas, visibles) tiene asignadas cada
  /// integrante — barras horizontales, una por persona, en el mismo color
  /// que su avatar en el resto del módulo (identidad consistente en toda
  /// la app en vez de una paleta categórica nueva).
  Widget _graficaCargaMiembros(List<Tarea> tareas, List<Miembro> miembros) {
    if (miembros.isEmpty || tareas.isEmpty) return _sinDatos();
    final conteos = {
      for (final m in miembros)
        m: tareas.where((t) => t.miembroIds.contains(m.id)).length,
    }..removeWhere((_, cantidad) => cantidad == 0);
    if (conteos.isEmpty) return _sinDatos();

    final entradas = conteos.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxCantidad = entradas.first.value.toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final e in entradas)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 11,
                  backgroundColor: e.key.colorAvatar,
                  child: Text(
                    e.key.nombre.isNotEmpty
                        ? e.key.nombre[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 88,
                  child: Text(
                    e.key.nombre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: KanbanColors.texto),
                  ),
                ),
                Expanded(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: e.value / maxCantidad),
                    duration: _kAnimDuracion,
                    curve: _kAnimCurva,
                    builder: (context, fraccion, _) => ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: fraccion,
                        minHeight: 8,
                        backgroundColor: KanbanColors.bg3,
                        valueColor: AlwaysStoppedAnimation(e.key.colorAvatar),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 18,
                  child: Text(
                    '${e.value}',
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: KanbanColors.texto,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// Diferencia entre fecha de vencimiento planeada y `fechaFinReal` para
  /// las tareas ya cerradas (terminadas/revisadas) que tienen ambos datos
  /// — un vistazo directo de qué tan bien se cumplen las fechas planeadas
  /// en el Gantt. Verde = a tiempo o antes, rojo = retraso.
  Widget _graficaCumplimiento(List<Tarea> tareas) {
    final cerradas =
        tareas
            .where(
              (t) =>
                  t.fechaVencimiento != null &&
                  t.fechaFinReal != null &&
                  // Solo tareas *actualmente* cerradas: si se reabrió, su
                  // `fechaFinReal` (nunca se limpia, para conservar
                  // historial) quedaría comparándose contra una fecha de
                  // vencimiento ya editada y daría un retraso sin sentido.
                  (t.estatus == TareaEstatus.terminado ||
                      t.estatus == TareaEstatus.revisado),
            )
            .map(
              (t) => (
                tarea: t,
                retrasoDias: t.fechaFinReal!
                    .difference(t.fechaVencimiento!)
                    .inDays,
              ),
            )
            .toList()
          ..sort((a, b) => b.retrasoDias.compareTo(a.retrasoDias));

    if (cerradas.isEmpty) return _sinDatos();

    final top = cerradas.take(6).toList();
    final maxAbs = top
        .map((e) => e.retrasoDias.abs())
        .fold<int>(1, (a, b) => a > b ? a : b)
        .toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final e in top)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                SizedBox(
                  width: 96,
                  child: Text(
                    e.tarea.titulo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: KanbanColors.texto),
                  ),
                ),
                Expanded(
                  child: _barraDivergente(
                    fraccion: e.retrasoDias / maxAbs,
                    color: e.retrasoDias > 0
                        ? KanbanColors.danger
                        : KanbanColors.ok,
                  ),
                ),
                SizedBox(
                  width: 56,
                  child: Text(
                    e.retrasoDias == 0
                        ? 'A tiempo'
                        : e.retrasoDias > 0
                        ? '+${e.retrasoDias}d'
                        : '${e.retrasoDias}d',
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: e.retrasoDias > 0
                          ? KanbanColors.danger
                          : KanbanColors.ok,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// Recorre el árbol de subtareas de todas las [tareas] y cuenta, por cada
  /// responsable (persona o departamento), cuántas siguen pendientes y
  /// cuántas ya se resolvieron — el vistazo directo de "quién trae carga
  /// delegada encima" que resulta de la nueva función de subtareas.
  Widget _graficaSubtareasDelegadas(
    List<Tarea> tareas,
    List<Miembro> miembros,
  ) {
    final pendientes = <String, int>{};
    final resueltas = <String, int>{};
    final colores = <String, Color>{};
    final nombres = <String, String>{};

    Miembro? buscarMiembro(int id) {
      for (final m in miembros) {
        if (m.id == id) return m;
      }
      return null;
    }

    void recorrer(List<Actividad> lista) {
      for (final a in lista) {
        String? clave;
        if (a.miembroId != null) {
          final m = buscarMiembro(a.miembroId!);
          clave = 'm:${a.miembroId}';
          nombres[clave] = m?.nombre ?? 'Persona #${a.miembroId}';
          colores[clave] = m?.colorAvatar ?? KanbanColors.tdim;
        } else if (a.departamento != null) {
          clave = 'd:${a.departamento}';
          nombres[clave] = a.departamento!;
          colores[clave] = KanbanColors.accent;
        }
        if (clave != null) {
          if (a.terminada) {
            resueltas[clave] = (resueltas[clave] ?? 0) + 1;
          } else {
            pendientes[clave] = (pendientes[clave] ?? 0) + 1;
          }
        }
        recorrer(a.subActividades);
      }
    }

    for (final t in tareas) {
      recorrer(t.actividades);
    }

    final claves = {...pendientes.keys, ...resueltas.keys}.toList()
      ..sort((a, b) => (pendientes[b] ?? 0).compareTo(pendientes[a] ?? 0));
    if (claves.isEmpty) {
      return SizedBox(
        height: 100,
        child: Center(
          child: Text(
            'Aún no hay subtareas delegadas a una persona o departamento.',
            style: TextStyle(fontSize: 12.5, color: KanbanColors.tdim),
          ),
        ),
      );
    }

    final maxCantidad = claves
        .map((k) => (pendientes[k] ?? 0) + (resueltas[k] ?? 0))
        .fold<int>(1, (a, b) => a > b ? a : b)
        .toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final k in claves)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: colores[k],
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 96,
                  child: Text(
                    nombres[k]!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: KanbanColors.texto),
                  ),
                ),
                Expanded(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(
                      begin: 0,
                      end: (pendientes[k] ?? 0) / maxCantidad,
                    ),
                    duration: _kAnimDuracion,
                    curve: _kAnimCurva,
                    builder: (context, fraccion, _) => ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: fraccion,
                        minHeight: 8,
                        backgroundColor: KanbanColors.bg3,
                        valueColor: AlwaysStoppedAnimation(
                          (pendientes[k] ?? 0) > 0
                              ? KanbanColors.danger
                              : KanbanColors.ok,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 76,
                  child: Text(
                    '${pendientes[k] ?? 0} pend. · ${resueltas[k] ?? 0} ok',
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: (pendientes[k] ?? 0) > 0
                          ? KanbanColors.danger
                          : KanbanColors.ok,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// Barra que crece desde el centro (cero) hacia la derecha (retraso) o
  /// hacia la izquierda (adelanto); `fraccion` va de -1 a 1.
  Widget _barraDivergente({required double fraccion, required Color color}) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: fraccion.clamp(-1.0, 1.0)),
      duration: _kAnimDuracion,
      curve: _kAnimCurva,
      builder: (context, animado, _) {
        return SizedBox(
          height: 10,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final centro = constraints.maxWidth / 2;
              final anchoBarra = (animado.abs() * centro).clamp(0.0, centro);
              return Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    height: 2,
                    width: constraints.maxWidth,
                    color: KanbanColors.borde,
                  ),
                  Positioned(
                    left: animado >= 0 ? centro : centro - anchoBarra,
                    width: anchoBarra,
                    child: Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  /// Cuántas tareas se crearon (`fechaInicio`) y cuántas se completaron
  /// (`fechaFinReal`) por semana en las últimas 8 semanas — siempre sobre
  /// el total de tareas del tablero (ignora el filtro de rango propio de
  /// esta vista, que es sobre otra ventana de tiempo arbitraria y mezclarlo
  /// con "últimas 8 semanas" confundiría más de lo que ayuda).
  Widget _graficaTendencia(List<Tarea> tareas) {
    const semanas = 8;
    final hoy = DateTime.now();
    final lunesActual = DateTime(
      hoy.year,
      hoy.month,
      hoy.day,
    ).subtract(Duration(days: hoy.weekday - 1));
    final inicios = [
      for (var i = semanas - 1; i >= 0; i--)
        lunesActual.subtract(Duration(days: i * 7)),
    ];

    int bucketDe(DateTime fecha) {
      final f = DateTime(fecha.year, fecha.month, fecha.day);
      for (var i = inicios.length - 1; i >= 0; i--) {
        if (!f.isBefore(inicios[i])) return i;
      }
      return -1;
    }

    final creadas = List<int>.filled(semanas, 0);
    final completadas = List<int>.filled(semanas, 0);
    for (final t in tareas) {
      if (t.fechaInicio != null) {
        final b = bucketDe(t.fechaInicio!);
        if (b >= 0 && b < semanas) creadas[b]++;
      }
      if (t.fechaFinReal != null) {
        final b = bucketDe(t.fechaFinReal!);
        if (b >= 0 && b < semanas) completadas[b]++;
      }
    }

    final maxY = [
      ...creadas,
      ...completadas,
    ].fold<int>(0, (a, b) => a > b ? a : b).toDouble();
    if (maxY == 0) return _sinDatos();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _leyendaDot(KanbanColors.accent, 'Creadas'),
            const SizedBox(width: 16),
            _leyendaDot(KanbanColors.ok, 'Completadas'),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 200,
          child: LineChart(
            duration: _kAnimDuracion,
            curve: _kAnimCurva,
            LineChartData(
              minY: 0,
              maxY: maxY + 1,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: ((maxY + 1) / 4).clamp(1, double.infinity),
                getDrawingHorizontalLine: (v) => FlLine(
                  color: KanbanColors.borde,
                  strokeWidth: 1,
                  dashArray: const [4, 4],
                ),
              ),
              borderData: FlBorderData(show: false),
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (_) => KanbanColors.bg3,
                  tooltipBorder: BorderSide(color: KanbanColors.borde),
                  tooltipBorderRadius: BorderRadius.circular(8),
                  getTooltipItems: (spots) => [
                    for (final s in spots)
                      LineTooltipItem(
                        '${etiquetaSemana(inicios[s.x.toInt()])}\n',
                        TextStyle(
                          fontSize: 10.5,
                          color: KanbanColors.tdim,
                          fontWeight: FontWeight.normal,
                        ),
                        children: [
                          TextSpan(
                            text:
                                '${s.y.toInt()} '
                                '${s.barIndex == 0 ? 'creadas' : 'completadas'}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: s.bar.color ?? KanbanColors.texto,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 26,
                    getTitlesWidget: (v, meta) => Text(
                      '${v.toInt()}',
                      style: TextStyle(fontSize: 10, color: KanbanColors.tdim),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 26,
                    getTitlesWidget: (v, meta) {
                      final i = v.toInt();
                      if (i < 0 || i >= inicios.length) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          etiquetaSemana(inicios[i]),
                          style: TextStyle(
                            fontSize: 9.5,
                            color: KanbanColors.tdim,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              lineBarsData: [
                _lineaTendencia(creadas, KanbanColors.accent, semanas),
                _lineaTendencia(completadas, KanbanColors.ok, semanas),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String etiquetaSemana(DateTime d) => '${d.day}/${d.month}';

  /// Línea con relleno degradado (se desvanece hacia abajo) y puntos estilo
  /// "anillo" (color propio + borde del color de fondo de la tarjeta, para
  /// que no se vean pegados a la línea) — el mismo lenguaje visual que el
  /// resto de gráficas de este módulo (`cardDecoration`, animación de
  /// entrada), en vez del `LineChart` por defecto de fl_chart.
  LineChartBarData _lineaTendencia(
    List<int> valores,
    Color color,
    int semanas,
  ) {
    return LineChartBarData(
      spots: [
        for (var i = 0; i < semanas; i++)
          FlSpot(i.toDouble(), valores[i].toDouble()),
      ],
      isCurved: true,
      curveSmoothness: 0.25,
      color: color,
      barWidth: 2.5,
      dotData: FlDotData(
        show: true,
        getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
          radius: 3.5,
          color: color,
          strokeWidth: 2,
          strokeColor: KanbanColors.bg2,
        ),
      ),
      belowBarData: BarAreaData(
        show: true,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.18), color.withValues(alpha: 0)],
        ),
      ),
    );
  }

  Widget _leyendaDot(Color color, String texto) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(texto, style: TextStyle(fontSize: 11.5, color: KanbanColors.tdim)),
      ],
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
