import 'dart:async';
import 'package:flutter/material.dart';
import '../../kanban_constants.dart';
import '../../data/kanban_repository.dart';
import '../../domain/entities/miembro.dart';
import '../../domain/entities/tarea.dart';
import '../../domain/entities/tarea_etiqueta.dart';
import '../widgets/kanban_column.dart';
import '../widgets/kanban_gantt/kanban_gantt_view.dart';
import '../widgets/kanban_graficas_view.dart';
import '../widgets/nueva_tarea_dialog.dart';
import '../widgets/plantillas_dialog.dart';
import '../widgets/tarea_detail_dialog.dart';

enum _Vista { kanban, graficas, gantt }

/// Tablero Kanban: barra de herramientas (buscador, vistas, filtros) y
/// columnas TAREAS / PROCESO / PAUSA / TERMINADO / REVISADO, replicando el
/// diseño del tablero de referencia, con look estilo Trello (etiquetas,
/// portadas, listas renombrables/archivables) y una vista Gantt.
///
/// Por defecto usa [InMemoryKanbanRepository]; cuando exista un backend
/// real basta con inyectar aquí una implementación de [KanbanRepository]
/// que hable con la API.
class KanbanDashboardScreen extends StatefulWidget {
  final KanbanRepository? repository;

  const KanbanDashboardScreen({super.key, this.repository});

  @override
  State<KanbanDashboardScreen> createState() => _KanbanDashboardScreenState();
}

class _KanbanDashboardScreenState extends State<KanbanDashboardScreen> {
  late final KanbanRepository _repo =
      widget.repository ?? InMemoryKanbanRepository();

  final _searchCtrl = TextEditingController();
  final _boardHCtrl = ScrollController();
  final _boardKey = GlobalKey();
  Timer? _debounce;
  Timer? _boardAutoscrollTimer;
  double? _boardAutoscrollDireccion;
  List<Tarea> _tareas = [];
  List<KanbanColumna> _columnas = [];
  List<TareaEtiqueta> _etiquetas = [];
  List<Miembro> _miembros = [];
  bool _cargando = true;

  _Vista _vista = _Vista.kanban;
  bool _misTareas = false;
  bool _soloPendientes = true;
  DateTime? _fechaDesde;
  DateTime? _fechaHasta;
  int _fondoIdx = 0;

  List<KanbanColumna> get _columnasVisibles =>
      _columnas.where((c) => !c.archivada).toList();

  Map<int, TareaEtiqueta> get _etiquetasPorId => {
    for (final e in _etiquetas) e.id: e,
  };

  Map<int, Miembro> get _miembrosPorId => {
    for (final m in _miembros) m.id: m,
  };

  /// Id del miembro "yo" (usuario de la demo) resuelto una sola vez contra
  /// el catálogo, con `-1` de respaldo seguro si no hay match.
  int get _miIdDemo => _miembros
      .firstWhere(
        (m) => m.nombre == kUsuarioActualDemo,
        orElse: () => const Miembro(
          id: -1,
          nombre: '',
          colorAvatar: Colors.transparent,
        ),
      )
      .id;

