import 'package:flutter/material.dart';

import '../domain/entities/actividad.dart';
import '../domain/entities/comentario.dart';
import '../domain/entities/historial_evento.dart';
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
  /// Busca por título, área, nombre de miembro asignado o texto de
  /// cualquier subtarea (a cualquier profundidad del árbol de actividades).
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

  /// Agrega una subtarea. Si [padreId] es `null` se agrega al nivel raíz de
  /// la tarea; si no, se agrega como subtarea de la actividad con ese id
  /// (a cualquier profundidad del árbol) — así el responsable de una
  /// subtarea puede a su vez delegar partes de su trabajo.
  Future<int> agregarActividad(int tareaId, String descripcion, {int? padreId});

  Future<void> toggleActividad(int tareaId, int actividadId);

  Future<void> eliminarActividad(int tareaId, int actividadId);

  /// Asigna (o limpia, si ambos vienen `null`) el responsable de una
  /// subtarea — persona o departamento, excluyentes entre sí. Puede dejar
  /// a la tarea auto-pausada mientras el responsable no la resuelva; ver
  /// [Tarea.pausadaPorSubtarea].
  Future<void> asignarResponsableActividad(
    int tareaId,
    int actividadId, {
    int? miembroId,
    String? departamento,
  });

  Future<void> agregarComentario(
    int tareaId,
    String autor,
    String contenido, {
    String? adjuntoPath,
    String? adjuntoNombre,
  });

  // Columnas (listas) del tablero.
  Future<List<KanbanColumna>> listarColumnas();

  Future<void> renombrarColumna(TareaEstatus estatus, String nuevoTitulo);

  Future<void> archivarColumna(TareaEstatus estatus, bool archivada);

  Future<void> reordenarColumnas(List<TareaEstatus> nuevoOrden);

  /// Fija (o quita, si [limite] es `null`) el límite de WIP sugerido de una
  /// columna — solo un aviso visual, no impide soltar una tarjeta de más.
  Future<void> actualizarLimiteWipColumna(TareaEstatus estatus, int? limite);

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
  int _nextHistorialId = 1;

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
      TareaEtiqueta(
        id: etUrgente,
        nombre: 'Urgente',
        color: const Color(0xFFEF4444),
      ),
      TareaEtiqueta(
        id: etCliente,
        nombre: 'Cliente',
        color: const Color(0xFF3B82F6),
      ),
      TareaEtiqueta(
        id: etInterno,
        nombre: 'Interno',
        color: const Color(0xFF22C55E),
      ),
      TareaEtiqueta(
        id: etBloqueado,
        nombre: 'Bloqueado',
        color: const Color(0xFFA855F7),
      ),
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
        historial: [
          HistorialEvento(
            id: _nextHistorialId++,
            autor: kUsuarioActualDemo,
            mensaje: 'Creó la tarjeta',
            fecha: ahora.subtract(const Duration(days: 2, hours: 1)),
          ),
          HistorialEvento(
            id: _nextHistorialId++,
            autor: kUsuarioActualDemo,
            mensaje: 'Movió la tarjeta de "TAREAS" a "PROCESO"',
            fecha: ahora.subtract(const Duration(days: 2)),
          ),
          HistorialEvento(
            id: _nextHistorialId++,
            autor: kUsuarioActualDemo,
            mensaje: 'Movió la tarjeta de "PROCESO" a "TERMINADO"',
            fecha: ahora,
          ),
        ],
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
          Actividad(
            id: _nextActividadId++,
            descripcion: 'Confirmar precio con proveedor',
            miembroId: mSalazar,
          ),
        ],
        orden: ordenProceso++,
        etiquetaIds: [etCliente],
        dependeDeIds: [idMedidas],
        historial: [
          HistorialEvento(
            id: _nextHistorialId++,
            autor: kUsuarioActualDemo,
            mensaje: 'Creó la tarjeta',
            fecha: ahora.subtract(const Duration(days: 1, minutes: 30)),
          ),
          HistorialEvento(
            id: _nextHistorialId++,
            autor: kUsuarioActualDemo,
            mensaje: 'Movió la tarjeta de "TAREAS" a "PROCESO"',
            fecha: ahora.subtract(const Duration(days: 1)),
          ),
          HistorialEvento(
            id: _nextHistorialId++,
            autor: kUsuarioActualDemo,
            mensaje: 'Marcó la subtarea "Revisar plano" como completada',
            fecha: ahora.subtract(const Duration(hours: 20)),
          ),
          HistorialEvento(
            id: _nextHistorialId++,
            autor: kUsuarioActualDemo,
            mensaje:
                'Asignó a J. Salazar como responsable de '
                '"Confirmar precio con proveedor"',
            fecha: ahora.subtract(const Duration(hours: 2)),
          ),
        ],
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
        actividades: [
          Actividad(
            id: _nextActividadId++,
            descripcion: 'Confirmar fecha de entrega con proveedor',
            miembroId: mSalazar,
          ),
        ],
        orden: ordenPausa++,
        etiquetaIds: [etBloqueado],
        dependeDeIds: [idMaterial],
        historial: [
          HistorialEvento(
            id: _nextHistorialId++,
            autor: kUsuarioActualDemo,
            mensaje: 'Creó la tarjeta',
            fecha: ahora.subtract(const Duration(hours: 1)),
          ),
          HistorialEvento(
            id: _nextHistorialId++,
            autor: kUsuarioActualDemo,
            mensaje:
                'Asignó a J. Salazar como responsable de '
                '"Confirmar fecha de entrega con proveedor"',
            fecha: ahora.subtract(const Duration(minutes: 30)),
          ),
        ],
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
        actividades: [
          Actividad(
            id: _nextActividadId++,
            descripcion: 'Revisar cumplimiento normativo',
            terminada: true,
            departamento: 'Calidad',
          ),
        ],
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
        actividades: [
          Actividad(
            id: _nextActividadId++,
            descripcion: 'Exportar archivos finales',
            terminada: true,
            miembroId: mGomez,
          ),
        ],
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
        actividades: [
          Actividad(
            id: _nextActividadId++,
            descripcion: 'Cotizar con al menos 2 proveedores',
            departamento: 'Sistemas',
          ),
        ],
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
        actividades: const [
          'Reproducir',
          'Diagnosticar causa',
          'Corregir',
          'Validar',
        ],
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

  String _tituloColumna(TareaEstatus estatus) => _columnas
      .firstWhere(
        (c) => c.estatus == estatus,
        orElse: () => KanbanColumna(
          estatus: estatus,
          titulo: estatus.name,
          icono: Icons.bookmark_rounded,
          color: Colors.transparent,
        ),
      )
      .titulo;

  /// Agrega una entrada al historial de la tarea [tareaId]. No falla si la
  /// tarea ya no existe (p. ej. una cascada que llega tarde tras borrarla).
  void _registrarHistorial(int tareaId, String mensaje) {
    final idx = _tareas.indexWhere((t) => t.id == tareaId);
    if (idx == -1) return;
    _tareas[idx] = _tareas[idx].copyWith(
      historial: [
        ..._tareas[idx].historial,
        HistorialEvento(
          id: _nextHistorialId++,
          autor: kUsuarioActualDemo,
          mensaje: mensaje,
          fecha: DateTime.now(),
        ),
      ],
    );
  }

  Actividad? _buscarActividad(List<Actividad> lista, int id) {
    for (final a in lista) {
      if (a.id == id) return a;
      final enHijas = _buscarActividad(a.subActividades, id);
      if (enHijas != null) return enHijas;
    }
    return null;
  }

  /// `true` si el contenido de algún comentario de [lista] contiene [like]
  /// — usado por la búsqueda del tablero para que también encuentre
  /// tarjetas por lo dicho en sus comentarios.
  bool _comentariosContienen(List<Comentario> lista, String like) =>
      lista.any((c) => c.contenido.toLowerCase().contains(like));

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
                    ) ||
                    _actividadesContienen(t.actividades, like) ||
                    _comentariosContienen(t.comentarios, like),
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
    // Reasigna ids de actividad frescos (en vez de confiar en los que traiga
    // `tarea`, p. ej. desde una plantilla): son locales al formulario que
    // creó la tarea, así que podrían repetirse con el id que `_nextActividadId`
    // le dé después a una actividad agregada desde el detalle de la tarjeta.
    final actividades = [
      for (final a in tarea.actividades) a.copyWith(id: _nextActividadId++),
    ];
    _tareas.add(
      tarea.copyWith(id: id, orden: enColumna, actividades: actividades),
    );
    _registrarHistorial(id, 'Creó la tarjeta');
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
    final destinoTareas =
        _tareas
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
      _tareas[tIdx] = _tareas[tIdx].copyWith(estatus: nuevoEstatus, orden: i);
    }
    if (origen != nuevoEstatus) {
      _renumerarColumna(origen);
      _registrarFechaRealDeEstatus(tareaId, nuevoEstatus);
      _registrarHistorial(
        tareaId,
        'Movió la tarjeta de "${_tituloColumna(origen)}" '
        'a "${_tituloColumna(nuevoEstatus)}"',
      );
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
    _registrarHistorial(
      tareaId,
      archivada ? 'Archivó la tarjeta' : 'Restauró la tarjeta',
    );
  }

  @override
  Future<void> actualizarTarea(Tarea tarea) async {
    await _latencia();
    final idx = _indice(tarea.id);
    final anterior = _tareas[idx];
    _tareas[idx] = tarea;
    _reprogramarSucesoresEnCascada(tarea.id);
    _registrarCambiosDeActualizacion(anterior, tarea);
  }

  bool _mismosIds(List<int> a, List<int> b) =>
      a.length == b.length && a.toSet().containsAll(b);

  /// Compara [anterior] contra [nueva] y agrega al historial un único
  /// mensaje combinado con lo que cambió — sin registrar nada si el
  /// guardado no modificó nada (p. ej. abrir y cerrar el detalle sin tocar
  /// campos).
  void _registrarCambiosDeActualizacion(Tarea anterior, Tarea nueva) {
    final cambios = <String>[];
    if (anterior.titulo != nueva.titulo) {
      cambios.add('renombró la tarjeta a "${nueva.titulo}"');
    }
    if (anterior.fechaVencimiento != nueva.fechaVencimiento) {
      cambios.add('cambió la fecha de vencimiento');
    }
    if (!_mismosIds(anterior.etiquetaIds, nueva.etiquetaIds)) {
      cambios.add('cambió las etiquetas');
    }
    if (!_mismosIds(anterior.miembroIds, nueva.miembroIds)) {
      cambios.add('cambió los asignados');
    }
    if (!_mismosIds(anterior.dependeDeIds, nueva.dependeDeIds)) {
      cambios.add('cambió las dependencias');
    }
    if (cambios.isEmpty) return;
    final mensaje = cambios[0][0].toUpperCase() + cambios[0].substring(1);
    _registrarHistorial(nueva.id, [mensaje, ...cambios.skip(1)].join('; '));
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
    for (final suc
        in _tareas.where((t) => t.dependeDeIds.contains(origenId)).toList()) {
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
  Future<int> agregarActividad(
    int tareaId,
    String descripcion, {
    int? padreId,
  }) async {
    await _latencia();
    final idx = _indice(tareaId);
    final id = _nextActividadId++;
    final nueva = Actividad(id: id, descripcion: descripcion);
    final actividades = padreId == null
        ? [..._tareas[idx].actividades, nueva]
        : _conSubactividadAgregada(_tareas[idx].actividades, padreId, nueva);
    _tareas[idx] = _tareas[idx].copyWith(actividades: actividades);
    _registrarHistorial(tareaId, 'Agregó la subtarea "$descripcion"');
    return id;
  }

  @override
  Future<void> toggleActividad(int tareaId, int actividadId) async {
    await _latencia();
    final idx = _indice(tareaId);
    final actual = _buscarActividad(_tareas[idx].actividades, actividadId);
    final actividades = _conActividadTransformada(
      _tareas[idx].actividades,
      actividadId,
      (a) => a.copyWith(terminada: !a.terminada),
    );
    _tareas[idx] = _tareas[idx].copyWith(actividades: actividades);
    _recalcularBloqueoPorSubtareas(tareaId);
    if (actual != null) {
      _registrarHistorial(
        tareaId,
        actual.terminada
            ? 'Marcó la subtarea "${actual.descripcion}" como pendiente'
            : 'Marcó la subtarea "${actual.descripcion}" como completada',
      );
    }
  }

  @override
  Future<void> eliminarActividad(int tareaId, int actividadId) async {
    await _latencia();
    final idx = _indice(tareaId);
    final actual = _buscarActividad(_tareas[idx].actividades, actividadId);
    final actividades = _sinActividad(_tareas[idx].actividades, actividadId);
    _tareas[idx] = _tareas[idx].copyWith(actividades: actividades);
    _recalcularBloqueoPorSubtareas(tareaId);
    if (actual != null) {
      _registrarHistorial(
        tareaId,
        'Eliminó la subtarea "${actual.descripcion}"',
      );
    }
  }

  @override
  Future<void> asignarResponsableActividad(
    int tareaId,
    int actividadId, {
    int? miembroId,
    String? departamento,
  }) async {
    await _latencia();
    final idx = _indice(tareaId);
    final actual = _buscarActividad(_tareas[idx].actividades, actividadId);
    final actividades = _conActividadTransformada(
      _tareas[idx].actividades,
      actividadId,
      (a) => a.conResponsable(miembroId: miembroId, departamento: departamento),
    );
    _tareas[idx] = _tareas[idx].copyWith(actividades: actividades);
    _recalcularBloqueoPorSubtareas(tareaId);
    if (actual == null) return;
    if (miembroId == null && departamento == null) {
      _registrarHistorial(
        tareaId,
        'Quitó el responsable de "${actual.descripcion}"',
      );
    } else {
      final nombre =
          departamento ??
          _miembros
              .firstWhere(
                (m) => m.id == miembroId,
                orElse: () => const Miembro(
                  id: -1,
                  nombre: 'alguien',
                  colorAvatar: Colors.transparent,
                ),
              )
              .nombre;
      _registrarHistorial(
        tareaId,
        'Asignó a $nombre como responsable de "${actual.descripcion}"',
      );
    }
  }

  /// Recorre el árbol de [lista] buscando la actividad con [id] y devuelve
  /// una copia del árbol con esa actividad reemplazada por
  /// `transformar(actividad)` — el resto del árbol (hermanas, ancestros,
  /// subárboles ajenos) se preserva tal cual.
  List<Actividad> _conActividadTransformada(
    List<Actividad> lista,
    int id,
    Actividad Function(Actividad) transformar,
  ) {
    return [
      for (final a in lista)
        if (a.id == id)
          transformar(a)
        else
          a.copyWith(
            subActividades: _conActividadTransformada(
              a.subActividades,
              id,
              transformar,
            ),
          ),
    ];
  }

  /// Igual que [_conActividadTransformada] pero agregando [nueva] como
  /// hija de la actividad con id [padreId], donde sea que esté en el árbol.
  List<Actividad> _conSubactividadAgregada(
    List<Actividad> lista,
    int padreId,
    Actividad nueva,
  ) {
    return [
      for (final a in lista)
        if (a.id == padreId)
          a.copyWith(subActividades: [...a.subActividades, nueva])
        else
          a.copyWith(
            subActividades: _conSubactividadAgregada(
              a.subActividades,
              padreId,
              nueva,
            ),
          ),
    ];
  }

  /// Quita la actividad con [id] (y todo su subárbol) de donde esté en
  /// [lista].
  List<Actividad> _sinActividad(List<Actividad> lista, int id) {
    return [
      for (final a in lista)
        if (a.id != id)
          a.copyWith(subActividades: _sinActividad(a.subActividades, id)),
    ];
  }

  /// `true` si la descripción de alguna actividad del árbol (a cualquier
  /// profundidad) contiene [like] — usado por la búsqueda del tablero para
  /// que también encuentre tarjetas por el texto de sus subtareas.
  bool _actividadesContienen(List<Actividad> lista, String like) {
    for (final a in lista) {
      if (a.descripcion.toLowerCase().contains(like)) return true;
      if (_actividadesContienen(a.subActividades, like)) return true;
    }
    return false;
  }

  /// Auto-pausa/reanuda la tarea según si su árbol de subtareas sigue
  /// teniendo algún responsable pendiente — ver [Tarea.pausadaPorSubtarea].
  /// No toca tareas ya cerradas ni una pausa que el usuario haya elegido a
  /// mano (esas no tienen `pausadaPorSubtarea` en `true`).
  void _recalcularBloqueoPorSubtareas(int tareaId) {
    final idx = _indice(tareaId);
    final t = _tareas[idx];
    if (t.estatus == TareaEstatus.terminado ||
        t.estatus == TareaEstatus.revisado) {
      return;
    }
    final bloqueada = t.tieneSubtareaBloqueante;
    if (bloqueada && t.estatus != TareaEstatus.pausa) {
      _tareas[idx] = t.copyWith(
        estatus: TareaEstatus.pausa,
        pausadaPorSubtarea: true,
        estatusAntesDePausa: t.estatus,
      );
      _registrarHistorial(
        tareaId,
        'Se pausó automáticamente por una subtarea sin resolver',
      );
    } else if (!bloqueada &&
        t.pausadaPorSubtarea &&
        t.estatus == TareaEstatus.pausa) {
      _tareas[idx] = t.copyWith(
        estatus: t.estatusAntesDePausa ?? TareaEstatus.proceso,
        pausadaPorSubtarea: false,
        limpiarEstatusAntesDePausa: true,
      );
      _registrarHistorial(tareaId, 'Se reanudó automáticamente');
    }
  }

  @override
  Future<void> agregarComentario(
    int tareaId,
    String autor,
    String contenido, {
    String? adjuntoPath,
    String? adjuntoNombre,
  }) async {
    await _latencia();
    final idx = _indice(tareaId);
    final comentarios = [
      ..._tareas[idx].comentarios,
      Comentario(
        id: _nextComentarioId++,
        autor: autor,
        contenido: contenido,
        fecha: DateTime.now(),
        adjuntoPath: adjuntoPath,
        adjuntoNombre: adjuntoNombre,
      ),
    ];
    _tareas[idx] = _tareas[idx].copyWith(comentarios: comentarios);
    _registrarHistorial(tareaId, 'Agregó un comentario');
  }

  @override
  Future<List<KanbanColumna>> listarColumnas() async {
    await _latencia();
    return List.unmodifiable(_columnas);
  }

  @override
  Future<void> renombrarColumna(
    TareaEstatus estatus,
    String nuevoTitulo,
  ) async {
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
  Future<void> actualizarLimiteWipColumna(
    TareaEstatus estatus,
    int? limite,
  ) async {
    await _latencia();
    final idx = _columnas.indexWhere((c) => c.estatus == estatus);
    if (idx == -1) return;
    _columnas[idx] = _columnas[idx].copyWith(
      limiteWip: limite,
      limpiarLimiteWip: limite == null,
    );
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
