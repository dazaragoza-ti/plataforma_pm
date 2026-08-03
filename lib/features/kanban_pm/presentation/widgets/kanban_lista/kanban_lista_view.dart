import 'package:flutter/material.dart';
import '../../../kanban_constants.dart';
import '../../../domain/entities/miembro.dart';
import '../../../domain/entities/tarea.dart';
import '../../../domain/entities/tarea_etiqueta.dart';
import '../common/avatar_stack.dart';
import '../csv_export/csv_utils.dart';
import '../csv_export/descargar_csv.dart';
import '../dialogs/confirmar_eliminar_dialog.dart';

/// Vista de "Lista": todas las tareas visibles en una tabla ordenable por
/// columna — útil para escanear o comparar muchas tarjetas a la vez, algo
/// que el tablero (una columna a la vista por estatus) no permite bien.
class KanbanListaView extends StatefulWidget {
  final List<Tarea> tareas;

  /// Total real de tarjetas por columna, sin los filtros de vista del
  /// dashboard — llave ausente o mapa vacío cae a contar sobre [tareas].
  /// El aviso de límite de WIP en "Mover a…" lo usa en vez de contar
  /// sobre [tareas] directamente: si no, con un filtro activo que oculte
  /// tarjetas de la columna destino, el aviso mostraría espacio libre que
  /// en realidad no existe (el bloqueo real sí valida contra el total).
  final Map<TareaEstatus, int> totalesPorEstatus;
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
    this.totalesPorEstatus = const {},
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
  /// Por debajo de este ancho, la `DataTable` (9 columnas, pensada para
  /// escritorio) se reemplaza por tarjetas apiladas — evita el scroll
  /// horizontal por completo en vez de solo hacerlo más descubrible.
  static const _kUmbralMovil = 600.0;

  /// (etiqueta, índice de columna) para el control de orden en móvil —
  /// mismos índices que `onSort` de la tabla (posición FÍSICA de cada
  /// `DataColumn`, incluidas "Etiquetas" y "Asignados" que no tienen
  /// `onSort` pero sí ocupan un índice), para compartir `_comparar`.
  static const _opcionesOrden = [
    ('Estado', 0),
    ('Tarea', 1),
    ('Prioridad', 3),
    ('Área', 4),
    ('Vencimiento', 6),
    ('Progreso', 7),
  ];

