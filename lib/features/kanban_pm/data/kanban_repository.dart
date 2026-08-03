import 'package:flutter/material.dart';

import '../domain/entities/miembro.dart';
import '../domain/entities/tarea.dart';
import '../domain/entities/tarea_etiqueta.dart';
import '../domain/entities/tarea_plantilla.dart';
import '../kanban_constants.dart';

export 'in_memory_kanban_repository.dart';

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

  /// Trae una sola tarea por id, sin pasar por la lista completa del
  /// tablero — pensado para abrir su detalle (p. ej. desde una
  /// notificación o un enlace directo) sin depender de que ya esté
  /// cargada en memoria. Devuelve `null` si no existe (o fue eliminada).
  Future<Tarea?> obtenerTarea(int tareaId);

  Future<int> crearTarea(Tarea tarea);

  /// Devuelve `false` (sin mover nada) si [nuevoEstatus] es una columna
  /// archivada — quien llama debe distinguir esto de un movimiento
  /// exitoso (p. ej. al mover varias tarjetas en lote, para no reportar
  /// como "movidas" tarjetas que en realidad se quedaron donde estaban).
  Future<bool> moverTarea(
    int tareaId,
    TareaEstatus nuevoEstatus, {
    int? posicion,
  });

  Future<void> eliminarTarea(int tareaId);

  Future<void> archivarTarea(int tareaId, bool archivada);

  /// Devuelve cuántas tareas sucesoras (`dependeDeIds`) se recorrieron en
  /// cascada como consecuencia de este cambio de fechas — así quien llama
  /// (p. ej. el Gantt tras un arrastre) puede avisar en el momento que el
  /// movimiento afectó a otras tarjetas, no solo a la editada.
  Future<int> actualizarTarea(Tarea tarea);

  /// Agrega una subtarea. Si [padreId] es `null` se agrega al nivel raíz de
  /// la tarea; si no, se agrega como subtarea de la actividad con ese id
  /// (a cualquier profundidad del árbol) — así el responsable de una
  /// subtarea puede a su vez delegar partes de su trabajo.
  Future<int> agregarActividad(int tareaId, String descripcion, {int? padreId});

  Future<void> toggleActividad(int tareaId, int actividadId);

  Future<void> eliminarActividad(int tareaId, int actividadId);

  /// Asigna (o limpia, si ambos vienen `null`) el responsable de una
  /// subtarea — persona o departamento, excluyentes entre sí — junto con la
  /// fecha/hora planeada de inicio y fin de su trabajo en ella. Puede dejar
  /// a la tarea auto-pausada mientras el responsable no la resuelva; ver
  /// [Tarea.pausadaPorSubtarea].
  Future<void> asignarResponsableActividad(
    int tareaId,
    int actividadId, {
    int? miembroId,
    String? departamento,
    DateTime? fechaInicio,
    DateTime? fechaFin,
  });

  /// Registra en el historial de [tareaId] el motivo que la persona escribió
  /// al pausarla — se guarda como una entrada más de [Tarea.historial] (no
  /// como un comentario aparte) para que, si la tarea se pausa varias
  /// veces, cada nota quede su propio registro con fecha en vez de
  /// pisarse entre sí.
  Future<void> registrarNotaPausa(int tareaId, String nota);

  // Columnas (listas) del tablero.
  Future<List<KanbanColumna>> listarColumnas();

  /// Crea una lista nueva al final del tablero, con un `TareaEstatus`
  /// propio (ver [TareaEstatus.personalizado]) — a diferencia de las 5
  /// columnas originales, esta no participa del flujo
  /// tareas→proceso→pausa→terminado/revisado ni de los cálculos que
  /// asumen ese flujo (Gantt, notificaciones); es una lista libre más,
  /// estilo Trello.
  Future<KanbanColumna> crearColumna(String titulo);

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

  /// [usuarioId] liga el nuevo miembro con una persona del directorio
  /// global (ver [Miembro.usuarioId]) — se manda al elegir a alguien que
  /// ya existe en otra área en vez de escribir un nombre nuevo; `null`
  /// crea un miembro que solo existe en esta área.
  Future<int> crearMiembro(
    String nombre,
    Color colorAvatar, {
    String? usuarioId,
  });

  Future<void> actualizarMiembro(Miembro miembro);

  /// Devuelve `false` (sin quitar a nadie) si [miembroId] es la última
  /// persona del área con [Miembro.usuarioId] ligado al directorio
  /// global — quitarla dejaría el área inaccesible para siempre (ni
  /// `WorkspaceRepository.listarWorkspacesDe` volvería a mostrársela a
  /// nadie). El guard vive aquí (no solo en el diálogo que la invoca)
  /// para que dos quitados casi simultáneos no puedan saltárselo: el
  /// diálogo evalúa "¿quedaría alguien?" antes de confirmar, pero esa
  /// evaluación no se revalida justo antes de escribir, así que dos
  /// llamadas que pasan el chequeo casi al mismo tiempo podían dejar el
  /// área sin nadie con acceso.
  Future<bool> eliminarMiembro(int miembroId);

  // Plantillas (templates) editables para crear tarjetas rápido.
  Future<List<TareaPlantilla>> listarPlantillas();

  Future<int> crearPlantilla(TareaPlantilla plantilla);

  Future<void> actualizarPlantilla(TareaPlantilla plantilla);

  Future<void> eliminarPlantilla(int plantillaId);
}
