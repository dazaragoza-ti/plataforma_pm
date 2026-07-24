import 'package:flutter/material.dart';
import '../../../data/kanban_repository.dart';
import '../../../domain/entities/kanban_columna.dart';
import '../../../kanban_constants.dart' show KanbanColors;

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
    final titulo = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: KanbanColors.bg2,
        surfaceTintColor: Colors.transparent,
        title: Text('Nueva lista', style: TextStyle(color: KanbanColors.texto)),
        content: SizedBox(
          width: 320,
          child: TextField(
            controller: ctrl,
            autofocus: true,
            style: TextStyle(fontSize: 13, color: KanbanColors.texto),
            decoration: InputDecoration(
              hintText: 'Título de la lista…',
              isDense: true,
              filled: true,
              fillColor: KanbanColors.bg3,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(9),
                borderSide: BorderSide(color: KanbanColors.borde),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(9),
                borderSide: BorderSide(color: KanbanColors.accent, width: 1.5),
              ),
            ),
            onSubmitted: (v) => Navigator.of(ctx).pop(v),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(ctrl.text),
            style: ElevatedButton.styleFrom(
              backgroundColor: KanbanColors.accent,
              foregroundColor: Colors.white,
            ),
            child: const Text('Crear'),
          ),
        ],
      ),
    );
    if (titulo == null || titulo.trim().isEmpty) return null;
    return repository.crearColumna(titulo);
  }
}
