import '../domain/entities/actividad.dart';
import '../domain/entities/comentario.dart';
import '../domain/entities/tarea.dart';
import '../kanban_constants.dart';

/// Contrato de acceso a datos del módulo Kanban PM.
///
/// Diseño propio, pensado para que el día que exista un backend/API real
/// baste con implementar esta misma interfaz (`ApiKanbanRepository
/// implements KanbanRepository`) sin tocar la capa de presentación — igual
/// que se hizo para `bitacora_pintura`.
abstract class KanbanRepository {
  Future<List<Tarea>> listarTareas({String busqueda = ''});

  Future<int> crearTarea(Tarea tarea);

  Future<void> moverTarea(int tareaId, TareaEstatus nuevoEstatus);

  Future<void> eliminarTarea(int tareaId);

  Future<void> actualizarTarea(Tarea tarea);

  Future<int> agregarActividad(int tareaId, String descripcion);

  Future<void> toggleActividad(int tareaId, int actividadId);

  Future<void> eliminarActividad(int tareaId, int actividadId);

  Future<void> agregarComentario(int tareaId, String autor, String contenido);
}

/// Implementación en memoria con datos de ejemplo, útil para desarrollar y
/// probar la UI sin backend real.
class InMemoryKanbanRepository implements KanbanRepository {
  final List<Tarea> _tareas = [];
  int _nextTareaId = 1;
  int _nextActividadId = 1;
  int _nextComentarioId = 1;

  InMemoryKanbanRepository() {
    _seed();
  }

  Future<void> _latencia() => Future.delayed(const Duration(milliseconds: 150));

  void _seed() {
    final ahora = DateTime.now();
    _tareas.addAll([
      Tarea(
        id: _nextTareaId++,
        titulo: 'Levantar medidas en planta',
        estatus: TareaEstatus.terminado,
        prioridad: TareaPrioridad.alta,
        grupo: 'Producción',
        responsable: 'J. Salazar',
        asignadoPor: kUsuarioActualDemo,
        fechaInicio: ahora.subtract(const Duration(days: 2)),
        fechaVencimiento: ahora.subtract(const Duration(days: 1)),
        generales: kGeneralesDemo[2],
        nivel: kNivelDemo[0],
        importancia: kImportanciaDemo[0],
      ),
      Tarea(
        id: _nextTareaId++,
        titulo: 'Calcular material necesario',
        estatus: TareaEstatus.proceso,
        prioridad: TareaPrioridad.alta,
        grupo: 'Producción',
        responsable: 'A. Martínez',
        asignadoPor: kUsuarioActualDemo,
        fechaVencimiento: ahora.add(const Duration(days: 1)),
        actividades: [
          Actividad(
            id: _nextActividadId++,
            descripcion: 'Revisar plano',
            terminada: true,
          ),
          Actividad(id: _nextActividadId++, descripcion: 'Cotizar lámina'),
        ],
      ),
      Tarea(
        id: _nextTareaId++,
        titulo: 'Esperar lámina de proveedor',
        estatus: TareaEstatus.pausa,
        prioridad: TareaPrioridad.media,
        grupo: 'Producción',
        responsable: 'A. Martínez',
        asignadoPor: kUsuarioActualDemo,
        fechaVencimiento: ahora.add(const Duration(days: 5)),
      ),
      Tarea(
        id: _nextTareaId++,
        titulo: 'Enviar cotización al cliente',
        estatus: TareaEstatus.tareas,
        prioridad: TareaPrioridad.urgente,
        grupo: 'Ventas',
        responsable: 'J. Salazar',
        asignadoPor: kUsuarioActualDemo,
        fechaVencimiento: ahora.add(const Duration(days: 3)),
      ),
      Tarea(
        id: _nextTareaId++,
        titulo: 'Redactar cambios al manual de calidad',
        estatus: TareaEstatus.terminado,
        prioridad: TareaPrioridad.media,
        grupo: 'Calidad',
        responsable: 'A. Martínez',
        asignadoPor: kUsuarioActualDemo,
        fechaVencimiento: ahora.subtract(const Duration(days: 5)),
      ),
      Tarea(
        id: _nextTareaId++,
        titulo: 'Validar manual con jefatura',
        estatus: TareaEstatus.revisado,
        prioridad: TareaPrioridad.media,
        grupo: 'Calidad',
        responsable: 'R. Gómez',
        asignadoPor: kUsuarioActualDemo,
        fechaVencimiento: ahora.add(const Duration(days: 12)),
        comentarios: [
          Comentario(
            id: _nextComentarioId++,
            autor: 'A. Martínez',
            contenido: 'Falta firma de dirección.',
            fecha: ahora.subtract(const Duration(hours: 5)),
          ),
        ],
      ),
      Tarea(
        id: _nextTareaId++,
        titulo: 'Rediseño de logo interno',
        estatus: TareaEstatus.terminado,
        prioridad: TareaPrioridad.baja,
        grupo: 'Diseño',
        responsable: 'R. Gómez',
        asignadoPor: kUsuarioActualDemo,
        fechaVencimiento: ahora.subtract(const Duration(days: 2)),
      ),
      Tarea(
        id: _nextTareaId++,
        titulo: 'Aprobar compra de servidor',
        estatus: TareaEstatus.tareas,
        prioridad: TareaPrioridad.media,
        grupo: 'Sistemas',
        responsable: 'L. Torres',
        asignadoPor: kUsuarioActualDemo,
        fechaVencimiento: ahora.subtract(const Duration(days: 1)),
      ),
    ]);
  }

