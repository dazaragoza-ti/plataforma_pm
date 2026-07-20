import 'package:flutter/material.dart';
import '../../../kanban_constants.dart';
import '../../../domain/entities/miembro.dart';
import '../../../domain/entities/tarea.dart';
import '../../../domain/entities/tarea_etiqueta.dart';
import '../avatar_stack.dart';
import '../csv_export/csv_utils.dart';
import '../csv_export/descargar_csv.dart';

/// Vista de "Lista": todas las tareas visibles en una tabla ordenable por
/// columna — útil para escanear o comparar muchas tarjetas a la vez, algo
/// que el tablero (una columna a la vista por estatus) no permite bien.
class KanbanListaView extends StatefulWidget {
  final List<Tarea> tareas;
  final List<KanbanColumna> columnas;
  final Map<int, Miembro> miembrosPorId;
  final Map<int, TareaEtiqueta> etiquetasPorId;
  final void Function(Tarea tarea) onAbrirTarea;
  final Future<void> Function(List<int> ids, TareaEstatus nuevoEstatus)
  onMoverSeleccion;
  final Future<void> Function(List<int> ids) onArchivarSeleccion;
  final Future<void> Function(List<int> ids) onEliminarSeleccion;

  const KanbanListaView({
    super.key,
    required this.tareas,
    required this.columnas,
    required this.miembrosPorId,
    required this.etiquetasPorId,
    required this.onAbrirTarea,
    required this.onMoverSeleccion,
    required this.onArchivarSeleccion,
    required this.onEliminarSeleccion,
  });

  @override
  State<KanbanListaView> createState() => _KanbanListaViewState();
}

class _KanbanListaViewState extends State<KanbanListaView> {
  int _columnaOrden = 5;
  bool _ascendente = true;
  final Set<int> _seleccionados = {};
  final _hScrollCtrl = ScrollController();

  @override
  void dispose() {
    _hScrollCtrl.dispose();
    super.dispose();
  }

  int _indiceColumna(TareaEstatus estatus) =>
      widget.columnas.indexWhere((c) => c.estatus == estatus);

  int _comparar(Tarea a, Tarea b) {
    switch (_columnaOrden) {
      case 0:
        return _indiceColumna(a.estatus).compareTo(_indiceColumna(b.estatus));
      case 1:
        return a.titulo.toLowerCase().compareTo(b.titulo.toLowerCase());
      case 2:
        return a.prioridad.index.compareTo(b.prioridad.index);
      case 3:
        return a.grupo.toLowerCase().compareTo(b.grupo.toLowerCase());
      case 5:
        final fa = a.fechaVencimiento;
        final fb = b.fechaVencimiento;
        if (fa == null && fb == null) return 0;
        if (fa == null) return 1;
        if (fb == null) return -1;
        return fa.compareTo(fb);
      case 6:
        return a.progreso.compareTo(b.progreso);
      default:
        return 0;
    }
  }

  List<Tarea> get _ordenadas {
    final lista = List<Tarea>.of(widget.tareas)
      ..sort(_ascendente ? _comparar : (a, b) => _comparar(b, a));
    return lista;
  }

  void _alOrdenar(int columnIndex, bool ascendente) {
    setState(() {
      _columnaOrden = columnIndex;
      _ascendente = ascendente;
    });
  }

