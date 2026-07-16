import 'package:flutter/material.dart';

import '../domain/entities/actividad.dart';
import '../domain/entities/comentario.dart';
import '../domain/entities/miembro.dart';
import '../domain/entities/tarea.dart';
import '../domain/entities/tarea_etiqueta.dart';
import '../domain/entities/tarea_plantilla.dart';
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

  Future<void> moverTarea(
    int tareaId,
    TareaEstatus nuevoEstatus, {
    int? posicion,
  });

  Future<void> eliminarTarea(int tareaId);

  Future<void> archivarTarea(int tareaId, bool archivada);

  Future<void> actualizarTarea(Tarea tarea);

  Future<int> agregarActividad(int tareaId, String descripcion);

  Future<void> toggleActividad(int tareaId, int actividadId);

  Future<void> eliminarActividad(int tareaId, int actividadId);

  Future<void> agregarComentario(int tareaId, String autor, String contenido);

  // Columnas (listas) del tablero.
  Future<List<KanbanColumna>> listarColumnas();

  Future<void> renombrarColumna(TareaEstatus estatus, String nuevoTitulo);

  Future<void> archivarColumna(TareaEstatus estatus, bool archivada);

  Future<void> reordenarColumnas(List<TareaEstatus> nuevoOrden);

  // Etiquetas (labels) del tablero.
  Future<List<TareaEtiqueta>> listarEtiquetas();

  Future<int> crearEtiqueta(String nombre, Color color);

  Future<void> actualizarEtiqueta(TareaEtiqueta etiqueta);

  Future<void> eliminarEtiqueta(int etiquetaId);

  // Miembros (personas) del tablero.
  Future<List<Miembro>> listarMiembros();

  Future<int> crearMiembro(String nombre, Color colorAvatar);

  Future<void> actualizarMiembro(Miembro miembro);

  Future<void> eliminarMiembro(int miembroId);

  // Plantillas (templates) editables para crear tarjetas rápido.
  Future<List<TareaPlantilla>> listarPlantillas();

  Future<int> crearPlantilla(TareaPlantilla plantilla);

  Future<void> actualizarPlantilla(TareaPlantilla plantilla);

  Future<void> eliminarPlantilla(int plantillaId);
}

/// Implementación en memoria con datos de ejemplo, útil para desarrollar y
/// probar la UI sin backend real.
class InMemoryKanbanRepository implements KanbanRepository {
  final List<Tarea> _tareas = [];
  final List<KanbanColumna> _columnas = List.of(kColumnas);
  final List<TareaEtiqueta> _etiquetas = [];
  final List<Miembro> _miembros = [];
  final List<TareaPlantilla> _plantillas = [];
  int _nextTareaId = 1;
  int _nextActividadId = 1;
  int _nextComentarioId = 1;
  int _nextEtiquetaId = 1;
  int _nextMiembroId = 1;
  int _nextPlantillaId = 1;

  InMemoryKanbanRepository() {
    _seed();
  }

  Future<void> _latencia() => Future.delayed(const Duration(milliseconds: 150));

