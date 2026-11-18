import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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

    // Let the auth state and the stubbed ingredient future resolve.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // The app bar title and the three navigation tabs should be present.
    expect(find.textContaining('SnapChef'), findsWidgets);
    expect(find.text('Ingredients'), findsWidgets);
    expect(find.text('Recipes'), findsWidgets);
    expect(find.text('Account'), findsWidgets);
  });
}
