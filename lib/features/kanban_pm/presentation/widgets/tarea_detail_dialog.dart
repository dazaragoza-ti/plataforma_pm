import 'package:flutter/material.dart';
import '../../kanban_constants.dart';
import '../../data/kanban_repository.dart';
import '../../domain/entities/miembro.dart';
import '../../domain/entities/tarea.dart';
import '../../domain/entities/tarea_etiqueta.dart';

/// Diálogo de detalle/edición de una tarea: datos generales, las 3
/// clasificaciones (Generales/Nivel/Importancia), checklist de actividades
/// y comentarios — replica el diseño del panel de detalle de referencia.
class TareaDetailDialog extends StatefulWidget {
  final KanbanRepository repository;
  final int tareaId;
  final VoidCallback onRefresh;

  const TareaDetailDialog({
    super.key,
    required this.repository,
    required this.tareaId,
    required this.onRefresh,
  });

  static Future<void> show(
    BuildContext context, {
    required KanbanRepository repository,
    required int tareaId,
    required VoidCallback onRefresh,
  }) {
    return showDialog(
      context: context,
      builder: (_) => TareaDetailDialog(
        repository: repository,
        tareaId: tareaId,
        onRefresh: onRefresh,
      ),
    );
  }

  @override
  State<TareaDetailDialog> createState() => _TareaDetailDialogState();
}

class _TareaDetailDialogState extends State<TareaDetailDialog> {
  Tarea? _tarea;
  final _tituloCtrl = TextEditingController();
  final _descripcionCtrl = TextEditingController();
  final _nuevaActividadCtrl = TextEditingController();
  final _comentarioCtrl = TextEditingController();
  final _nuevaEtiquetaCtrl = TextEditingController();
  final _nuevoMiembroCtrl = TextEditingController();

  String? _area;
  int _generalesIdx = 0;
  int _nivelIdx = 0;
  int _importanciaIdx = 0;
  DateTime? _fechaInicio;
  DateTime? _fechaFin;
  bool _ocultarCompletados = false;
  bool _creandoActividad = false;
  bool _guardando = false;

