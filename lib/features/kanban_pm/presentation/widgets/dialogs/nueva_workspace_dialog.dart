import 'package:flutter/material.dart';

import '../../../data/workspace_repository.dart';
import '../../../domain/entities/workspace.dart';
import '../../../kanban_constants.dart' show KanbanColors, kColorPaletteEtiquetas;
import '../common/color_wheel_picker.dart';

/// Diálogo para crear una nueva área de trabajo: nombre + color (para
/// distinguirlas de un vistazo en el selector). Crea el área en el
/// repositorio y devuelve la [Workspace] resultante (o `null` si se
/// canceló).
class NuevaWorkspaceDialog {
  static Future<Workspace?> show(
    BuildContext context, {
    required WorkspaceRepository repository,
  }) async {
    final ctrl = TextEditingController();
    var color = kColorPaletteEtiquetas[0];

    final resultado = await showDialog<(String, Color)>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            backgroundColor: KanbanColors.bg2,
            surfaceTintColor: Colors.transparent,
            title: Text(
              'Nueva área de trabajo',
              style: TextStyle(color: KanbanColors.texto),
            ),
            content: SizedBox(
              width: 320,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: ctrl,
                    autofocus: true,
                    style: TextStyle(fontSize: 13, color: KanbanColors.texto),
                    decoration: InputDecoration(
                      hintText: 'Nombre del área de trabajo…',
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
                        borderSide: BorderSide(
                          color: KanbanColors.accent,
                          width: 1.5,
                        ),
                      ),
                    ),
                    onSubmitted: (v) =>
                        Navigator.of(ctx).pop((v, color)),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'COLOR',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.4,
                      color: KanbanColors.tdim,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: ColorWheelPicker(
                      initialColor: color,
                      size: 180,
                      onColorChanged: (c) => setDialogState(() => color = c),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop((ctrl.text, color)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: KanbanColors.accent,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Crear'),
              ),
            ],
          );
        },
      ),
    );
    if (resultado == null || resultado.$1.trim().isEmpty) return null;
    return repository.crearWorkspace(resultado.$1, resultado.$2);
  }
}
