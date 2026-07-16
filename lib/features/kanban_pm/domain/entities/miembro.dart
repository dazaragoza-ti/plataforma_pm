import 'package:flutter/material.dart';

/// Persona del catálogo del tablero, asignable a varias [Tarea]s a la vez
/// (multi-asignación, igual que las etiquetas).
class Miembro {
  final int id;
  final String nombre;
  final Color colorAvatar;

  const Miembro({
    required this.id,
    required this.nombre,
    required this.colorAvatar,
  });

  Miembro copyWith({String? nombre, Color? colorAvatar}) => Miembro(
    id: id,
    nombre: nombre ?? this.nombre,
    colorAvatar: colorAvatar ?? this.colorAvatar,
  );
}
