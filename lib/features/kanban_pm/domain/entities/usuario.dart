import 'package:flutter/material.dart';

/// Identidad de una persona, compartida entre TODAS las áreas de trabajo —
/// a diferencia de [Miembro] (que vive dentro de un área y solo tiene
/// sentido ahí, aunque sea "la misma persona" en otra), este es un único
/// registro sin importar en cuántas áreas participe. Es lo que permite
/// que alguien fuera de un departamento, al ser asignado a una actividad
/// de esa área, siga siendo reconocido como la misma persona en la suya.
class Usuario {
  final String id;
  final String nombre;
  final Color colorAvatar;

  const Usuario({
    required this.id,
    required this.nombre,
    required this.colorAvatar,
  });
}
