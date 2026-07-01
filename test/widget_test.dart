import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Importación correcta de tu archivo de entrada principal
import 'package:plataforma_pm/main.dart';

void main() {
  testWidgets('Smoke test de inicio de Plataforma PM', (WidgetTester tester) async {
    // Construye nuestra aplicación usando la clase corregida (MainApp) y renderiza el primer frame.
    await tester.pumpWidget(const MainApp());

    // Verificamos que los textos principales de la pantalla de login aparezcan en pantalla
    expect(find.text('Plataforma PM'), findsOneWidget);
    expect(find.text('Iniciar Sesión'), findsOneWidget);
    
    // Verificamos que no existan elementos del contador por defecto que generen falsos negativos
    expect(find.text('0'), findsNothing);
    expect(find.byIcon(Icons.add), findsNothing);
  });
}