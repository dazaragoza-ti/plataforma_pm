import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../../kanban_constants.dart';
import '../../data/kanban_repository.dart';
import '../../domain/entities/actividad.dart';
import '../../domain/entities/miembro.dart';
import '../../domain/entities/tarea.dart';
import '../../domain/entities/tarea_etiqueta.dart';
import '../widgets/etiquetas_dialog.dart';
import '../widgets/kanban_column.dart';
import '../widgets/kanban_gantt/kanban_gantt_view.dart';
import '../widgets/kanban_graficas_view.dart';
import '../widgets/kanban_lista_view.dart';
import '../widgets/nueva_tarea_dialog.dart';
import '../widgets/plantillas_dialog.dart';
import '../widgets/tarea_detail_dialog.dart';

enum _Vista { kanban, lista, graficas, gantt }

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

  /// Solo la carga inicial muestra el spinner de pantalla completa: los
  /// refrescos posteriores (mover una tarjeta, arrastrar una barra del
  /// Gantt, crear una tarea…) actualizan `_tareas` en el sitio sin
  /// desmontar la vista activa — desmontarla reseteaba el scroll/zoom del
  /// Gantt y se sentía como si la página completa se recargara.
  bool _primeraCarga = true;

  _Vista _vista = _Vista.kanban;
  bool _misTareas = false;
  bool _soloPendientes = true;
  DateTime? _fechaDesde;
  DateTime? _fechaHasta;
  int _fondoIdx = 0;

  /// Subtareas pendientes asignadas a mí (a cualquier profundidad, en
  /// cualquier tarea visible), para la campana de notificaciones del
  /// header — ver [_actualizarNotificaciones].
  List<({Tarea tarea, Actividad actividad})> _notificaciones = [];
  final Set<int> _actividadIdsVistos = {};

  /// `false` hasta la primera carga completa: evita que todo lo que ya
  /// estaba asignado desde el arranque se muestre como "nuevo" con un
  /// toast por cada tarjeta.
  bool _notificacionesListas = false;

  List<KanbanColumna> get _columnasVisibles =>
      _columnas.where((c) => !c.archivada).toList();

  Map<int, TareaEtiqueta> get _etiquetasPorId => {
    for (final e in _etiquetas) e.id: e,
  };

  Map<int, Miembro> get _miembrosPorId => {for (final m in _miembros) m.id: m};

  /// Id del miembro "yo" (usuario de la demo) resuelto una sola vez contra
  /// el catálogo, con `-1` de respaldo seguro si no hay match.
  int get _miIdDemo => _miembros
      .firstWhere(
        (m) => m.nombre == kUsuarioActualDemo,
        orElse: () =>
            const Miembro(id: -1, nombre: '', colorAvatar: Colors.transparent),
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
    if (_primeraCarga) setState(() => _cargando = true);
    try {
      var tareas = await _repo.listarTareas(busqueda: _searchCtrl.text);
      final columnasArchivadas = _columnas
          .where((c) => c.archivada)
          .map((c) => c.estatus)
          .toSet();
      tareas = tareas
          .where((t) => !t.archivada && !columnasArchivadas.contains(t.estatus))
          .toList();
      // Antes de aplicar "Mis tareas"/"Solo pendientes"/fechas (que son
      // filtros de lo que se *muestra*): la campana de notificaciones debe
      // reflejar todas las subtareas asignadas a mí, no solo las que caben
      // en el filtro de vista actual.
      final baseParaNotificaciones = tareas;
      if (_misTareas) {
        final miId = _miIdDemo;
        tareas = tareas
            .where(
              (t) =>
                  t.miembroIds.contains(miId) ||
                  _tengoSubtareaPendiente(t.actividades, miId),
            )
            .toList();
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
      final nuevasNotificaciones = _actualizarNotificaciones(
        baseParaNotificaciones,
      );
      setState(() => _tareas = tareas);
      if (nuevasNotificaciones.isNotEmpty) {
        _avisarNuevasAsignaciones(nuevasNotificaciones);
      }
    } catch (ex) {
      if (mounted) _toast('Error al cargar: $ex', ok: false);
    } finally {
      if (mounted) {
        setState(() {
          _cargando = false;
          _primeraCarga = false;
        });
      }
    }
  }

  /// Recalcula qué subtareas siguen asignadas a mí y pendientes, a partir
  /// de [tareas] (ya filtradas de archivadas, pero antes de "Mis
  /// tareas"/"Solo pendientes"/fechas). Devuelve las que son nuevas desde
  /// la última carga (vacío en la primera carga, para no bombardear con
  /// toasts todo lo que ya estaba asignado desde el arranque).
  List<({Tarea tarea, Actividad actividad})> _actualizarNotificaciones(
    List<Tarea> tareas,
  ) {
    final miId = _miIdDemo;
    final actuales = miId == -1
        ? const <({Tarea tarea, Actividad actividad})>[]
        : _subtareasAsignadasA(tareas, miId);
    final nuevas = _notificacionesListas
        ? actuales
              .where((n) => !_actividadIdsVistos.contains(n.actividad.id))
              .toList()
        : const <({Tarea tarea, Actividad actividad})>[];
    _notificaciones = actuales;
    _actividadIdsVistos
      ..clear()
      ..addAll(actuales.map((n) => n.actividad.id));
    _notificacionesListas = true;
    return nuevas;
  }

  void _avisarNuevasAsignaciones(
    List<({Tarea tarea, Actividad actividad})> nuevas,
  ) {
    if (nuevas.length == 1) {
      final n = nuevas.first;
      _toastAccion(
        'Te asignaron la subtarea "${n.actividad.descripcion}" '
            'en "${n.tarea.titulo}"',
        'Ver',
        () => _abrirDetalle(n.tarea),
      );
    } else {
      _toastAccion(
        'Te asignaron ${nuevas.length} subtareas nuevas',
        'Ver',
        _abrirNotificaciones,
      );
    }
  }

  Future<void> _abrirNotificaciones() async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: KanbanColors.bg2,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Subtareas asignadas a mí',
          style: TextStyle(color: KanbanColors.texto),
        ),
        content: SizedBox(
          width: 360,
          child: _notificaciones.isEmpty
              ? Text(
                  'No tienes subtareas pendientes.',
                  style: TextStyle(color: KanbanColors.tdim),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final n in _notificaciones)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          Icons.assignment_ind_outlined,
                          size: 18,
                          color: KanbanColors.accent,
                        ),
                        title: Text(
                          n.actividad.descripcion,
                          style: TextStyle(
                            fontSize: 13,
                            color: KanbanColors.texto,
                          ),
                        ),
                        subtitle: Text(
                          'en "${n.tarea.titulo}"',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: KanbanColors.tdim,
                          ),
                        ),
                        onTap: () {
                          Navigator.of(ctx).pop();
                          _abrirDetalle(n.tarea);
                        },
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

  Future<void> _cambiarLimiteWip(TareaEstatus estatus, int? limite) async {
    setState(() {
      final idx = _columnas.indexWhere((c) => c.estatus == estatus);
      if (idx != -1) {
        _columnas[idx] = _columnas[idx].copyWith(
          limiteWip: limite,
          limpiarLimiteWip: limite == null,
        );
      }
    });
    await _repo.actualizarLimiteWipColumna(estatus, limite);
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

  Future<void> _abrirEtiquetas() async {
    await EtiquetasDialog.show(context, repository: _repo);
    await _cargar();
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
        _tareas[idx] = _tareas[idx].copyWith(estatus: nuevoEstatus, orden: i);
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
      _toastAccion('Tarjeta archivada', 'Deshacer', () async {
        await _repo.archivarTarea(t.id, false);
        await _cargar();
      });
    } catch (ex) {
      _toast('Error: $ex', ok: false);
    }
  }

  Future<void> _eliminarTarjeta(Tarea t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: KanbanColors.bg2,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Eliminar tarjeta',
          style: TextStyle(color: KanbanColors.texto),
        ),
        content: Text(
          '¿Eliminar "${t.titulo}"? Esta acción no se puede deshacer.',
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
    if (ok != true) return;
    try {
      await _repo.eliminarTarea(t.id);
      await _cargar();
      _toastAccion('Tarjeta eliminada', 'Deshacer', () async {
        // Recreación ligera: nueva id, no restaura enlaces de otras
        // tareas que dependían de esta (el repositorio ya los limpió).
        await _repo.crearTarea(t.copyWith());
        await _cargar();
      });
    } catch (ex) {
      _toast('Error: $ex', ok: false);
    }
  }

  /// Mueve, archiva o elimina varias tarjetas a la vez — usado por la
  /// barra de selección de la vista Lista. Recorre los ids uno por uno
  /// (el repositorio en memoria no tiene una operación de lote nativa) y
  /// recién al final refresca una sola vez, para no repintar el tablero
  /// entre cada tarjeta.
  Future<void> _moverTareasEnLote(
    List<int> ids,
    TareaEstatus nuevoEstatus,
  ) async {
    try {
      for (final id in ids) {
        await _repo.moverTarea(id, nuevoEstatus);
      }
      await _cargar();
      _toast(
        '${ids.length} ${ids.length == 1 ? 'tarjeta movida' : 'tarjetas movidas'}',
      );
    } catch (ex) {
      _toast('Error: $ex', ok: false);
    }
  }

  Future<void> _archivarTareasEnLote(List<int> ids) async {
    try {
      for (final id in ids) {
        await _repo.archivarTarea(id, true);
      }
      await _cargar();
      _toastAccion(
        '${ids.length} ${ids.length == 1 ? 'tarjeta archivada' : 'tarjetas archivadas'}',
        'Deshacer',
        () async {
          for (final id in ids) {
            await _repo.archivarTarea(id, false);
          }
          await _cargar();
        },
      );
    } catch (ex) {
      _toast('Error: $ex', ok: false);
    }
  }

  Future<void> _eliminarTareasEnLote(List<int> ids) async {
    try {
      final respaldo = _tareas.where((t) => ids.contains(t.id)).toList();
      for (final id in ids) {
        await _repo.eliminarTarea(id);
      }
      await _cargar();
      _toastAccion(
        '${ids.length} ${ids.length == 1 ? 'tarjeta eliminada' : 'tarjetas eliminadas'}',
        'Deshacer',
        () async {
          for (final t in respaldo) {
            await _repo.crearTarea(t.copyWith());
          }
          await _cargar();
        },
      );
    } catch (ex) {
      _toast('Error: $ex', ok: false);
    }
  }

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

  Future<void> _abrirListasArchivadas() async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: KanbanColors.bg2,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Listas archivadas',
          style: TextStyle(color: KanbanColors.texto),
        ),
        content: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final c in _columnas.where((c) => c.archivada))
                ListTile(
                  dense: true,
                  title: Text(
                    c.titulo,
                    style: TextStyle(color: KanbanColors.texto),
                  ),
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
            backgroundColor: KanbanColors.bg2,
            surfaceTintColor: Colors.transparent,
            title: Text('Filtros', style: TextStyle(color: KanbanColors.texto)),
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
                    title: Text(
                      'Solo pendientes',
                      style: TextStyle(fontSize: 13, color: KanbanColors.texto),
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
    return Tooltip(
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
    );
  }

  Widget _botonNotificaciones() {
    final n = _notificaciones.length;
    return Badge(
      label: Text('$n'),
      isLabelVisible: n > 0,
      backgroundColor: KanbanColors.danger,
      child: _headerIconButton(
        icon: Icons.notifications_outlined,
        tooltip: n == 0
            ? 'Sin subtareas pendientes asignadas a mí'
            : '$n ${n == 1 ? 'subtarea asignada a mí' : 'subtareas asignadas a mí'}',
        onTap: _abrirNotificaciones,
      ),
    );
  }

  Widget _headerToggleChip({
    required IconData icon,
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return InkWell(
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
                color: active ? KanbanColors.accentDark : KanbanColors.texto,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Grupo izquierdo del header: regresar (no-web), título y selector de
  /// vista. Envuelto en un [Wrap] (no un [Row] rígido) para que, si no
  /// alcanza el ancho, salte de línea en vez de desbordarse — el caso que
  /// importa en pantallas angostas (móvil, ventana redimensionada).
  Widget _headerGrupoIzquierdo() {
    final archivadas = _columnas.where((c) => c.archivada).length;
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 10,
      runSpacing: 8,
      children: [
        // El botón de regresar solo tiene sentido en desktop/móvil: en web
        // el usuario navega con el propio historial del navegador, así que
        // aquí estorbaría más de lo que ayuda.
        if (!kIsWeb)
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
        Text(
          'Kanban PM',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
            color: KanbanColors.texto,
          ),
        ),
        SegmentedButton<_Vista>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(
              value: _Vista.kanban,
              icon: Icon(Icons.view_column_rounded, size: 15),
              label: Text('Kanban'),
            ),
            ButtonSegment(
              value: _Vista.lista,
              icon: Icon(Icons.view_list_rounded, size: 15),
              label: Text('Lista'),
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
          style: KanbanColors.segmentedButtonStyle().copyWith(
            textStyle: WidgetStateProperty.all(const TextStyle(fontSize: 12)),
          ),
        ),
        if (archivadas > 0)
          TextButton.icon(
            onPressed: _abrirListasArchivadas,
            icon: const Icon(Icons.archive_outlined, size: 14),
            label: Text(
              '$archivadas ${archivadas == 1 ? 'lista archivada' : 'listas archivadas'}',
              style: const TextStyle(fontSize: 11.5),
            ),
          ),
      ],
    );
  }

  /// Grupo derecho del header: buscador, filtros y acciones. También un
  /// [Wrap] (alineado a la derecha cuando hay espacio de sobra) por la
  /// misma razón que el grupo izquierdo.
  Widget _headerGrupoDerecho() {
    return Wrap(
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 10,
      runSpacing: 8,
      children: [
        SizedBox(
          width: 240,
          child: TextField(
            controller: _searchCtrl,
            onChanged: _onSearchChanged,
            style: TextStyle(fontSize: 13, color: KanbanColors.texto),
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: KanbanColors.bg3,
              prefixIcon: Icon(
                Icons.search_rounded,
                size: 17,
                color: KanbanColors.tdim,
              ),
              hintText: 'Buscar…',
              hintStyle: TextStyle(color: KanbanColors.tdim, fontSize: 12.5),
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
                borderSide: BorderSide(color: KanbanColors.accent, width: 1.5),
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
        _botonNotificaciones(),
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
          icon: Icons.label_outline_rounded,
          tooltip: 'Etiquetas del tablero',
          onTap: _abrirEtiquetas,
        ),
        _headerIconButton(
          icon: Icons.dashboard_customize_outlined,
          tooltip: 'Plantillas de tarjeta',
          onTap: _abrirPlantillas,
        ),
        ElevatedButton.icon(
          onPressed: _abrirNuevaTarea,
          icon: const Icon(Icons.add_rounded, size: 17),
          label: const Text('Nueva tarea', style: TextStyle(fontSize: 13)),
          style: ElevatedButton.styleFrom(
            elevation: 0,
            backgroundColor: KanbanColors.accent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(9),
            ),
          ),
        ),
      ],
    );
  }

  Widget _header() {
    return Container(
      decoration: BoxDecoration(
        color: KanbanColors.bg2,
        border: Border(bottom: BorderSide(color: KanbanColors.borde)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      // Row de dos `Flexible` (no dos `Expanded` de ancho fijo): cada grupo
      // ocupa solo lo que necesita y el `Wrap` interno absorbe el resto —
      // así en pantallas anchas el grupo derecho queda pegado a la
      // izquierda del izquierdo (visual "empujado a la derecha"), y en
      // angostas ambos grupos pueden partirse en líneas propias sin que el
      // Row completo se desborde.
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Flexible(child: _headerGrupoIzquierdo()),
          const SizedBox(width: 10),
          Flexible(child: _headerGrupoDerecho()),
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
        // `LayoutBuilder` en vez de `MediaQuery.size.height - <número mágico>`:
        // ese número mágico asumía una altura de header fija, que dejó de
        // ser cierta en cuanto el header pasó a envolver en varias líneas
        // en pantallas angostas. Aquí se toma el alto real ya disponible.
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              controller: _boardHCtrl,
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < visibles.length; i++) ...[
                    _columnaGap(i),
                    SizedBox(
                      height: constraints.maxHeight,
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
                        onArrastreGlobalHorizontal:
                            _manejarAutoscrollHorizontal,
                        onCambiarLimiteWip: (limite) =>
                            _cambiarLimiteWip(visibles[i].estatus, limite),
                      ),
                    ),
                  ],
                  _columnaGap(visibles.length),
                ],
              ),
            );
          },
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
                    _Vista.lista => KanbanListaView(
                      tareas: _tareas,
                      columnas: _columnasVisibles,
                      miembrosPorId: _miembrosPorId,
                      etiquetasPorId: _etiquetasPorId,
                      onAbrirTarea: _abrirDetalle,
                      onMoverSeleccion: _moverTareasEnLote,
                      onArchivarSeleccion: _archivarTareasEnLote,
                      onEliminarSeleccion: _eliminarTareasEnLote,
                    ),
                    _Vista.graficas => KanbanGraficasView(
                      tareas: _tareas,
                      columnas: _columnasVisibles,
                      miembros: _miembros,
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

/// `true` si alguna actividad del árbol (a cualquier profundidad) tiene a
/// [miembroId] como responsable y sigue sin marcarse terminada — usado
/// para que "Mis tareas" también muestre tarjetas que no son mías pero
/// donde tengo una subtarea delegada pendiente.
bool _tengoSubtareaPendiente(List<Actividad> actividades, int miembroId) {
  for (final a in actividades) {
    if (a.miembroId == miembroId && !a.terminada) return true;
    if (_tengoSubtareaPendiente(a.subActividades, miembroId)) return true;
  }
  return false;
}

/// Recolecta, con su tarea dueña, cada subtarea (a cualquier profundidad)
/// asignada a [miembroId] que siga sin marcarse terminada — la fuente de
/// datos de la campana de notificaciones del header.
List<({Tarea tarea, Actividad actividad})> _subtareasAsignadasA(
  List<Tarea> tareas,
  int miembroId,
) {
  final resultado = <({Tarea tarea, Actividad actividad})>[];
  void recorrer(Tarea t, List<Actividad> lista) {
    for (final a in lista) {
      if (a.miembroId == miembroId && !a.terminada) {
        resultado.add((tarea: t, actividad: a));
      }
      recorrer(t, a.subActividades);
    }
  }

  for (final t in tareas) {
    recorrer(t, t.actividades);
  }
  return resultado;
}
