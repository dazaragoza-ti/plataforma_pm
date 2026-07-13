import 'dart:async';
import 'package:flutter/material.dart';
import '../../kanban_constants.dart';
import '../../data/kanban_repository.dart';
import '../../domain/entities/tarea.dart';
import '../widgets/kanban_column.dart';
import '../widgets/kanban_graficas_view.dart';
import '../widgets/nueva_tarea_dialog.dart';
import '../widgets/tarea_detail_dialog.dart';

/// Tablero Kanban: barra de herramientas (buscador, vistas, filtros) y
/// columnas TAREAS / PROCESO / PAUSA / TERMINADO / REVISADO, replicando el
/// diseño del tablero de referencia.
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
  Timer? _debounce;
  List<Tarea> _tareas = [];
  bool _cargando = true;

  bool _mostrarFiltros = true;
  bool _vistaGraficas = false;
  bool _misTareas = false;
  bool _soloPendientes = true;
  DateTime? _fechaDesde;
  DateTime? _fechaHasta;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      var tareas = await _repo.listarTareas(busqueda: _searchCtrl.text);
      if (_misTareas) {
        tareas = tareas
            .where((t) => t.responsable == kUsuarioActualDemo)
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

  void _limpiarFiltros() {
    _searchCtrl.clear();
    setState(() {
      _misTareas = false;
      _soloPendientes = true;
      _fechaDesde = null;
      _fechaHasta = null;
    });
    _cargar();
  }

  void _toast(String msg, {bool ok = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(color: Colors.white)),
        backgroundColor: ok ? KanbanColors.ok : KanbanColors.danger,
      ),
    );
  }

  Future<void> _abrirNuevaTarea() async {
    final id = await NuevaTareaDialog.show(context, repository: _repo);
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

  Future<void> _moverTarea(Tarea t, TareaEstatus nuevoEstatus) async {
    setState(() {
      final idx = _tareas.indexWhere((x) => x.id == t.id);
      if (idx != -1) {
        _tareas[idx] = _tareas[idx].copyWith(estatus: nuevoEstatus);
      }
    });
    try {
      await _repo.moverTarea(t.id, nuevoEstatus);
    } catch (ex) {
      _toast('Error al mover tarea: $ex', ok: false);
      await _cargar();
    }
  }

  Future<void> _elegirFecha({required bool esInicio}) async {
    final fecha = await showDatePicker(
      context: context,
      initialDate: (esInicio ? _fechaDesde : _fechaHasta) ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (fecha == null) return;
    setState(() => esInicio ? _fechaDesde = fecha : _fechaHasta = fecha);
    _cargar();
  }

  Widget _pillButton(
    String label, {
    required IconData icon,
    bool active = false,
    VoidCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(
          icon,
          size: 14,
          color: active ? Colors.white : KanbanColors.texto,
        ),
        label: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: active ? Colors.white : KanbanColors.texto,
          ),
        ),
        style: OutlinedButton.styleFrom(
          backgroundColor: active ? KanbanColors.toolbarTeal : Colors.white,
          side: BorderSide(
            color: active ? KanbanColors.toolbarTeal : KanbanColors.borde,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
      ),
    );
  }

  Widget _iconSquareButton(
    IconData icon,
    Color color, {
    VoidCallback? onTap,
    String? tooltip,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Tooltip(
        message: tooltip ?? '',
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: onTap,
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(6),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 16, color: Colors.white),
          ),
        ),
      ),
    );
  }

  Widget _staticBox(String texto) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: KanbanColors.borde),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        texto,
        style: const TextStyle(fontSize: 11.5, color: KanbanColors.texto),
      ),
    );
  }

  Widget _dateBox(String label, DateTime? valor, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: const Icon(
          Icons.calendar_today_rounded,
          size: 13,
          color: KanbanColors.tdim,
        ),
        label: Text(
          valor == null
              ? label
              : '${valor.day.toString().padLeft(2, '0')}/${valor.month.toString().padLeft(2, '0')}/${valor.year}',
          style: const TextStyle(fontSize: 11.5, color: KanbanColors.texto),
        ),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: KanbanColors.borde),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
      ),
    );
  }

  Widget _toolbarFila1() {
    final semanaActual =
        ((DateTime.now()
                    .difference(DateTime(DateTime.now().year, 1, 1))
                    .inDays) /
                7)
            .ceil();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          _iconSquareButton(
            Icons.notifications_rounded,
            KanbanColors.toolbarRed,
            tooltip: 'Notificaciones',
          ),
          _iconSquareButton(
            _mostrarFiltros
                ? Icons.visibility_off_rounded
                : Icons.visibility_rounded,
            KanbanColors.toolbarTeal,
            tooltip: 'Mostrar/ocultar filtros',
            onTap: () => setState(() => _mostrarFiltros = !_mostrarFiltros),
          ),
          const SizedBox(width: 6),
          _pillButton(
            'KANBAN',
            icon: Icons.badge_rounded,
            active: !_vistaGraficas,
            onTap: () => setState(() => _vistaGraficas = false),
          ),
          _pillButton('CALENDARIO', icon: Icons.calendar_month_rounded),
          _pillButton('TAREAS', icon: Icons.reorder_rounded),
          _pillButton(
            'GRÁFICAS',
            icon: Icons.pie_chart_rounded,
            active: _vistaGraficas,
            onTap: () => setState(() => _vistaGraficas = true),
          ),
          _pillButton(
            'MIS TAREAS',
            icon: Icons.person_rounded,
            active: _misTareas,
            onTap: () {
              setState(() => _misTareas = !_misTareas);
              _cargar();
            },
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 220,
            child: TextField(
              controller: _searchCtrl,
              onChanged: _onSearchChanged,
              style: const TextStyle(fontSize: 12.5, color: KanbanColors.texto),
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Ingrese su búsqueda',
                hintStyle: const TextStyle(
                  color: KanbanColors.tdim,
                  fontSize: 12,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: KanbanColors.borde),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: KanbanColors.borde),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(
                    color: KanbanColors.toolbarTeal,
                    width: 2,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          ElevatedButton.icon(
            onPressed: _cargar,
            icon: const Icon(Icons.search, size: 14, color: Colors.white),
            label: const Text(
              'Aplicar filtros',
              style: TextStyle(fontSize: 11.5, color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: KanbanColors.toolbarDark,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
          const SizedBox(width: 6),
          _pillButton('ESTRUCTURA', icon: Icons.account_tree_rounded),
          _staticBox('TODOS'),
          _pillButton('GENERALES', icon: Icons.label_rounded),
          _pillButton('NIVEL', icon: Icons.label_rounded),
          _pillButton('IMPORTANCIA', icon: Icons.label_rounded),
          _staticBox('${DateTime.now().year}'),
          _staticBox('SEMANA'),
          _staticBox('$semanaActual'),
        ],
      ),
    );
  }

  Widget _toolbarFila2() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          _dateBox('Desde', _fechaDesde, () => _elegirFecha(esInicio: true)),
          _dateBox('Hasta', _fechaHasta, () => _elegirFecha(esInicio: false)),
          _iconSquareButton(
            Icons.view_headline_rounded,
            KanbanColors.toolbarTeal,
            tooltip: 'Vista',
          ),
          _iconSquareButton(
            Icons.login_rounded,
            KanbanColors.toolbarGreen,
            tooltip: 'Aplicar',
            onTap: _cargar,
          ),
          _iconSquareButton(
            Icons.close_rounded,
            KanbanColors.toolbarRed,
            tooltip: 'Limpiar filtros',
            onTap: _limpiarFiltros,
          ),
          const SizedBox(width: 6),
          InkWell(
            onTap: () {
              setState(() => _soloPendientes = !_soloPendientes);
              _cargar();
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Checkbox(
                  value: _soloPendientes,
                  activeColor: KanbanColors.toolbarTeal,
                  onChanged: (v) {
                    setState(() => _soloPendientes = v ?? true);
                    _cargar();
                  },
                ),
                const Text(
                  'Pendientes',
                  style: TextStyle(fontSize: 12.5, color: KanbanColors.texto),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _header() {
    return Container(
      decoration: BoxDecoration(
        color: KanbanColors.bg2,
        border: const Border(bottom: BorderSide(color: KanbanColors.borde)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                padding: EdgeInsets.zero,
                tooltip: 'Regresar al menú',
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: KanbanColors.accent,
                  size: 16,
                ),
                onPressed: () => Navigator.of(context).pop(),
              ),
              const SizedBox(width: 6),
              const Text(
                'Kanban PM',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: KanbanColors.texto,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _toolbarFila1(),
          if (_mostrarFiltros) ...[const SizedBox(height: 8), _toolbarFila2()],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KanbanColors.bg,
      body: Column(
        children: [
          _header(),
          Expanded(
            child: _cargando
                ? const Center(child: CircularProgressIndicator())
                : _vistaGraficas
                ? KanbanGraficasView(tareas: _tareas)
                : Padding(
                    padding: const EdgeInsets.all(16),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final col in kColumnas)
                            SizedBox(
                              height: MediaQuery.of(context).size.height - 230,
                              child: KanbanColumnView(
                                columna: col,
                                tareas: _tareas
                                    .where((t) => t.estatus == col.estatus)
                                    .toList(),
                                onTapTarea: _abrirDetalle,
                                onDropTarea: _moverTarea,
                                accionExtra: col.estatus == TareaEstatus.tareas
                                    ? SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton.icon(
                                          onPressed: _abrirNuevaTarea,
                                          icon: const Icon(
                                            Icons.add_rounded,
                                            size: 16,
                                            color: Colors.white,
                                          ),
                                          label: const Text(
                                            'NUEVA TAREA',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                KanbanColors.toolbarGreen,
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 10,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                          ),
                                        ),
                                      )
                                    : null,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
