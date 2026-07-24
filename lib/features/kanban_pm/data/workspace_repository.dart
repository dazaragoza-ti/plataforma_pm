import 'package:flutter/material.dart';

import '../domain/entities/workspace.dart';
import '../kanban_constants.dart';
import 'kanban_repository.dart';

/// Catálogo de áreas de trabajo — cada una es un tablero Kanban completo e
/// independiente. Diseño análogo a [KanbanRepository]: pensado para que el
/// día que exista un backend real baste con implementar esta misma interfaz.
abstract class WorkspaceRepository {
  Future<List<Workspace>> listarWorkspaces();

  Future<Workspace> crearWorkspace(String nombre, Color color);

  Future<void> renombrarWorkspace(String id, String nuevoNombre);

  Future<void> cambiarColorWorkspace(String id, Color color);

  Future<void> eliminarWorkspace(String id);

  /// El [KanbanRepository] del área de trabajo [workspaceId] — cada una
  /// tiene el suyo propio (columnas/tareas/etiquetas/miembros separados).
  /// Lanza si el id no existe: quien llama siempre lo obtiene de una
  /// [Workspace] ya listada, así que un id inexistente es un bug, no un
  /// caso a manejar en silencio.
  KanbanRepository kanbanRepositoryPara(String workspaceId);
}

/// Implementación en memoria: la primera área de trabajo ("Mi tablero")
/// arranca con los mismos datos de ejemplo que usaba el módulo antes de
/// tener áreas de trabajo, para no perder el tablero de demostración; las
/// que crea la persona usuaria arrancan vacías.
class InMemoryWorkspaceRepository implements WorkspaceRepository {
  final List<Workspace> _workspaces = [];
  final Map<String, KanbanRepository> _repos = {};
  int _nextId = 1;

  InMemoryWorkspaceRepository() {
    _seed();
  }

  Future<void> _latencia() => Future.delayed(const Duration(milliseconds: 150));

  void _seed() {
    final id = 'ws_${_nextId++}';
    _workspaces.add(
      Workspace(
        id: id,
        nombre: 'Mi tablero',
        color: kColorPaletteEtiquetas[0],
        fechaCreacion: DateTime.now(),
      ),
    );
    _repos[id] = InMemoryKanbanRepository();
  }

  @override
  Future<List<Workspace>> listarWorkspaces() async {
    await _latencia();
    // El conteo de tarjetas no se guarda en `_workspaces` (cambia con cada
    // acción dentro del tablero, llevarlo sincronizado ahí sería
    // duplicar estado) — se calcula fresco contra el `KanbanRepository` de
    // cada área justo antes de devolver la lista.
    final resultado = <Workspace>[];
    for (final w in _workspaces) {
      final tareas = await _repos[w.id]!.listarTareas();
      resultado.add(
        w.copyWith(tareasCount: tareas.where((t) => !t.archivada).length),
      );
    }
    return List.unmodifiable(resultado);
  }

  @override
  Future<Workspace> crearWorkspace(String nombre, Color color) async {
    await _latencia();
    final id = 'ws_${_nextId++}';
    final workspace = Workspace(
      id: id,
      nombre: nombre.trim().isEmpty ? 'Área de trabajo' : nombre.trim(),
      color: color,
      fechaCreacion: DateTime.now(),
    );
    _workspaces.add(workspace);
    _repos[id] = InMemoryKanbanRepository(conDatosDemo: false);
    return workspace;
  }

  @override
  Future<void> renombrarWorkspace(String id, String nuevoNombre) async {
    await _latencia();
    final idx = _workspaces.indexWhere((w) => w.id == id);
    if (idx == -1) return;
    final nombre = nuevoNombre.trim();
    if (nombre.isEmpty) return;
    _workspaces[idx] = _workspaces[idx].copyWith(nombre: nombre);
  }

  @override
  Future<void> cambiarColorWorkspace(String id, Color color) async {
    await _latencia();
    final idx = _workspaces.indexWhere((w) => w.id == id);
    if (idx == -1) return;
    _workspaces[idx] = _workspaces[idx].copyWith(color: color);
  }

  @override
  Future<void> eliminarWorkspace(String id) async {
    await _latencia();
    _workspaces.removeWhere((w) => w.id == id);
    _repos.remove(id);
  }

  @override
  KanbanRepository kanbanRepositoryPara(String workspaceId) {
    final repo = _repos[workspaceId];
    if (repo == null) {
      throw StateError('El área de trabajo "$workspaceId" no existe.');
    }
    return repo;
  }
}
