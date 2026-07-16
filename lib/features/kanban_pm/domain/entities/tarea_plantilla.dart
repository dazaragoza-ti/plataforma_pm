import '../../kanban_constants.dart';

/// Plantilla editable para crear tarjetas rápido con valores por defecto
/// ya cargados (título sugerido, prioridad, área, checklist típico...),
/// gestionada por el usuario desde el tablero (crear/editar/eliminar).
class TareaPlantilla {
  final int id;
  final String nombre;
  final String tituloSugerido;
  final String descripcion;
  final TareaPrioridad prioridad;
  final String grupo;
  final List<String> actividades;

  const TareaPlantilla({
    required this.id,
    required this.nombre,
    this.tituloSugerido = '',
    this.descripcion = '',
    this.prioridad = TareaPrioridad.media,
    this.grupo = '',
    this.actividades = const [],
  });

  TareaPlantilla copyWith({
    String? nombre,
    String? tituloSugerido,
    String? descripcion,
    TareaPrioridad? prioridad,
    String? grupo,
    List<String>? actividades,
  }) {
    return TareaPlantilla(
      id: id,
      nombre: nombre ?? this.nombre,
      tituloSugerido: tituloSugerido ?? this.tituloSugerido,
      descripcion: descripcion ?? this.descripcion,
      prioridad: prioridad ?? this.prioridad,
      grupo: grupo ?? this.grupo,
      actividades: actividades ?? this.actividades,
    );
  }
}
