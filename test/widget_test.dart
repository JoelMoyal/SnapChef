// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snapchef/snapchef_auth.dart';

void main() {
  testWidgets('Empty login is rejected before any auth request', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginPage()));
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Log in'));
    await tester.tap(find.widgetWithText(FilledButton, 'Log in'));
    await tester.pump();
    expect(find.text('Please enter a valid email address.'), findsOneWidget);
    expect(find.text('Enter your password.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Registration rejects mismatching passwords', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: RegistrationPage()));
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Test User');
    await tester.enterText(fields.at(1), 'test@example.com');
    await tester.enterText(fields.at(2), 'password123');
    await tester.enterText(fields.at(3), 'different123');
    final submit = find.widgetWithText(FilledButton, 'Create account');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pump();
    expect(find.text('Passwords do not match.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}