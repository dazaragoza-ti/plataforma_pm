import 'package:flutter/material.dart';
import '../../../kanban_constants.dart';
import '../../../data/kanban_repository.dart';
import '../../../domain/entities/tarea.dart';
import 'kanban_alert_dialog.dart';

/// Diálogo de confirmación al pausar una tarea (al arrastrarla a la columna
/// Pausa o al usar el botón "Pausar" del detalle): recuerda qué actividades
/// quedan pendientes y deja anotar el motivo de la pausa antes de
/// confirmar, para que no sea una sorpresa al volver. La nota se guarda en
/// el historial de la tarea (ver [KanbanRepository.registrarNotaPausa]) —
/// como cada pausa deja su propio registro, pausar varias veces no pisa
/// las notas anteriores. Devuelve `true` si se debe proceder con el
/// movimiento a Pausa, `false` si se canceló. Sin actividades no hay nada
/// que recordar, así que no interrumpe con un diálogo vacío.
class PausarTareaDialog {
  static Future<bool> show(
    BuildContext context, {
    required KanbanRepository repository,
    required Tarea tarea,
  }) async {
    final hayPendientes = tarea.actividades.any((a) => !a.terminada);
    if (!hayPendientes) return true;
    final resultado = await showDialog<bool>(
      context: context,
      builder: (_) =>
          _PausarTareaDialogContent(repository: repository, tarea: tarea),
    );
    return resultado ?? false;
  }
}

class _PausarTareaDialogContent extends StatefulWidget {
  final KanbanRepository repository;
  final Tarea tarea;

  const _PausarTareaDialogContent({
    required this.repository,
    required this.tarea,
  });

  @override
  State<_PausarTareaDialogContent> createState() =>
      _PausarTareaDialogContentState();
}

class _PausarTareaDialogContentState extends State<_PausarTareaDialogContent> {
  final _notaCtrl = TextEditingController();
  int? _actividadId;
  bool _guardando = false;

  @override
  void dispose() {
    _notaCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirmar() async {
    final nota = _notaCtrl.text.trim();
    if (nota.isEmpty) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() => _guardando = true);
    final actividadId = _actividadId;
    // Sin actividad elegida, la nota queda general; eligiendo una, el
    // historial deja explícito a cuál se refiere en vez de una nota suelta
    // sin contexto de qué se avanzó.
    final mensaje = actividadId == null
        ? nota
        : 'En "${widget.tarea.actividades.firstWhere((a) => a.id == actividadId).descripcion}": $nota';
    await widget.repository.registrarNotaPausa(widget.tarea.id, mensaje);
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final pendientes = widget.tarea.actividades.where((a) => !a.terminada);
    return kanbanAlertDialog(
      titulo: 'Pausar tarea',
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Estas actividades siguen pendientes — toca una para anotar '
              'el avance sobre ella (opcional):',
              style: TextStyle(fontSize: 12.5, color: KanbanColors.tdim),
            ),
            const SizedBox(height: 4),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: SingleChildScrollView(
                child: RadioGroup<int>(
                  groupValue: _actividadId,
                  onChanged: (v) => setState(() => _actividadId = v),
                  child: Column(
                    children: [
                      for (final a in pendientes)
                        RadioListTile<int>(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          value: a.id,
                          title: Text(
                            a.descripcion,
                            style: TextStyle(
                              fontSize: 13,
                              color: KanbanColors.texto,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _notaCtrl,
              maxLines: 3,
              style: TextStyle(fontSize: 13, color: KanbanColors.texto),
              decoration: kanbanInputDecoration(
                hint: '¿Por qué se pausa? (opcional)',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _guardando ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _guardando ? null : _confirmar,
          style: ElevatedButton.styleFrom(
            backgroundColor: KanbanColors.accent,
            foregroundColor: Colors.white,
          ),
          child: Text(_guardando ? 'Guardando…' : 'Pausar'),
        ),
      ],
    );
  }
}