  List<Tarea> _todasTareas = [];
  List<TareaEtiqueta> _catalogoEtiquetas = [];
  Set<int> _etiquetaIdsSeleccionadas = {};
  List<Miembro> _catalogoMiembros = [];
  Set<int> _miembroIdsSeleccionados = {};
  Color? _portada;
  Set<int> _dependeDeSeleccionadas = {};
  bool _creandoEtiqueta = false;
  Color _colorNuevaEtiqueta = kColorPaletteEtiquetas.first;
  bool _creandoMiembro = false;
  Color _colorNuevoMiembro = kColorPaletteEtiquetas.first;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _tituloCtrl.dispose();
    _descripcionCtrl.dispose();
    _nuevaActividadCtrl.dispose();
    _comentarioCtrl.dispose();
    _nuevaEtiquetaCtrl.dispose();
    _nuevoMiembroCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    final results = await Future.wait([
      widget.repository.listarTareas(),
      widget.repository.listarEtiquetas(),
      widget.repository.listarMiembros(),
    ]);
    if (!mounted) return;
    final tareas = results[0] as List<Tarea>;
    final etiquetas = results[1] as List<TareaEtiqueta>;
    final miembros = results[2] as List<Miembro>;
    final t = tareas.firstWhere((x) => x.id == widget.tareaId);
    setState(() {
      _tarea = t;
      _todasTareas = tareas;
      _catalogoEtiquetas = etiquetas;
      _catalogoMiembros = miembros;
      _tituloCtrl.text = t.titulo;
      _descripcionCtrl.text = t.descripcion;
      _area = t.grupo.isEmpty ? null : t.grupo;
      _fechaInicio = t.fechaInicio;
      _fechaFin = t.fechaVencimiento;
      _portada = t.portada;
      _etiquetaIdsSeleccionadas = t.etiquetaIds.toSet();
      _miembroIdsSeleccionados = t.miembroIds.toSet();
      _dependeDeSeleccionadas = t.dependeDeIds.toSet();
      _generalesIdx = t.generales == null
          ? 0
          : kGeneralesDemo
                .indexWhere((c) => c.$1 == t.generales!.$1)
                .clamp(0, kGeneralesDemo.length - 1);
      _nivelIdx = t.nivel == null
          ? 0
          : kNivelDemo
                .indexWhere((c) => c.$1 == t.nivel!.$1)
                .clamp(0, kNivelDemo.length - 1);
      _importanciaIdx = t.importancia == null
          ? 0
          : kImportanciaDemo
                .indexWhere((c) => c.$1 == t.importancia!.$1)
                .clamp(0, kImportanciaDemo.length - 1);
    });
  }

  void _toggleEtiqueta(int id) {
    setState(() {
      if (!_etiquetaIdsSeleccionadas.add(id)) {
        _etiquetaIdsSeleccionadas.remove(id);
      }
    });
  }

  Future<void> _crearEtiqueta() async {
    final nombre = _nuevaEtiquetaCtrl.text.trim();
    if (nombre.isEmpty) return;
    final id = await widget.repository.crearEtiqueta(
      nombre,
      _colorNuevaEtiqueta,
    );
    _nuevaEtiquetaCtrl.clear();
    if (!mounted) return;
    setState(() {
      _creandoEtiqueta = false;
      _etiquetaIdsSeleccionadas.add(id);
    });
    await _cargar();
  }

  void _toggleMiembro(int id) {
    setState(() {
      if (!_miembroIdsSeleccionados.add(id)) {
        _miembroIdsSeleccionados.remove(id);
      }
    });
  }

  Future<void> _crearMiembro() async {
    final nombre = _nuevoMiembroCtrl.text.trim();
    if (nombre.isEmpty) return;
    final id = await widget.repository.crearMiembro(
      nombre,
      _colorNuevoMiembro,
    );
    _nuevoMiembroCtrl.clear();
    if (!mounted) return;
    setState(() {
      _creandoMiembro = false;
      _miembroIdsSeleccionados.add(id);
    });
    await _cargar();
  }

  /// `true` si dejar que la tarea actual dependa de [candidatoId] cerraría
  /// un ciclo (i.e. `candidatoId` ya depende — directa o transitivamente —
  /// de la tarea actual).
  bool _creariaCiclo(int candidatoId) {
    final visitados = <int>{};
    bool dfs(int actualId) {
      if (actualId == _tarea!.id) return true;
      if (!visitados.add(actualId)) return false;
      final idx = _todasTareas.indexWhere((x) => x.id == actualId);
      if (idx == -1) return false;
      for (final depId in _todasTareas[idx].dependeDeIds) {
        if (dfs(depId)) return true;
      }
      return false;
    }

    return dfs(candidatoId);
  }

  void _toggleDependencia(int id) {
    setState(() {
      if (!_dependeDeSeleccionadas.add(id)) {
        _dependeDeSeleccionadas.remove(id);
      }
    });
  }

  Future<void> _elegirFecha({required bool esInicio}) async {
    final fecha = await showDatePicker(
      context: context,
      initialDate: (esInicio ? _fechaInicio : _fechaFin) ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (fecha == null) return;
    setState(() => esInicio ? _fechaInicio = fecha : _fechaFin = fecha);
  }

  Future<void> _elegirHora() async {
    final actual = _fechaInicio ?? DateTime.now();
    final hora = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(actual),
    );
    if (hora == null) return;
    setState(() {
      final base = _fechaInicio ?? DateTime.now();
      _fechaInicio = DateTime(
        base.year,
        base.month,
        base.day,
        hora.hour,
        hora.minute,
      );
    });
  }

  Future<void> _iniciar() async {
    final t = _tarea!;
    final TareaEstatus nuevo;
    switch (t.estatus) {
      case TareaEstatus.tareas:
      case TareaEstatus.pausa:
        nuevo = TareaEstatus.proceso;
      case TareaEstatus.proceso:
        nuevo = TareaEstatus.pausa;
      case TareaEstatus.terminado:
      case TareaEstatus.revisado:
        nuevo = TareaEstatus.proceso;
    }
    await widget.repository.moverTarea(t.id, nuevo);
    widget.onRefresh();
    await _cargar();
  }

  String _labelBoton(TareaEstatus estatus) {
    switch (estatus) {
      case TareaEstatus.tareas:
        return 'Iniciar';
      case TareaEstatus.pausa:
        return 'Reanudar';
      case TareaEstatus.proceso:
        return 'Pausar';
      case TareaEstatus.terminado:
      case TareaEstatus.revisado:
        return 'Reabrir';
    }
  }

  Future<void> _guardar() async {
    setState(() => _guardando = true);
    try {
      await widget.repository.actualizarTarea(
        _tarea!.copyWith(
          titulo: _tituloCtrl.text.trim(),
          descripcion: _descripcionCtrl.text.trim(),
          grupo: _area ?? '',
          fechaInicio: _fechaInicio,
          fechaVencimiento: _fechaFin,
          generales: kGeneralesDemo[_generalesIdx],
          nivel: kNivelDemo[_nivelIdx],
          importancia: kImportanciaDemo[_importanciaIdx],
          etiquetaIds: _etiquetaIdsSeleccionadas.toList(),
          miembroIds: _miembroIdsSeleccionados.toList(),
          portada: _portada,
          limpiarPortada: _portada == null,
          dependeDeIds: _dependeDeSeleccionadas.toList(),
        ),
      );
      widget.onRefresh();
      if (mounted) Navigator.of(context).pop();
    } catch (ex) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $ex'),
            backgroundColor: KanbanColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _agregarActividad() async {
    final desc = _nuevaActividadCtrl.text.trim();
    if (desc.isEmpty) return;
    _nuevaActividadCtrl.clear();
    await widget.repository.agregarActividad(widget.tareaId, desc);
    widget.onRefresh();
    await _cargar();
  }

  Future<void> _toggleActividad(int actividadId) async {
    await widget.repository.toggleActividad(widget.tareaId, actividadId);
    widget.onRefresh();
    await _cargar();
  }

  Future<void> _eliminarActividad(int actividadId) async {
    await widget.repository.eliminarActividad(widget.tareaId, actividadId);
    widget.onRefresh();
    await _cargar();
  }

  Future<void> _agregarComentario() async {
    final texto = _comentarioCtrl.text.trim();
    if (texto.isEmpty) return;
    _comentarioCtrl.clear();
    await widget.repository.agregarComentario(widget.tareaId, 'Yo', texto);
    widget.onRefresh();
    await _cargar();
  }

  Future<void> _eliminarTarea() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar tarea'),
        content: Text(
          '¿Eliminar "${_tarea!.titulo}"? Esta acción no se puede deshacer.',
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
    if (ok == true) {
      await widget.repository.eliminarTarea(widget.tareaId);
      widget.onRefresh();
      if (mounted) Navigator.of(context).pop();
    }
  }

  String _fecha(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  String _hora(DateTime d) {
    final h12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final periodo = d.hour < 12 ? 'a. m.' : 'p. m.';
    return '${h12.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')} $periodo';
  }

  Widget _campoBox({required Widget child, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: KanbanColors.borde),
          borderRadius: BorderRadius.circular(9),
        ),
        child: child,
      ),
    );
  }

  /// Etiqueta de sección flat/minimal (mayúsculas, tenue, sin negrita)
  /// compartida por los campos simples del formulario — evita repetir el
  /// mismo `Text` con estilo distinto en cada sección.
  Widget _seccionLabel(String texto) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        texto.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
          color: KanbanColors.tdim,
        ),
      ),
    );
  }

  InputDecoration _decoracion() => InputDecoration(
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
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
  );

  Widget _dropdownClasificacion(
    List<(String, Color)> opciones,
    int seleccionado,
    void Function(int) onChanged,
  ) {
    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<int>(
            initialValue: seleccionado,
            isExpanded: true,
            decoration: _decoracion().copyWith(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 9,
              ),
            ),
            items: [
              for (var i = 0; i < opciones.length; i++)
                DropdownMenuItem(
                  value: i,
                  child: Text(
                    opciones[i].$1,
                    style: const TextStyle(fontSize: 12.5),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (v) => onChanged(v ?? 0),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: opciones[seleccionado].$2,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ],
    );
  }

  Widget _fila(
    String label,
    String valor, {
    IconData icon = Icons.person_rounded,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Icon(icon, size: 14, color: KanbanColors.tdim),
          const SizedBox(width: 6),
          Text(
            '$label ',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: KanbanColors.texto,
            ),
          ),
          Expanded(
            child: Text(
              valor.toUpperCase(),
              style: TextStyle(fontSize: 12, color: KanbanColors.texto),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = _tarea;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 700),
        child: t == null
            ? const SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator()),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: KanbanColors.bg2,
                      border: Border(
                        bottom: BorderSide(color: KanbanColors.borde),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: KanbanColors.bg3,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '#${t.id}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: KanbanColors.tdim,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            t.titulo,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: KanbanColors.texto,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Eliminar tarea',
                          icon: Icon(
                            Icons.delete_outline_rounded,
                            color: KanbanColors.tdim,
                            size: 19,
                          ),
                          onPressed: _eliminarTarea,
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.close_rounded,
                            color: KanbanColors.tdim,
                            size: 20,
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _iniciar,
                            icon: Icon(
                              Icons.play_circle_outline_rounded,
                              size: 16,
                              color: KanbanColors.toolbarTeal,
                            ),
                            label: Text(
                              _labelBoton(t.estatus),
                              style: TextStyle(
                                fontSize: 12.5,
                                color: KanbanColors.toolbarTeal,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                color: KanbanColors.toolbarTeal,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: _campoBox(
                                  onTap: _elegirHora,
                                  child: Text(
                                    _fechaInicio == null
                                        ? 'Hora'
                                        : _hora(_fechaInicio!),
                                    style: const TextStyle(fontSize: 12.5),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _campoBox(
                                  onTap: () => _elegirFecha(esInicio: true),
                                  child: Text(
                                    _fechaInicio == null
                                        ? 'Fecha inicio'
                                        : _fecha(_fechaInicio!),
                                    style: const TextStyle(fontSize: 12.5),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _campoBox(
                                  onTap: () => _elegirFecha(esInicio: false),
                                  child: Text(
                                    _fechaFin == null
                                        ? 'Fecha fin'
                                        : _fecha(_fechaFin!),
                                    style: const TextStyle(fontSize: 12.5),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _tituloCtrl,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: KanbanColors.texto,
                            ),
                            decoration: _decoracion(),
                          ),
                          const SizedBox(height: 16),
                          _seccionLabel('Etiquetas'),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              for (final et in _catalogoEtiquetas)
                                FilterChip(
                                  label: Text(
                                    et.nombre,
                                    style: const TextStyle(fontSize: 11.5),
                                  ),
                                  selected: _etiquetaIdsSeleccionadas.contains(
                                    et.id,
                                  ),
                                  selectedColor: et.color.withValues(
                                    alpha: 0.3,
                                  ),
                                  backgroundColor: et.color.withValues(
                                    alpha: 0.12,
                                  ),
                                  checkmarkColor: et.color,
                                  side: BorderSide(color: et.color),
                                  onSelected: (_) => _toggleEtiqueta(et.id),
                                ),
                              ActionChip(
                                avatar: const Icon(Icons.add_rounded, size: 15),
                                label: const Text(
                                  'Nueva',
                                  style: TextStyle(fontSize: 11.5),
                                ),
                                onPressed: () => setState(
                                  () => _creandoEtiqueta = !_creandoEtiqueta,
                                ),
                              ),
                            ],
                          ),
                          if (_creandoEtiqueta) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _nuevaEtiquetaCtrl,
                                    autofocus: true,
                                    style: const TextStyle(fontSize: 12.5),
                                    decoration: _decoracion().copyWith(
                                      hintText: 'Nombre de la etiqueta…',
                                    ),
                                    onSubmitted: (_) => _crearEtiqueta(),
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(
                                    Icons.check_circle_rounded,
                                    color: KanbanColors.ok,
                                  ),
                                  onPressed: _crearEtiqueta,
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              children: [
                                for (final c in kColorPaletteEtiquetas)
                                  InkWell(
                                    onTap: () => setState(
                                      () => _colorNuevaEtiqueta = c,
                                    ),
                                    child: Container(
                                      width: 22,
                                      height: 22,
                                      decoration: BoxDecoration(
                                        color: c,
                                        shape: BoxShape.circle,
                                        border:
                                            _colorNuevaEtiqueta == c
                                            ? Border.all(
                                                color: KanbanColors.texto,
                                                width: 2,
                                              )
                                            : null,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 16),
                          _seccionLabel('Portada'),
                          Wrap(
                            spacing: 6,
                            children: [
                              InkWell(
                                onTap: () => setState(() => _portada = null),
                                child: Container(
                                  width: 26,
                                  height: 26,
                                  decoration: BoxDecoration(
                                    color: KanbanColors.bg3,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: _portada == null
                                          ? KanbanColors.texto
                                          : KanbanColors.borde,
                                      width: _portada == null ? 2 : 1,
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.close_rounded,
                                    size: 14,
                                    color: KanbanColors.tdim,
                                  ),
                                ),
                              ),
                              for (final c in kColorPaletteEtiquetas)
                                InkWell(
                                  onTap: () => setState(() => _portada = c),
                                  child: Container(
                                    width: 26,
                                    height: 26,
                                    decoration: BoxDecoration(
                                      color: c,
                                      shape: BoxShape.circle,
                                      border: _portada == c
                                          ? Border.all(
                                              color: KanbanColors.texto,
                                              width: 2,
                                            )
                                          : null,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          _seccionLabel('Área'),
                          DropdownButtonFormField<String>(
                            initialValue: _area,
                            isExpanded: true,
                            decoration: _decoracion().copyWith(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 9,
                              ),
                            ),
                            items: [
                              for (final g in kGruposDemo)
                                DropdownMenuItem(
                                  value: g,
                                  child: Text(
                                    g,
                                    style: const TextStyle(fontSize: 12.5),
                                  ),
                                ),
                            ],
                            onChanged: (v) => setState(() => _area = v),
                          ),
                          const SizedBox(height: 12),
                          _seccionLabel('Generales'),
                          _dropdownClasificacion(
                            kGeneralesDemo,
                            _generalesIdx,
                            (i) => setState(() => _generalesIdx = i),
                          ),
                          const SizedBox(height: 12),
                          _seccionLabel('Nivel'),
                          _dropdownClasificacion(
                            kNivelDemo,
                            _nivelIdx,
                            (i) => setState(() => _nivelIdx = i),
                          ),
                          const SizedBox(height: 12),
                          _seccionLabel('Importancia'),
                          _dropdownClasificacion(
                            kImportanciaDemo,
                            _importanciaIdx,
                            (i) => setState(() => _importanciaIdx = i),
                          ),
                          const SizedBox(height: 16),
                          _seccionLabel('Descripción'),
                          TextField(
                            controller: _descripcionCtrl,
                            maxLines: 3,
                            style: const TextStyle(fontSize: 12.5),
                            decoration: _decoracion().copyWith(
                              contentPadding: const EdgeInsets.all(10),
                              filled: true,
                              fillColor: KanbanColors.bg3,
                            ),
                          ),
                          const SizedBox(height: 14),
                          _fila(
                            'Asignado por:',
                            t.asignadoPor.isEmpty
                                ? 'Sin definir'
                                : t.asignadoPor,
                            icon: Icons.account_tree_rounded,
                          ),
                          const SizedBox(height: 12),
                          _seccionLabel('Miembros'),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              for (final m in _catalogoMiembros)
                                FilterChip(
                                  avatar: CircleAvatar(
                                    backgroundColor: m.colorAvatar,
                                    child: Text(
                                      m.nombre.isNotEmpty
                                          ? m.nombre[0].toUpperCase()
                                          : '?',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  label: Text(
                                    m.nombre,
                                    style: const TextStyle(fontSize: 11.5),
                                  ),
                                  selected: _miembroIdsSeleccionados.contains(
                                    m.id,
                                  ),
                                  selectedColor: m.colorAvatar.withValues(
                                    alpha: 0.3,
                                  ),
                                  onSelected: (_) => _toggleMiembro(m.id),
                                ),
                              ActionChip(
                                avatar: const Icon(Icons.add_rounded, size: 15),
                                label: const Text(
                                  'Nuevo',
                                  style: TextStyle(fontSize: 11.5),
                                ),
                                onPressed: () => setState(
                                  () => _creandoMiembro = !_creandoMiembro,
                                ),
                              ),
                            ],
                          ),
                          if (_creandoMiembro) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _nuevoMiembroCtrl,
                                    autofocus: true,
                                    style: const TextStyle(fontSize: 12.5),
                                    decoration: _decoracion().copyWith(
                                      hintText: 'Nombre de la persona…',
                                    ),
                                    onSubmitted: (_) => _crearMiembro(),
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(
                                    Icons.check_circle_rounded,
                                    color: KanbanColors.ok,
                                  ),
                                  onPressed: _crearMiembro,
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              children: [
                                for (final c in kColorPaletteEtiquetas)
                                  InkWell(
                                    onTap: () => setState(
                                      () => _colorNuevoMiembro = c,
                                    ),
                                    child: Container(
                                      width: 22,
                                      height: 22,
                                      decoration: BoxDecoration(
                                        color: c,
                                        shape: BoxShape.circle,
                                        border:
                                            _colorNuevoMiembro == c
                                            ? Border.all(
                                                color: KanbanColors.texto,
                                                width: 2,
                                              )
                                            : null,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Icon(
                                Icons.link_rounded,
                                size: 15,
                                color: KanbanColors.texto,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'DEPENDE DE (${_dependeDeSeleccionadas.length})',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.bold,
                                  color: KanbanColors.texto,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          if (_todasTareas.length <= 1)
                            Padding(
                              padding: EdgeInsets.only(bottom: 8),
                              child: Text(
                                'No hay otras tareas para relacionar.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: KanbanColors.tdim,
                                ),
                              ),
                            )
                          else
                            for (final otra in _todasTareas.where(
                              (x) => x.id != t.id,
                            ))
                              Builder(
                                builder: (context) {
                                  final seleccionada = _dependeDeSeleccionadas
                                      .contains(otra.id);
                                  final bloqueada =
                                      !seleccionada && _creariaCiclo(otra.id);
                                  return Opacity(
                                    opacity: bloqueada ? 0.4 : 1,
                                    child: Row(
                                      children: [
                                        Checkbox(
                                          value: seleccionada,
                                          activeColor:
                                              KanbanColors.toolbarTeal,
                                          onChanged: bloqueada
                                              ? null
                                              : (_) =>
                                                    _toggleDependencia(otra.id),
                                        ),
                                        Expanded(
                                          child: Text(
                                            bloqueada
                                                ? '${otra.titulo} (crearía un ciclo)'
                                                : otra.titulo,
                                            style: const TextStyle(
                                              fontSize: 12.5,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                          const SizedBox(height: 10),
                          Divider(color: KanbanColors.borde),
                          const SizedBox(height: 4),
                          if (t.actividades.isNotEmpty) ...[
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: Stack(
                                children: [
                                  Container(
                                    height: 16,
                                    color: KanbanColors.bg3,
                                  ),
                                  FractionallySizedBox(
                                    widthFactor: t.progreso,
                                    child: Container(
                                      height: 16,
                                      color: KanbanColors.toolbarTeal,
                                    ),
                                  ),
                                  Positioned.fill(
                                    child: Center(
                                      child: Text(
                                        '${(t.progreso * 100).round()}%',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: KanbanColors.texto,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                          Row(
                            children: [
                              Icon(
                                Icons.checklist_rounded,
                                size: 15,
                                color: KanbanColors.texto,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'ACTIVIDADES (${t.actividadesTerminadas}/${t.actividades.length})',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.bold,
                                  color: KanbanColors.texto,
                                ),
                              ),
                              const Spacer(),
                              TextButton(
                                onPressed: () => setState(
                                  () => _ocultarCompletados =
                                      !_ocultarCompletados,
                                ),
                                child: Text(
                                  _ocultarCompletados
                                      ? 'Mostrar completados'
                                      : 'Ocultar completados',
                                  style: const TextStyle(fontSize: 11.5),
                                ),
                              ),
                            ],
                          ),
                          for (final a in t.actividades.where(
                            (a) => !_ocultarCompletados || !a.terminada,
                          ))
                            Row(
                              children: [
                                Checkbox(
                                  value: a.terminada,
                                  activeColor: KanbanColors.toolbarTeal,
                                  onChanged: (_) => _toggleActividad(a.id),
                                ),
                                Expanded(
                                  child: Text(
                                    a.descripcion,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      color: a.terminada
                                          ? KanbanColors.tdim
                                          : KanbanColors.texto,
                                      decoration: a.terminada
                                          ? TextDecoration.lineThrough
                                          : null,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(
                                    Icons.close_rounded,
                                    size: 15,
                                    color: KanbanColors.tdim,
                                  ),
                                  onPressed: () => _eliminarActividad(a.id),
                                ),
                              ],
                            ),
                          const SizedBox(height: 6),
                          if (_creandoActividad)
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _nuevaActividadCtrl,
                                    autofocus: true,
                                    onSubmitted: (_) => _agregarActividad(),
                                    style: const TextStyle(fontSize: 12.5),
                                    decoration: _decoracion().copyWith(
                                      hintText: 'Descripción de la actividad…',
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(
                                    Icons.check_circle_rounded,
                                    color: KanbanColors.ok,
                                  ),
                                  onPressed: _agregarActividad,
                                ),
                              ],
                            )
                          else
                            OutlinedButton.icon(
                              onPressed: () =>
                                  setState(() => _creandoActividad = true),
                              icon: const Icon(Icons.add_rounded, size: 15),
                              label: const Text(
                                'Crear actividad',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          const SizedBox(height: 16),
                          Divider(color: KanbanColors.borde),
                          Row(
                            children: [
                              Icon(
                                Icons.chat_bubble_outline_rounded,
                                size: 15,
                                color: KanbanColors.texto,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'COMENTARIOS (${t.comentarios.length})',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.bold,
                                  color: KanbanColors.texto,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          for (final c in t.comentarios)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: KanbanColors.bg3,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      c.autor,
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      c.contenido,
                                      style: const TextStyle(fontSize: 12.5),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: KanbanColors.borde),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.all(6),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _comentarioCtrl,
                                    onSubmitted: (_) => _agregarComentario(),
                                    style: const TextStyle(fontSize: 12.5),
                                    decoration: const InputDecoration(
                                      isDense: true,
                                      hintText:
                                          'Escribe un comentario, pega o arrastra un archivo',
                                      border: InputBorder.none,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(
                                    Icons.attach_file_rounded,
                                    size: 18,
                                    color: KanbanColors.tdim,
                                  ),
                                  onPressed: null,
                                ),
                                IconButton(
                                  icon: Icon(
                                    Icons.send_rounded,
                                    size: 18,
                                    color: KanbanColors.toolbarTeal,
                                  ),
                                  onPressed: _agregarComentario,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(color: KanbanColors.borde),
                      ),
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _guardando ? null : _guardar,
                        icon: _guardando
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.save_rounded,
                                size: 16,
                                color: Colors.white,
                              ),
                        label: const Text(
                          'GUARDAR',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          elevation: 0,
                          backgroundColor: KanbanColors.toolbarGreen,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(9),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
