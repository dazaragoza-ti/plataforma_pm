import 'dart:async';
import 'package:flutter/material.dart';
import '../../kanban_constants.dart';
import '../../domain/entities/miembro.dart';
import '../../domain/entities/tarea.dart';
import '../../domain/entities/tarea_etiqueta.dart';
import 'kanban_task_card.dart';

/// Dirección de autoscroll (-1, 1 ó `null`) según qué tan cerca está
/// [posEnEje] de los bordes de `[inicioArea, finArea]` — pura aritmética,
/// sin `Timer`/`ScrollController`, para poder reutilizarla tanto en el
/// autoscroll vertical de una columna como en el horizontal del tablero.
double? direccionAutoscroll({
  required double posEnEje,
  required double inicioArea,
  required double finArea,
  double umbral = 48.0,
}) {
  final distInicio = posEnEje - inicioArea;
  final distFin = finArea - posEnEje;
  if (distInicio < umbral && distInicio > -20) return -1;
  if (distFin < umbral && distFin > -20) return 1;
  return null;
}

/// Columna del tablero (TAREAS / PROCESO / PAUSA / TERMINADO / REVISADO),
/// con look y comportamiento estilo Trello: título editable, menú de lista
/// (renombrar/archivar/mover), composer de alta rápida al pie, y arrastre
/// de tarjetas a una posición exacta dentro o entre columnas.
class KanbanColumnView extends StatefulWidget {
  final KanbanColumna columna;
  final List<Tarea> tareas;
  final Map<int, TareaEtiqueta> etiquetasPorId;
  final Map<int, Miembro> miembrosPorId;
  final void Function(Tarea tarea) onTapTarea;
  final void Function(Tarea tarea, TareaEstatus destino, int posicion)
  onReordenar;
  final void Function(String nuevoTitulo) onRenombrar;
  final VoidCallback onArchivarColumna;
  final VoidCallback? onMoverIzquierda;
  final VoidCallback? onMoverDerecha;
  final void Function(String titulo) onCrearRapida;
  final void Function(Tarea tarea) onArchivarTarjeta;
  final void Function(Tarea tarea) onEliminarTarjeta;
  final void Function(Offset globalPos)? onArrastreGlobalHorizontal;
  final void Function(int? limite)? onCambiarLimiteWip;

  const KanbanColumnView({
    super.key,
    required this.columna,
    required this.tareas,
    this.etiquetasPorId = const {},
    this.miembrosPorId = const {},
    required this.onTapTarea,
    required this.onReordenar,
    required this.onRenombrar,
    required this.onArchivarColumna,
    this.onMoverIzquierda,
    this.onMoverDerecha,
    required this.onCrearRapida,
    required this.onArchivarTarjeta,
    required this.onEliminarTarjeta,
    this.onArrastreGlobalHorizontal,
    this.onCambiarLimiteWip,
  });

  @override
  State<KanbanColumnView> createState() => _KanbanColumnViewState();
}

