import 'package:flutter/material.dart';
import '../../kanban_constants.dart';
import '../../domain/entities/miembro.dart';
import '../../domain/entities/tarea.dart';
import '../../domain/entities/tarea_etiqueta.dart';

/// Tarjeta que representa una [Tarea] dentro de una columna del tablero,
/// con look estilo Trello: portada, etiquetas de color, pastillas de
/// checklist/fecha y acciones rápidas siempre visibles.
class KanbanTaskCard extends StatelessWidget {
  final Tarea tarea;
  final List<TareaEtiqueta> etiquetas;
  final List<Miembro> miembros;
  final VoidCallback onTap;
  final VoidCallback? onArchivar;
  final VoidCallback? onEliminar;

  const KanbanTaskCard({
    super.key,
    required this.tarea,
    this.etiquetas = const [],
    this.miembros = const [],
    required this.onTap,
    this.onArchivar,
    this.onEliminar,
  });

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

  Widget _pill({
    required IconData icon,
    required String texto,
    required Color color,
    Color? fondo,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: fondo ?? color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 3),
          Text(
            texto,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vencida = tarea.vencida;
    final checklistCompleto =
        tarea.actividades.isNotEmpty && tarea.progreso >= 1.0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: KanbanColors.cardDecoration(radius: 10),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (tarea.portada != null)
                    Container(height: 34, color: tarea.portada),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 34, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (etiquetas.isNotEmpty) ...[
                          Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children: [
                              for (final et in etiquetas)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: et.color,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    et.nombre,
                                    style: const TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                        ],
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: tarea.prioridad.color.withValues(
                                    alpha: 0.4,
                                  ),
                                ),
                              ),
                              child: Text(
                                tarea.prioridad.etiqueta,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: tarea.prioridad.color,
                                ),
                              ),
                            ),
                            const Spacer(),
                            if (tarea.grupo.isNotEmpty)
                              Text(
                                tarea.grupo,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: KanbanColors.tdim,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          tarea.titulo,
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                            height: 1.25,
                            color: KanbanColors.texto,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (tarea.descripcion.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            tarea.descripcion,
                            style: TextStyle(
                              fontSize: 12,
                              color: KanbanColors.tdim,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        if (tarea.actividades.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: tarea.progreso,
                              minHeight: 5,
                              backgroundColor: KanbanColors.bg3,
                              valueColor: AlwaysStoppedAnimation(
                                checklistCompleto
                                    ? KanbanColors.ok
                                    : KanbanColors.accent,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            if (miembros.isEmpty)
                              CircleAvatar(
                                radius: 11,
                                backgroundColor: KanbanColors.bg3,
                                child: Icon(
                                  Icons.person_outline_rounded,
                                  size: 13,
                                  color: KanbanColors.tdim,
                                ),
                              )
                            else
                              SizedBox(
                                height: 22,
                                width:
                                    14.0 *
                                        (miembros.length > 3
                                            ? 3
                                            : miembros.length) +
                                    8,
                                child: Stack(
                                  children: [
                                    for (
                                      var i = 0;
                                      i <
                                          (miembros.length > 3
                                              ? 3
                                              : miembros.length);
                                      i++
                                    )
                                      Positioned(
                                        left: i * 14.0,
                                        child: CircleAvatar(
                                          radius: 11,
                                          backgroundColor: KanbanColors.bg2,
                                          child: CircleAvatar(
                                            radius: 10,
                                            backgroundColor:
                                                miembros[i].colorAvatar,
                                            child: Text(
                                              miembros[i].nombre.isNotEmpty
                                                  ? miembros[i].nombre[0]
                                                        .toUpperCase()
                                                  : '?',
                                              style: const TextStyle(
                                                fontSize: 9,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    if (miembros.length > 3)
                                      Positioned(
                                        left: 3 * 14.0,
                                        child: CircleAvatar(
                                          radius: 11,
                                          backgroundColor: KanbanColors.bg2,
                                          child: CircleAvatar(
                                            radius: 10,
                                            backgroundColor:
                                                KanbanColors.tdim,
                                            child: Text(
                                              '+${miembros.length - 3}',
                                              style: const TextStyle(
                                                fontSize: 8,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                miembros.isEmpty
                                    ? 'Sin asignar'
                                    : miembros.length == 1
                                    ? miembros.first.nombre
                                    : '${miembros.first.nombre} +${miembros.length - 1}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: KanbanColors.texto,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            if (tarea.actividades.isNotEmpty)
                              _pill(
                                icon: Icons.checklist_rounded,
                                texto:
                                    '${tarea.actividadesTerminadas}/${tarea.actividades.length}',
                                color: checklistCompleto
                                    ? KanbanColors.ok
                                    : KanbanColors.tdim,
                              ),
                            if (tarea.comentarios.isNotEmpty)
                              _pill(
                                icon: Icons.chat_bubble_outline_rounded,
                                texto: '${tarea.comentarios.length}',
                                color: KanbanColors.tdim,
                              ),
                            if (tarea.dependeDeIds.isNotEmpty)
                              _pill(
                                icon: Icons.link_rounded,
                                texto: '${tarea.dependeDeIds.length}',
                                color: KanbanColors.tdim,
                              ),
                            if (tarea.fechaVencimiento != null)
                              _pill(
                                icon: Icons.event_rounded,
                                texto: _fecha(tarea.fechaVencimiento!),
                                color: vencida
                                    ? KanbanColors.danger
                                    : KanbanColors.tdim,
                                fondo: vencida
                                    ? KanbanColors.dangerLight
                                    : null,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (onArchivar != null || onEliminar != null)
                Positioned(
                  top: tarea.portada != null ? 38 : 4,
                  right: 4,
                  child: PopupMenuButton<String>(
                    tooltip: 'Más acciones',
                    padding: EdgeInsets.zero,
                    icon: Icon(
                      Icons.more_horiz_rounded,
                      size: 16,
                      color: KanbanColors.tdim,
                    ),
                    onSelected: (v) {
                      if (v == 'archivar') onArchivar?.call();
                      if (v == 'eliminar') onEliminar?.call();
                    },
                    itemBuilder: (context) => [
                      if (onArchivar != null)
                        const PopupMenuItem(
                          value: 'archivar',
                          child: Text(
                            'Archivar tarjeta',
                            style: TextStyle(fontSize: 12.5),
                          ),
                        ),
                      if (onEliminar != null)
                        const PopupMenuItem(
                          value: 'eliminar',
                          child: Text(
                            'Eliminar tarjeta',
                            style: TextStyle(fontSize: 12.5),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
