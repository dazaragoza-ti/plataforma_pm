import 'package:flutter/material.dart';
import '../../../domain/entities/kanban_columna.dart';
import '../../../domain/entities/tarea_estatus.dart';
import '../../../kanban_constants.dart' show KanbanColors;
import 'kanban_alert_dialog.dart';

/// Diálogo de solo lectura con las listas archivadas del tablero, cada una
/// con un botón para desarchivarla — quien llama decide qué hacer con eso
/// vía [onDesarchivar], ya que archivar/desarchivar toca el estado
/// (`_columnas`) de la pantalla, no de este diálogo.
class ListasArchivadasDialog {
  static Future<void> show(
    BuildContext context, {
    required List<KanbanColumna> columnas,
    required void Function(TareaEstatus estatus) onDesarchivar,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => kanbanAlertDialog(
        titulo: 'Listas archivadas',
        content: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final c in columnas.where((c) => c.archivada))
                ListTile(
                  dense: true,
                  title: Text(
                    c.titulo,
                    style: TextStyle(color: KanbanColors.texto),
                  ),
                  trailing: TextButton(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      onDesarchivar(c.estatus);
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
}
