import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plataforma_pm/features/kanban_pm/domain/entities/tarea.dart';
import 'package:plataforma_pm/features/kanban_pm/kanban_constants.dart';

void main() {
  Tarea tareaBase() => Tarea(
    id: 1,
    titulo: 'Tarea de prueba',
    estatus: TareaEstatus.tareas,
    fechaInicio: DateTime(2026, 1, 1),
    fechaVencimiento: DateTime(2026, 1, 10),
    fechaInicioReal: DateTime(2026, 1, 2),
    fechaFinReal: DateTime(2026, 1, 9),
    generales: ('General', Colors.blue),
    nivel: ('Nivel', Colors.red),
    importancia: ('Importancia', Colors.green),
  );

  group('Tarea.copyWith', () {
    test('sin argumentos conserva todos los campos', () {
      final t = tareaBase();
      final copia = t.copyWith();
      expect(copia.fechaInicio, t.fechaInicio);
      expect(copia.fechaVencimiento, t.fechaVencimiento);
      expect(copia.fechaInicioReal, t.fechaInicioReal);
      expect(copia.fechaFinReal, t.fechaFinReal);
      expect(copia.generales, t.generales);
      expect(copia.nivel, t.nivel);
      expect(copia.importancia, t.importancia);
    });

    test('los sentinelas limpiar* limpian a null cada campo', () {
      final t = tareaBase();
      final limpia = t.copyWith(
        limpiarFechaInicio: true,
        limpiarFechaVencimiento: true,
        limpiarFechaInicioReal: true,
        limpiarFechaFinReal: true,
        limpiarGenerales: true,
        limpiarNivel: true,
        limpiarImportancia: true,
      );
      expect(limpia.fechaInicio, isNull);
      expect(limpia.fechaVencimiento, isNull);
      expect(limpia.fechaInicioReal, isNull);
      expect(limpia.fechaFinReal, isNull);
      expect(limpia.generales, isNull);
      expect(limpia.nivel, isNull);
      expect(limpia.importancia, isNull);
    });

    test('pasar un valor nuevo lo aplica sin necesidad del sentinela', () {
      final t = tareaBase();
      final nuevaFecha = DateTime(2027, 5, 5);
      final copia = t.copyWith(fechaVencimiento: nuevaFecha);
      expect(copia.fechaVencimiento, nuevaFecha);
    });

    test('limpiarPortada y limpiarEstatusAntesDePausa (ya existentes) siguen '
        'funcionando igual', () {
      final t = tareaBase().copyWith(
        portada: Colors.purple,
        estatusAntesDePausa: TareaEstatus.proceso,
      );
      final limpia = t.copyWith(
        limpiarPortada: true,
        limpiarEstatusAntesDePausa: true,
      );
      expect(limpia.portada, isNull);
      expect(limpia.estatusAntesDePausa, isNull);
    });
  });

  group('Tarea getters derivados', () {
    test('progreso es 0 sin actividades', () {
      expect(tareaBase().progreso, 0);
    });

    test('cerrada es true solo para terminado/revisado', () {
      expect(
        tareaBase().copyWith(estatus: TareaEstatus.proceso).cerrada,
        isFalse,
      );
      expect(
        tareaBase().copyWith(estatus: TareaEstatus.terminado).cerrada,
        isTrue,
      );
      expect(
        tareaBase().copyWith(estatus: TareaEstatus.revisado).cerrada,
        isTrue,
      );
    });

    test('vencida es false si ya está cerrada, sin importar la fecha', () {
      final vencidaPeroCerrada = Tarea(
        id: 2,
        titulo: 'x',
        estatus: TareaEstatus.terminado,
        fechaVencimiento: DateTime(2000, 1, 1),
      );
      expect(vencidaPeroCerrada.vencida, isFalse);
    });
  });
}
