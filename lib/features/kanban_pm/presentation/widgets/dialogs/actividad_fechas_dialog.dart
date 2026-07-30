import 'package:flutter/material.dart';

import '../../../kanban_constants.dart' show KanbanColors;
import 'kanban_alert_dialog.dart';

/// Fechas (con hora) elegidas para el trabajo de un responsable en una
/// subtarea — ver [ActividadFechasDialog].
class ActividadFechas {
  final DateTime? inicio;
  final DateTime? fin;

  const ActividadFechas({this.inicio, this.fin});
}

/// Diálogo que pide fecha y hora de inicio/fin planeadas al asignar el
/// responsable de una subtarea — igual que una tarea completa tiene su
/// propio rango de fechas, cada subtarea delegada también necesita el suyo
/// para poder compararse después contra lo real (ver el módulo Gantt).
class ActividadFechasDialog {
  static Future<ActividadFechas?> show(
    BuildContext context, {
    DateTime? inicioInicial,
    DateTime? finInicial,
  }) {
    var inicio = inicioInicial;
    var fin = finInicial;

    String fmt(DateTime d) =>
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

    return showDialog<ActividadFechas>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          Future<void> elegir({required bool esInicio}) async {
            final actual = (esInicio ? inicio : fin) ?? DateTime.now();
            final fecha = await showDatePicker(
              context: ctx,
              initialDate: actual,
              firstDate: DateTime.now().subtract(const Duration(days: 365)),
              lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
            );
            if (fecha == null || !ctx.mounted) return;
            final hora = await showTimePicker(
              context: ctx,
              initialTime: TimeOfDay.fromDateTime(actual),
            );
            if (hora == null || !ctx.mounted) return;
            final combinada = DateTime(
              fecha.year,
              fecha.month,
              fecha.day,
              hora.hour,
              hora.minute,
            );
            setDialogState(() {
              if (esInicio) {
                inicio = combinada;
                // Si el nuevo inicio queda después del fin ya elegido, el
                // fin se recorre junto con él — mismo comportamiento que
                // `tarea_detail_dialog.dart`/`gantt_bar.dart`, en vez de
                // dejar guardar un rango de fechas invertido.
                if (fin != null && combinada.isAfter(fin!)) fin = combinada;
              } else {
                fin = combinada;
                if (inicio != null && combinada.isBefore(inicio!)) {
                  inicio = combinada;
                }
              }
            });
          }

          Widget campo(String etiqueta, DateTime? valor, VoidCallback onTap) {
            return OutlinedButton.icon(
              onPressed: onTap,
              icon: const Icon(Icons.event_rounded, size: 15),
              label: Text(
                valor == null ? etiqueta : fmt(valor),
                style: const TextStyle(fontSize: 12),
              ),
            );
          }

          return kanbanAlertDialog(
            titulo: 'Fechas de la subtarea',
            content: SizedBox(
              width: 320,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cuándo debería empezar y terminar de trabajar en esto '
                    'el responsable.',
                    style: TextStyle(fontSize: 12, color: KanbanColors.tdim),
                  ),
                  const SizedBox(height: 14),
                  campo('Inicio…', inicio, () => elegir(esInicio: true)),
                  const SizedBox(height: 8),
                  campo('Fin…', fin, () => elegir(esInicio: false)),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Omitir'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(
                  ctx,
                ).pop(ActividadFechas(inicio: inicio, fin: fin)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: KanbanColors.accent,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Guardar'),
              ),
            ],
          );
        },
      ),
    );
  }
}
