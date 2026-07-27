import 'package:flutter/material.dart';

import '../domain/entities/usuario.dart';

/// Directorio de personas compartido por TODA la app (no por área de
/// trabajo) — simula lo que en un backend real sería una tabla `usuario`
/// consultada desde cualquier área, mientras este módulo siga sin
/// login/API real. Los mismos 5 nombres que ya usaba `kIntegrantesDemo`
/// para no tener dos catálogos de personas distintos en la demo.
class UsuarioDirectorio {
  UsuarioDirectorio._();
  static final UsuarioDirectorio instancia = UsuarioDirectorio._();

  final List<Usuario> _usuarios = const [
    Usuario(id: 'u1', nombre: 'J. Salazar', colorAvatar: Color(0xFFEF4444)),
    Usuario(id: 'u2', nombre: 'A. Martínez', colorAvatar: Color(0xFFF59E0B)),
    Usuario(id: 'u3', nombre: 'R. Gómez', colorAvatar: Color(0xFFEAB308)),
    Usuario(id: 'u4', nombre: 'L. Torres', colorAvatar: Color(0xFF22C55E)),
    Usuario(id: 'u5', nombre: 'M. Fernández', colorAvatar: Color(0xFF14B8A6)),
  ];

  List<Usuario> listar() => List.unmodifiable(_usuarios);

  Usuario porId(String id) =>
      _usuarios.firstWhere((u) => u.id == id, orElse: () => _usuarios.first);
}

/// "Sesión" simulada: quién está usando la app en este momento. Mientras no
/// exista login real, cualquier pantalla puede cambiarla (ver el selector
/// de persona en `WorkspaceSelectorScreen`) para poder probar cómo se ve
/// la app desde varias personas sin necesitar autenticación de verdad.
/// `ValueNotifier` para que quien la usa (p. ej. el filtro de áreas de
/// trabajo por membresía) se entere sola del cambio, sin pasar el valor a
/// mano por cada widget de por medio.
final ValueNotifier<Usuario> usuarioActual = ValueNotifier(
  UsuarioDirectorio.instancia.listar().first,
);
