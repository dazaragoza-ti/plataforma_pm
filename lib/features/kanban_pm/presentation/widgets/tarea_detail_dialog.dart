import 'package:flutter/material.dart';
import '../../kanban_constants.dart';
import '../../data/kanban_repository.dart';
import '../../domain/entities/tarea.dart';

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

  String? _area;
  int _generalesIdx = 0;
  int _nivelIdx = 0;
  int _importanciaIdx = 0;
  DateTime? _fechaInicio;
  DateTime? _fechaFin;
  bool _ocultarCompletados = false;
  bool _creandoActividad = false;
  bool _guardando = false;

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
    super.dispose();
  }

  Future<void> _cargar() async {
    final tareas = await widget.repository.listarTareas();
    if (!mounted) return;
    final t = tareas.firstWhere((x) => x.id == widget.tareaId);
    setState(() {
      _tarea = t;
      _tituloCtrl.text = t.titulo;
      _descripcionCtrl.text = t.descripcion;
      _area = t.grupo.isEmpty ? null : t.grupo;
      _fechaInicio = t.fechaInicio;
      _fechaFin = t.fechaVencimiento;
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
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: KanbanColors.borde),
          borderRadius: BorderRadius.circular(6),
        ),
        child: child,
      ),
    );
  }

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
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              border: OutlineInputBorder(),
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
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: KanbanColors.texto,
            ),
          ),
          Expanded(
            child: Text(
              valor.toUpperCase(),
              style: const TextStyle(fontSize: 12, color: KanbanColors.texto),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
                    color: KanbanColors.toolbarDark,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.edit_rounded,
                          color: Colors.white70,
                          size: 15,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '#${t.id}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: KanbanColors.accent,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            t.titulo.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Eliminar tarea',
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            color: Colors.white70,
                            size: 19,
                          ),
                          onPressed: _eliminarTarea,
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.close_rounded,
                            color: Colors.white,
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
                            icon: const Icon(
                              Icons.play_circle_outline_rounded,
                              size: 16,
                              color: KanbanColors.toolbarTeal,
                            ),
                            label: Text(
                              _labelBoton(t.estatus),
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: KanbanColors.toolbarTeal,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(
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
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                            decoration: const InputDecoration(
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 10,
                              ),
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Área:',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: KanbanColors.texto,
                            ),
                          ),
                          const SizedBox(height: 4),
                          DropdownButtonFormField<String>(
                            initialValue: _area,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 9,
                              ),
                              border: OutlineInputBorder(),
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
                          const SizedBox(height: 10),
                          const Text(
                            'Generales:',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: KanbanColors.texto,
                            ),
                          ),
                          const SizedBox(height: 4),
                          _dropdownClasificacion(
                            kGeneralesDemo,
                            _generalesIdx,
                            (i) => setState(() => _generalesIdx = i),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Nivel:',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: KanbanColors.texto,
                            ),
                          ),
                          const SizedBox(height: 4),
                          _dropdownClasificacion(
                            kNivelDemo,
                            _nivelIdx,
                            (i) => setState(() => _nivelIdx = i),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Importancia:',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: KanbanColors.texto,
                            ),
                          ),
                          const SizedBox(height: 4),
                          _dropdownClasificacion(
                            kImportanciaDemo,
                            _importanciaIdx,
                            (i) => setState(() => _importanciaIdx = i),
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'Descripción',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: KanbanColors.texto,
                            ),
                          ),
                          const SizedBox(height: 4),
                          TextField(
                            controller: _descripcionCtrl,
                            maxLines: 3,
                            style: const TextStyle(fontSize: 12.5),
                            decoration: InputDecoration(
                              isDense: true,
                              contentPadding: const EdgeInsets.all(10),
                              filled: true,
                              fillColor: KanbanColors.bg3,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                                borderSide: const BorderSide(
                                  color: KanbanColors.borde,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          _fila(
                            'Asignado por:',
                            t.asignadoPor.isEmpty
                                ? 'Sin definir'
                                : t.asignadoPor,
                            icon: Icons.account_tree_rounded,
                          ),
                          _fila(
                            'Persona Asignada:',
                            t.responsable.isEmpty
                                ? 'Sin asignar'
                                : t.responsable,
                            icon: Icons.person_rounded,
                          ),
                          const SizedBox(height: 14),
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
                                        style: const TextStyle(
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
                              const Icon(
                                Icons.checklist_rounded,
                                size: 15,
                                color: KanbanColors.texto,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'ACTIVIDADES (${t.actividadesTerminadas}/${t.actividades.length})',
                                style: const TextStyle(
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
                                  icon: const Icon(
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
                                    decoration: const InputDecoration(
                                      isDense: true,
                                      hintText: 'Descripción de la actividad…',
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
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
                          const Divider(color: KanbanColors.borde),
                          Row(
                            children: [
                              const Icon(
                                Icons.chat_bubble_outline_rounded,
                                size: 15,
                                color: KanbanColors.texto,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'COMENTARIOS (${t.comentarios.length})',
                                style: const TextStyle(
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
                                  icon: const Icon(
                                    Icons.attach_file_rounded,
                                    size: 18,
                                    color: KanbanColors.tdim,
                                  ),
                                  onPressed: null,
                                ),
                                IconButton(
                                  icon: const Icon(
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
                    decoration: const BoxDecoration(
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
                          backgroundColor: KanbanColors.toolbarGreen,
                          padding: const EdgeInsets.symmetric(vertical: 12),
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
