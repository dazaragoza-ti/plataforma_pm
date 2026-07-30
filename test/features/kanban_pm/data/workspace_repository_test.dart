import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plataforma_pm/features/kanban_pm/data/usuario_directorio.dart';
import 'package:plataforma_pm/features/kanban_pm/data/workspace_repository.dart';

void main() {
  late InMemoryWorkspaceRepository repo;

  setUp(() {
    repo = InMemoryWorkspaceRepository();
  });

  test('arranca con "Mi tablero" ya creado (seed)', () async {
    final workspaces = await repo.listarWorkspaces();
    expect(workspaces, hasLength(1));
    expect(workspaces.first.nombre, 'Mi tablero');
  });

  group('crearWorkspace', () {
    test('agrega automáticamente al creador como miembro', () async {
      final creador = UsuarioDirectorio.instancia.porId('u2');
      final workspace = await repo.crearWorkspace(
        'Equipo de Ventas',
        Colors.blue,
        creadorUsuarioId: creador.id,
      );
      final miembros = await repo
          .kanbanRepositoryPara(workspace.id)
          .listarMiembros();
      expect(miembros.any((m) => m.usuarioId == creador.id), isTrue);
    });

    test('sin creadorUsuarioId no agrega ningún miembro', () async {
      final workspace = await repo.crearWorkspace('Sin dueño', Colors.grey);
      final miembros = await repo
          .kanbanRepositoryPara(workspace.id)
          .listarMiembros();
      expect(miembros, isEmpty);
    });

    test('un nombre vacío cae a un nombre por defecto', () async {
      final workspace = await repo.crearWorkspace('   ', Colors.grey);
      expect(workspace.nombre, 'Área de trabajo');
    });
  });

  group('listarWorkspacesDe', () {
    test('solo devuelve las áreas donde el usuario es miembro', () async {
      final u1 = UsuarioDirectorio.instancia.porId('u1');
      final u2 = UsuarioDirectorio.instancia.porId('u2');
      await repo.crearWorkspace(
        'Área de u1',
        Colors.blue,
        creadorUsuarioId: u1.id,
      );
      await repo.crearWorkspace(
        'Área de u2',
        Colors.green,
        creadorUsuarioId: u2.id,
      );
      final deU2 = await repo.listarWorkspacesDe(u2.id);
      expect(deU2.map((w) => w.nombre), contains('Área de u2'));
      expect(deU2.map((w) => w.nombre), isNot(contains('Área de u1')));
    });
  });

  group('eliminarWorkspace', () {
    test('ya no aparece en listarWorkspaces después de eliminarla', () async {
      final creada = await repo.crearWorkspace('Temporal', Colors.orange);
      await repo.eliminarWorkspace(creada.id);
      final workspaces = await repo.listarWorkspaces();
      expect(workspaces.map((w) => w.id), isNot(contains(creada.id)));
    });

    test('eliminar una mientras se listan todas no lanza (regresión de la '
        'condición de carrera en _repos[w.id])', () async {
      final creada = await repo.crearWorkspace('Se va a borrar', Colors.red);
      // Dispara ambas casi al mismo tiempo, sin esperar una antes que la
      // otra: antes, si `eliminarWorkspace` quitaba la entrada de `_repos`
      // justo cuando `listarWorkspaces` llegaba a esa área, `_repos[id]!`
      // lanzaba un null-check en vez de simplemente omitirla.
      final resultados = await Future.wait([
        repo.listarWorkspaces(),
        repo.eliminarWorkspace(creada.id),
      ]);
      final workspaces = resultados[0] as List;
      expect(workspaces, isNotEmpty);
    });
  });
}
