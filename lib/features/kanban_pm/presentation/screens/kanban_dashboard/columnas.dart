part of '../kanban_dashboard_screen.dart';

/// Gestión de listas/columnas: renombrar, archivar, reordenar (botones y
/// arrastre), autoscroll horizontal del tablero durante el arrastre, y los
/// diálogos de listas/tarjetas archivadas.
mixin _KanbanDashboardColumnasMixin on _KanbanDashboardDatosMixin {
  Future<void> _renombrarColumna(
    TareaEstatus estatus,
    String nuevoTitulo,
  ) async {
    setState(() {
      final idx = _columnas.indexWhere((c) => c.estatus == estatus);
      if (idx != -1) {
        _columnas[idx] = _columnas[idx].copyWith(titulo: nuevoTitulo);
      }
    });
    await _repo.renombrarColumna(estatus, nuevoTitulo);
  }

  Future<void> _archivarColumna(TareaEstatus estatus, bool archivada) async {
    if (archivada) {
      // Cuenta sobre `_tareasCompletas` (el total real), no `_tareas`: un
      // filtro de vista activo no debe hacer parecer una lista vacía
      // cuando en realidad tiene tarjetas ocultas por el filtro. Sin
      // esta confirmación, un solo clic en "Archivar lista" podía
      // esconder un número arbitrario de tarjetas activas del tablero,
      // la vista Lista, Calendario/Gráficas y la campana de
      // notificaciones, sin ningún aviso previo de cuántas ni de que
      // seguían "vivas" en algún lado.
      final activas = _tareasCompletas
          .where((t) => t.estatus == estatus)
          .length;
      if (activas > 0) {
        final columna = _columnas.firstWhere((c) => c.estatus == estatus);
        final ok =
            await showDialog<bool>(
              context: context,
              builder: (ctx) => kanbanAlertDialog(
                titulo: 'Archivar lista',
                content: Text(
                  '"${columna.titulo}" tiene '
                  '${activas == 1 ? '1 tarjeta activa' : '$activas tarjetas activas'}. '
                  'Se ocultarán del tablero (y de Lista/Calendario/Gráficas) '
                  'hasta que desarchives esta lista. ¿Continuar?',
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
                      backgroundColor: KanbanColors.accent,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Archivar'),
                  ),
                ],
              ),
            ) ??
            false;
        if (!ok || !mounted) return;
      }
    }
    setState(() {
      final idx = _columnas.indexWhere((c) => c.estatus == estatus);
      if (idx != -1) {
        _columnas[idx] = _columnas[idx].copyWith(archivada: archivada);
      }
      // Al archivar, saca también de `_tareas` (no solo de `_columnas`) las
      // tarjetas de esa columna en el mismo `setState`: sin esto, mientras
      // `_cargar()` de más abajo no termine (~150ms), `_columnasVisibles`
      // ya no incluía la columna pero `_tareas` sí seguía trayendo sus
      // tarjetas — en Gráficas, la dona (agrupada por columnas visibles)
      // dejaba de sumar el mismo total que el KPI de arriba (que cuenta
      // `_tareas` completo) durante esa ventana.
      if (archivada) {
        _tareas = _tareas.where((t) => t.estatus != estatus).toList();
      }
    });
    await _repo.archivarColumna(estatus, archivada);
    await _cargar();
    if (archivada) {
      _toastAccion(
        'Lista archivada',
        'Deshacer',
        () => _archivarColumna(estatus, false),
      );
    }
  }

  /// A diferencia del primer intento (un composer al final de todas las
  /// columnas, estilo Trello): con varias columnas quedaba fuera de vista
  /// hasta hacer scroll horizontal hasta el fondo, poco descubrible. Un
  /// ícono en el header — igual que "Etiquetas"/"Plantillas" — no depende
  /// de cuántas columnas haya ni de en qué parte del scroll se esté.
  Future<void> _abrirNuevaLista() async {
    final columna = await NuevaListaDialog.show(context, repository: _repo);
    if (columna == null || !mounted) return;
    setState(() => _columnas = [..._columnas, columna]);
  }

  void _manejarAutoscrollHorizontal(Offset globalPos) {
    final box = _boardKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final area = box.localToGlobal(Offset.zero) & box.size;
    final direccion = direccionAutoscroll(
      posEnEje: globalPos.dx,
      inicioArea: area.left,
      finArea: area.right,
    );
    if (direccion == _boardAutoscrollDireccion) return;
    _boardAutoscrollDireccion = direccion;
    _boardAutoscrollTimer?.cancel();
    if (direccion == null) return;
    _boardAutoscrollTimer = Timer.periodic(const Duration(milliseconds: 16), (
      _,
    ) {
      if (!_boardHCtrl.hasClients) return;
      final destino = (_boardHCtrl.offset + direccion * 14).clamp(
        0.0,
        _boardHCtrl.position.maxScrollExtent,
      );
      _boardHCtrl.jumpTo(destino);
    });
  }

  void _detenerAutoscrollHorizontal() {
    _boardAutoscrollTimer?.cancel();
    _boardAutoscrollTimer = null;
    _boardAutoscrollDireccion = null;
  }

  /// Reordena las columnas por arrastre a un índice exacto entre las
  /// visibles, reconstruyendo la lista completa (incluidas las archivadas,
  /// preservando su posición relativa) antes de escribir de vuelta con
  /// `reordenarColumnas` — un reordenamiento que solo considerara las
  /// visibles borraría las archivadas del repositorio para siempre.
  Future<void> _reordenarColumnaDrag(
    TareaEstatus origenEstatus,
    int gapIndex,
  ) async {
    _detenerAutoscrollHorizontal();
    final visibles = _columnasVisibles;
    final origenIdx = visibles.indexWhere((c) => c.estatus == origenEstatus);
    if (origenIdx == -1) return;
    final posicion = gapIndex > origenIdx ? gapIndex - 1 : gapIndex;
    final nuevasVisibles = List.of(visibles);
    final movida = nuevasVisibles.removeAt(origenIdx);
    nuevasVisibles.insert(posicion.clamp(0, nuevasVisibles.length), movida);
    final cola = List.of(nuevasVisibles);
    final resultado = [
      for (final c in _columnas) c.archivada ? c : cola.removeAt(0),
    ];
    setState(() => _columnas = resultado);
    try {
      await _repo.reordenarColumnas(resultado.map((c) => c.estatus).toList());
    } catch (ex) {
      _toast('Error al reordenar listas: $ex', ok: false);
      // El `setState` de arriba es optimista: si el repositorio no logró
      // guardar el nuevo orden, se revierte recargando el catálogo real de
      // columnas en vez de dejar el tablero mostrando un orden que nunca
      // se persistió.
      await _cargarColumnasYEtiquetas();
    }
  }

  /// Zona para soltar una lista entre dos columnas. El área que realmente
  /// detecta el arrastre (`SizedBox` de ancho fijo y alto completo) es bien
  /// más grande que la línea que se ve — antes el `DragTarget` cambiaba de
  /// tamaño según si estaba activo (6 a 24 de ancho, sin alto explícito), así
  /// que el hueco real donde soltar era angosto e impredecible. Con un
  /// tamaño fijo de antemano el usuario puede soltar en cualquier punto de
  /// esa franja, sin apuntar a un pixel exacto.
  Widget _columnaGap(int gapIndex, double alto) {
    return DragTarget<KanbanColumna>(
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (details) =>
          _reordenarColumnaDrag(details.data.estatus, gapIndex),
      onMove: (details) => _manejarAutoscrollHorizontal(details.offset),
      builder: (context, candidateData, rejectedData) {
        final activo = candidateData.isNotEmpty;
        return SizedBox(
          width: 26,
          height: alto,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              curve: Curves.easeOut,
              width: activo ? 5 : 0,
              height: alto,
              decoration: BoxDecoration(
                color: KanbanColors.accent,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _abrirListasArchivadas() => ListasArchivadasDialog.show(
    context,
    columnas: _columnas,
    onDesarchivar: (estatus) => _archivarColumna(estatus, false),
  );

  Future<void> _abrirTarjetasArchivadas() => TarjetasArchivadasDialog.show(
    context,
    repository: _repo,
    onDesarchivada: () => _cargar(),
  );
}

/// Envuelve una columna para que también sea destino de arrastre de otra
/// lista: [_columnaGap] solo cubre una franja angosta entre columnas, así
/// que soltar sobre el cuerpo de una columna (mucho más grande) no hacía
/// nada. Decide "antes" o "después" de esta columna según la mitad
/// (izquierda/derecha) donde se suelta, delegando el reordenamiento real a
/// la misma función que ya usa [_columnaGap].
class _ColumnaDropTarget extends StatefulWidget {
  final int indice;
  final TareaEstatus estatusPropio;
  final void Function(TareaEstatus origenEstatus, int gapIndex) onSoltar;
  final Widget child;

  const _ColumnaDropTarget({
    super.key,
    required this.indice,
    required this.estatusPropio,
    required this.onSoltar,
    required this.child,
  });

  @override
  State<_ColumnaDropTarget> createState() => _ColumnaDropTargetState();
}

class _ColumnaDropTargetState extends State<_ColumnaDropTarget> {
  bool? _mitadIzquierda;

  void _actualizarMitad(Offset globalPos) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final local = box.globalToLocal(globalPos);
    final izquierda = local.dx < box.size.width / 2;
    if (izquierda != _mitadIzquierda) {
      setState(() => _mitadIzquierda = izquierda);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DragTarget<KanbanColumna>(
      onWillAcceptWithDetails: (details) =>
          details.data.estatus != widget.estatusPropio,
      onMove: (details) => _actualizarMitad(details.offset),
      onLeave: (_) => setState(() => _mitadIzquierda = null),
      onAcceptWithDetails: (details) {
        final porIzquierda = _mitadIzquierda ?? true;
        final gapIndex = porIzquierda ? widget.indice : widget.indice + 1;
        widget.onSoltar(details.data.estatus, gapIndex);
        setState(() => _mitadIzquierda = null);
      },
      builder: (context, candidateData, rejectedData) {
        final activo = candidateData.isNotEmpty;
        final porIzquierda = _mitadIzquierda ?? true;
        return Stack(
          children: [
            widget.child,
            if (activo)
              Positioned(
                top: 0,
                bottom: 0,
                left: porIzquierda ? 0 : null,
                right: porIzquierda ? null : 0,
                child: IgnorePointer(
                  child: Container(
                    width: 4,
                    decoration: BoxDecoration(
                      color: KanbanColors.accent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
