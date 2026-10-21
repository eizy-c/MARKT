import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markt_app/main.dart';

void main() {
  testWidgets('Carga inicial y renderizado de MarktApp', (WidgetTester tester) async {
    await tester.pumpWidget(const MarktApp());
    await tester.pump();

    // Comprobar que el título inicial y la pantalla de Dashboard carguen
    expect(find.text('Panel Principal'), findsWidgets);
    expect(find.text('Resumen del Negocio'), findsOneWidget);
    expect(find.byIcon(Icons.menu), findsWidgets);
    expect(find.byIcon(Icons.bug_report), findsOneWidget);

    // Abrir menú lateral nativo (Drawer)
    await tester.tap(find.byIcon(Icons.menu).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Validar ítems del menú nativo
    expect(find.text('Terminal POS (Ventas)'), findsOneWidget);
    expect(find.text('Libro de Caja'), findsOneWidget);
    expect(find.text('Proyectos & Pedidos'), findsOneWidget);
  });
}
