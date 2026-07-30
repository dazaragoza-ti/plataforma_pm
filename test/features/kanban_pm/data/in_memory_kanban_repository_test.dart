import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plataforma_pm/features/kanban_pm/data/in_memory_kanban_repository.dart';
import 'package:plataforma_pm/features/kanban_pm/data/usuario_directorio.dart';
import 'package:plataforma_pm/features/kanban_pm/domain/entities/tarea.dart';
import 'package:plataforma_pm/features/kanban_pm/kanban_constants.dart';

void main() {
  late InMemoryKanbanRepository repo;

  setUp(() {
    // Sin datos de ejemplo: cada test arma exactamente las tareas que
    // necesita, en vez de convivir con las 8 tarjetas de la demo.
    repo = InMemoryKanbanRepository(conDatosDemo: false);
  });

  tearDown(() {
    // `usuarioActual` es un singleton global compartido entre tests — sin
    // resetearlo, un test que cambia de identidad "contamina" los que
    // corren después.
    usuarioActual.value = UsuarioDirectorio.instancia.listar().first;
  });

  group('crearTarea / obtenerTarea / listarTareas', () {
    test('crea una tarea y aparece en listarTareas', () async {
      final id = await repo.crearTarea(
        Tarea(id: 0, titulo: 'Nueva', estatus: TareaEstatus.tareas),
      );
      final tareas = await repo.listarTareas();
      expect(tareas.map((t) => t.id), contains(id));
      expect(tareas.firstWhere((t) => t.id == id).titulo, 'Nueva');
    });

    test('obtenerTarea devuelve null si el id no existe', () async {
      final t = await repo.obtenerTarea(999);
      expect(t, isNull);
    });

    test(
      'el historial de creación usa la identidad activa (usuarioActual)',
      () async {
        usuarioActual.value = UsuarioDirectorio.instancia.porId('u3');
        final id = await repo.crearTarea(
          Tarea(id: 0, titulo: 'X', estatus: TareaEstatus.tareas),
        );
        final t = await repo.obtenerTarea(id);
        expect(t!.historial, isNotEmpty);
        expect(t.historial.last.autor, 'R. Gómez');
      },
    );
  });

  group('moverTarea', () {
    test('mueve la tarea a la columna nueva', () async {
      final id = await repo.crearTarea(
        Tarea(id: 0, titulo: 'A', estatus: TareaEstatus.tareas),
      );
      await repo.moverTarea(id, TareaEstatus.proceso);
      final t = await repo.obtenerTarea(id);
      expect(t!.estatus, TareaEstatus.proceso);
    });

    test('respeta la posición pedida entre las tareas ya movidas', () async {
      final id1 = await repo.crearTarea(
        Tarea(id: 0, titulo: 'A', estatus: TareaEstatus.proceso),
      );
      final id2 = await repo.crearTarea(
        Tarea(id: 0, titulo: 'B', estatus: TareaEstatus.proceso),
      );
      final id3 = await repo.crearTarea(
        Tarea(id: 0, titulo: 'C', estatus: TareaEstatus.tareas),
      );
      await repo.moverTarea(id3, TareaEstatus.proceso, posicion: 0);
      final enProceso =
          (await repo.listarTareas())
              .where((t) => t.estatus == TareaEstatus.proceso)
              .toList()
            ..sort((a, b) => a.orden.compareTo(b.orden));
      expect(enProceso.map((t) => t.id).toList(), [id3, id1, id2]);
    });
  });

  group('búsqueda (listarTareas con busqueda)', () {
    test('encuentra por título', () async {
      await repo.crearTarea(
        Tarea(id: 0, titulo: 'Cotizar lámina', estatus: TareaEstatus.tareas),
      );
      await repo.crearTarea(
        Tarea(id: 0, titulo: 'Otra cosa', estatus: TareaEstatus.tareas),
      );
      final resultado = await repo.listarTareas(busqueda: 'lámina');
      expect(resultado, hasLength(1));
    });

    test('encuentra por nombre del miembro asignado', () async {
      final miembroId = await repo.crearMiembro(
        'Juan Pérez',
        const Color(0xFF000000),
      );
      await repo.crearTarea(
        Tarea(
          id: 0,
          titulo: 'Sin match en título',
          estatus: TareaEstatus.tareas,
          miembroIds: [miembroId],
        ),
      );
      final resultado = await repo.listarTareas(busqueda: 'juan');
      expect(resultado, hasLength(1));
    });
  });

  group('reordenarColumnas', () {
    test('cambia el orden reportado por listarColumnas', () async {
      final columnas = await repo.listarColumnas();
      final invertido = columnas
          .map((c) => c.estatus)
          .toList()
          .reversed
          .toList();
      await repo.reordenarColumnas(invertido);
      final nuevas = await repo.listarColumnas();
      expect(nuevas.map((c) => c.estatus).toList(), invertido);
    });
  });

  group('cascada de fechas por dependencia', () {
    test('empuja al sucesor si la predecesora se retrasa', () async {
      final idA = await repo.crearTarea(
        Tarea(
          id: 0,
          titulo: 'A',
          estatus: TareaEstatus.tareas,
          fechaInicio: DateTime(2026, 1, 1),
          fechaVencimiento: DateTime(2026, 1, 5),
        ),
      );
      final idB = await repo.crearTarea(
        Tarea(
          id: 0,
          titulo: 'B',
          estatus: TareaEstatus.tareas,
          fechaInicio: DateTime(2026, 1, 6),
          fechaVencimiento: DateTime(2026, 1, 10),
          dependeDeIds: [idA],
        ),
      );
      final a = (await repo.obtenerTarea(idA))!;
      final movidas = await repo.actualizarTarea(
        a.copyWith(fechaVencimiento: DateTime(2026, 1, 15)),
      );
      expect(movidas, greaterThan(0));
      final b = (await repo.obtenerTarea(idB))!;
      expect(b.fechaInicio!.isAfter(DateTime(2026, 1, 15)), isTrue);
    });

    test('un ciclo de dependencias no cuelga ni lanza', () async {
      final idA = await repo.crearTarea(
        Tarea(
          id: 0,
          titulo: 'A',
          estatus: TareaEstatus.tareas,
          fechaInicio: DateTime(2026, 1, 1),
          fechaVencimiento: DateTime(2026, 1, 5),
        ),
      );
      final idB = await repo.crearTarea(
        Tarea(
          id: 0,
          titulo: 'B',
          estatus: TareaEstatus.tareas,
          fechaInicio: DateTime(2026, 1, 6),
          fechaVencimiento: DateTime(2026, 1, 10),
          dependeDeIds: [idA],
        ),
      );
      // Cierra el ciclo: A también pasa a depender de B.
      final a = (await repo.obtenerTarea(idA))!;
      await repo.actualizarTarea(a.copyWith(dependeDeIds: [idB]));
      // El guard de ciclos es por camino de recursión (ver
      // `_reprogramarSucesoresEnCascada`); si regresara a un `Set` global de
      // visitados, este `actualizarTarea` sí podría quedarse recursando.
      final b = (await repo.obtenerTarea(idB))!;
      await repo.actualizarTarea(
        b.copyWith(fechaVencimiento: DateTime(2026, 1, 20)),
      );
    });
  });

  group('auto-pausa por subtarea', () {
    test(
      'se pausa sola al asignar responsable y se reanuda al completarla',
      () async {
        final id = await repo.crearTarea(
          Tarea(id: 0, titulo: 'Con subtarea', estatus: TareaEstatus.proceso),
        );
        final actId = await repo.agregarActividad(
          id,
          'Confirmar con proveedor',
        );
        // Una segunda subtarea sin terminar: así, al completar la primera,
        // "todas las actividades están listas" sigue siendo falso y el auto-
        // completado a "Terminado" (`_recalcularCompletadoPorActividades`) no
        // se dispara — aísla el comportamiento de auto-pausa/reanudo del de
        // auto-completado, que es un comportamiento aparte ya cubierto por
        // otro camino.
        await repo.agregarActividad(id, 'Otra subtarea pendiente');
        final miembroId = await repo.crearMiembro(
          'Responsable',
          const Color(0xFF000000),
        );
        await repo.asignarResponsableActividad(id, actId, miembroId: miembroId);
        var t = (await repo.obtenerTarea(id))!;
        expect(t.estatus, TareaEstatus.pausa);
        expect(t.pausadaPorSubtarea, isTrue);
        expect(t.estatusAntesDePausa, TareaEstatus.proceso);

        await repo.toggleActividad(id, actId);
        t = (await repo.obtenerTarea(id))!;
        expect(t.estatus, TareaEstatus.proceso);
        expect(t.pausadaPorSubtarea, isFalse);
        expect(t.estatusAntesDePausa, isNull);
      },
    );
  });
}
