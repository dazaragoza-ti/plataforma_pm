import 'package:flutter/material.dart';
import '../../../kanban_constants.dart';
import '../../../data/kanban_repository.dart';
import '../../../domain/entities/actividad.dart';
import '../../../domain/entities/miembro.dart';
import '../../../domain/entities/tarea.dart';
import '../../../domain/entities/tarea_plantilla.dart';

/// Diálogo para crear una nueva tarea. Si se le pasa [plantilla], precarga
/// título sugerido/descripción/prioridad/área/checklist de esa plantilla —
/// el usuario puede seguir editando todo antes de crear la tarjeta.
class NuevaTareaDialog extends StatefulWidget {
  final KanbanRepository repository;
  final List<KanbanColumna> columnas;
  final List<Miembro> miembros;
  final TareaPlantilla? plantilla;

  const NuevaTareaDialog({
    super.key,
    required this.repository,
    required this.columnas,
    required this.miembros,
    this.plantilla,
  });

  static Future<int?> show(
    BuildContext context, {
    required KanbanRepository repository,
    required List<KanbanColumna> columnas,
    required List<Miembro> miembros,
    TareaPlantilla? plantilla,
  }) {
    return showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (_) => NuevaTareaDialog(
        repository: repository,
        columnas: columnas,
        miembros: miembros,
        plantilla: plantilla,
      ),
    );
  }

  @override
  State<NuevaTareaDialog> createState() => _NuevaTareaDialogState();
}

class _NuevaTareaDialogState extends State<NuevaTareaDialog> {
  late final _tituloCtrl = TextEditingController(
    text: widget.plantilla?.tituloSugerido ?? '',
  );
  late final _descripcionCtrl = TextEditingController(
    text: widget.plantilla?.descripcion ?? '',
  );
  late final Set<int> _miembroIdsSeleccionados = {
    ...?widget.plantilla?.miembroIds,
  };
  // `_grupo`/`_estatus` ya no se eligen en este formulario (ver comentario
  // más abajo en `build`), pero siguen determinando con qué área/columna
  // se crea la tarjeta: heredado de la plantilla o, sin plantilla, vacío /
  // la primera columna del tablero.
  late final String? _grupo = (widget.plantilla?.grupo.isNotEmpty ?? false)
      ? widget.plantilla!.grupo
      : null;
  late TareaPrioridad _prioridad =
      widget.plantilla?.prioridad ?? TareaPrioridad.media;
  late final TareaEstatus _estatus = widget.columnas.isNotEmpty
      ? widget.columnas.first.estatus
      : TareaEstatus.tareas;
  DateTime? _fechaVencimiento;
  bool _guardando = false;

  @override
  void dispose() {
    _tituloCtrl.dispose();
    _descripcionCtrl.dispose();
    super.dispose();
  }

