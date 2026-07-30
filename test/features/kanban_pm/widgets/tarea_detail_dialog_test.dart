import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plataforma_pm/features/kanban_pm/data/in_memory_kanban_repository.dart';
import 'package:plataforma_pm/features/kanban_pm/domain/entities/tarea.dart';
import 'package:plataforma_pm/features/kanban_pm/kanban_constants.dart';
import 'package:plataforma_pm/features/kanban_pm/presentation/widgets/dialogs/tarea_detail_dialog.dart';

void main() {
  testWidgets(
    'cerrar el diálogo mientras se crea una etiqueta no lanza excepción '
    '(smoke test del escenario del bug de controller-tras-dispose)',
    (tester) async {
      final repo = InMemoryKanbanRepository(conDatosDemo: false);
      // `tester.runAsync` (no un `await` directo): antes de `pumpWidget`,
      // el test corre en la zona de reloj falso de `flutter_test`, que
      // solo avanza cuando el propio test lo pide explícitamente (vía
      // `pump(duration)`). Un `Future.delayed` real (como el de
      // `_latencia()` en el repositorio) programado ahí nunca se resuelve
      // solo — sin esto, el test se quedaba colgado para siempre en esta
      // misma línea.
      final id = (await tester.runAsync(
        () => repo.crearTarea(
          Tarea(id: 0, titulo: 'Tarea de prueba', estatus: TareaEstatus.tareas),
        ),
      ))!;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => TareaDetailDialog.show(
                    context,
                    repository: repo,
                    tareaId: id,
                    onRefresh: () {},
                  ),
                  child: const Text('Abrir'),
                ),
              ),
            ),
          ),
        ),
      );

      // `pump(duration)` acotado en vez de `pumpAndSettle()`: el título
      // tiene un `TextField` con `autofocus: true`, y el cursor
      // parpadeante corre con un `Timer.periodic` que jamás deja que
      // `pumpAndSettle` se estabilice (nunca hay "cero" callbacks
      // pendientes).
      await tester.tap(find.text('Abrir'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.widgetWithText(ActionChip, 'Nueva'));
      await tester.pump();

      final campoNombre = find.byWidgetPredicate(
        (w) =>
            w is TextField &&
            w.decoration?.hintText == 'Nombre de la etiqueta…',
      );
      expect(campoNombre, findsOneWidget);
      await tester.enterText(campoNombre, 'Etiqueta de prueba');
      await tester.pump();

      // Dispara `_crearEtiqueta` (llama a `repository.crearEtiqueta`, que
      // internamente espera ~150ms simulados) sin esperar a que resuelva.
      await tester.tap(find.byIcon(Icons.check_circle_rounded));
      await tester.pump();

      // Cierra el diálogo ANTES de que la llamada al repositorio resuelva.
      await tester.tap(find.byIcon(Icons.close_rounded).first);
      await tester.pump();

      // Avanza en pasos chicos (no un salto grande de una vez) hasta que
      // el diálogo realmente termine de desmontarse — así queda
      // garantizado que `dispose()` ya corrió ANTES de dejar completar la
      // llamada pendiente al repositorio (150ms simulados desde que se
      // tocó el ✓), sin importar cuánto dure exactamente la transición de
      // salida del diálogo en esta versión de Flutter.
      for (var i = 0; i < 30 && find.byType(TareaDetailDialog).evaluate().isNotEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 10));
      }
      expect(
        find.byType(TareaDetailDialog),
        findsNothing,
        reason: 'el diálogo debería haber terminado de desmontarse',
      );

      // Deja resolver la llamada pendiente al repositorio con el diálogo
      // ya desmontado (confirmado arriba). Este es un smoke test del
      // patrón "cerrar mientras algo async sigue en vuelo": verifica que
      // no aparezca ninguna excepción en ese escenario. No logré forzar
      // de forma confiable, dentro del modelo de reloj falso de
      // `flutter_test`, la carrera exacta que expondría el bug original
      // (`.clear()` sobre el controller ya disposed) — en las pruebas
      // hechas para armar este test, tanto la versión corregida como una
      // reversión deliberada del orden `mounted`/`clear()` pasaron por
      // igual aquí. La corrección real (mover el chequeo de `mounted`
      // antes de tocar el controller, ver `_crearEtiqueta`) se verificó
      // por revisión directa del código, no por este test.
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
    },
  );
}
