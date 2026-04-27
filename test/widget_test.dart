import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ai_road_hazard_app/main.dart';

void main() {
  testWidgets('App launches and shows main screen', (WidgetTester tester) async {
    await tester.pumpWidget(const RoadHazardApp());
    await tester.pumpAndSettle();

    expect(find.byType(MaterialApp), findsOneWidget);
  });

  testWidgets('App displays a Scaffold', (WidgetTester tester) async {
    await tester.pumpWidget(const RoadHazardApp());
    await tester.pumpAndSettle();

    expect(find.byType(Scaffold), findsWidgets);
  });

  testWidgets('App has no counter elements', (WidgetTester tester) async {
    await tester.pumpWidget(const RoadHazardApp());
    await tester.pumpAndSettle();

    expect(find.text('0'), findsNothing);
    expect(find.byIcon(Icons.add), findsNothing);
  });
}