  @override
  void initState() {
    super.initState();
    _cargarColumnasYEtiquetas();
    _cargar();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _boardAutoscrollTimer?.cancel();
    _searchCtrl.dispose();
    _boardHCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarColumnasYEtiquetas() async {
    final columnas = await _repo.listarColumnas();
    final etiquetas = await _repo.listarEtiquetas();
    final miembros = await _repo.listarMiembros();
    if (!mounted) return;
    setState(() {
      _columnas = columnas;
      _etiquetas = etiquetas;
      _miembros = miembros;
    });
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      var tareas = await _repo.listarTareas(busqueda: _searchCtrl.text);
      final columnasArchivadas = _columnas
          .where((c) => c.archivada)
          .map((c) => c.estatus)
          .toSet();
      tareas = tareas
          .where(
            (t) => !t.archivada && !columnasArchivadas.contains(t.estatus),
          )
          .toList();
      if (_misTareas) {
        final miId = _miIdDemo;
        tareas = tareas.where((t) => t.miembroIds.contains(miId)).toList();
      }
      if (_soloPendientes) {
        tareas = tareas
            .where((t) => t.estatus != TareaEstatus.terminado)
            .toList();
      }
      if (_fechaDesde != null) {
        tareas = tareas
            .where(
              (t) =>
                  t.fechaVencimiento == null ||
                  !t.fechaVencimiento!.isBefore(_fechaDesde!),
            )
            .toList();
      }
      if (_fechaHasta != null) {
        tareas = tareas
            .where(
              (t) =>
                  t.fechaVencimiento == null ||
                  !t.fechaVencimiento!.isAfter(_fechaHasta!),
            )
            .toList();
      }
      if (!mounted) return;
      setState(() => _tareas = tareas);
    } catch (ex) {
      if (mounted) _toast('Error al cargar: $ex', ok: false);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _cargar);
  }

