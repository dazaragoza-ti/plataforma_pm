import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plataforma_pm/features/kanban_pm/data/in_memory_kanban_repository.dart';
import 'package:plataforma_pm/features/kanban_pm/domain/entities/miembro.dart';
import 'package:plataforma_pm/features/kanban_pm/domain/entities/tarea_etiqueta.dart';
import 'package:plataforma_pm/features/kanban_pm/presentation/widgets/dialogs/filtros_dialog.dart';

void main() {
  testWidgets(
    'combina miembro y etiqueta seleccionados en el resultado devuelto',
    (tester) async {
      final repo = InMemoryKanbanRepository(conDatosDemo: false);
      const miembro = Miembro(id: 1, nombre: 'Ana', colorAvatar: Colors.red);
      const etiqueta = TareaEtiqueta(
        id: 1,
        nombre: 'Urgente',
        color: Colors.orange,
      );

      FiltrosResultado? resultado;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    resultado = await FiltrosDialog.show(
                      context,
                      repository: repo,
                      miembros: const [miembro],
                      etiquetas: const [etiqueta],
                      fechaDesde: null,
                      fechaHasta: null,
                      soloPendientes: false,
                      miembroIdsFiltro: const {},
                      departamentosFiltro: const {},
                      etiquetaIdsFiltro: const {},
                    );
                  },
                  child: const Text('Abrir filtros'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Abrir filtros'));
      // Dos `showDialog` en cadena (loading -> filtros reales): `pumpAndSettle`
      // deja correr ambas transiciones y el fetch simulado de por medio.
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilterChip, 'Ana'));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilterChip, 'Urgente'));
      await tester.pump();
      await tester.tap(find.text('Aplicar'));
      await tester.pumpAndSettle();

      expect(resultado, isNotNull);
      expect(resultado!.miembroIds, {miembro.id});
      expect(resultado!.etiquetaIds, {etiqueta.id});
    },
  );

  testWidgets('"Limpiar" vacía toda la selección hecha en el diálogo', (
    tester,
  ) async {
    final repo = InMemoryKanbanRepository(conDatosDemo: false);
    const miembro = Miembro(id: 1, nombre: 'Ana', colorAvatar: Colors.red);

    FiltrosResultado? resultado;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  resultado = await FiltrosDialog.show(
                    context,
                    repository: repo,
                    miembros: const [miembro],
                    etiquetas: const [],
                    fechaDesde: null,
                    fechaHasta: null,
                    soloPendientes: true,
                    miembroIdsFiltro: {miembro.id},
                    departamentosFiltro: const {},
                    etiquetaIdsFiltro: const {},
                  );
                },
                child: const Text('Abrir filtros'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Abrir filtros'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Limpiar'));
    await tester.pump();
    await tester.tap(find.text('Aplicar'));
    await tester.pumpAndSettle();

    expect(resultado, isNotNull);
    expect(resultado!.miembroIds, isEmpty);
    expect(resultado!.soloPendientes, isFalse);
  });
}
