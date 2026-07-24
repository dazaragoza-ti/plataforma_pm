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

  Future<void> _moverColumna(TareaEstatus estatus, int direccion) async {
    final idx = _columnas.indexWhere((c) => c.estatus == estatus);
    if (idx == -1) return;
    var otroIdx = idx + direccion;
    while (otroIdx >= 0 &&
        otroIdx < _columnas.length &&
        _columnas[otroIdx].archivada) {
      otroIdx += direccion;
    }
    if (otroIdx < 0 || otroIdx >= _columnas.length) return;
    final nuevas = List.of(_columnas);
    final tmp = nuevas[idx];
    nuevas[idx] = nuevas[otroIdx];
    nuevas[otroIdx] = tmp;
    setState(() => _columnas = nuevas);
    await _repo.reordenarColumnas(nuevas.map((c) => c.estatus).toList());
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

  Widget _columnaGap(int gapIndex) {
    return DragTarget<KanbanColumna>(
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (details) =>
          _reordenarColumnaDrag(details.data.estatus, gapIndex),
      onMove: (details) => _manejarAutoscrollHorizontal(details.offset),
      builder: (context, candidateData, rejectedData) {
        final activo = candidateData.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          width: activo ? 24 : 6,
          decoration: activo
              ? BoxDecoration(
                  color: KanbanColors.accentLight,
                  borderRadius: BorderRadius.circular(4),
                )
              : null,
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
