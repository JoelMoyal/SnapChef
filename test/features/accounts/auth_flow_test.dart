import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snapchef/src/app.dart';
import 'package:snapchef/src/core/models/app_user.dart';
import 'package:snapchef/src/features/accounts/application/auth_providers.dart';
import 'package:snapchef/src/features/accounts/application/profile_providers.dart';
import 'package:snapchef/src/features/accounts/data/auth_repository.dart';
import 'package:snapchef/src/features/accounts/data/profile_repository.dart';

/// Stub with no latency, plus switches to simulate network failures and a
/// backend that requires email confirmation.
class _FakeAuthRepository extends StubAuthRepository {
  _FakeAuthRepository() : super(latency: Duration.zero);

  bool offline = false;
  bool requireConfirmation = false;

  @override
  Future<AppUser> logIn({required String email, required String password}) {
    if (offline) throw const AuthException(AuthError.network);
    return super.logIn(email: email, password: password);
  }

  @override
  Future<AppUser?> signUp({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
  }) async {
    if (offline) throw const AuthException(AuthError.network);
    if (requireConfirmation) return null;
    return super.signUp(
      firstName: firstName,
      lastName: lastName,
      email: email,
      password: password,
    );
  }
}

Future<_FakeAuthRepository> _pumpApp(WidgetTester tester) async {
  final repo = _FakeAuthRepository();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(repo),
        profileRepositoryProvider.overrideWithValue(StubProfileRepository()),
      ],
      child: const SnapChefApp(),
    ),
  );
  await tester.pumpAndSettle();
  return repo;
}

Finder _field(String label) => find.widgetWithText(TextFormField, label);