  int _columnaOrden = 6;
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
      case 3:
        return a.prioridad.index.compareTo(b.prioridad.index);
      case 4:
        return a.grupo.toLowerCase().compareTo(b.grupo.toLowerCase());
      case 6:
        final fa = a.fechaVencimiento;
        final fb = b.fechaVencimiento;
        if (fa == null && fb == null) return 0;
        if (fa == null) return 1;
        if (fb == null) return -1;
        return fa.compareTo(fb);
      case 7:
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
    if (!await _confirmarEliminarLote(ids.length)) return;
    if (!mounted) return;
    setState(() => _seleccionados.clear());
    await widget.onEliminarSeleccion(ids);
  }

  /// Confirmación compartida por la eliminación en lote y la acción rápida
  /// por fila — eliminar es destructivo e irreversible, así que ambos
  /// caminos deben pasar por el mismo diálogo en vez de que la acción
  /// rápida se salte la confirmación "porque es una sola tarjeta".
  Future<bool> _confirmarEliminarLote(int cantidad) => confirmarEliminar(
    context,
    titulo: cantidad == 1 ? 'Eliminar tarjeta' : 'Eliminar tarjetas',
    // No "esta acción no se puede deshacer": el toast que sigue si se
    // confirma sí ofrece "Deshacer" (recreando con ids nuevos, sin
    // restaurar dependencias) — decir lo contrario aquí lo contradice.
    mensaje:
        '¿Eliminar $cantidad ${cantidad == 1 ? 'tarjeta' : 'tarjetas'}? '
        'Podrás deshacerlo enseguida, pero se perderán sus enlaces de '
        'dependencia con otras tarjetas.',
  );

  Future<void> _eliminarUna(Tarea t) async {
    if (!await _confirmarEliminarLote(1)) return;
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
          kanbanFecha(t.fechaVencimiento),
          '${(t.progreso * 100).round()}%',
        ].map(campoCsv).join(','),
      );
    }
    try {
      descargarCsv('tareas_kanban.csv', lineas.join('\r\n'));
    } on UnsupportedError {
      kanbanToast(
        context,
        'Exportar a CSV solo está disponible en la versión web.',
        ok: false,
      );
    } catch (_) {
      // En web, cualquier otro fallo (bloqueo de pop-up, política de
      // seguridad al crear el Blob/URL, etc.) no es "no disponible" —
      // el mensaje de arriba sería falso y confundiría a quien sí está
      // en la versión que debería soportarlo.
      kanbanToast(context, 'No se pudo exportar el CSV. Intenta de nuevo.', ok: false);
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
                child: Text(
                  // Aviso del límite de WIP aquí mismo: sin esto, mover en
                  // lote a una columna ya llena (p. ej. Proceso, límite 1)
                  // solo se enteraba al ver el toast de rechazo después de
                  // elegirla — mejor que la lista ya lo muestre.
                  c.limiteWip == null
                      ? c.titulo
                      : '${c.titulo} '
                            '(${widget.totalesPorEstatus[c.estatus] ?? widget.tareas.where((t) => t.estatus == c.estatus).length}'
                            '/${c.limiteWip})',
                  style: const TextStyle(fontSize: 12.5),
                ),
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

  /// Reemplaza el tocar-el-encabezado-de-columna de la tabla (que no existe
  /// en tarjetas): un menú con las mismas columnas ordenables + un botón
  /// para invertir la dirección, sin duplicar `_comparar`.
  Widget _controlOrdenMovil() {
    final actual = _opcionesOrden.firstWhere(
      (o) => o.$2 == _columnaOrden,
      orElse: () => _opcionesOrden.first,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: PopupMenuButton<int>(
              tooltip: 'Ordenar por…',
              onSelected: (idx) => _alOrdenar(idx, _ascendente),
              itemBuilder: (context) => [
                for (final o in _opcionesOrden)
                  PopupMenuItem(
                    value: o.$2,
                    child: Text(o.$1, style: const TextStyle(fontSize: 12.5)),
                  ),
              ],
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: KanbanColors.bg2,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: KanbanColors.borde),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.sort_rounded,
                      size: 15,
                      color: KanbanColors.tdim,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Ordenar: ${actual.$1}',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: KanbanColors.texto,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.expand_more_rounded,
                      size: 16,
                      color: KanbanColors.tdim,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: _ascendente
                ? 'Ascendente — tocar para invertir'
                : 'Descendente — tocar para invertir',
            icon: Icon(
              _ascendente
                  ? Icons.arrow_upward_rounded
                  : Icons.arrow_downward_rounded,
              size: 18,
              color: KanbanColors.texto,
            ),
            style: IconButton.styleFrom(
              backgroundColor: KanbanColors.bg2,
              side: BorderSide(color: KanbanColors.borde),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(9),
              ),
            ),
            onPressed: () => _alOrdenar(_columnaOrden, !_ascendente),
          ),
        ],
      ),
    );
  }

  /// Tarjeta de una tarea para pantallas angostas — mismo contenido que la
  /// fila de la tabla (`_celdaEstado`/`_celdaEtiquetas`/etc., reutilizadas
  /// tal cual), pero apilado verticalmente en vez de en columnas, para no
  /// necesitar scroll horizontal.
  Widget _tarjetaMovil(Tarea t) {
    final seleccionada = _seleccionados.contains(t.id);
    final etiquetas = t.etiquetaIds
        .map((id) => widget.etiquetasPorId[id])
        .whereType<TareaEtiqueta>()
        .toList();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      decoration: KanbanColors.cardDecoration(radius: 12).copyWith(
        border: Border.all(
          color: seleccionada ? KanbanColors.accent : KanbanColors.borde,
          width: seleccionada ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        onTap: () => widget.onAbrirTarea(t),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 34,
                    height: 34,
                    child: Checkbox(
                      value: seleccionada,
                      onChanged: (v) => setState(() {
                        if (v ?? false) {
                          _seleccionados.add(t.id);
                        } else {
                          _seleccionados.remove(t.id);
                        }
                      }),
                    ),
                  ),
                  Expanded(child: _celdaEstado(t)),
                  PopupMenuButton<String>(
                    icon: Icon(
                      Icons.more_vert_rounded,
                      size: 18,
                      color: KanbanColors.tdim,
                    ),
                    onSelected: (v) {
                      if (v == 'archivar') {
                        widget.onArchivarSeleccion([t.id]);
                      } else {
                        _eliminarUna(t);
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: 'archivar',
                        child: Text(
                          'Archivar',
                          style: TextStyle(fontSize: 12.5),
                        ),
                      ),
                      PopupMenuItem(
                        value: 'eliminar',
                        child: Text(
                          'Eliminar',
                          style: TextStyle(fontSize: 12.5),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Text(
                t.titulo,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: KanbanColors.texto,
                ),
              ),
              if (etiquetas.isNotEmpty) ...[
                const SizedBox(height: 8),
                _celdaEtiquetas(t),
              ],
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _celdaPrioridad(t),
                  if (t.grupo.isNotEmpty)
                    Text(
                      t.grupo,
                      style: TextStyle(fontSize: 12, color: KanbanColors.tdim),
                    ),
                ],
              ),
              if (t.actividades.isNotEmpty) ...[
                const SizedBox(height: 10),
                _celdaProgreso(t),
              ],
              if (_notaPausaReciente(t) != null) ...[
                const SizedBox(height: 10),
                _celdaNotaPausa(_notaPausaReciente(t)!),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  _celdaAsignados(t),
                  const Spacer(),
                  _celdaVencimiento(t),
                ],
              ),
            ],
          ),
        ),
      ),
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
    final esMovil = MediaQuery.sizeOf(context).width < _kUmbralMovil;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_seleccionados.isNotEmpty)
          _barraSeleccion()
        else
          _barraHerramientas(),
        if (esMovil) _controlOrdenMovil(),
        Expanded(
          child: esMovil
              ? ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  itemCount: filas.length,
                  itemBuilder: (context, i) => _tarjetaMovil(filas[i]),
                )
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: Container(
                    decoration: KanbanColors.cardDecorationConFondo(radius: 12),
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
                                    KanbanColors.bg3ConFondo,
                                  ),
                                  dividerThickness: 1,
                                  horizontalMargin: 16,
                                  columnSpacing: 20,
                                  onSelectAll: (v) => setState(() {
                                    if (v ?? false) {
                                      _seleccionados.addAll(
                                        filas.map((t) => t.id),
                                      );
                                    } else {
                                      _seleccionados.clear();
                                    }
                                  }),
                                  columns: [
                                    DataColumn(
                                      label: Text(
                                        'Estado',
                                        style: estiloEncabezado,
                                      ),
                                      onSort: _alOrdenar,
                                    ),
                                    DataColumn(
                                      label: Text(
                                        'Tarea',
                                        style: estiloEncabezado,
                                      ),
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
                                      label: Text(
                                        'Área',
                                        style: estiloEncabezado,
                                      ),
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
                                    for (var i = 0; i < filas.length; i++)
                                      DataRow(
                                        // Filas alternadas, mismo lenguaje que
                                        // ya usaban las del Gantt: una deja ver
                                        // tal cual el fondo de la tarjeta (que
                                        // ya lleva el tinte del selector de
                                        // paleta) y la otra es una franja más
                                        // clara encima — antes todas las filas
                                        // eran iguales y planas.
                                        color: WidgetStateProperty.resolveWith((
                                          states,
                                        ) {
                                          if (states.contains(
                                            WidgetState.selected,
                                          )) {
                                            return KanbanColors.accentLight;
                                          }
                                          return i.isOdd
                                              ? KanbanColors.bg3.withValues(
                                                  alpha: 0.4,
                                                )
                                              : Colors.transparent;
                                        }),
                                        selected: _seleccionados.contains(
                                          filas[i].id,
                                        ),
                                        onSelectChanged: (v) => setState(() {
                                          if (v ?? false) {
                                            _seleccionados.add(filas[i].id);
                                          } else {
                                            _seleccionados.remove(filas[i].id);
                                          }
                                        }),
                                        cells: [
                                          DataCell(_celdaEstado(filas[i])),
                                          DataCell(
                                            _celdaTitulo(filas[i]),
                                            onTap: () =>
                                                widget.onAbrirTarea(filas[i]),
                                          ),
                                          DataCell(_celdaEtiquetas(filas[i])),
                                          DataCell(_celdaPrioridad(filas[i])),
                                          DataCell(
                                            Text(
                                              filas[i].grupo.isEmpty
                                                  ? '—'
                                                  : filas[i].grupo,
                                              style: TextStyle(
                                                fontSize: 12.5,
                                                color: KanbanColors.texto,
                                              ),
                                            ),
                                          ),
                                          DataCell(_celdaAsignados(filas[i])),
                                          DataCell(_celdaVencimiento(filas[i])),
                                          DataCell(_celdaProgreso(filas[i])),
                                          DataCell(_celdaAcciones(filas[i])),
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
    final nota = _notaPausaReciente(t);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 260),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            t.titulo,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: KanbanColors.texto,
            ),
          ),
          // Motivo de la última pausa, visible sin tener que abrir la
          // tarjeta — en la tabla no hay espacio para la caja completa que
          // usa la tarjeta apilada de celular, así que va como subtítulo.
          if (nota != null) ...[
            const SizedBox(height: 2),
            Row(
              children: [
                Icon(
                  Icons.pause_circle_outline_rounded,
                  size: 11,
                  color: KanbanColors.tdim,
                ),
                const SizedBox(width: 3),
                Expanded(
                  child: Text(
                    nota,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontStyle: FontStyle.italic,
                      color: KanbanColors.tdim,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
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
      kanbanFecha(t.fechaVencimiento),
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

  /// Texto de la nota más reciente entre las entradas de historial que
  /// `registrarNotaPausa` fue dejando (una por cada vez que se pausó la
  /// tarea con un motivo escrito) — recorre de más nueva a más vieja y se
  /// queda con la primera que encuentra.
  String? _notaPausaReciente(Tarea t) {
    const prefijo = 'Pausó: ';
    for (var i = t.historial.length - 1; i >= 0; i--) {
      final mensaje = t.historial[i].mensaje;
      if (mensaje.startsWith(prefijo)) {
        return mensaje.substring(prefijo.length);
      }
    }
    return null;
  }

  Widget _celdaNotaPausa(String nota) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: KanbanColors.bg3,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.pause_circle_outline_rounded,
            size: 13,
            color: KanbanColors.tdim,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              nota,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11.5, color: KanbanColors.tdim),
            ),
          ),
        ],
      ),
    );
  }
}