  void _seed() {
    final ahora = DateTime.now();

    final etUrgente = _nextEtiquetaId++;
    final etCliente = _nextEtiquetaId++;
    final etInterno = _nextEtiquetaId++;
    final etBloqueado = _nextEtiquetaId++;
    _etiquetas.addAll([
      TareaEtiqueta(id: etUrgente, nombre: 'Urgente', color: const Color(0xFFEF4444)),
      TareaEtiqueta(id: etCliente, nombre: 'Cliente', color: const Color(0xFF3B82F6)),
      TareaEtiqueta(id: etInterno, nombre: 'Interno', color: const Color(0xFF22C55E)),
      TareaEtiqueta(id: etBloqueado, nombre: 'Bloqueado', color: const Color(0xFFA855F7)),
    ]);

    final miembrosSeed = <int>[];
    for (final nombre in kIntegrantesDemo) {
      final id = _nextMiembroId++;
      miembrosSeed.add(id);
      _miembros.add(
        Miembro(
          id: id,
          nombre: nombre,
          colorAvatar:
              kColorPaletteEtiquetas[(id - 1) % kColorPaletteEtiquetas.length],
        ),
      );
    }
    final mSalazar = miembrosSeed[0];
    final mMartinez = miembrosSeed[1];
    final mGomez = miembrosSeed[2];
    final mTorres = miembrosSeed[3];

    final idMedidas = _nextTareaId++;
    final idMaterial = _nextTareaId++;
    final idLamina = _nextTareaId++;
    final idCotizacion = _nextTareaId++;
    final idManual = _nextTareaId++;
    final idValidar = _nextTareaId++;
    final idLogo = _nextTareaId++;
    final idServidor = _nextTareaId++;

    var ordenTareas = 0;
    var ordenProceso = 0;
    var ordenPausa = 0;
    var ordenTerminado = 0;
    var ordenRevisado = 0;

    _tareas.addAll([
      Tarea(
        id: idMedidas,
        titulo: 'Levantar medidas en planta',
        estatus: TareaEstatus.terminado,
        prioridad: TareaPrioridad.alta,
        grupo: 'Producción',
        miembroIds: [mSalazar],
        asignadoPor: kUsuarioActualDemo,
        fechaInicio: ahora.subtract(const Duration(days: 2)),
        fechaVencimiento: ahora.subtract(const Duration(days: 1)),
        fechaInicioReal: ahora.subtract(const Duration(days: 2)),
        fechaFinReal: ahora,
        generales: kGeneralesDemo[2],
        nivel: kNivelDemo[0],
        importancia: kImportanciaDemo[0],
        orden: ordenTerminado++,
        etiquetaIds: [etInterno],
      ),
      Tarea(
        id: idMaterial,
        titulo: 'Calcular material necesario',
        estatus: TareaEstatus.proceso,
        prioridad: TareaPrioridad.alta,
        grupo: 'Producción',
        miembroIds: [mMartinez],
        asignadoPor: kUsuarioActualDemo,
        fechaInicio: ahora.subtract(const Duration(days: 1)),
        fechaVencimiento: ahora.add(const Duration(days: 1)),
        fechaInicioReal: ahora,
        actividades: [
          Actividad(
            id: _nextActividadId++,
            descripcion: 'Revisar plano',
            terminada: true,
          ),
          Actividad(id: _nextActividadId++, descripcion: 'Cotizar lámina'),
        ],
        orden: ordenProceso++,
        etiquetaIds: [etCliente],
        dependeDeIds: [idMedidas],
      ),
      Tarea(
        id: idLamina,
        titulo: 'Esperar lámina de proveedor',
        estatus: TareaEstatus.pausa,
        prioridad: TareaPrioridad.media,
        grupo: 'Producción',
        miembroIds: [mMartinez],
        asignadoPor: kUsuarioActualDemo,
        fechaInicio: ahora,
        fechaVencimiento: ahora.add(const Duration(days: 5)),
        orden: ordenPausa++,
        etiquetaIds: [etBloqueado],
        dependeDeIds: [idMaterial],
      ),
      Tarea(
        id: idCotizacion,
        titulo: 'Enviar cotización al cliente',
        estatus: TareaEstatus.tareas,
        prioridad: TareaPrioridad.urgente,
        grupo: 'Ventas',
        miembroIds: [mSalazar],
        asignadoPor: kUsuarioActualDemo,
        fechaInicio: ahora.add(const Duration(days: 1)),
        fechaVencimiento: ahora.add(const Duration(days: 3)),
        orden: ordenTareas++,
        etiquetaIds: [etUrgente, etCliente],
      ),
      Tarea(
        id: idManual,
        titulo: 'Redactar cambios al manual de calidad',
        estatus: TareaEstatus.terminado,
        prioridad: TareaPrioridad.media,
        grupo: 'Calidad',
        miembroIds: [mMartinez],
        asignadoPor: kUsuarioActualDemo,
        fechaInicio: ahora.subtract(const Duration(days: 7)),
        fechaVencimiento: ahora.subtract(const Duration(days: 5)),
        fechaInicioReal: ahora.subtract(const Duration(days: 7)),
        fechaFinReal: ahora.subtract(const Duration(days: 6)),
        orden: ordenTerminado++,
      ),
      Tarea(
        id: idValidar,
        titulo: 'Validar manual con jefatura',
        estatus: TareaEstatus.revisado,
        prioridad: TareaPrioridad.media,
        grupo: 'Calidad',
        miembroIds: [mGomez],
        asignadoPor: kUsuarioActualDemo,
        fechaInicio: ahora.add(const Duration(days: 8)),
        fechaVencimiento: ahora.add(const Duration(days: 12)),
        comentarios: [
          Comentario(
            id: _nextComentarioId++,
            autor: 'A. Martínez',
            contenido: 'Falta firma de dirección.',
            fecha: ahora.subtract(const Duration(hours: 5)),
          ),
        ],
        orden: ordenRevisado++,
        dependeDeIds: [idManual],
      ),
      Tarea(
        id: idLogo,
        titulo: 'Rediseño de logo interno',
        estatus: TareaEstatus.terminado,
        prioridad: TareaPrioridad.baja,
        grupo: 'Diseño',
        miembroIds: [mGomez],
        asignadoPor: kUsuarioActualDemo,
        fechaInicio: ahora.subtract(const Duration(days: 4)),
        fechaVencimiento: ahora.subtract(const Duration(days: 2)),
        fechaInicioReal: ahora.subtract(const Duration(days: 3)),
        fechaFinReal: ahora.subtract(const Duration(days: 1)),
        orden: ordenTerminado++,
        portada: const Color(0xFFA855F7),
      ),
      Tarea(
        id: idServidor,
        titulo: 'Aprobar compra de servidor',
        estatus: TareaEstatus.tareas,
        prioridad: TareaPrioridad.media,
        grupo: 'Sistemas',
        miembroIds: [mTorres],
        asignadoPor: kUsuarioActualDemo,
        fechaInicio: ahora.subtract(const Duration(days: 2)),
        fechaVencimiento: ahora.subtract(const Duration(days: 1)),
        orden: ordenTareas++,
      ),
    ]);

    _plantillas.addAll([
      TareaPlantilla(
        id: _nextPlantillaId++,
        nombre: 'Solicitud de cliente',
        tituloSugerido: 'Atender solicitud de ',
        descripcion: 'Detallar lo que pide el cliente y la fecha límite.',
        prioridad: TareaPrioridad.alta,
        grupo: 'Ventas',
        actividades: const ['Confirmar alcance', 'Cotizar', 'Enviar respuesta'],
      ),
      TareaPlantilla(
        id: _nextPlantillaId++,
        nombre: 'Reporte de falla',
        tituloSugerido: 'Falla: ',
        descripcion: 'Describir el síntoma, cuándo empezó y su impacto.',
        prioridad: TareaPrioridad.urgente,
        grupo: 'Sistemas',
        actividades: const ['Reproducir', 'Diagnosticar causa', 'Corregir', 'Validar'],
      ),
      TareaPlantilla(
        id: _nextPlantillaId++,
        nombre: 'Tarea interna',
        prioridad: TareaPrioridad.media,
        grupo: 'Producción',
        actividades: const [],
      ),
    ]);
  }