Future<void> _fillSignup(
  WidgetTester tester, {
  String email = 'ana@example.com',
}) async {
  await tester.enterText(_field('First name'), 'Ana');
  await tester.enterText(_field('Last name'), 'Lopez');
  await tester.enterText(_field('Email'), email);
  await tester.enterText(_field('Password'), 'password123');
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('logged-out users land on the welcome screen', (tester) async {
    await _pumpApp(tester);

    expect(find.text('Create account'), findsOneWidget);
    expect(find.text('Log in'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('sign up shows errors beside empty fields', (tester) async {
    await _pumpApp(tester);
    await _tap(tester, find.text('Create account'));
    await _tap(tester, find.widgetWithText(FilledButton, 'Create account'));

    expect(find.text('Enter your first name'), findsOneWidget);
    expect(find.text('Enter your last name'), findsOneWidget);
    expect(find.text('Enter your email'), findsOneWidget);
    expect(find.text('Create a password'), findsOneWidget);
  });

  testWidgets('account created → main app; log out → welcome', (tester) async {
    await _pumpApp(tester);
    await _tap(tester, find.text('Create account'));
    await _fillSignup(tester);
    await _tap(tester, find.widgetWithText(FilledButton, 'Create account'));

    expect(find.byType(NavigationBar), findsOneWidget);

    await _tap(tester, find.text('Account'));
    expect(find.text('Ana Lopez'), findsOneWidget);
    await _tap(tester, find.text('Log out'));

    expect(find.text('Create account'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('email already registered offers log in with email filled', (
    tester,
  ) async {
    final repo = await _pumpApp(tester);
    await repo.signUp(
      firstName: 'Ana',
      lastName: 'Lopez',
      email: 'ana@example.com',
      password: 'password123',
    );
    await repo.logOut();
    await tester.pumpAndSettle();

    await _tap(tester, find.text('Create account'));
    await _fillSignup(tester);
    await _tap(tester, find.widgetWithText(FilledButton, 'Create account'));

    expect(
      find.text('An account with this email already exists.'),
      findsOneWidget,
    );
    await _tap(tester, find.text('Log in instead'));

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('ana@example.com'), findsOneWidget);
  });

  testWidgets('login: empty fields, wrong password, then success', (
    tester,
  ) async {
    final repo = await _pumpApp(tester);
    await repo.signUp(
      firstName: 'Ana',
      lastName: 'Lopez',
      email: 'ana@example.com',
      password: 'password123',
    );
    await repo.logOut();
    await tester.pumpAndSettle();

    await _tap(tester, find.text('Log in'));
    final submit = find.widgetWithText(FilledButton, 'Log in');

    await _tap(tester, submit);
    expect(find.text('Enter your email'), findsOneWidget);
    expect(find.text('Enter your password'), findsOneWidget);

    await tester.enterText(_field('Email'), 'ana@example.com');
    await tester.enterText(_field('Password'), 'wrong-password');
    await _tap(tester, submit);
    expect(find.textContaining('don’t match'), findsOneWidget);

    await tester.enterText(_field('Password'), 'password123');
    await _tap(tester, submit);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('sign up with email confirmation shows check-your-email', (
    tester,
  ) async {
    final repo = await _pumpApp(tester);
    repo.requireConfirmation = true;

    await _tap(tester, find.text('Create account'));
    await _fillSignup(tester);
    await _tap(tester, find.widgetWithText(FilledButton, 'Create account'));

    expect(find.text('Check your email'), findsOneWidget);
    await _tap(tester, find.text('Go to log in'));
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('ana@example.com'), findsOneWidget);
  });

  testWidgets('network error shows a retryable message', (tester) async {
    final repo = await _pumpApp(tester);
    repo.offline = true;

    await _tap(tester, find.text('Log in'));
    await tester.enterText(_field('Email'), 'ana@example.com');
    await tester.enterText(_field('Password'), 'password123');
    await _tap(tester, find.widgetWithText(FilledButton, 'Log in'));

    expect(find.textContaining('Please try again'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Log in'), findsOneWidget);
  });

  testWidgets('forgot password: code, new password, then log in with it', (
    tester,
  ) async {
    final repo = await _pumpApp(tester);
    await repo.signUp(
      firstName: 'Ana',
      lastName: 'Lopez',
      email: 'ana@example.com',
      password: 'password123',
    );
    await repo.logOut();
    await tester.pumpAndSettle();

    await _tap(tester, find.text('Log in'));
    await tester.enterText(_field('Email'), 'ana@example.com');
    await _tap(tester, find.text('Forgot password?'));
    expect(find.text('Reset your password'), findsOneWidget);
    await _tap(tester, find.text('Send reset code'));

    await tester.enterText(_field('Code'), '000000');
    await _tap(tester, find.text('Verify code'));
    expect(find.textContaining('wrong or has expired'), findsOneWidget);

    await tester.enterText(_field('Code'), StubAuthRepository.resetCode);
    await _tap(tester, find.text('Verify code'));
    expect(find.text('Choose a new password'), findsOneWidget);

    await tester.enterText(_field('New password'), 'newpassword1');
    await tester.enterText(_field('Confirm new password'), 'newpassword1');
    await _tap(tester, find.text('Save new password'));
    expect(find.byType(NavigationBar), findsOneWidget);

    await repo.logOut();
    await tester.pumpAndSettle();
    await expectLater(
      repo.logIn(email: 'ana@example.com', password: 'newpassword1'),
      completes,
    );
  });

  testWidgets('food preferences are saved and reloaded', (tester) async {
    await _pumpApp(tester);
    await _tap(tester, find.text('Create account'));
    await _fillSignup(tester);
    await _tap(tester, find.widgetWithText(FilledButton, 'Create account'));

    await _tap(tester, find.text('Account'));
    await _tap(tester, find.text('Food preferences'));
    await _tap(tester, find.widgetWithText(FilterChip, 'Vegan'));
    await _tap(tester, find.widgetWithText(FilterChip, 'Peanuts'));
    await _tap(tester, find.text('Save preferences'));
    expect(find.text('Your preferences have been saved.'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await _tap(tester, find.text('Food preferences'));

    Future<bool> selected(String label) async {
      final chip = find.widgetWithText(FilterChip, label);
      await tester.scrollUntilVisible(
        chip,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      return tester.widget<FilterChip>(chip).selected;
    }

    expect(await selected('Vegan'), isTrue);
    expect(await selected('Italian'), isFalse);
    expect(await selected('Peanuts'), isTrue);
  });
}