  String _fecha(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  void didUpdateWidget(KanbanListaView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Si una tarea seleccionada ya no está en la lista (se archivó, se
    // eliminó o un filtro la sacó), suéltala — si no, la barra de acciones
    // seguiría contándola y una acción en lote fallaría al buscarla.
    final idsVigentes = widget.tareas.map((t) => t.id).toSet();
    _seleccionados.removeWhere((id) => !idsVigentes.contains(id));
  }

  Future<void> _mover(TareaEstatus nuevoEstatus) async {
    final ids = _seleccionados.toList();
    setState(() => _seleccionados.clear());
    await widget.onMoverSeleccion(ids, nuevoEstatus);
  }

  Future<void> _archivar() async {
    final ids = _seleccionados.toList();
    setState(() => _seleccionados.clear());
    await widget.onArchivarSeleccion(ids);
  }

  Future<void> _eliminar() async {
    final ids = _seleccionados.toList();
    if (!await _confirmarEliminar(ids.length)) return;
    setState(() => _seleccionados.clear());
    await widget.onEliminarSeleccion(ids);
  }

  /// Confirmación compartida por la eliminación en lote y la acción rápida
  /// por fila — eliminar es destructivo e irreversible, así que ambos
  /// caminos deben pasar por el mismo diálogo en vez de que la acción
  /// rápida se salte la confirmación "porque es una sola tarjeta".
  Future<bool> _confirmarEliminar(int cantidad) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: KanbanColors.bg2,
        surfaceTintColor: Colors.transparent,
        title: Text(
          cantidad == 1 ? 'Eliminar tarjeta' : 'Eliminar tarjetas',
          style: TextStyle(color: KanbanColors.texto),
        ),
        content: Text(
          '¿Eliminar $cantidad ${cantidad == 1 ? 'tarjeta' : 'tarjetas'}? '
          'Esta acción no se puede deshacer.',
          style: TextStyle(color: KanbanColors.texto),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: KanbanColors.danger,
              foregroundColor: Colors.white,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _eliminarUna(Tarea t) async {
    if (!await _confirmarEliminar(1)) return;
    await widget.onEliminarSeleccion([t.id]);
  }

  void _exportarCsv() {
    final encabezado = const [
      'Estado',
      'Tarea',
      'Etiquetas',
      'Prioridad',
      'Área',
      'Asignados',
      'Vencimiento',
      'Progreso',
    ].map(campoCsv).join(',');
    final lineas = [encabezado];
    for (final t in _ordenadas) {
      final idxCol = _indiceColumna(t.estatus);
      final estado = idxCol == -1 ? '' : widget.columnas[idxCol].titulo;
      final etiquetas = t.etiquetaIds
          .map((id) => widget.etiquetasPorId[id]?.nombre)
          .whereType<String>()
          .join('; ');
      final asignados = t.miembroIds
          .map((id) => widget.miembrosPorId[id]?.nombre)
          .whereType<String>()
          .join('; ');
      lineas.add(
        [
          estado,
          t.titulo,
          etiquetas,
          t.prioridad.etiqueta,
          t.grupo,
          asignados,
          t.fechaVencimiento == null ? '' : _fecha(t.fechaVencimiento!),
          '${(t.progreso * 100).round()}%',
        ].map(campoCsv).join(','),
      );
    }
    try {
      descargarCsv('tareas_kanban.csv', lineas.join('\r\n'));
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Exportar a CSV solo está disponible en la versión web.',
          ),
          backgroundColor: KanbanColors.danger,
        ),
      );
    }
  }

