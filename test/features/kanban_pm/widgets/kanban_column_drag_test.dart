import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plataforma_pm/features/kanban_pm/domain/entities/tarea.dart';
import 'package:plataforma_pm/features/kanban_pm/kanban_constants.dart';
import 'package:plataforma_pm/features/kanban_pm/presentation/widgets/kanban_board/kanban_column.dart';

void main() {
  testWidgets(
    'arrastrar una tarjeta a otra columna dispara onReordenar con el '
    'estatus de la columna destino',
    (tester) async {
      final columnaOrigen = KanbanColumna(
        estatus: TareaEstatus.tareas,
        titulo: 'Tareas',
        icono: Icons.list_alt_rounded,
        color: Colors.blue,
      );
      final columnaDestino = KanbanColumna(
        estatus: TareaEstatus.proceso,
        titulo: 'Proceso',
        icono: Icons.autorenew_rounded,
        color: Colors.orange,
      );
      final tarea = Tarea(
        id: 1,
        titulo: 'Mover esto',
        estatus: TareaEstatus.tareas,
      );

      Tarea? tareaRecibida;
      TareaEstatus? estatusRecibido;

      void onReordenar(Tarea t, TareaEstatus destino, {int? antesDeId}) {
        tareaRecibida = t;
        estatusRecibido = destino;
      }

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                SizedBox(
                  width: 280,
                  height: 600,
                  child: KanbanColumnView(
                    columna: columnaOrigen,
                    tareas: [tarea],
                    onTapTarea: (_) {},
                    onReordenar: onReordenar,
                    onRenombrar: (_) {},
                    onArchivarColumna: () {},
                    onArchivarTarjeta: (_) {},
                    onEliminarTarjeta: (_) {},
                  ),
                ),
                SizedBox(
                  width: 280,
                  height: 600,
                  child: KanbanColumnView(
                    columna: columnaDestino,
                    tareas: const [],
                    onTapTarea: (_) {},
                    onReordenar: onReordenar,
                    onRenombrar: (_) {},
                    onArchivarColumna: () {},
                    onArchivarTarjeta: (_) {},
                    onEliminarTarjeta: (_) {},
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final origen = tester.getCenter(find.text('Mover esto'));
      final destino = tester.getCenter(find.text('Sin tarjetas'));

      // El viewport de prueba por defecto (800x600) cae en la rama de
      // escritorio de `kanban_column.dart` (`Draggable` normal, no
      // `LongPressDraggable`), así que el arrastre arranca con un simple
      // pan sin necesidad de esperar el umbral de long-press.
      final gesture = await tester.startGesture(origen);
      await tester.pump(const Duration(milliseconds: 50));
      await gesture.moveTo(destino);
      await tester.pump(const Duration(milliseconds: 50));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(tareaRecibida?.id, tarea.id);
      expect(estatusRecibido, columnaDestino.estatus);
    },
  );
}
