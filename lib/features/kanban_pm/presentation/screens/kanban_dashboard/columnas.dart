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
    setState(() {
      final idx = _columnas.indexWhere((c) => c.estatus == estatus);
      if (idx != -1) {
        _columnas[idx] = _columnas[idx].copyWith(archivada: archivada);
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
    await _repo.reordenarColumnas(resultado.map((c) => c.estatus).toList());
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
