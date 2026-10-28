import 'dart:async';

import '../../../core/models/app_user.dart';

/// Why an auth request failed. Maps to the "Result?" branches in
/// `docs/login-flow.png`.
enum AuthError {
  /// Login: email and password don't match an account.
  invalidCredentials,

  /// Login: the account exists but its email hasn't been confirmed yet.
  emailNotConfirmed,

  /// Sign up: an account with this email already exists.
  emailInUse,

  /// Either flow: network or server error. The user can retry.
  network,
}

class AuthException implements Exception {
  const AuthException(this.error);

  final AuthError error;

  @override
  String toString() => 'AuthException($error)';
}

/// Contract for authentication. The UI depends on this interface, never on a
/// concrete backend, so the stub can be swapped for Firebase Auth later
/// without touching the screens.
abstract interface class AuthRepository {
  /// Emits the current user (or null) immediately, then on every change.
  /// Errors on the first event mean the stored session couldn't be restored.
  Stream<AppUser?> authStateChanges();

  /// Throws [AuthException] with [AuthError.invalidCredentials],
  /// [AuthError.emailNotConfirmed] or [AuthError.network].
  Future<AppUser> logIn({required String email, required String password});

  /// Returns the signed-in user, or null when the backend requires email
  /// confirmation first (a confirmation link has been sent).
  ///
  /// Throws [AuthException] with [AuthError.emailInUse] or [AuthError.network].
  Future<AppUser?> signUp({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
  });

  Future<void> logOut();
}

/// Temporary in-memory stub so the flow runs end-to-end before the backend is
/// chosen. Accounts and the session are lost when the app restarts.
class StubAuthRepository implements AuthRepository {
  StubAuthRepository({this.latency = const Duration(milliseconds: 400)});

  final Duration latency;
  final _accounts = <String, ({AppUser user, String password})>{};
  final _changes = StreamController<AppUser?>.broadcast();
  AppUser? _current;

  @override
  Stream<AppUser?> authStateChanges() async* {
    yield _current;
    yield* _changes.stream;
  }

  @override
  Future<AppUser> logIn({
    required String email,
    required String password,
  }) async {
    await _simulateLatency();
    final account = _accounts[_normalize(email)];
    if (account == null || account.password != password) {
      throw const AuthException(AuthError.invalidCredentials);
    }
    return _setCurrent(account.user);
  }

  @override
  Future<AppUser?> signUp({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
  }) async {
    await _simulateLatency();
    final key = _normalize(email);
    if (_accounts.containsKey(key)) {
      throw const AuthException(AuthError.emailInUse);
    }
    final user = AppUser(
      id: 'stub-${_accounts.length + 1}',
      email: key,
      firstName: firstName.trim(),
      lastName: lastName.trim(),
    );
    _accounts[key] = (user: user, password: password);
    return _setCurrent(user);
  }

  @override
  Future<void> logOut() async {
    _setCurrent(null);
  }

  // Skipped at zero latency so tests can call the stub directly inside
  // testWidgets, whose fake clock never advances on its own.
  Future<void> _simulateLatency() async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
  }

  String _normalize(String email) => email.trim().toLowerCase();

  T _setCurrent<T extends AppUser?>(T user) {
    _current = user;
    _changes.add(user);
    return user;
  }
}
