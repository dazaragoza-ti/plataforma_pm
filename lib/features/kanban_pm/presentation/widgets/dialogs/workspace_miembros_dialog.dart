import 'package:flutter/material.dart';
import '../../../data/kanban_repository.dart';
import '../../../data/usuario_directorio.dart';
import '../../../domain/entities/miembro.dart';
import '../../../domain/entities/usuario.dart';
import '../../../kanban_constants.dart';
import 'confirmar_eliminar_dialog.dart';
import 'kanban_alert_dialog.dart';

/// Gestor de miembros de un área de trabajo: agregar a alguien del
/// directorio global o quitar a un miembro existente — accesible desde el
/// menú "⋯" de cada tarjeta del selector de áreas de trabajo.
class WorkspaceMiembrosDialog extends StatefulWidget {
  final KanbanRepository repository;
  final String tituloWorkspace;

  const WorkspaceMiembrosDialog({
    super.key,
    required this.repository,
    required this.tituloWorkspace,
  });

  static Future<void> show(
    BuildContext context, {
    required KanbanRepository repository,
    required String tituloWorkspace,
  }) {
    return showDialog(
      context: context,
      builder: (_) => WorkspaceMiembrosDialog(
        repository: repository,
        tituloWorkspace: tituloWorkspace,
      ),
    );
  }

  @override
  State<WorkspaceMiembrosDialog> createState() =>
      _WorkspaceMiembrosDialogState();
}

class _WorkspaceMiembrosDialogState extends State<WorkspaceMiembrosDialog> {
  List<Miembro> _miembros = [];
  bool _cargando = true;

  /// Ids del directorio con un `crearMiembro` en curso — deshabilita su
  /// chip mientras tanto. Sin esto, un doble tap rápido sobre la misma
  /// persona (antes de que el primer `await` resuelva y la quite de
  /// "disponibles") podía crear dos `Miembro` distintos ligados al mismo
  /// `usuarioId`, ya que el repositorio no deduplica por ese campo.
  final Set<String> _agregando = {};

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  void _error(Object ex) {
    if (!mounted) return;
    kanbanToast(context, 'Error: $ex', ok: false);
  }

  Future<void> _cargar() async {
    try {
      final miembros = await widget.repository.listarMiembros();
      if (!mounted) return;
      setState(() {
        _miembros = miembros;
        _cargando = false;
      });
    } catch (ex) {
      if (mounted) setState(() => _cargando = false);
      _error(ex);
    }
  }

  Future<void> _agregar(Usuario u) async {
    if (_agregando.contains(u.id)) return;
    setState(() => _agregando.add(u.id));
    try {
      await widget.repository.crearMiembro(
        u.nombre,
        u.colorAvatar,
        usuarioId: u.id,
      );
      await _cargar();
    } catch (ex) {
      _error(ex);
    } finally {
      if (mounted) setState(() => _agregando.remove(u.id));
    }
  }

  Future<void> _quitar(Miembro m) async {
    // Sin este guard, quitar a la última persona con `usuarioId` (ligada
    // al directorio global) deja el área sin nadie a quien
    // `listarWorkspacesDe` se la muestre nunca más — ni siquiera a quien
    // acaba de quitarla, porque este mismo diálogo solo es alcanzable
    // desde la tarjeta del área en el selector. El área seguiría
    // existiendo en el repositorio (con todas sus tareas), pero
    // inaccesible para siempre.
    final quedariaAlguienConAcceso = _miembros.any(
      (x) => x.id != m.id && x.usuarioId != null,
    );
    if (!quedariaAlguienConAcceso) {
      kanbanToast(
        context,
        'No puedes quitar a la última persona con acceso a esta área: '
        'quedaría inaccesible para siempre. Agrega a alguien más antes de '
        'quitarla.',
        ok: false,
      );
      return;
    }
    final ok = await confirmarEliminar(
      context,
      titulo: 'Quitar miembro',
      mensaje:
          '¿Quitar a "${m.nombre}" de "${widget.tituloWorkspace}"? Se le '
          'quita de las tarjetas y subtareas donde estuviera asignado en '
          'esta área.',
      etiquetaConfirmar: 'Quitar',
    );
    if (!ok) return;
    try {
      await widget.repository.eliminarMiembro(m.id);
      await _cargar();
    } catch (ex) {
      _error(ex);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Gente del directorio global que ya existe pero todavía no es
    // miembro de esta área — mismo criterio que el selector equivalente
    // de `tarea_detail_dialog.dart` para "agregar de otra área".
    final disponibles = UsuarioDirectorio.instancia
        .listar()
        .where((u) => !_miembros.any((m) => m.usuarioId == u.id))
        .toList();
    return kanbanAlertDialog(
      titulo: 'Miembros de "${widget.tituloWorkspace}"',
      content: SizedBox(
        width: 340,
        child: _cargando
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_miembros.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Todavía no hay miembros en esta área.',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: KanbanColors.tdim,
                        ),
                      ),
                    )
                  else
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 260),
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [for (final m in _miembros) _tile(m)],
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  if (disponibles.isEmpty)
                    Text(
                      'No hay más personas del directorio para agregar.',
                      style: TextStyle(fontSize: 11.5, color: KanbanColors.tdim),
                    )
                  else ...[
                    Text(
                      'AGREGAR MIEMBRO',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                        color: KanbanColors.tdim,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final u in disponibles)
                          ActionChip(
                            avatar: CircleAvatar(
                              radius: 10,
                              backgroundColor: u.colorAvatar,
                              child: Text(
                                u.nombre.isNotEmpty
                                    ? u.nombre[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            label: Text(
                              u.nombre,
                              style: TextStyle(
                                fontSize: 11.5,
                                color: KanbanColors.texto,
                              ),
                            ),
                            backgroundColor: KanbanColors.bg3,
                            side: BorderSide(color: KanbanColors.borde),
                            onPressed: _agregando.contains(u.id)
                                ? null
                                : () => _agregar(u),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }

  Widget _tile(Miembro m) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: m.colorAvatar,
            child: Text(
              m.nombre.isNotEmpty ? m.nombre[0].toUpperCase() : '?',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              m.nombre,
              style: TextStyle(fontSize: 13, color: KanbanColors.texto),
            ),
          ),
          IconButton(
            tooltip: 'Quitar de esta área',
            icon: Icon(
              Icons.delete_outline_rounded,
              size: 18,
              color: KanbanColors.tdim,
            ),
            onPressed: () => _quitar(m),
          ),
        ],
      ),
    );
  }
}