  int _indice(int tareaId) {
    final idx = _tareas.indexWhere((t) => t.id == tareaId);
    if (idx == -1) throw Exception('Tarea #$tareaId no encontrada');
    return idx;
  }

  @override
  Future<List<Tarea>> listarTareas({String busqueda = ''}) async {
    await _latencia();
    final like = busqueda.trim().toLowerCase();
    if (like.isEmpty) return List.unmodifiable(_tareas);
    return _tareas
        .where(
          (t) =>
              t.titulo.toLowerCase().contains(like) ||
              t.responsable.toLowerCase().contains(like) ||
              t.grupo.toLowerCase().contains(like),
        )
        .toList();
  }

  @override
  Future<int> crearTarea(Tarea tarea) async {
    await _latencia();
    final id = _nextTareaId++;
    _tareas.add(tarea.copyWith(id: id));
    return id;
  }

  @override
  Future<void> moverTarea(int tareaId, TareaEstatus nuevoEstatus) async {
    await _latencia();
    final idx = _indice(tareaId);
    _tareas[idx] = _tareas[idx].copyWith(estatus: nuevoEstatus);
  }

  @override
  Future<void> eliminarTarea(int tareaId) async {
    await _latencia();
    _tareas.removeWhere((t) => t.id == tareaId);
  }

  @override
  Future<void> actualizarTarea(Tarea tarea) async {
    await _latencia();
    final idx = _indice(tarea.id);
    _tareas[idx] = tarea;
  }

  @override
  Future<int> agregarActividad(int tareaId, String descripcion) async {
    await _latencia();
    final idx = _indice(tareaId);
    final id = _nextActividadId++;
    final actividades = [
      ..._tareas[idx].actividades,
      Actividad(id: id, descripcion: descripcion),
    ];
    _tareas[idx] = _tareas[idx].copyWith(actividades: actividades);
    return id;
  }

  @override
  Future<void> toggleActividad(int tareaId, int actividadId) async {
    await _latencia();
    final idx = _indice(tareaId);
    final actividades = _tareas[idx].actividades.map((a) {
      return a.id == actividadId ? a.copyWith(terminada: !a.terminada) : a;
    }).toList();
    _tareas[idx] = _tareas[idx].copyWith(actividades: actividades);
  }

  @override
  Future<void> eliminarActividad(int tareaId, int actividadId) async {
    await _latencia();
    final idx = _indice(tareaId);
    final actividades = _tareas[idx].actividades
        .where((a) => a.id != actividadId)
        .toList();
    _tareas[idx] = _tareas[idx].copyWith(actividades: actividades);
  }

  @override
  Future<void> agregarComentario(
    int tareaId,
    String autor,
    String contenido,
  ) async {
    await _latencia();
    final idx = _indice(tareaId);
    final comentarios = [
      ..._tareas[idx].comentarios,
      Comentario(
        id: _nextComentarioId++,
        autor: autor,
        contenido: contenido,
        fecha: DateTime.now(),
      ),
    ];
    _tareas[idx] = _tareas[idx].copyWith(comentarios: comentarios);
  }
}
