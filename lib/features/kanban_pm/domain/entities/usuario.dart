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

  /// `true` si esta persona pertenece al comité — hoy la única diferencia
  /// que hace en la práctica es exponerle la etiqueta "Comité" (para
  /// marcar tarjetas del Kanban) y el botón "Proyectos" del header del
  /// tablero, ambos ocultos para el resto. No es un rol de workspace (ese
  /// es "dueño/miembro/invitado", por área) — es un atributo de la
  /// persona misma, igual que su nombre o su color.
  final bool perteneceComite;

  const Usuario({
    required this.id,
    required this.nombre,
    required this.colorAvatar,
    this.perteneceComite = false,
  });
}
