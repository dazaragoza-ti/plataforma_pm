import 'package:flutter/material.dart';

import '../../../data/workspace_repository.dart';
import '../../../domain/entities/workspace.dart';
import '../../../kanban_constants.dart'
    show KanbanColors, kColorPaletteEtiquetas, kanbanToast, kanbanInputDecoration;
import '../../../data/usuario_directorio.dart';
import '../common/color_wheel_picker.dart';
import 'kanban_alert_dialog.dart';

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
    try {
      return await _mostrarYCrear(context, repository: repository, ctrl: ctrl);
    } finally {
      ctrl.dispose();
    }
  }

  static Future<Workspace?> _mostrarYCrear(
    BuildContext context, {
    required WorkspaceRepository repository,
    required TextEditingController ctrl,
  }) async {
    var color = kColorPaletteEtiquetas[0];

    final resultado = await showDialog<(String, Color)>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          // Si el nombre queda vacío no se cierra el diálogo sin avisar (antes
          // Enter/"Crear" cerraban de todas formas y no se creaba nada): se
          // mantiene abierto para corregir, igual que etiquetas/plantillas.
          void confirmar() {
            if (ctrl.text.trim().isEmpty) return;
            Navigator.of(ctx).pop((ctrl.text.trim(), color));
          }

          return kanbanAlertDialog(
            titulo: 'Nueva área de trabajo',
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
                    decoration: kanbanInputDecoration(
                      hint: 'Nombre del área de trabajo…',
                    ),
                    onSubmitted: (_) => confirmar(),
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
      ),
    );
    if (resultado == null || resultado.$1.trim().isEmpty) return null;
    try {
      return await repository.crearWorkspace(
        resultado.$1,
        resultado.$2,
        creadorUsuarioId: usuarioActual.value.id,
      );
    } catch (ex) {
      if (context.mounted) {
        kanbanToast(context, 'No se pudo crear el área de trabajo: $ex', ok: false);
      }
      return null;
    }
  }
}
