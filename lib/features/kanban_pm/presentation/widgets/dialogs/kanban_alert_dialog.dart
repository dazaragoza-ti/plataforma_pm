import 'package:flutter/material.dart';
import '../../../kanban_constants.dart';

/// `AlertDialog` con el estilo estándar del módulo Kanban PM (fondo,
/// sin tinte de superficie, título con el color de texto del tema activo) —
/// antes cada diálogo del módulo repetía estas mismas 3 propiedades a mano.
AlertDialog kanbanAlertDialog({
  required String titulo,
  required Widget content,
  required List<Widget> actions,
}) {
  return AlertDialog(
    backgroundColor: KanbanColors.bg2,
    surfaceTintColor: Colors.transparent,
    title: Text(titulo, style: TextStyle(color: KanbanColors.texto)),
    content: content,
    actions: actions,
  );
}
