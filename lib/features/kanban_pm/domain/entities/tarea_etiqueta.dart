import 'package:flutter/material.dart';

/// Etiqueta de color del catálogo del tablero, asignable a varias [Tarea]s
/// a la vez — igual que los labels de Trello.
class TareaEtiqueta {
  final int id;
  final String nombre;
  final Color color;

  const TareaEtiqueta({
    required this.id,
    required this.nombre,
    required this.color,
  });

  TareaEtiqueta copyWith({String? nombre, Color? color}) => TareaEtiqueta(
    id: id,
    nombre: nombre ?? this.nombre,
    color: color ?? this.color,
  );
}