  int _indice(int tareaId) {
    final idx = _tareas.indexWhere((t) => t.id == tareaId);
    if (idx == -1) throw Exception('Tarea #$tareaId no encontrada');
    return idx;
  }

  void _renumerarColumna(TareaEstatus estatus) {
    final enColumna = _tareas.where((t) => t.estatus == estatus).toList()
      ..sort((a, b) => a.orden.compareTo(b.orden));
    for (var i = 0; i < enColumna.length; i++) {
      final idx = _tareas.indexWhere((t) => t.id == enColumna[i].id);
      _tareas[idx] = _tareas[idx].copyWith(orden: i);
    }
  }

  @override
  Future<List<Tarea>> listarTareas({String busqueda = ''}) async {
    await _latencia();
    final like = busqueda.trim().toLowerCase();
    final base = like.isEmpty
        ? _tareas
        : _tareas
              .where(
                (t) =>
                    t.titulo.toLowerCase().contains(like) ||
                    t.grupo.toLowerCase().contains(like) ||
                    t.miembroIds.any(
                      (id) => _miembros
                          .firstWhere(
                            (m) => m.id == id,
                            orElse: () => const Miembro(
                              id: -1,
                              nombre: '',
                              colorAvatar: Colors.transparent,
                            ),
                          )
                          .nombre
                          .toLowerCase()
                          .contains(like),
                    ),
              )
              .toList();
    final resultado = List<Tarea>.of(base)
      ..sort((a, b) => a.orden.compareTo(b.orden));
    return List.unmodifiable(resultado);
  }

  @override
  Future<int> crearTarea(Tarea tarea) async {
    await _latencia();
    final id = _nextTareaId++;
    final enColumna = _tareas.where((t) => t.estatus == tarea.estatus).length;
    _tareas.add(tarea.copyWith(id: id, orden: enColumna));
    return id;
  }