class _KanbanColumnViewState extends State<KanbanColumnView> {
  final _scrollCtrl = ScrollController();
  final _tituloCtrl = TextEditingController();
  final _nuevaTarjetaCtrl = TextEditingController();
  bool _editandoTitulo = false;
  bool _creandoTarjeta = false;
  Timer? _autoscrollTimer;
  double? _autoscrollDireccion;

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _tituloCtrl.dispose();
    _nuevaTarjetaCtrl.dispose();
    _autoscrollTimer?.cancel();
    super.dispose();
  }

  void _iniciarEdicionTitulo() {
    _tituloCtrl.text = widget.columna.titulo;
    setState(() => _editandoTitulo = true);
  }

  void _confirmarTitulo() {
    final nuevo = _tituloCtrl.text.trim();
    if (nuevo.isNotEmpty && nuevo != widget.columna.titulo) {
      widget.onRenombrar(nuevo);
    }
    setState(() => _editandoTitulo = false);
  }

  Future<void> _elegirLimiteWip() async {
    final ctrl = TextEditingController(
      text: widget.columna.limiteWip?.toString() ?? '',
    );
    // El campo vacío es "sin límite": no hace falta un botón aparte para
    // quitarlo, basta con borrar el número y guardar.
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: KanbanColors.bg2,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Límite de WIP',
          style: TextStyle(color: KanbanColors.texto),
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          style: TextStyle(color: KanbanColors.texto),
          decoration: InputDecoration(
            isDense: true,
            hintText: 'Sin límite',
            hintStyle: TextStyle(color: KanbanColors.tdim),
            helperText: 'Aviso visual: no impide soltar una tarjeta de más.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (confirmado == true) {
      widget.onCambiarLimiteWip?.call(int.tryParse(ctrl.text.trim()));
    }
  }

  void _confirmarNuevaTarjeta() {
    final titulo = _nuevaTarjetaCtrl.text.trim();
    if (titulo.isNotEmpty) {
      widget.onCrearRapida(titulo);
      _nuevaTarjetaCtrl.clear();
    }
    setState(() => _creandoTarjeta = false);
  }

  void _manejarAutoscroll(Offset globalPos, Rect areaVisible) {
    final direccion = direccionAutoscroll(
      posEnEje: globalPos.dy,
      inicioArea: areaVisible.top,
      finArea: areaVisible.bottom,
    );
    if (direccion == _autoscrollDireccion) return;
    _autoscrollDireccion = direccion;
    _autoscrollTimer?.cancel();
    if (direccion == null) return;
    _autoscrollTimer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (!_scrollCtrl.hasClients) return;
      final destino = (_scrollCtrl.offset + direccion * 12).clamp(
        0.0,
        _scrollCtrl.position.maxScrollExtent,
      );
      _scrollCtrl.jumpTo(destino);
    });
  }

  void _detenerAutoscroll() {
    _autoscrollTimer?.cancel();
    _autoscrollTimer = null;
    _autoscrollDireccion = null;
  }

  void _manejarDrop(Tarea arrastrada, int gapIndex) {
    final origenIdx = widget.tareas.indexWhere((t) => t.id == arrastrada.id);
    final posicion = (origenIdx != -1 && gapIndex > origenIdx)
        ? gapIndex - 1
        : gapIndex;
    widget.onReordenar(arrastrada, widget.columna.estatus, posicion);
  }

  Widget _gap(int index) {
    return DragTarget<Tarea>(
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (details) {
        _detenerAutoscroll();
        _manejarDrop(details.data, index);
      },
      onMove: (details) {
        final box = context.findRenderObject() as RenderBox?;
        if (box == null) return;
        _manejarAutoscroll(
          details.offset,
          box.localToGlobal(Offset.zero) & box.size,
        );
        widget.onArrastreGlobalHorizontal?.call(details.offset);
      },
      onLeave: (_) => _detenerAutoscroll(),
      builder: (context, candidateData, rejectedData) {
        final activo = candidateData.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          height: activo ? 44 : 8,
          margin: EdgeInsets.symmetric(
            vertical: activo ? 3 : 0,
            horizontal: activo ? 4 : 0,
          ),
          decoration: activo
              ? BoxDecoration(
                  color: KanbanColors.accentLight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: KanbanColors.accent,
                    style: BorderStyle.solid,
                  ),
                )
              : null,
        );
      },
    );
  }

  bool get _wipExcedido =>
      widget.columna.limiteWip != null &&
      widget.tareas.length > widget.columna.limiteWip!;

  Widget _filaTitulo() {
    final limite = widget.columna.limiteWip;
    return Row(
      children: [
        Flexible(
          child: Text(
            widget.columna.titulo,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: KanbanColors.texto,
              letterSpacing: 0.2,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          limite == null
              ? '${widget.tareas.length}'
              : '${widget.tareas.length}/$limite',
          style: TextStyle(
            fontSize: 13,
            fontWeight: _wipExcedido ? FontWeight.bold : FontWeight.w500,
            color: _wipExcedido ? KanbanColors.danger : KanbanColors.tdim,
          ),
        ),
        if (_wipExcedido) ...[
          const SizedBox(width: 4),
          Tooltip(
            message: 'Se pasó del límite de WIP de esta lista ($limite)',
            child: Icon(
              Icons.warning_amber_rounded,
              size: 14,
              color: KanbanColors.danger,
            ),
          ),
        ],
      ],
    );
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 10, 12),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: widget.columna.color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _editandoTitulo
                ? TextField(
                    controller: _tituloCtrl,
                    autofocus: true,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: KanbanColors.texto,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      filled: true,
                      fillColor: KanbanColors.bg2,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 6,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(color: KanbanColors.borde),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(color: KanbanColors.accent),
                      ),
                    ),
                    onSubmitted: (_) => _confirmarTitulo(),
                    onTapOutside: (_) => _confirmarTitulo(),
                  )
                : Draggable<KanbanColumna>(
                    data: widget.columna,
                    feedback: Material(
                      color: Colors.transparent,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: KanbanColors.bg2,
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        child: Text(
                          widget.columna.titulo,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: KanbanColors.texto,
                          ),
                        ),
                      ),
                    ),
                    childWhenDragging: Opacity(
                      opacity: 0.3,
                      child: _filaTitulo(),
                    ),
                    child: InkWell(
                      onTap: _iniciarEdicionTitulo,
                      child: _filaTitulo(),
                    ),
                  ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Menú de la lista',
            padding: EdgeInsets.zero,
            icon: Icon(
              Icons.more_horiz_rounded,
              size: 17,
              color: KanbanColors.tdim,
            ),
            onSelected: (v) {
              switch (v) {
                case 'renombrar':
                  _iniciarEdicionTitulo();
                case 'archivar':
                  widget.onArchivarColumna();
                case 'izquierda':
                  widget.onMoverIzquierda?.call();
                case 'derecha':
                  widget.onMoverDerecha?.call();
                case 'limite_wip':
                  _elegirLimiteWip();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'renombrar',
                child: Text(
                  'Renombrar lista',
                  style: TextStyle(fontSize: 12.5),
                ),
              ),
              const PopupMenuItem(
                value: 'limite_wip',
                child: Text('Límite de WIP…', style: TextStyle(fontSize: 12.5)),
              ),
              const PopupMenuItem(
                value: 'archivar',
                child: Text('Archivar lista', style: TextStyle(fontSize: 12.5)),
              ),
              PopupMenuItem(
                value: 'izquierda',
                enabled: widget.onMoverIzquierda != null,
                child: const Text(
                  'Mover a la izquierda',
                  style: TextStyle(fontSize: 12.5),
                ),
              ),
              PopupMenuItem(
                value: 'derecha',
                enabled: widget.onMoverDerecha != null,
                child: const Text(
                  'Mover a la derecha',
                  style: TextStyle(fontSize: 12.5),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _footer() {
    if (_creandoTarjeta) {
      return Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nuevaTarjetaCtrl,
              autofocus: true,
              maxLines: 2,
              minLines: 1,
              style: TextStyle(fontSize: 12.5, color: KanbanColors.texto),
              decoration: InputDecoration(
                isDense: true,
                filled: true,
                fillColor: KanbanColors.bg2,
                hintText: 'Título de la tarjeta…',
                hintStyle: TextStyle(color: KanbanColors.tdim),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: KanbanColors.borde),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: KanbanColors.accent),
                ),
              ),
              onSubmitted: (_) => _confirmarNuevaTarjeta(),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                ElevatedButton(
                  onPressed: _confirmarNuevaTarjeta,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: KanbanColors.toolbarGreen,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                  ),
                  child: const Text(
                    'Añadir',
                    style: TextStyle(fontSize: 12, color: Colors.white),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: () => setState(() {
                    _creandoTarjeta = false;
                    _nuevaTarjetaCtrl.clear();
                  }),
                ),
              ],
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => setState(() => _creandoTarjeta = true),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 9, horizontal: 8),
          child: Row(
            children: [
              Icon(Icons.add_rounded, size: 17, color: KanbanColors.tdim),
              SizedBox(width: 6),
              Text(
                'Añadir tarjeta',
                style: TextStyle(fontSize: 13, color: KanbanColors.tdim),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      margin: const EdgeInsets.only(right: 14),
      decoration: BoxDecoration(
        color: KanbanColors.bg3,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _wipExcedido ? KanbanColors.danger : KanbanColors.borde,
          width: _wipExcedido ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(),
          Expanded(
            child: DragTarget<Tarea>(
              onWillAcceptWithDetails: (_) => true,
              onAcceptWithDetails: (details) {
                _detenerAutoscroll();
                _manejarDrop(details.data, widget.tareas.length);
              },
              onMove: (details) {
                final box = context.findRenderObject() as RenderBox?;
                if (box == null) return;
                _manejarAutoscroll(
                  details.offset,
                  box.localToGlobal(Offset.zero) & box.size,
                );
                widget.onArrastreGlobalHorizontal?.call(details.offset);
              },
              onLeave: (_) => _detenerAutoscroll(),
              builder: (context, candidateData, rejectedData) {
                return Stack(
                  children: [
                    Positioned.fill(
                      child: Container(
                        color: candidateData.isNotEmpty
                            ? KanbanColors.accentLight.withValues(alpha: 0.35)
                            : Colors.transparent,
                      ),
                    ),
                    _ListaTarjetas(
                      scrollController: _scrollCtrl,
                      tareas: widget.tareas,
                      etiquetasPorId: widget.etiquetasPorId,
                      miembrosPorId: widget.miembrosPorId,
                      gapBuilder: _gap,
                      onTapTarea: widget.onTapTarea,
                      onArchivarTarjeta: widget.onArchivarTarjeta,
                      onEliminarTarjeta: widget.onEliminarTarjeta,
                    ),
                  ],
                );
              },
            ),
          ),
          _footer(),
        ],
      ),
    );
  }
}

