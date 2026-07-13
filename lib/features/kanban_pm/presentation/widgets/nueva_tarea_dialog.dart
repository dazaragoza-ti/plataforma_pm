import 'package:flutter/material.dart';
import '../../kanban_constants.dart';
import '../../data/kanban_repository.dart';
import '../../domain/entities/tarea.dart';

/// Diálogo para crear una nueva tarea.
class NuevaTareaDialog extends StatefulWidget {
  final KanbanRepository repository;

  const NuevaTareaDialog({super.key, required this.repository});

  static Future<int?> show(
    BuildContext context, {
    required KanbanRepository repository,
  }) {
    return showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (_) => NuevaTareaDialog(repository: repository),
    );
  }

  @override
  State<NuevaTareaDialog> createState() => _NuevaTareaDialogState();
}

class _NuevaTareaDialogState extends State<NuevaTareaDialog> {
  final _tituloCtrl = TextEditingController();
  final _descripcionCtrl = TextEditingController();
  final _responsableCtrl = TextEditingController();
  String? _grupo;
  TareaPrioridad _prioridad = TareaPrioridad.media;
  TareaEstatus _estatus = TareaEstatus.tareas;
  DateTime? _fechaVencimiento;
  bool _guardando = false;

  @override
  void dispose() {
    _tituloCtrl.dispose();
    _descripcionCtrl.dispose();
    _responsableCtrl.dispose();
    super.dispose();
  }

  Future<void> _elegirFecha() async {
    final fecha = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 3)),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (fecha != null) setState(() => _fechaVencimiento = fecha);
  }

  Future<void> _crear() async {
    if (_tituloCtrl.text.trim().isEmpty) return;
    setState(() => _guardando = true);
    try {
      final id = await widget.repository.crearTarea(
        Tarea(
          id: 0,
          titulo: _tituloCtrl.text.trim(),
          descripcion: _descripcionCtrl.text.trim(),
          estatus: _estatus,
          prioridad: _prioridad,
          grupo: _grupo ?? '',
          asignadoPor: kUsuarioActualDemo,
          responsable: _responsableCtrl.text.trim(),
          fechaInicio: DateTime.now(),
          fechaVencimiento: _fechaVencimiento,
        ),
      );
      if (mounted) Navigator.of(context).pop(id);
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

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [KanbanColors.accentDark, KanbanColors.accent],
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                children: [
                  const Icon(
                    Icons.add_task_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Nueva tarea',
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
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
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _campo('Título', _tituloCtrl),
                  const SizedBox(height: 10),
                  _campo('Descripción', _descripcionCtrl, maxLines: 3),
                  const SizedBox(height: 10),
                  _campo('Responsable', _responsableCtrl),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _grupo,
                          decoration: _decoracion('Área'),
                          items: [
                            for (final g in kGruposDemo)
                              DropdownMenuItem(
                                value: g,
                                child: Text(
                                  g,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                          ],
                          onChanged: (v) => setState(() => _grupo = v),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<TareaPrioridad>(
                          initialValue: _prioridad,
                          decoration: _decoracion('Prioridad'),
                          items: [
                            for (final p in TareaPrioridad.values)
                              DropdownMenuItem(
                                value: p,
                                child: Text(
                                  p.etiqueta,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                          ],
                          onChanged: (v) => setState(
                            () => _prioridad = v ?? TareaPrioridad.media,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<TareaEstatus>(
                          initialValue: _estatus,
                          decoration: _decoracion('Columna'),
                          items: [
                            for (final c in kColumnas)
                              DropdownMenuItem(
                                value: c.estatus,
                                child: Text(
                                  c.titulo,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                          ],
                          onChanged: (v) => setState(
                            () => _estatus = v ?? TareaEstatus.tareas,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _elegirFecha,
                          icon: const Icon(
                            Icons.event_rounded,
                            size: 16,
                            color: KanbanColors.accent,
                          ),
                          label: Text(
                            _fechaVencimiento == null
                                ? 'Vencimiento'
                                : '${_fechaVencimiento!.day}/${_fechaVencimiento!.month}/${_fechaVencimiento!.year}',
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: KanbanColors.texto,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            side: const BorderSide(color: KanbanColors.borde),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _guardando ? null : _crear,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: KanbanColors.accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: _guardando
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Crear tarea'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _decoracion(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontSize: 12, color: KanbanColors.tdim),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: KanbanColors.borde),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: KanbanColors.borde),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: KanbanColors.accent, width: 2),
      ),
    );
  }

  Widget _campo(String label, TextEditingController ctrl, {int maxLines = 1}) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      style: const TextStyle(fontSize: 13, color: KanbanColors.texto),
      decoration: _decoracion(label),
    );
  }
}