  @override
  Future<void> moverTarea(
    int tareaId,
    TareaEstatus nuevoEstatus, {
    int? posicion,
  }) async {
    await _latencia();
    final idx = _indice(tareaId);
    final origen = _tareas[idx].estatus;
    final destinoTareas = _tareas
        .where((t) => t.id != tareaId && t.estatus == nuevoEstatus)
        .toList()
      ..sort((a, b) => a.orden.compareTo(b.orden));
    final pos = (posicion ?? destinoTareas.length).clamp(
      0,
      destinoTareas.length,
    );
    destinoTareas.insert(pos, _tareas[idx]);
    for (var i = 0; i < destinoTareas.length; i++) {
      final tIdx = _tareas.indexWhere((t) => t.id == destinoTareas[i].id);
      _tareas[tIdx] = _tareas[tIdx].copyWith(
        estatus: nuevoEstatus,
        orden: i,
      );
    }
    if (origen != nuevoEstatus) {
      _renumerarColumna(origen);
      _registrarFechaRealDeEstatus(tareaId, nuevoEstatus);
    }
  }

  /// Sella `fechaInicioReal`/`fechaFinReal` la primera vez que una tarea
  /// entra a "proceso" o a "terminado"/"revisado", para poder comparar
  /// tiempo planeado vs. tiempo real en el Gantt. No pisa un sello ya
  /// existente: si la tarjeta se regresa y se vuelve a mover, se conserva
  /// el primer registro histórico.
  void _registrarFechaRealDeEstatus(int tareaId, TareaEstatus nuevoEstatus) {
    final idx = _indice(tareaId);
    final t = _tareas[idx];
    if (nuevoEstatus == TareaEstatus.proceso && t.fechaInicioReal == null) {
      _tareas[idx] = t.copyWith(fechaInicioReal: DateTime.now());
    } else if ((nuevoEstatus == TareaEstatus.terminado ||
            nuevoEstatus == TareaEstatus.revisado) &&
        t.fechaFinReal == null) {
      _tareas[idx] = t.copyWith(
        fechaInicioReal: t.fechaInicioReal ?? DateTime.now(),
        fechaFinReal: DateTime.now(),
      );
    }
  }

  @override
  Future<void> eliminarTarea(int tareaId) async {
    await _latencia();
    _tareas.removeWhere((t) => t.id == tareaId);
    for (var i = 0; i < _tareas.length; i++) {
      if (_tareas[i].dependeDeIds.contains(tareaId)) {
        _tareas[i] = _tareas[i].copyWith(
          dependeDeIds: _tareas[i].dependeDeIds
              .where((id) => id != tareaId)
              .toList(),
        );
      }
    }
  }

  @override
  Future<void> archivarTarea(int tareaId, bool archivada) async {
    await _latencia();
    final idx = _indice(tareaId);
    _tareas[idx] = _tareas[idx].copyWith(archivada: archivada);
    _renumerarColumna(_tareas[idx].estatus);
  }

  @override
  Future<void> actualizarTarea(Tarea tarea) async {
    await _latencia();
    final idx = _indice(tarea.id);
    _tareas[idx] = tarea;
    _reprogramarSucesoresEnCascada(tarea.id);
  }

