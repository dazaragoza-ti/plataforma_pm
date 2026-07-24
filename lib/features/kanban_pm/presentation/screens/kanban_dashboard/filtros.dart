part of '../kanban_dashboard_screen.dart';

/// Filtros del tablero, el diálogo de etiquetas y el fondo del tablero.
mixin _KanbanDashboardFiltrosMixin on _KanbanDashboardDatosMixin {
  bool get _filtrosActivos =>
      _fechaDesde != null ||
      _fechaHasta != null ||
      // El valor por defecto ahora es `false` (ver el campo): "activo" es
      // cuando se desvía de eso, es decir, cuando SÍ está prendido.
      _soloPendientes ||
      _miembroIdsFiltro.isNotEmpty ||
      _departamentosFiltro.isNotEmpty ||
      _etiquetaIdsFiltro.isNotEmpty;

  Future<void> _abrirFiltros() async {
    final resultado = await FiltrosDialog.show(
      context,
      repository: _repo,
      miembros: _miembros,
      etiquetas: _etiquetas,
      fechaDesde: _fechaDesde,
      fechaHasta: _fechaHasta,
      soloPendientes: _soloPendientes,
      miembroIdsFiltro: _miembroIdsFiltro,
      departamentosFiltro: _departamentosFiltro,
      etiquetaIdsFiltro: _etiquetaIdsFiltro,
    );
    if (resultado == null) return;
    setState(() {
      _fechaDesde = resultado.fechaDesde;
      _fechaHasta = resultado.fechaHasta;
      _soloPendientes = resultado.soloPendientes;
      _miembroIdsFiltro = resultado.miembroIds;
      _departamentosFiltro = resultado.departamentos;
      _etiquetaIdsFiltro = resultado.etiquetaIds;
    });
    await _cargar();
  }

  Future<void> _abrirEtiquetas() async {
    await EtiquetasDialog.show(context, repository: _repo);
    // `_cargar` por sí solo no bastaba: solo trae tareas, y el catálogo de
    // etiquetas (`_etiquetasPorId`, lo que pintan las tarjetas del Kanban,
    // la lista y las gráficas) solo lo llena `_cargarColumnasYEtiquetas`.
    // Sin este llamado, renombrar o recolorear una etiqueta desde este
    // diálogo no se veía reflejado hasta recargar toda la página.
    await _cargarColumnasYEtiquetas();
    await _cargar();
  }

  /// Además de rotar `_fondoIdx`, actualiza `KanbanColors.fondoTablero`:
  /// sin esto, las tarjetas/tiles que usan `cardDecorationConFondo` (ver
  /// [KanbanColors]) no se enteraban de qué color se eligió y se quedaban
  /// siempre en blanco/oscuro sin importar el fondo seleccionado.
  void _cambiarFondo() {
    setState(() {
      _fondoIdx = (_fondoIdx + 1) % kFondosTablero.length;
      KanbanColors.fondoTablero = kFondosTablero[_fondoIdx];
    });
  }
}