  void _toast(String msg, {bool ok = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(color: Colors.white)),
        backgroundColor: ok ? KanbanColors.ok : KanbanColors.danger,
      ),
    );
  }

  void _toastAccion(String msg, String etiquetaAccion, VoidCallback onAccion) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(color: Colors.white)),
        backgroundColor: KanbanColors.ok,
        action: SnackBarAction(
          label: etiquetaAccion,
          textColor: Colors.white,
          onPressed: onAccion,
        ),
      ),
    );
  }

  Future<void> _abrirNuevaTarea() async {
    final id = await NuevaTareaDialog.show(
      context,
      repository: _repo,
      columnas: _columnasVisibles,
      miembros: _miembros,
    );
    if (id != null) {
      await _cargar();
      _toast('Tarea #$id creada');
    }
  }

  Future<void> _abrirPlantillas() async {
    final elegida = await PlantillasDialog.show(context, repository: _repo);
    if (elegida == null || !mounted) return;
    final id = await NuevaTareaDialog.show(
      context,
      repository: _repo,
      columnas: _columnasVisibles,
      miembros: _miembros,
      plantilla: elegida,
    );
    if (id != null) {
      await _cargar();
      _toast('Tarea #$id creada');
    }
  }

  Future<void> _abrirDetalle(Tarea t) async {
    await TareaDetailDialog.show(
      context,
      repository: _repo,
      tareaId: t.id,
      onRefresh: _cargar,
    );
    await _cargar();
  }

  Future<void> _moverTarea(
    Tarea t,
    TareaEstatus nuevoEstatus,
    int posicion,
  ) async {
    final origen = t.estatus;
    setState(() {
      final destinoActual =
          _tareas
              .where((x) => x.id != t.id && x.estatus == nuevoEstatus)
              .toList()
            ..sort((a, b) => a.orden.compareTo(b.orden));
      final pos = posicion.clamp(0, destinoActual.length);
      destinoActual.insert(pos, t.copyWith(estatus: nuevoEstatus));
      for (var i = 0; i < destinoActual.length; i++) {
        final idx = _tareas.indexWhere((x) => x.id == destinoActual[i].id);
        _tareas[idx] = _tareas[idx].copyWith(
          estatus: nuevoEstatus,
          orden: i,
        );
      }
      if (origen != nuevoEstatus) {
        final origenActual = _tareas.where((x) => x.estatus == origen).toList()
          ..sort((a, b) => a.orden.compareTo(b.orden));
        for (var i = 0; i < origenActual.length; i++) {
          final idx = _tareas.indexWhere((x) => x.id == origenActual[i].id);
          _tareas[idx] = _tareas[idx].copyWith(orden: i);
        }
      }
      _tareas.sort((a, b) => a.orden.compareTo(b.orden));
    });
    try {
      await _repo.moverTarea(t.id, nuevoEstatus, posicion: posicion);
    } catch (ex) {
      _toast('Error al mover tarea: $ex', ok: false);
      await _cargar();
    }
  }

  Future<void> _crearTarjetaRapida(TareaEstatus estatus, String titulo) async {
    try {
      await _repo.crearTarea(
        Tarea(
          id: 0,
          titulo: titulo,
          estatus: estatus,
          asignadoPor: kUsuarioActualDemo,
          fechaInicio: DateTime.now(),
        ),
      );
      await _cargar();
    } catch (ex) {
      _toast('Error al crear tarjeta: $ex', ok: false);
    }
  }

  Future<void> _archivarTarjeta(Tarea t) async {
    try {
      await _repo.archivarTarea(t.id, true);
      await _cargar();
      _toastAccion(
        'Tarjeta archivada',
        'Deshacer',
        () async {
          await _repo.archivarTarea(t.id, false);
          await _cargar();
        },
      );
    } catch (ex) {
      _toast('Error: $ex', ok: false);
    }
  }

  Future<void> _eliminarTarjeta(Tarea t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar tarjeta'),
        content: Text('¿Eliminar "${t.titulo}"? Esta acción no se puede deshacer.'),
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
    if (ok != true) return;
    try {
      await _repo.eliminarTarea(t.id);
      await _cargar();
      _toastAccion(
        'Tarjeta eliminada',
        'Deshacer',
        () async {
          // Recreación ligera: nueva id, no restaura enlaces de otras
          // tareas que dependían de esta (el repositorio ya los limpió).
          await _repo.crearTarea(t.copyWith());
          await _cargar();
        },
      );
    } catch (ex) {
      _toast('Error: $ex', ok: false);
    }
  }

  Future<void> _renombrarColumna(TareaEstatus estatus, String nuevoTitulo) async {
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
    nuevasVisibles.insert(
      posicion.clamp(0, nuevasVisibles.length),
      movida,
    );
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

  Future<void> _abrirListasArchivadas() async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Listas archivadas'),
        content: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final c in _columnas.where((c) => c.archivada))
                ListTile(
                  dense: true,
                  title: Text(c.titulo),
                  trailing: TextButton(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      _archivarColumna(c.estatus, false);
                    },
                    child: const Text('Desarchivar'),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  bool get _filtrosActivos =>
      _fechaDesde != null || _fechaHasta != null || !_soloPendientes;

  Future<void> _abrirFiltros() async {
    var desde = _fechaDesde;
    var hasta = _fechaHasta;
    var pendientes = _soloPendientes;

    Future<void> elegirFecha(
      StateSetter setDialogState, {
      required bool esInicio,
    }) async {
      final fecha = await showDatePicker(
        context: context,
        initialDate: (esInicio ? desde : hasta) ?? DateTime.now(),
        firstDate: DateTime.now().subtract(const Duration(days: 365)),
        lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      );
      if (fecha == null) return;
      setDialogState(() => esInicio ? desde = fecha : hasta = fecha);
    }

    String fmt(DateTime d) =>
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: const Text('Filtros'),
            content: SizedBox(
              width: 340,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              elegirFecha(setDialogState, esInicio: true),
                          icon: const Icon(
                            Icons.calendar_today_rounded,
                            size: 14,
                          ),
                          label: Text(
                            desde == null ? 'Desde' : fmt(desde!),
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              elegirFecha(setDialogState, esInicio: false),
                          icon: const Icon(
                            Icons.calendar_today_rounded,
                            size: 14,
                          ),
                          label: Text(
                            hasta == null ? 'Hasta' : fmt(hasta!),
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: pendientes,
                    onChanged: (v) =>
                        setDialogState(() => pendientes = v ?? true),
                    title: const Text(
                      'Solo pendientes',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => setDialogState(() {
                  desde = null;
                  hasta = null;
                  pendientes = true;
                }),
                child: const Text('Limpiar'),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _fechaDesde = desde;
                    _fechaHasta = hasta;
                    _soloPendientes = pendientes;
                  });
                  Navigator.of(ctx).pop();
                  _cargar();
                },
                child: const Text('Aplicar'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _headerIconButton({
    required IconData icon,
    required String tooltip,
    VoidCallback? onTap,
    bool active = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          borderRadius: BorderRadius.circular(9),
          onTap: onTap,
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: active ? KanbanColors.accentLight : Colors.transparent,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(
                color: active ? KanbanColors.accent : KanbanColors.borde,
              ),
            ),
            alignment: Alignment.center,
            child: Icon(
              icon,
              size: 18,
              color: active ? KanbanColors.accentDark : KanbanColors.texto,
            ),
          ),
        ),
      ),
    );
  }

  Widget _headerToggleChip({
    required IconData icon,
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: active ? KanbanColors.accentLight : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: active ? KanbanColors.accent : KanbanColors.borde,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 15,
                color: active ? KanbanColors.accentDark : KanbanColors.texto,
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: active
                      ? KanbanColors.accentDark
                      : KanbanColors.texto,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() {
    final archivadas = _columnas.where((c) => c.archivada).length;
    return Container(
      decoration: BoxDecoration(
        color: KanbanColors.bg2,
        border: Border(bottom: BorderSide(color: KanbanColors.borde)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          IconButton(
            padding: EdgeInsets.zero,
            tooltip: 'Regresar al menú',
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: KanbanColors.accent,
              size: 16,
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 8),
          Text(
            'Kanban PM',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.2,
              color: KanbanColors.texto,
            ),
          ),
          const SizedBox(width: 24),
          SegmentedButton<_Vista>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: _Vista.kanban,
                icon: Icon(Icons.view_column_rounded, size: 15),
                label: Text('Kanban'),
              ),
              ButtonSegment(
                value: _Vista.graficas,
                icon: Icon(Icons.pie_chart_rounded, size: 15),
                label: Text('Gráficas'),
              ),
              ButtonSegment(
                value: _Vista.gantt,
                icon: Icon(Icons.view_timeline_rounded, size: 15),
                label: Text('Gantt'),
              ),
            ],
            selected: {_vista},
            onSelectionChanged: (s) => setState(() => _vista = s.first),
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
              textStyle: WidgetStateProperty.all(
                const TextStyle(fontSize: 12),
              ),
            ),
          ),
          if (archivadas > 0)
            Padding(
              padding: const EdgeInsets.only(left: 10),
              child: TextButton.icon(
                onPressed: _abrirListasArchivadas,
                icon: const Icon(Icons.archive_outlined, size: 14),
                label: Text(
                  '$archivadas ${archivadas == 1 ? 'lista archivada' : 'listas archivadas'}',
                  style: const TextStyle(fontSize: 11.5),
                ),
              ),
            ),
          const Spacer(),
          SizedBox(
            width: 240,
            child: TextField(
              controller: _searchCtrl,
              onChanged: _onSearchChanged,
              style: TextStyle(fontSize: 13, color: KanbanColors.texto),
              decoration: InputDecoration(
                isDense: true,
                prefixIcon: const Icon(Icons.search_rounded, size: 17),
                hintText: 'Buscar…',
                hintStyle: TextStyle(
                  color: KanbanColors.tdim,
                  fontSize: 12.5,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(9),
                  borderSide: BorderSide(color: KanbanColors.borde),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(9),
                  borderSide: BorderSide(color: KanbanColors.borde),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(9),
                  borderSide: BorderSide(
                    color: KanbanColors.accent,
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),
          _headerIconButton(
            icon: Icons.tune_rounded,
            tooltip: 'Filtros',
            active: _filtrosActivos,
            onTap: _abrirFiltros,
          ),
          _headerToggleChip(
            icon: Icons.person_rounded,
            label: 'Mis tareas',
            active: _misTareas,
            onTap: () {
              setState(() => _misTareas = !_misTareas);
              _cargar();
            },
          ),
          _headerIconButton(
            icon: KanbanColors.oscuro
                ? Icons.light_mode_rounded
                : Icons.dark_mode_rounded,
            tooltip: KanbanColors.oscuro ? 'Modo claro' : 'Modo oscuro',
            active: KanbanColors.oscuro,
            onTap: () => setState(
              () => KanbanColors.establecerOscuro(!KanbanColors.oscuro),
            ),
          ),
          if (!KanbanColors.oscuro)
            _headerIconButton(
              icon: Icons.palette_outlined,
              tooltip: 'Cambiar fondo del tablero',
              onTap: () => setState(
                () => _fondoIdx = (_fondoIdx + 1) % kFondosTablero.length,
              ),
            ),
          _headerIconButton(
            icon: Icons.dashboard_customize_outlined,
            tooltip: 'Plantillas de tarjeta',
            onTap: _abrirPlantillas,
          ),
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: ElevatedButton.icon(
              onPressed: _abrirNuevaTarea,
              icon: const Icon(Icons.add_rounded, size: 17),
              label: const Text('Nueva tarea', style: TextStyle(fontSize: 13)),
              style: ElevatedButton.styleFrom(
                elevation: 0,
                backgroundColor: KanbanColors.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 11,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tablero(BuildContext context) {
    final visibles = _columnasVisibles;
    return Listener(
      onPointerUp: (_) => _detenerAutoscrollHorizontal(),
      child: Padding(
        key: _boardKey,
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          controller: _boardHCtrl,
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < visibles.length; i++) ...[
                _columnaGap(i),
                SizedBox(
                  height: MediaQuery.of(context).size.height - 230,
                  child: KanbanColumnView(
                    columna: visibles[i],
                    tareas: _tareas
                        .where((t) => t.estatus == visibles[i].estatus)
                        .toList(),
                    etiquetasPorId: _etiquetasPorId,
                    miembrosPorId: _miembrosPorId,
                    onTapTarea: _abrirDetalle,
                    onReordenar: _moverTarea,
                    onRenombrar: (nuevo) =>
                        _renombrarColumna(visibles[i].estatus, nuevo),
                    onArchivarColumna: () =>
                        _archivarColumna(visibles[i].estatus, true),
                    onMoverIzquierda: i > 0
                        ? () => _moverColumna(visibles[i].estatus, -1)
                        : null,
                    onMoverDerecha: i < visibles.length - 1
                        ? () => _moverColumna(visibles[i].estatus, 1)
                        : null,
                    onCrearRapida: (titulo) =>
                        _crearTarjetaRapida(visibles[i].estatus, titulo),
                    onArchivarTarjeta: _archivarTarjeta,
                    onEliminarTarjeta: _eliminarTarjeta,
                    onArrastreGlobalHorizontal: _manejarAutoscrollHorizontal,
                  ),
                ),
              ],
              _columnaGap(visibles.length),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KanbanColors.oscuro
          ? KanbanColors.bg
          : kFondosTablero[_fondoIdx],
      body: Column(
        children: [
          _header(),
          Expanded(
            child: _cargando
                ? const Center(child: CircularProgressIndicator())
                : switch (_vista) {
                    _Vista.graficas => KanbanGraficasView(
                      tareas: _tareas,
                      columnas: _columnasVisibles,
                    ),
                    _Vista.gantt => KanbanGanttView(
                      tareas: _tareas,
                      columnas: _columnasVisibles,
                      repository: _repo,
                      onRefresh: _cargar,
                      onAbrirTarea: _abrirDetalle,
                    ),
                    _Vista.kanban => _tablero(context),
                  },
          ),
        ],
      ),
    );
  }
}
