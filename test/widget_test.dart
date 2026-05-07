import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saferoute/app.dart';

void main() {
  testWidgets('renders home screen', (WidgetTester tester) async {
    await tester.pumpWidget(const SafeRouteApp());
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.widgetWithText(AppBar, 'SafeRoute'), findsOneWidget);
  });
}
