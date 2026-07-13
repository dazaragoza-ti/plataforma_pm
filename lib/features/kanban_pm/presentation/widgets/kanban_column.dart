import 'package:flutter/material.dart';
import '../../kanban_constants.dart';
import '../../domain/entities/tarea.dart';
import 'kanban_task_card.dart';

/// Columna del tablero (TAREAS / PROCESO / PAUSA / TERMINADO / REVISADO).
///
/// Acepta soltar una tarjeta arrastrada desde otra columna para moverla
/// (drag & drop). El encabezado usa el ícono de marcador y el borde
/// inferior de color propio de cada columna, igual que en el tablero de
/// referencia.
class KanbanColumnView extends StatelessWidget {
  final KanbanColumna columna;
  final List<Tarea> tareas;
  final void Function(Tarea tarea) onTapTarea;
  final void Function(Tarea tarea, TareaEstatus nuevoEstatus) onDropTarea;
  final Widget? accionExtra;

  const KanbanColumnView({
    super.key,
    required this.columna,
    required this.tareas,
    required this.onTapTarea,
    required this.onDropTarea,
    this.accionExtra,
  });

  @override
  Widget build(BuildContext context) {
    return DragTarget<Tarea>(
      onWillAcceptWithDetails: (details) =>
          details.data.estatus != columna.estatus,
      onAcceptWithDetails: (details) =>
          onDropTarea(details.data, columna.estatus),
      builder: (context, candidateData, rejectedData) {
        final resaltado = candidateData.isNotEmpty;
        return Container(
          width: 280,
          margin: const EdgeInsets.only(right: 14),
          decoration: BoxDecoration(
            color: resaltado ? KanbanColors.accentLight : KanbanColors.bg3,
            borderRadius: BorderRadius.circular(6),
            border: resaltado ? Border.all(color: KanbanColors.accent) : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: columna.color, width: 3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(columna.icono, size: 15, color: columna.color),
                    const SizedBox(width: 6),
                    Text(
                      columna.titulo,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: KanbanColors.texto,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${tareas.length}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: KanbanColors.texto,
                      ),
                    ),
                  ],
                ),
              ),
              if (accionExtra != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
                  child: accionExtra,
                ),
              Expanded(
                child: tareas.isEmpty
                    ? Center(
                        child: Text(
                          'Sin tareas',
                          style: TextStyle(
                            fontSize: 12,
                            color: KanbanColors.tdim.withValues(alpha: 0.8),
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                        itemCount: tareas.length,
                        itemBuilder: (context, i) {
                          final t = tareas[i];
                          return Draggable<Tarea>(
                            data: t,
                            feedback: Material(
                              color: Colors.transparent,
                              child: SizedBox(
                                width: 256,
                                child: KanbanTaskCard(tarea: t, onTap: () {}),
                              ),
                            ),
                            childWhenDragging: Opacity(
                              opacity: 0.35,
                              child: KanbanTaskCard(tarea: t, onTap: () {}),
                            ),
                            child: KanbanTaskCard(
                              tarea: t,
                              onTap: () => onTapTarea(t),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