  Future<void> _elegirFecha() async {
    final fecha = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 3)),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (fecha != null) setState(() => _fechaVencimiento = fecha);
  }

  Future<void> _crear() async {
    if (_tituloCtrl.text.trim().isEmpty) return;
    // Sin este chequeo, crear una tarjeta nueva directo en una columna con
    // límite de WIP (p. ej. Proceso, límite 1) era la única de las 4 formas
    // de llegar a esa columna que no respetaba el límite — arrastrar,
    // mover en lote y "Iniciar/Reabrir" del detalle ya lo bloqueaban.
    KanbanColumna? columna;
    for (final c in widget.columnas) {
      if (c.estatus == _estatus) {
        columna = c;
        break;
      }
    }
    final limite = columna?.limiteWip;
    if (limite != null) {
      final todas = await widget.repository.listarTareas();
      final ocupadas = todas
          .where((t) => !t.archivada && t.estatus == _estatus)
          .length;
      if (ocupadas >= limite) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Ya hay ${ocupadas == 1 ? 'una tarjeta' : '$ocupadas tarjetas'} '
                'en "${columna!.titulo}" (límite $limite). Elige otra '
                'columna o créala y muévela después.',
              ),
              backgroundColor: KanbanColors.danger,
            ),
          );
        }
        return;
      }
    }
    if (!mounted) return;
    setState(() => _guardando = true);
    try {
      final id = await widget.repository.crearTarea(
        Tarea(
          id: 0,
          titulo: _tituloCtrl.text.trim(),
          descripcion: _descripcionCtrl.text.trim(),
          estatus: _estatus,
          prioridad: _prioridad,
          grupo: _grupo ?? '',
          asignadoPor: kUsuarioActualDemo,
          miembroIds: _miembroIdsSeleccionados.toList(),
          etiquetaIds: widget.plantilla?.etiquetaIds ?? const [],
          portada: widget.plantilla?.portada,
          fechaInicio: DateTime.now(),
          fechaVencimiento: _fechaVencimiento,
          // El repositorio reasigna estos ids al crear la tarea (ver
          // `crearTarea`); el `0` es solo un placeholder.
          actividades: [
            for (final desc in widget.plantilla?.actividades ?? const [])
              Actividad(id: 0, descripcion: desc),
          ],
        ),
      );
      if (mounted) Navigator.of(context).pop(id);
    } catch (ex) {
      // El detalle técnico va a la consola, no a la cara del usuario: útil
      // para depurar, pero un mensaje como "Exception: ..." no le dice
      // nada a quien está creando una tarea.
      debugPrint('Error al crear tarea: $ex');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('No se pudo crear la tarea. Intenta de nuevo.'),
            backgroundColor: KanbanColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: KanbanColors.bg2,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              decoration: BoxDecoration(
                color: KanbanColors.bg2,
                border: Border(bottom: BorderSide(color: KanbanColors.borde)),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Nueva tarea',
                          style: TextStyle(
                            fontSize: 15,
                            color: KanbanColors.texto,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (widget.plantilla != null)
                          Text(
                            'Desde plantilla: ${widget.plantilla!.nombre}',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: KanbanColors.accentDark,
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      color: KanbanColors.tdim,
                      size: 20,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _campo('Título', _tituloCtrl),
                  const SizedBox(height: 10),
                  _campo('Descripción', _descripcionCtrl, maxLines: 3),
                  const SizedBox(height: 10),
                  Text(
                    'Miembros',
                    style: TextStyle(fontSize: 12, color: KanbanColors.tdim),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final m in widget.miembros)
                        FilterChip(
                          avatar: CircleAvatar(
                            backgroundColor: m.colorAvatar,
                            child: Text(
                              m.nombre.isNotEmpty
                                  ? m.nombre[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          label: Text(
                            m.nombre,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: KanbanColors.texto,
                            ),
                          ),
                          selected: _miembroIdsSeleccionados.contains(m.id),
                          backgroundColor: KanbanColors.bg3,
                          selectedColor: m.colorAvatar.withValues(alpha: 0.3),
                          side: BorderSide(color: KanbanColors.borde),
                          onSelected: (v) => setState(() {
                            if (v) {
                              _miembroIdsSeleccionados.add(m.id);
                            } else {
                              _miembroIdsSeleccionados.remove(m.id);
                            }
                          }),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Área y Columna ya no se piden aquí: toda tarea nueva
                  // entra a la primera columna del tablero (ver `_estatus`)
                  // y sin área asignada — moverla a otra columna o asignarle
                  // un área se hace después, desde la tarjeta ya creada.
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<TareaPrioridad>(
                          initialValue: _prioridad,
                          decoration: _decoracion('Prioridad'),
                          items: [
                            for (final p in TareaPrioridad.values)
                              DropdownMenuItem(
                                value: p,
                                child: Text(
                                  p.etiqueta,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: KanbanColors.texto,
                                  ),
                                ),
                              ),
                          ],
                          onChanged: (v) => setState(
                            () => _prioridad = v ?? TareaPrioridad.media,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _elegirFecha,
                          icon: Icon(
                            Icons.event_rounded,
                            size: 16,
                            color: KanbanColors.accent,
                          ),
                          label: Text(
                            _fechaVencimiento == null
                                ? 'Vencimiento'
                                : '${_fechaVencimiento!.day}/${_fechaVencimiento!.month}/${_fechaVencimiento!.year}',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: KanbanColors.texto,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            side: BorderSide(color: KanbanColors.borde),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _guardando ? null : _crear,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: KanbanColors.accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: _guardando
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Crear tarea'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _decoracion(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(fontSize: 12, color: KanbanColors.tdim),
      isDense: true,
      filled: true,
      fillColor: KanbanColors.bg3,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: KanbanColors.borde),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: KanbanColors.borde),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: KanbanColors.accent, width: 2),
      ),
    );
  }

  Widget _campo(String label, TextEditingController ctrl, {int maxLines = 1}) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      style: TextStyle(fontSize: 13, color: KanbanColors.texto),
      decoration: _decoracion(label),
    );
  }
}
