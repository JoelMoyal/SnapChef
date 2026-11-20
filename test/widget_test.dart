import 'package:flutter_riverpod/flutter_riverpod.dart';
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

import 'package:snapchef/src/app.dart';
import 'package:snapchef/src/features/accounts/application/auth_providers.dart';
import 'package:snapchef/src/features/accounts/data/auth_repository.dart';

void main() {
  testWidgets('App boots and shows the SnapChef shell when signed in', (
    tester,
  ) async {
    final auth = StubAuthRepository(latency: Duration.zero);
    await auth.signUp(
      firstName: 'Ana',
      lastName: 'Lopez',
      email: 'ana@example.com',
      password: 'password123',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(auth)],
        child: const SnapChefApp(),
      ),
    );

    // Let the auth state resolve.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // The app bar title and the three navigation tabs should be present.
    expect(find.textContaining('SnapChef'), findsWidgets);
    expect(find.text('Ingredients'), findsWidgets);
    expect(find.text('Recipes'), findsWidgets);
    expect(find.text('Account'), findsWidgets);
  });
}