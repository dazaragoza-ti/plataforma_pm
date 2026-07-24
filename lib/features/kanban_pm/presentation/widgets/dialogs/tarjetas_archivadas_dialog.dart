import 'package:flutter/material.dart';
import '../../../data/kanban_repository.dart';
import '../../../kanban_constants.dart' show KanbanColors;

/// A diferencia de las listas archivadas (que siguen en la lista de
/// columnas de la pantalla y no necesitan una consulta aparte), las
/// tarjetas archivadas se filtran por completo de la lista de tareas
/// visible — así que antes no había ninguna forma de verlas ni
/// recuperarlas pasados los 5 segundos del aviso "Deshacer" al momento de
/// archivar. Este diálogo consulta el repositorio directo (no recibe la
/// lista por parámetro) porque las archivadas nunca viven en el estado
/// de la pantalla.
class TarjetasArchivadasDialog {
  static Future<void> show(
    BuildContext context, {
    required KanbanRepository repository,
    required VoidCallback onDesarchivada,
  }) async {
    final todas = await repository.listarTareas();
    final archivadas = todas.where((t) => t.archivada).toList();
    if (!context.mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: KanbanColors.bg2,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Tarjetas archivadas',
          style: TextStyle(color: KanbanColors.texto),
        ),
        content: SizedBox(
          width: 340,
          child: archivadas.isEmpty
              ? Text(
                  'No hay tarjetas archivadas.',
                  style: TextStyle(color: KanbanColors.tdim),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final t in archivadas)
                      ListTile(
                        dense: true,
                        title: Text(
                          t.titulo,
                          style: TextStyle(color: KanbanColors.texto),
                        ),
                        subtitle: t.grupo.isEmpty
                            ? null
                            : Text(
                                t.grupo,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: KanbanColors.tdim,
                                ),
                              ),
                        trailing: TextButton(
                          onPressed: () async {
                            Navigator.of(ctx).pop();
                            await repository.archivarTarea(t.id, false);
                            onDesarchivada();
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