  /// Empuja hacia adelante, recursivamente, cualquier tarea sucesora
  /// (`dependeDeIds` contiene [origenId]) cuyo inicio quede antes de
  /// `fechaVencimiento + 1 día` de la tarea en [origenId].
  ///
  /// El guard de ciclos es por *camino* (ancestros de la recursión actual),
  /// no un `Set` global de visitados — con un set global, un grafo en
  /// diamante (dos ramas distintas empujando la misma tarea) pierde el
  /// segundo empuje si la primera rama ya la marcó como visitada.
  void _reprogramarSucesoresEnCascada(
    int origenId, {
    List<int> camino = const [],
  }) {
    if (camino.contains(origenId)) return;
    final idx = _tareas.indexWhere((t) => t.id == origenId);
    if (idx == -1) return;
    final origen = _tareas[idx];
    if (origen.fechaVencimiento == null) return;
    final siguienteCamino = [...camino, origenId];
    for (final suc in _tareas
        .where((t) => t.dependeDeIds.contains(origenId))
        .toList()) {
      if (suc.fechaInicio == null || suc.fechaVencimiento == null) continue;
      final minInicio = origen.fechaVencimiento!.add(const Duration(days: 1));
      if (suc.fechaInicio!.isBefore(minInicio)) {
        final delta = minInicio.difference(suc.fechaInicio!);
        final sIdx = _tareas.indexWhere((t) => t.id == suc.id);
        _tareas[sIdx] = _tareas[sIdx].copyWith(
          fechaInicio: suc.fechaInicio!.add(delta),
          fechaVencimiento: suc.fechaVencimiento!.add(delta),
        );
        _reprogramarSucesoresEnCascada(suc.id, camino: siguienteCamino);
      }
    }
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

  @override
  Future<List<KanbanColumna>> listarColumnas() async {
    await _latencia();
    return List.unmodifiable(_columnas);
  }

  @override
  Future<void> renombrarColumna(TareaEstatus estatus, String nuevoTitulo) async {
    await _latencia();
    final idx = _columnas.indexWhere((c) => c.estatus == estatus);
    if (idx == -1) return;
    final titulo = nuevoTitulo.trim();
    if (titulo.isEmpty) return;
    _columnas[idx] = _columnas[idx].copyWith(titulo: titulo);
  }

  @override
  Future<void> archivarColumna(TareaEstatus estatus, bool archivada) async {
    await _latencia();
    final idx = _columnas.indexWhere((c) => c.estatus == estatus);
    if (idx == -1) return;
    _columnas[idx] = _columnas[idx].copyWith(archivada: archivada);
  }

  @override
  Future<void> reordenarColumnas(List<TareaEstatus> nuevoOrden) async {
    await _latencia();
    final porEstatus = {for (final c in _columnas) c.estatus: c};
    _columnas
      ..clear()
      ..addAll(nuevoOrden.map((e) => porEstatus[e]).whereType<KanbanColumna>());
  }

  @override
  Future<List<TareaEtiqueta>> listarEtiquetas() async {
    await _latencia();
    return List.unmodifiable(_etiquetas);
  }

  @override
  Future<int> crearEtiqueta(String nombre, Color color) async {
    await _latencia();
    final id = _nextEtiquetaId++;
    _etiquetas.add(TareaEtiqueta(id: id, nombre: nombre.trim(), color: color));
    return id;
  }

  @override
  Future<void> actualizarEtiqueta(TareaEtiqueta etiqueta) async {
    await _latencia();
    final idx = _etiquetas.indexWhere((e) => e.id == etiqueta.id);
    if (idx == -1) return;
    _etiquetas[idx] = etiqueta;
  }

  @override
  Future<void> eliminarEtiqueta(int etiquetaId) async {
    await _latencia();
    _etiquetas.removeWhere((e) => e.id == etiquetaId);
    for (var i = 0; i < _tareas.length; i++) {
      if (_tareas[i].etiquetaIds.contains(etiquetaId)) {
        _tareas[i] = _tareas[i].copyWith(
          etiquetaIds: _tareas[i].etiquetaIds
              .where((id) => id != etiquetaId)
              .toList(),
        );
      }
    }
  }

  @override
  Future<List<Miembro>> listarMiembros() async {
    await _latencia();
    return List.unmodifiable(_miembros);
  }

  @override
  Future<int> crearMiembro(String nombre, Color colorAvatar) async {
    await _latencia();
    final id = _nextMiembroId++;
    _miembros.add(
      Miembro(id: id, nombre: nombre.trim(), colorAvatar: colorAvatar),
    );
    return id;
  }

  @override
  Future<void> actualizarMiembro(Miembro miembro) async {
    await _latencia();
    final idx = _miembros.indexWhere((m) => m.id == miembro.id);
    if (idx == -1) return;
    _miembros[idx] = miembro;
  }

  @override
  Future<void> eliminarMiembro(int miembroId) async {
    await _latencia();
    _miembros.removeWhere((m) => m.id == miembroId);
    for (var i = 0; i < _tareas.length; i++) {
      if (_tareas[i].miembroIds.contains(miembroId)) {
        _tareas[i] = _tareas[i].copyWith(
          miembroIds: _tareas[i].miembroIds
              .where((id) => id != miembroId)
              .toList(),
        );
      }
    }
  }

  @override
  Future<List<TareaPlantilla>> listarPlantillas() async {
    await _latencia();
    return List.unmodifiable(_plantillas);
  }

  @override
  Future<int> crearPlantilla(TareaPlantilla plantilla) async {
    await _latencia();
    final id = _nextPlantillaId++;
    _plantillas.add(
      TareaPlantilla(
        id: id,
        nombre: plantilla.nombre.trim(),
        tituloSugerido: plantilla.tituloSugerido,
        descripcion: plantilla.descripcion,
        prioridad: plantilla.prioridad,
        grupo: plantilla.grupo,
        actividades: plantilla.actividades,
      ),
    );
    return id;
  }

  @override
  Future<void> actualizarPlantilla(TareaPlantilla plantilla) async {
    await _latencia();
    final idx = _plantillas.indexWhere((p) => p.id == plantilla.id);
    if (idx == -1) return;
    _plantillas[idx] = plantilla;
  }

  @override
  Future<void> eliminarPlantilla(int plantillaId) async {
    await _latencia();
    _plantillas.removeWhere((p) => p.id == plantillaId);
  }
}