  Widget _barraHerramientas() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${widget.tareas.length} ${widget.tareas.length == 1 ? 'tarea' : 'tareas'}',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12.5, color: KanbanColors.tdim),
            ),
          ),
          TextButton.icon(
            onPressed: _exportarCsv,
            icon: Icon(
              Icons.file_download_outlined,
              size: 16,
              color: KanbanColors.texto,
            ),
            label: Text(
              'Exportar CSV',
              style: TextStyle(fontSize: 12.5, color: KanbanColors.texto),
            ),
          ),
        ],
      ),
    );
  }

  Widget _barraSeleccion() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: KanbanColors.cardDecoration(radius: 10),
      // `Row` con dos `Flexible`+`Wrap` (no un `Row` simple con `Spacer`):
      // en pantallas angostas los botones de acción pueden partirse en una
      // línea propia en vez de desbordar la tarjeta.
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Flexible(
            child: Text(
              '${_seleccionados.length} '
              '${_seleccionados.length == 1 ? 'seleccionada' : 'seleccionadas'}',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: KanbanColors.texto,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Wrap(
              alignment: WrapAlignment.end,
              children: [_accionesSeleccion()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _accionesSeleccion() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        PopupMenuButton<TareaEstatus>(
          tooltip: 'Mover a…',
          onSelected: _mover,
          itemBuilder: (context) => [
            for (final c in widget.columnas)
              PopupMenuItem(
                value: c.estatus,
                child: Text(c.titulo, style: const TextStyle(fontSize: 12.5)),
              ),
          ],
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.drive_file_move_outline,
                  size: 16,
                  color: KanbanColors.texto,
                ),
                const SizedBox(width: 6),
                Text(
                  'Mover a…',
                  style: TextStyle(fontSize: 12.5, color: KanbanColors.texto),
                ),
              ],
            ),
          ),
        ),
        IconButton(
          tooltip: 'Archivar seleccionadas',
          icon: Icon(
            Icons.archive_outlined,
            size: 18,
            color: KanbanColors.texto,
          ),
          onPressed: _archivar,
        ),
        IconButton(
          tooltip: 'Eliminar seleccionadas',
          icon: Icon(
            Icons.delete_outline_rounded,
            size: 18,
            color: KanbanColors.danger,
          ),
          onPressed: _eliminar,
        ),
        IconButton(
          tooltip: 'Cancelar selección',
          icon: Icon(Icons.close_rounded, size: 18, color: KanbanColors.tdim),
          onPressed: () => setState(_seleccionados.clear),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.tareas.isEmpty) {
      return Center(
        child: Text(
          'No hay tareas para mostrar en la lista.',
          style: TextStyle(fontSize: 13, color: KanbanColors.tdim),
        ),
      );
    }

    final filas = _ordenadas;
    final estiloEncabezado = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: KanbanColors.tdim,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_seleccionados.isNotEmpty)
          _barraSeleccion()
        else
          _barraHerramientas(),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              decoration: KanbanColors.cardDecoration(radius: 12),
              clipBehavior: Clip.antiAlias,
              // `LayoutBuilder` + `ConstrainedBox(minWidth: ...)`: sin esto,
              // la tabla (más angosta que la pantalla) queda pegada a la
              // izquierda dentro de una tarjeta ancha, con un vacío enorme
              // a la derecha — el fondo de filas/encabezado ahora sí llena
              // el ancho disponible aunque las columnas sigan angostas.
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // `Scrollbar` visible: con 9 columnas, en tablet/móvil la
                  // tabla no cabe completa y sin esto no había ninguna
                  // señal de que se puede desplazar para ver el resto
                  // (Vencimiento, Progreso, acciones quedaban invisibles).
                  return Scrollbar(
                    controller: _hScrollCtrl,
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      controller: _hScrollCtrl,
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minWidth: constraints.maxWidth,
                        ),
                        child: SingleChildScrollView(
                          child: DataTable(
                            sortColumnIndex: _columnaOrden,
                            sortAscending: _ascendente,
                            headingRowColor: WidgetStateProperty.all(
                              KanbanColors.bg3,
                            ),
                            dividerThickness: 1,
                            horizontalMargin: 16,
                            columnSpacing: 20,
                            onSelectAll: (v) => setState(() {
                              if (v ?? false) {
                                _seleccionados.addAll(filas.map((t) => t.id));
                              } else {
                                _seleccionados.clear();
                              }
                            }),
                            columns: [
                              DataColumn(
                                label: Text('Estado', style: estiloEncabezado),
                                onSort: _alOrdenar,
                              ),
                              DataColumn(
                                label: Text('Tarea', style: estiloEncabezado),
                                onSort: _alOrdenar,
                              ),
                              DataColumn(
                                label: Text(
                                  'Etiquetas',
                                  style: estiloEncabezado,
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  'Prioridad',
                                  style: estiloEncabezado,
                                ),
                                onSort: _alOrdenar,
                              ),
                              DataColumn(
                                label: Text('Área', style: estiloEncabezado),
                                onSort: _alOrdenar,
                              ),
                              DataColumn(
                                label: Text(
                                  'Asignados',
                                  style: estiloEncabezado,
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  'Vencimiento',
                                  style: estiloEncabezado,
                                ),
                                onSort: _alOrdenar,
                              ),
                              DataColumn(
                                label: Text(
                                  'Progreso',
                                  style: estiloEncabezado,
                                ),
                                onSort: _alOrdenar,
                                numeric: true,
                              ),
                              DataColumn(
                                label: Text('', style: estiloEncabezado),
                              ),
                            ],
                            rows: [
                              for (final t in filas)
                                DataRow(
                                  selected: _seleccionados.contains(t.id),
                                  onSelectChanged: (v) => setState(() {
                                    if (v ?? false) {
                                      _seleccionados.add(t.id);
                                    } else {
                                      _seleccionados.remove(t.id);
                                    }
                                  }),
                                  cells: [
                                    DataCell(_celdaEstado(t)),
                                    DataCell(
                                      _celdaTitulo(t),
                                      onTap: () => widget.onAbrirTarea(t),
                                    ),
                                    DataCell(_celdaEtiquetas(t)),
                                    DataCell(_celdaPrioridad(t)),
                                    DataCell(
                                      Text(
                                        t.grupo.isEmpty ? '—' : t.grupo,
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          color: KanbanColors.texto,
                                        ),
                                      ),
                                    ),
                                    DataCell(_celdaAsignados(t)),
                                    DataCell(_celdaVencimiento(t)),
                                    DataCell(_celdaProgreso(t)),
                                    DataCell(_celdaAcciones(t)),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _celdaEstado(Tarea t) {
    final idx = _indiceColumna(t.estatus);
    final columna = idx == -1 ? null : widget.columnas[idx];
    if (columna == null) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            color: columna.color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          columna.titulo,
          style: TextStyle(fontSize: 12.5, color: KanbanColors.texto),
        ),
        if (t.pausadaPorSubtarea) ...[
          const SizedBox(width: 6),
          Tooltip(
            message: 'Bloqueada por una subtarea sin resolver',
            child: Icon(
              Icons.pause_circle_outline_rounded,
              size: 15,
              color: const Color(0xFFFD7E14),
            ),
          ),
        ],
      ],
    );
  }

  Widget _celdaEtiquetas(Tarea t) {
    final etiquetas = t.etiquetaIds
        .map((id) => widget.etiquetasPorId[id])
        .whereType<TareaEtiqueta>()
        .toList();
    if (etiquetas.isEmpty) {
      return Text(
        '—',
        style: TextStyle(fontSize: 12, color: KanbanColors.tdim),
      );
    }
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 160),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: [
          for (final et in etiquetas)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: et.color,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                et.nombre,
                style: const TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _celdaAcciones(Tarea t) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Archivar',
          icon: Icon(
            Icons.archive_outlined,
            size: 17,
            color: KanbanColors.tdim,
          ),
          onPressed: () => widget.onArchivarSeleccion([t.id]),
        ),
        IconButton(
          tooltip: 'Eliminar',
          icon: Icon(
            Icons.delete_outline_rounded,
            size: 17,
            color: KanbanColors.tdim,
          ),
          onPressed: () => _eliminarUna(t),
        ),
      ],
    );
  }

  Widget _celdaTitulo(Tarea t) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 260),
      child: Text(
        t.titulo,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: KanbanColors.texto,
        ),
      ),
    );
  }

  Widget _celdaPrioridad(Tarea t) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: t.prioridad.color.withValues(alpha: 0.4)),
      ),
      child: Text(
        t.prioridad.etiqueta,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          color: t.prioridad.color,
        ),
      ),
    );
  }

  Widget _celdaAsignados(Tarea t) {
    final miembros = t.miembroIds
        .map((id) => widget.miembrosPorId[id])
        .whereType<Miembro>()
        .toList();
    if (miembros.isEmpty) {
      return Text(
        'Sin asignar',
        style: TextStyle(fontSize: 12, color: KanbanColors.tdim),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [AvatarStack(miembros: miembros)],
    );
  }

  Widget _celdaVencimiento(Tarea t) {
    if (t.fechaVencimiento == null) {
      return Text(
        '—',
        style: TextStyle(fontSize: 12, color: KanbanColors.tdim),
      );
    }
    return Text(
      _fecha(t.fechaVencimiento!),
      style: TextStyle(
        fontSize: 12,
        fontWeight: t.vencida ? FontWeight.w700 : FontWeight.normal,
        color: t.vencida ? KanbanColors.danger : KanbanColors.texto,
      ),
    );
  }

  Widget _celdaProgreso(Tarea t) {
    if (t.actividades.isEmpty) {
      return Text(
        '—',
        style: TextStyle(fontSize: 12, color: KanbanColors.tdim),
      );
    }
    final completo = t.progreso >= 1.0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 48,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: t.progreso,
              minHeight: 6,
              backgroundColor: KanbanColors.bg3,
              valueColor: AlwaysStoppedAnimation(
                completo ? KanbanColors.ok : KanbanColors.accent,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${(t.progreso * 100).round()}%',
          style: TextStyle(fontSize: 11.5, color: KanbanColors.texto),
        ),
      ],
    );
  }
}
