import 'package:flutter/material.dart';

/// Persona del catálogo del tablero, asignable a varias [Tarea]s a la vez
/// (multi-asignación, igual que las etiquetas).
class Miembro {
  final int id;
  final String nombre;
  final Color colorAvatar;

  /// Liga este registro (local a esta área de trabajo) con el [Usuario]
  /// global correspondiente — `null` si es una persona que solo existe
  /// aquí, sin cuenta en el directorio compartido. Es lo que permite que
  /// una misma persona, agregada al catálogo de una segunda área, siga
  /// siendo reconocida como la misma (y que esa área le aparezca en su
  /// selector) en vez de ser un registro suelto sin relación.
  final String? usuarioId;

  const Miembro({
    required this.id,
    required this.nombre,
    required this.colorAvatar,
    this.usuarioId,
  });

  Miembro copyWith({String? nombre, Color? colorAvatar}) => Miembro(
    id: id,
    nombre: nombre ?? this.nombre,
    colorAvatar: colorAvatar ?? this.colorAvatar,
    usuarioId: usuarioId,
  );

  /// Por `id` (no por campos completos): dos instancias que representan al
  /// mismo miembro pero llegaron de "fetches" distintos (p. ej. antes y
  /// después de un `copyWith`) deben seguir siendo iguales para `Set`/`Map`
  /// — sin esto (identidad por defecto de `Object`), `kanban_graficas_view`
  /// podía terminar con dos llaves distintas para la misma persona si sus
  /// datos venían de instancias diferentes.
  @override
  bool operator ==(Object other) => other is Miembro && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
