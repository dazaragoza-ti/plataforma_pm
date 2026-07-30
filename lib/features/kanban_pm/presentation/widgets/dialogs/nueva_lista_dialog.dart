import 'package:flutter/material.dart';
import '../../../data/kanban_repository.dart';
import '../../../domain/entities/kanban_columna.dart';
import '../../../kanban_constants.dart'
    show KanbanColors, kanbanToast, kanbanInputDecoration;
import 'kanban_alert_dialog.dart';

/// Diálogo para crear una lista/columna nueva (estilo Trello) — un ícono
/// en el header ("Nueva lista"), no un composer al final del tablero: con
/// varias columnas ese composer quedaba fuera de vista hasta hacer scroll
/// horizontal hasta el fondo, poco descubrible.
///
/// Crea la columna en el repositorio y devuelve la [KanbanColumna]
/// resultante (o `null` si se canceló), para que quien llama solo tenga
/// que añadirla a su propia lista local con `setState`.
class NuevaListaDialog {
  static Future<KanbanColumna?> show(
    BuildContext context, {
    required KanbanRepository repository,
  }) async {
    final ctrl = TextEditingController();
    try {
      return await _mostrarYCrear(context, repository: repository, ctrl: ctrl);
    } finally {
      ctrl.dispose();
    }
  }

  static Future<KanbanColumna?> _mostrarYCrear(
    BuildContext context, {
    required KanbanRepository repository,
    required TextEditingController ctrl,
  }) async {
    final titulo = await showDialog<String>(
      context: context,
      builder: (ctx) {
        // Si el título queda vacío no se cierra el diálogo sin avisar (antes
        // Enter/"Crear" cerraban de todas formas sin crear ninguna lista):
        // se mantiene abierto para corregir, igual que etiquetas/plantillas.
        void confirmar() {
          final texto = ctrl.text.trim();
          if (texto.isEmpty) return;
          Navigator.of(ctx).pop(texto);
        }

        return kanbanAlertDialog(
          titulo: 'Nueva lista',
          content: SizedBox(
            width: 320,
            child: TextField(
              controller: ctrl,
              autofocus: true,
              style: TextStyle(fontSize: 13, color: KanbanColors.texto),
              decoration: kanbanInputDecoration(hint: 'Título de la lista…'),
              onSubmitted: (_) => confirmar(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: confirmar,
              style: ElevatedButton.styleFrom(
                backgroundColor: KanbanColors.accent,
                foregroundColor: Colors.white,
              ),
              child: const Text('Crear'),
            ),
          ],
        );
      },
    );
    if (titulo == null) return null;
    try {
      return await repository.crearColumna(titulo);
    } catch (ex) {
      if (context.mounted) {
        kanbanToast(context, 'No se pudo crear la lista: $ex', ok: false);
      }
      return null;
    }
  }
}
