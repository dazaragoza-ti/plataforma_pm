import 'package:flutter/material.dart';

enum TareaPrioridad { baja, media, alta, urgente }

extension TareaPrioridadX on TareaPrioridad {
  String get etiqueta => switch (this) {
    TareaPrioridad.baja => 'Baja',
    TareaPrioridad.media => 'Media',
    TareaPrioridad.alta => 'Alta',
    TareaPrioridad.urgente => 'Urgente',
  };

  Color get color => switch (this) {
    TareaPrioridad.baja => const Color(0xFF22C55E),
    TareaPrioridad.media => const Color(0xFF2196F3),
    TareaPrioridad.alta => const Color(0xFFF59E0B),
    TareaPrioridad.urgente => const Color(0xFFEF4444),
  };
}
