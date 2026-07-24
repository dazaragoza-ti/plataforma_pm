/// Identificador de columna/estatus. Antes era un `enum` cerrado de 5
/// valores; ahora es una clase con identidad por `id` para poder crear
/// columnas nuevas en tiempo de ejecución (ver
/// `KanbanRepository.crearColumna`) — los 5 valores originales quedan
/// como constantes `static const` con el mismo nombre de antes, así que
/// el resto del código (`TareaEstatus.pausa`, comparaciones `==`, usarlos
/// como llave de `Map`) sigue funcionando igual sin tocarlo.
class TareaEstatus {
  final String id;
  const TareaEstatus._(this.id);

  static const tareas = TareaEstatus._('tareas');
  static const proceso = TareaEstatus._('proceso');
  static const pausa = TareaEstatus._('pausa');
  static const terminado = TareaEstatus._('terminado');
  static const revisado = TareaEstatus._('revisado');

  /// Para columnas creadas por el usuario (ver [KanbanRepository.crearColumna]).
  factory TareaEstatus.personalizado(String id) = TareaEstatus._;

  @override
  bool operator ==(Object other) => other is TareaEstatus && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'TareaEstatus($id)';
}

extension TareaEstatusX on TareaEstatus {
  /// Único punto de verdad para "¿este estatus ya está fuera del flujo
  /// activo?" (terminado o revisado) — evita repetir el `||` en cada sitio
  /// que necesita tratarlos como equivalentes.
  bool get esCerrado =>
      this == TareaEstatus.terminado || this == TareaEstatus.revisado;
}
