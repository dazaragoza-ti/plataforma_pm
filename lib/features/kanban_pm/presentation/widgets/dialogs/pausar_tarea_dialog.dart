import 'package:flutter/material.dart';
import '../../../kanban_constants.dart';
import '../../../data/kanban_repository.dart';
import '../../../domain/entities/tarea.dart';

/// Diálogo de confirmación al pausar una tarea (al arrastrarla a la columna
/// Pausa o al usar el botón "Pausar" del detalle): recuerda qué actividades
/// quedan pendientes antes de pausar, para que no sea una sorpresa al
/// volver. Devuelve `true` si se debe proceder con el movimiento a Pausa,
/// `false` si se canceló. Sin actividades no hay nada que recordar, así
/// que no interrumpe con un diálogo vacío.
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
      builder: (_) => _PausarTareaDialogContent(
        repository: repository,
        tarea: tarea,
      ),
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

class _PausarTareaDialogContentState
    extends State<_PausarTareaDialogContent> {
  @override
  Widget build(BuildContext context) {
    final pendientes = widget.tarea.actividades.where((a) => !a.terminada);
    return AlertDialog(
      backgroundColor: KanbanColors.bg2,
      surfaceTintColor: Colors.transparent,
      title: Text('Pausar tarea', style: TextStyle(color: KanbanColors.texto)),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Estas actividades siguen pendientes:',
              style: TextStyle(fontSize: 12.5, color: KanbanColors.tdim),
            ),
            const SizedBox(height: 4),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final a in pendientes)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(
                          children: [
                            Icon(
                              Icons.circle_outlined,
                              size: 14,
                              color: KanbanColors.tdim,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
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
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: KanbanColors.accent,
            foregroundColor: Colors.white,
          ),
          child: const Text('Pausar'),
        ),
      ],
    );
  }
}