/// Lista de tarjetas de una columna, virtualizada con `ListView.builder`:
/// antes se construían todas las tarjetas de golpe (`ListView(children:
/// [for...])`), sin importar cuántas cupieran en pantalla. Cada tarjeta va
/// en su propio [RepaintBoundary] para que arrastrar o repintar una no
/// obligue a Skia/CanvasKit a re-rasterizar las demás.
///
/// Los índices intercalan un "hueco" (`DragTarget` para soltar en una
/// posición exacta) antes de cada tarjeta, más uno final: con `n` tareas
/// hay `2n + 2` ítems (huecos + tarjetas + el hueco final + el spacer de
/// abajo), o 3 ítems fijos si la columna está vacía.
class _ListaTarjetas extends StatelessWidget {
  final ScrollController scrollController;
  final List<Tarea> tareas;
  final Map<int, TareaEtiqueta> etiquetasPorId;
  final Map<int, Miembro> miembrosPorId;
  final Widget Function(int index) gapBuilder;
  final void Function(Tarea tarea) onTapTarea;
  final void Function(Tarea tarea) onArchivarTarjeta;
  final void Function(Tarea tarea) onEliminarTarjeta;

  const _ListaTarjetas({
    required this.scrollController,
    required this.tareas,
    required this.etiquetasPorId,
    required this.miembrosPorId,
    required this.gapBuilder,
    required this.onTapTarea,
    required this.onArchivarTarjeta,
    required this.onEliminarTarjeta,
  });

