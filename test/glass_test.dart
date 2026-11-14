import 'package:cresta/src/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Bordes que dibuja el vidrio (solo el aro lo tiene).
Iterable<BoxBorder> _borders(WidgetTester t) => t
    .widgetList<DecoratedBox>(find.byType(DecoratedBox))
    .map((d) => d.decoration)
    .whereType<BoxDecoration>()
    .map((d) => d.border)
    .whereType<BoxBorder>();

void main() {
  testWidgets('sobre un mapa claro, el vidrio no lleva aro', (t) async {
    await t.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Glass(child: SizedBox(width: 40, height: 40)),
      ),
    );
    expect(_borders(t), isEmpty);
  });

  testWidgets('sobre un mapa oscuro, aro gris y tono más claro', (t) async {
    await t.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: DarkMapScope(
          dark: true,
          child: Glass(child: SizedBox(width: 40, height: 40)),
        ),
      ),
    );
    expect(_borders(t), hasLength(1));
    final fill = t
        .widgetList<DecoratedBox>(find.byType(DecoratedBox))
        .map((d) => d.decoration)
        .whereType<BoxDecoration>()
        .firstWhere((d) => d.color != null);
    expect(fill.color!.a, greaterThanOrEqualTo(.92));
  });
}
