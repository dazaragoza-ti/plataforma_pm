import 'package:flutter/material.dart';
import '../../../data/kanban_repository.dart';
import '../../../domain/entities/miembro.dart';
import '../../../domain/entities/tarea_etiqueta.dart';
import '../../../kanban_constants.dart' show KanbanColors;

/// Selección hecha en [FiltrosDialog] — quien llama decide cómo aplicarla
/// (normalmente `setState` + recargar), este diálogo no toca el estado de
/// la pantalla que lo invoca.
class FiltrosResultado {
  const FiltrosResultado({
    required this.fechaDesde,
    required this.fechaHasta,
    required this.soloPendientes,
    required this.miembroIds,
    required this.departamentos,
    required this.etiquetaIds,
  });

  final DateTime? fechaDesde;
  final DateTime? fechaHasta;
  final bool soloPendientes;
  final Set<int> miembroIds;
  final Set<String> departamentos;
  final Set<int> etiquetaIds;
}

/// Diálogo de filtros compartido por Kanban/Lista/Gráficas/Gantt.
class FiltrosDialog {
  static Future<FiltrosResultado?> show(
    BuildContext context, {
    required KanbanRepository repository,
    required List<Miembro> miembros,
    required List<TareaEtiqueta> etiquetas,
    required DateTime? fechaDesde,
    required DateTime? fechaHasta,
    required bool soloPendientes,
    required Set<int> miembroIdsFiltro,
    required Set<String> departamentosFiltro,
    required Set<int> etiquetaIdsFiltro,
  }) async {
    var desde = fechaDesde;
    var hasta = fechaHasta;
    var pendientes = soloPendientes;
    var miembroIds = Set<int>.of(miembroIdsFiltro);
    var departamentos = Set<String>.of(departamentosFiltro);
    var etiquetaIds = Set<int>.of(etiquetaIdsFiltro);

    // Los departamentos no tienen catálogo propio (son texto libre en
    // `Tarea.grupo`) — se derivan de *todas* las tareas, no de la lista ya
    // filtrada, para no perder opciones que el filtro actual esconde.
    final todasLasTareas = await repository.listarTareas();
    final departamentosDisponibles =
        todasLasTareas
            .map((t) => t.grupo)
            .where((g) => g.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    if (!context.mounted) return null;

    Future<void> elegirFecha(
      BuildContext dialogContext,
      StateSetter setDialogState, {
      required bool esInicio,
    }) async {
      final fecha = await showDatePicker(
        context: dialogContext,
        initialDate: (esInicio ? desde : hasta) ?? DateTime.now(),
        firstDate: DateTime.now().subtract(const Duration(days: 365)),
        lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      );
      if (fecha == null) return;
      setDialogState(() => esInicio ? desde = fecha : hasta = fecha);
    }

    String fmt(DateTime d) =>
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

    // Mismo lenguaje visual que el resto del módulo (acento naranja, sin
    // el check de Material por defecto): un `FilterChip` sin personalizar
    // hereda el color primario azul del tema ambiente de la app, que no
    // combina con nada más de este diálogo.
    Widget filtroChip({
      required String label,
      required bool selected,
      required ValueChanged<bool> onSelected,
    }) => FilterChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: selected ? Colors.white : KanbanColors.texto,
        ),
      ),
      selected: selected,
      onSelected: onSelected,
      showCheckmark: false,
      selectedColor: KanbanColors.accent,
      backgroundColor: KanbanColors.bg3,
      side: BorderSide(
        color: selected ? KanbanColors.accent : KanbanColors.borde,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );

    Widget seccion(String titulo) => Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 6),
      child: Text(
        titulo.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
          color: KanbanColors.tdim,
        ),
      ),
    );

    return showDialog<FiltrosResultado>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            backgroundColor: KanbanColors.bg2,
            surfaceTintColor: Colors.transparent,
            title: Text('Filtros', style: TextStyle(color: KanbanColors.texto)),
            content: SizedBox(
              width: 380,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 460),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => elegirFecha(
                                ctx,
                                setDialogState,
                                esInicio: true,
                              ),
                              icon: const Icon(
                                Icons.calendar_today_rounded,
                                size: 14,
                              ),
                              label: Text(
                                desde == null ? 'Desde' : fmt(desde!),
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => elegirFecha(
                                ctx,
                                setDialogState,
                                esInicio: false,
                              ),
                              icon: const Icon(
                                Icons.calendar_today_rounded,
                                size: 14,
                              ),
                              label: Text(
                                hasta == null ? 'Hasta' : fmt(hasta!),
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        value: pendientes,
                        onChanged: (v) =>
                            setDialogState(() => pendientes = v ?? true),
                        title: Text(
                          'Solo pendientes',
                          style: TextStyle(
                            fontSize: 13,
                            color: KanbanColors.texto,
                          ),
                        ),
                      ),
                      if (miembros.isNotEmpty) ...[
                        seccion('Personas'),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final m in miembros)
                              filtroChip(
                                label: m.nombre,
                                selected: miembroIds.contains(m.id),
                                onSelected: (v) => setDialogState(() {
                                  v
                                      ? miembroIds.add(m.id)
                                      : miembroIds.remove(m.id);
                                }),
                              ),
                          ],
                        ),
                      ],
                      if (departamentosDisponibles.isNotEmpty) ...[
                        seccion('Departamento'),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final d in departamentosDisponibles)
                              filtroChip(
                                label: d,
                                selected: departamentos.contains(d),
                                onSelected: (v) => setDialogState(() {
                                  v
                                      ? departamentos.add(d)
                                      : departamentos.remove(d);
                                }),
                              ),
                          ],
                        ),
                      ],
                      if (etiquetas.isNotEmpty) ...[
                        seccion('Etiquetas'),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final e in etiquetas)
                              FilterChip(
                                label: Text(
                                  e.nombre,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.white,
                                  ),
                                ),
                                showCheckmark: false,
                                backgroundColor: e.color.withValues(
                                  alpha: 0.55,
                                ),
                                selectedColor: e.color,
                                side: BorderSide(
                                  color: etiquetaIds.contains(e.id)
                                      ? e.color
                                      : Colors.transparent,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                selected: etiquetaIds.contains(e.id),
                                onSelected: (v) => setDialogState(() {
                                  v
                                      ? etiquetaIds.add(e.id)
                                      : etiquetaIds.remove(e.id);
                                }),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => setDialogState(() {
                  desde = null;
                  hasta = null;
                  pendientes = false;
                  miembroIds = {};
                  departamentos = {};
                  etiquetaIds = {};
                }),
                child: const Text('Limpiar'),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(
                  FiltrosResultado(
                    fechaDesde: desde,
                    fechaHasta: hasta,
                    soloPendientes: pendientes,
                    miembroIds: miembroIds,
                    departamentos: departamentos,
                    etiquetaIds: etiquetaIds,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: KanbanColors.accent,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Aplicar'),
              ),
            ],
          );
        },
      ),
    );
  }
}
