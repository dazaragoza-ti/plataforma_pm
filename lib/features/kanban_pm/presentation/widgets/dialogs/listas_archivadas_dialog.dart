import 'package:flutter/material.dart';
import '../../../domain/entities/kanban_columna.dart';
import '../../../domain/entities/tarea_estatus.dart';
import '../../../kanban_constants.dart' show KanbanColors;

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
