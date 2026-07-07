import 'package:flutter/material.dart';

/// Constantes visuales y de dominio del módulo de Bitácora de Pintura.
///
/// Son la contraparte de `constantes.py` en el proyecto original: la
/// paleta de acento se conserva igual (azules) para mantener consistencia
/// visual con el resto de "Plataforma PM".
class BitacoraColors {
  BitacoraColors._();

  static const Color accent = Color(0xFF1976D2);
  static const Color accentLight = Color(0xFFE3F2FD);
  static const Color accentDark = Color(0xFF1565C0);
  static const Color bg = Color(0xFFF0F4F8);
  static const Color bg2 = Colors.white;
  static const Color bg3 = Color(0xFFF5F7FA);
  static const Color danger = Color(0xFFEF4444);
  static const Color dangerLight = Color(0xFFFEF2F2);
  static const Color ok = Color(0xFF22C55E);
  static const Color texto = Color(0xFF0F172A);
  static const Color tdim = Color(0xFF94A3B8);
  static const Color borde = Color(0xFFE2E8F0);
}

/// Catálogo de pintores disponibles para asignar a una bitácora.
///
/// TODO: en el proyecto original esta lista vivía en el backend / base de
/// datos (`PINTORES`). Aquí queda como catálogo estático; conviene moverla
/// a un endpoint o tabla de configuración cuando exista un backend real.
const List<String> kPintores = ['Rafa', 'Maribel', 'Adriana', 'Marcos'];

/// Superficies capturables por pieza (12 superficies, igual que el original).
const List<String> kSuperficies = [
  'Frente exterior',
  'Tapa superior exterior',
  'Lateral derecho exterior',
  'Lateral izquierdo exterior',
  'Fondo exterior',
  'Asiento exterior',
  'Frente interior',
  'Tapa superior interior',
  'Lateral derecho interior',
  'Lateral izquierdo interior',
  'Fondo interior',
  'Asiento interior',
];

/// Dimensiones de la matriz de mediciones por superficie.
const int kFilas = 4;
const int kCols = 3;

/// Elementos por página en el listado del dashboard.
const int kPerPage = 12;

/// Punto de corte para cambiar a layout de escritorio en los diálogos.
const double kDesktopBreakpoint = 750;
