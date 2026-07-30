import 'package:flutter/material.dart';
import '../../../kanban_constants.dart';
import 'kanban_alert_dialog.dart';

/// Diálogo de confirmación estándar para "Eliminar X" del módulo Kanban PM
/// — antes cada diálogo (tarea, etiqueta, plantilla, tarjeta…) repetía el
/// mismo par de botones Cancelar/Eliminar (rojo) con variaciones menores de
/// texto y estilo. Devuelve `true` solo si se confirmó.
Future<bool> confirmarEliminar(
  BuildContext context, {
  required String titulo,
  required String mensaje,
  String etiquetaConfirmar = 'Eliminar',
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => kanbanAlertDialog(
      titulo: titulo,
      content: Text(mensaje, style: TextStyle(color: KanbanColors.texto)),
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
          child: Text(etiquetaConfirmar),
        ),
      ],
    ),
  );
  return ok ?? false;
}
