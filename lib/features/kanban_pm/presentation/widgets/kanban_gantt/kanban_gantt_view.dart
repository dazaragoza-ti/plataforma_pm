import 'package:flutter/material.dart';

import '../../../data/kanban_repository.dart';
import '../../../domain/entities/tarea.dart';
import '../../../kanban_constants.dart';
import 'gantt_bar.dart';
import 'gantt_connectors_painter.dart';
import 'gantt_critical_path.dart';
import 'gantt_layout.dart';

const List<String> _kMeses = [
  'ene', 'feb', 'mar', 'abr', 'may', 'jun',
  'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
];

/// Vista "Gantt": cronograma con barras arrastrables/redimensionables y
/// líneas de dependencia entre tareas — sin paquetes externos, solo
/// widgets propios + `CustomPainter`.
class KanbanGanttView extends StatefulWidget {
  final List<Tarea> tareas;
  final List<KanbanColumna> columnas;
  final KanbanRepository repository;
  final Future<void> Function() onRefresh;
  final void Function(Tarea tarea) onAbrirTarea;

  const KanbanGanttView({
    super.key,
    required this.tareas,
    required this.columnas,
    required this.repository,
    required this.onRefresh,
    required this.onAbrirTarea,
  });

  @override
  State<KanbanGanttView> createState() => _KanbanGanttViewState();
}

class _KanbanGanttViewState extends State<KanbanGanttView> {
  final _hCtrlHeader = ScrollController();
  final _hCtrlBody = ScrollController();
  bool _yaCentrado = false;
  GanttZoom _zoom = GanttZoom.dia;

  @override
  void initState() {
    super.initState();
    _hCtrlBody.addListener(_sincronizarHeader);
  }

  @override
  void dispose() {
    _hCtrlBody.removeListener(_sincronizarHeader);
    _hCtrlHeader.dispose();
    _hCtrlBody.dispose();
    super.dispose();
  }

  void _sincronizarHeader() {
    if (!_hCtrlHeader.hasClients) return;
    final destino = _hCtrlBody.offset.clamp(
      0.0,
      _hCtrlHeader.position.maxScrollExtent,
    );
    _hCtrlHeader.jumpTo(destino);
  }

  void _centrarEnHoy(GanttLayout layout) {
    if (_yaCentrado || !_hCtrlBody.hasClients) return;
    _yaCentrado = true;
    final hoy = DateTime.now();
    final dias = DateTime(
      hoy.year,
      hoy.month,
      hoy.day,
    ).difference(layout.inicio).inDays;
    final destino = (dias * _zoom.dayWidth - 120).clamp(
      0.0,
      _hCtrlBody.position.maxScrollExtent,
    );
    _hCtrlBody.jumpTo(destino);
  }

  Future<void> _actualizarFechas(
    Tarea tarea,
    DateTime inicio,
    DateTime fin,
  ) async {
    await widget.repository.actualizarTarea(
      tarea.copyWith(fechaInicio: inicio, fechaVencimiento: fin),
    );
    await widget.onRefresh();
  }

  Widget _encabezadoDias(GanttLayout layout) {
    final limite = layout.inicio.add(Duration(days: layout.totalDias));
    switch (_zoom) {
      case GanttZoom.dia:
        return Row(
          children: [
            for (var i = 0; i < layout.totalDias; i++)
              _diaHeader(layout.inicio.add(Duration(days: i))),
          ],
        );
      case GanttZoom.semana:
        final celdas = <Widget>[];
        var cursor = layout.inicio;
        while (cursor.isBefore(limite)) {
          final fin = cursor.add(const Duration(days: 7));
          final real = fin.isBefore(limite) ? fin : limite;
          celdas.add(
            _celdaAgrupada(
              ancho: real.difference(cursor).inDays * _zoom.dayWidth,
              texto: '${cursor.day} ${_kMeses[cursor.month - 1]}',
              destacada: _contieneHoy(cursor, real),
            ),
          );
          cursor = real;
        }
        return Row(children: celdas);
      case GanttZoom.mes:
        final celdas = <Widget>[];
        var cursor = layout.inicio;
        while (cursor.isBefore(limite)) {
          final finMes = DateTime(cursor.year, cursor.month + 1, 1);
          final real = finMes.isBefore(limite) ? finMes : limite;
          celdas.add(
            _celdaAgrupada(
              ancho: real.difference(cursor).inDays * _zoom.dayWidth,
              texto: '${_kMeses[cursor.month - 1]} ${cursor.year}',
              destacada: _contieneHoy(cursor, real),
            ),
          );
          cursor = real;
        }
        return Row(children: celdas);
    }
  }

