import 'package:flutter/material.dart';
import '../../kanban_constants.dart';
import '../../domain/entities/tarea.dart';

/// Tarjeta que representa una [Tarea] dentro de una columna del tablero.
class KanbanTaskCard extends StatelessWidget {
  final Tarea tarea;
  final VoidCallback onTap;

  const KanbanTaskCard({super.key, required this.tarea, required this.onTap});

  String _fecha(DateTime d) {
    const meses = [
      'ene',
      'feb',
      'mar',
      'abr',
      'may',
      'jun',
      'jul',
      'ago',
      'sep',
      'oct',
      'nov',
      'dic',
    ];
    return '${d.day.toString().padLeft(2, '0')} ${meses[d.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    final vencida = tarea.vencida;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: KanbanColors.bg2,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: KanbanColors.borde),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: tarea.prioridad.color.withValues(alpha: 0.13),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      tarea.prioridad.etiqueta,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: tarea.prioridad.color,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (tarea.grupo.isNotEmpty)
                    Text(
                      tarea.grupo,
                      style: const TextStyle(
                        fontSize: 10,
                        color: KanbanColors.tdim,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                tarea.titulo,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: KanbanColors.texto,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (tarea.descripcion.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  tarea.descripcion,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: KanbanColors.tdim,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (tarea.actividades.isNotEmpty) ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: tarea.progreso,
                    minHeight: 5,
                    backgroundColor: KanbanColors.bg3,
                    valueColor: const AlwaysStoppedAnimation(
                      KanbanColors.accent,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  CircleAvatar(
                    radius: 11,
                    backgroundColor: KanbanColors.accentLight,
                    child: Text(
                      tarea.responsable.isNotEmpty
                          ? tarea.responsable[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: KanbanColors.accentDark,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      tarea.responsable.isEmpty
                          ? 'Sin asignar'
                          : tarea.responsable,
                      style: const TextStyle(
                        fontSize: 11,
                        color: KanbanColors.texto,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (tarea.actividades.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.checklist_rounded,
                            size: 12,
                            color: KanbanColors.tdim,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '${tarea.actividadesTerminadas}/${tarea.actividades.length}',
                            style: const TextStyle(
                              fontSize: 10.5,
                              color: KanbanColors.tdim,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (tarea.comentarios.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.chat_bubble_outline_rounded,
                            size: 12,
                            color: KanbanColors.tdim,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '${tarea.comentarios.length}',
                            style: const TextStyle(
                              fontSize: 10.5,
                              color: KanbanColors.tdim,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              if (tarea.fechaVencimiento != null) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      Icons.event_rounded,
                      size: 12,
                      color: vencida ? KanbanColors.danger : KanbanColors.tdim,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _fecha(tarea.fechaVencimiento!),
                      style: TextStyle(
                        fontSize: 10.5,
                        color: vencida
                            ? KanbanColors.danger
                            : KanbanColors.tdim,
                        fontWeight: vencida
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    if (vencida) ...[
                      const SizedBox(width: 4),
                      const Text(
                        'VENCIDA',
                        style: TextStyle(
                          fontSize: 9,
                          color: KanbanColors.danger,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
