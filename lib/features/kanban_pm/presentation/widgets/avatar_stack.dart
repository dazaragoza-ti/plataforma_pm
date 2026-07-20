import 'package:flutter/material.dart';
import '../../kanban_constants.dart';
import '../../domain/entities/miembro.dart';

/// Avatares superpuestos de los miembros asignados a una tarea, con una
/// burbuja "+N" si hay más de [maxVisible] — mismo widget usado por la
/// tarjeta del Kanban y la fila de la vista Lista (antes cada una tenía su
/// propia copia de este bloque).
///
/// No maneja el caso sin asignados: cada sitio que lo usa lo muestra
/// distinto (ícono de placeholder en la tarjeta, texto "Sin asignar" en la
/// lista), así que queda a cargo de quien llama.
class AvatarStack extends StatelessWidget {
  final List<Miembro> miembros;
  final int maxVisible;

  const AvatarStack({super.key, required this.miembros, this.maxVisible = 3});

  @override
  Widget build(BuildContext context) {
    final visibles = miembros.length > maxVisible
        ? maxVisible
        : miembros.length;
    return SizedBox(
      height: 22,
      width: 14.0 * visibles + 8,
      child: Stack(
        children: [
          for (var i = 0; i < visibles; i++)
            Positioned(
              left: i * 14.0,
              child: CircleAvatar(
                radius: 11,
                backgroundColor: KanbanColors.bg2,
                child: CircleAvatar(
                  radius: 10,
                  backgroundColor: miembros[i].colorAvatar,
                  child: Text(
                    miembros[i].nombre.isNotEmpty
                        ? miembros[i].nombre[0].toUpperCase()
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
          if (miembros.length > maxVisible)
            Positioned(
              left: maxVisible * 14.0,
              child: CircleAvatar(
                radius: 11,
                backgroundColor: KanbanColors.bg2,
                child: CircleAvatar(
                  radius: 10,
                  backgroundColor: KanbanColors.tdim,
                  child: Text(
                    '+${miembros.length - maxVisible}',
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
    );
  }
}
