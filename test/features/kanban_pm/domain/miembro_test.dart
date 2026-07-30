import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plataforma_pm/features/kanban_pm/domain/entities/miembro.dart';

void main() {
  group('Miembro ==/hashCode', () {
    test('dos instancias con el mismo id son iguales', () {
      const a = Miembro(id: 7, nombre: 'Ana', colorAvatar: Colors.red);
      const b = Miembro(
        id: 7,
        nombre: 'Ana (renombrada)',
        colorAvatar: Colors.blue,
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('instancias con distinto id no son iguales', () {
      const a = Miembro(id: 1, nombre: 'Ana', colorAvatar: Colors.red);
      const b = Miembro(id: 2, nombre: 'Ana', colorAvatar: Colors.red);
      expect(a, isNot(equals(b)));
    });

    test('copyWith conserva el id, así que sigue igual al original', () {
      const original = Miembro(id: 3, nombre: 'Ana', colorAvatar: Colors.red);
      final copia = original.copyWith(nombre: 'Ana María');
      expect(copia, equals(original));
    });

    test('un Set colapsa instancias distintas del mismo id', () {
      const a = Miembro(id: 5, nombre: 'Ana', colorAvatar: Colors.red);
      final b = a.copyWith(colorAvatar: Colors.green);
      final set = {a, b};
      expect(set, hasLength(1));
    });
  });
}