  Widget _tarjeta(Tarea tarea) {
    final etiquetas = tarea.etiquetaIds
        .map((id) => etiquetasPorId[id])
        .whereType<TareaEtiqueta>()
        .toList();
    final miembros = tarea.miembroIds
        .map((id) => miembrosPorId[id])
        .whereType<Miembro>()
        .toList();
    return RepaintBoundary(
      key: ValueKey(tarea.id),
      child: Draggable<Tarea>(
        data: tarea,
        feedback: Material(
          color: Colors.transparent,
          child: SizedBox(
            width: 256,
            child: KanbanTaskCard(
              tarea: tarea,
              etiquetas: etiquetas,
              miembros: miembros,
              onTap: () {},
            ),
          ),
        ),
        childWhenDragging: Opacity(
          opacity: 0.35,
          child: KanbanTaskCard(tarea: tarea, onTap: () {}),
        ),
        child: KanbanTaskCard(
          tarea: tarea,
          etiquetas: etiquetas,
          miembros: miembros,
          onTap: () => onTapTarea(tarea),
          onArchivar: () => onArchivarTarjeta(tarea),
          onEliminar: () => onEliminarTarjeta(tarea),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final n = tareas.length;
    if (n == 0) {
      return ListView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
        children: [
          gapBuilder(0),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                'Sin tarjetas',
                style: TextStyle(
                  fontSize: 12,
                  color: KanbanColors.tdim.withValues(alpha: 0.8),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
        ],
      );
    }
    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      itemCount: 2 * n + 2,
      itemBuilder: (context, index) {
        if (index == 2 * n) return gapBuilder(n);
        if (index == 2 * n + 1) return const SizedBox(height: 4);
        final pair = index ~/ 2;
        return index.isEven ? gapBuilder(pair) : _tarjeta(tareas[pair]);
      },
    );
  }
}