  bool _contieneHoy(DateTime desde, DateTime hasta) {
    final hoy = soloFecha(DateTime.now());
    return !hoy.isBefore(desde) && hoy.isBefore(hasta);
  }

  Widget _celdaAgrupada({
    required double ancho,
    required String texto,
    required bool destacada,
  }) {
    return Container(
      width: ancho,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: destacada ? KanbanColors.accentLight : null,
        border: Border(
          right: BorderSide(color: KanbanColors.borde, width: 0.5),
        ),
      ),
      child: Text(
        texto,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: destacada ? FontWeight.bold : FontWeight.normal,
          color: destacada ? KanbanColors.accentDark : KanbanColors.texto,
        ),
      ),
    );
  }

  Widget _diaHeader(DateTime dia) {
    final hoy = DateTime.now();
    final esHoy =
        dia.year == hoy.year && dia.month == hoy.month && dia.day == hoy.day;
    return Container(
      width: _zoom.dayWidth,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: esHoy ? KanbanColors.accentLight : null,
        border: Border(
          right: BorderSide(color: KanbanColors.borde, width: 0.5),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            _kMeses[dia.month - 1],
            style: TextStyle(fontSize: 8.5, color: KanbanColors.tdim),
          ),
          Text(
            '${dia.day}',
            style: TextStyle(
              fontSize: 11,
              fontWeight: esHoy ? FontWeight.bold : FontWeight.normal,
              color: esHoy ? KanbanColors.accentDark : KanbanColors.texto,
            ),
          ),
        ],
      ),
    );
  }

  /// Barra "real" (tiempo real transcurrido) bajo la barra planeada: de solo
  /// lectura, sin arrastre/resize — su único propósito es la comparación
  /// visual planeado vs. real. Si sigue en curso (sin `fechaFinReal`), se
  /// dibuja con borde punteado en vez de relleno sólido.
  Widget _barraReal({required Rect rect, required bool enCurso}) {
    final color = KanbanColors.texto.withValues(alpha: 0.55);
    return Positioned(
      left: rect.left,
      top: rect.top,
      width: rect.width,
      height: rect.height,
      child: enCurso
          ? CustomPaint(painter: _BordePunteadoPainter(color: color))
          : DecoratedBox(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
    );
  }

  Widget _panelSinFechas(List<Tarea> sinFechas) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: KanbanColors.bg2,
        border: Border(top: BorderSide(color: KanbanColors.borde)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${sinFechas.length} ${sinFechas.length == 1 ? 'tarjeta sin fecha' : 'tarjetas sin fecha'} — agrégales fecha de inicio y vencimiento para verlas en el cronograma',
            style: TextStyle(fontSize: 11.5, color: KanbanColors.tdim),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final t in sinFechas)
                ActionChip(
                  label: Text(t.titulo, style: const TextStyle(fontSize: 11.5)),
                  onPressed: () => widget.onAbrirTarea(t),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _leyendaChip(String texto, {required Color color, bool punteada = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: punteada ? 6 : 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
            border: punteada ? Border.all(color: color, width: 1) : null,
          ),
        ),
        const SizedBox(width: 6),
        Text(texto, style: TextStyle(fontSize: 11.5, color: KanbanColors.tdim)),
      ],
    );
  }

  Widget _selectorZoom() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        children: [
          _leyendaChip('Planeado', color: KanbanColors.accent),
          const SizedBox(width: 14),
          _leyendaChip('Real', color: KanbanColors.texto.withValues(alpha: 0.55)),
          const Spacer(),
          SegmentedButton<GanttZoom>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: GanttZoom.dia, label: Text('Día')),
              ButtonSegment(value: GanttZoom.semana, label: Text('Semana')),
              ButtonSegment(value: GanttZoom.mes, label: Text('Mes')),
            ],
            selected: {_zoom},
            onSelectionChanged: (s) => setState(() {
              _zoom = s.first;
              _yaCentrado = false;
            }),
            style: const ButtonStyle(visualDensity: VisualDensity.compact),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final layout = calcularGanttLayout(
      tareas: widget.tareas,
      columnas: widget.columnas,
      dayWidth: _zoom.dayWidth,
    );
    final rutaCritica = calcularRutaCritica(widget.tareas);

    if (layout.filas.isEmpty) {
      return Column(
        children: [
          _selectorZoom(),
          Expanded(
            child: Center(
              child: Text(
                layout.sinFechas.isEmpty
                    ? 'No hay tareas para mostrar en el Gantt.'
                    : 'Ninguna tarjeta tiene fecha de inicio y vencimiento aún.',
                style: TextStyle(fontSize: 13, color: KanbanColors.tdim),
              ),
            ),
          ),
          if (layout.sinFechas.isNotEmpty) _panelSinFechas(layout.sinFechas),
        ],
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => _centrarEnHoy(layout));

    final anchoTotal = layout.totalDias * _zoom.dayWidth;
    final altoTotal = layout.filas.length * kGanttRowHeight;

    return Column(
      children: [
        _selectorZoom(),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: kGanttHeaderHeight,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(width: kGanttTitleColumnWidth),
                    Expanded(
                      child: ClipRect(
                        child: SingleChildScrollView(
                          controller: _hCtrlHeader,
                          scrollDirection: Axis.horizontal,
                          physics: const NeverScrollableScrollPhysics(),
                          child: SizedBox(
                            width: anchoTotal,
                            child: _encabezadoDias(layout),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: KanbanColors.borde),
              Expanded(
                child: SingleChildScrollView(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: kGanttTitleColumnWidth,
                        child: Column(
                          children: [
                            for (final fila in layout.filas)
                              Container(
                                height: kGanttRowHeight,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                ),
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                      color: KanbanColors.borde,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: fila.columna.color,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: InkWell(
                                        onTap: () =>
                                            widget.onAbrirTarea(fila.tarea),
                                        child: Text(
                                          fila.tarea.titulo,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          controller: _hCtrlBody,
                          scrollDirection: Axis.horizontal,
                          child: SizedBox(
                            width: anchoTotal,
                            height: altoTotal,
                            child: Stack(
                              children: [
                                for (var i = 0; i < layout.filas.length; i++)
                                  Positioned(
                                    left: 0,
                                    right: 0,
                                    top: i * kGanttRowHeight,
                                    height: kGanttRowHeight,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        border: Border(
                                          bottom: BorderSide(
                                            color: KanbanColors.borde,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                CustomPaint(
                                  size: Size(anchoTotal, altoTotal),
                                  painter: GanttConnectorsPainter(
                                    tareas: layout.filas
                                        .map((f) => f.tarea)
                                        .toList(),
                                    barras: layout.barras,
                                  ),
                                ),
                                for (final fila in layout.filas)
                                  GanttBar(
                                    tarea: fila.tarea,
                                    rect: layout.barras[fila.tarea.id]!,
                                    color: fila.columna.color,
                                    dayWidth: _zoom.dayWidth,
                                    esCritica: rutaCritica.contains(
                                      fila.tarea.id,
                                    ),
                                    onTap: () =>
                                        widget.onAbrirTarea(fila.tarea),
                                    onFechasCambiadas: (ini, fin) =>
                                        _actualizarFechas(
                                          fila.tarea,
                                          ini,
                                          fin,
                                        ),
                                  ),
                                for (final fila in layout.filas)
                                  if (layout.barrasReales[fila.tarea.id]
                                      case final rectReal?)
                                    _barraReal(
                                      rect: rectReal,
                                      enCurso: layout.realesEnCurso.contains(
                                        fila.tarea.id,
                                      ),
                                    ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        if (layout.sinFechas.isNotEmpty) _panelSinFechas(layout.sinFechas),
      ],
    );
  }
}

/// Borde punteado horizontal para la barra "real" de una tarea aún en
/// curso (sin `fechaFinReal`): distingue de un vistazo "todavía no cierra"
/// de "ya cerró" sin necesitar otro color.
class _BordePunteadoPainter extends CustomPainter {
  final Color color;

  const _BordePunteadoPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = size.height
      ..strokeCap = StrokeCap.round;
    const anchoGuion = 5.0;
    const espacio = 3.0;
    final y = size.height / 2;
    var x = 0.0;
    while (x < size.width) {
      final fin = (x + anchoGuion).clamp(0.0, size.width);
      canvas.drawLine(Offset(x, y), Offset(fin, y), paint);
      x += anchoGuion + espacio;
    }
  }

  @override
  bool shouldRepaint(covariant _BordePunteadoPainter oldDelegate) =>
      oldDelegate.color != color;
}
