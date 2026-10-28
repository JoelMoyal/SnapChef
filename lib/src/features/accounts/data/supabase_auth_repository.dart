import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../../core/models/app_user.dart';
import 'auth_repository.dart';

/// [AuthRepository] backed by Supabase Auth. Requires `Supabase.initialize`
/// to have run (see `main.dart`).
class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._auth);

  final supabase.GoTrueClient _auth;

  @override
  Stream<AppUser?> authStateChanges() async* {
    yield _toAppUser(_auth.currentUser);
    yield* _auth.onAuthStateChange.map((s) => _toAppUser(s.session?.user));
  }

  @override
  Future<AppUser> logIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      return _toAppUser(response.user)!;
    } catch (error) {
      throw _map(error);
    }
  }

  @override
  Future<AppUser?> signUp({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
  }) async {
    final first = firstName.trim();
    final last = lastName.trim();
    final supabase.AuthResponse response;
    try {
      response = await _auth.signUp(
        email: email.trim(),
        password: password,
        // full_name keeps the existing snapchef_profiles table populated.
        data: {
          'first_name': first,
          'last_name': last,
          'full_name': '$first $last',
        },
      );
    } catch (error) {
      throw _map(error);
    }
    final user = response.user;
    // With email confirmation on, Supabase hides duplicate sign-ups by
    // returning a user with no identities instead of an error.
    if (user != null && (user.identities?.isEmpty ?? false)) {
      throw const AuthException(AuthError.emailInUse);
    }
    return response.session == null ? null : _toAppUser(user);
  }

  @override
  Future<void> logOut() => _auth.signOut();

  static AuthException _map(Object error) {
    final code = error is supabase.AuthException ? error.code : null;
    return AuthException(switch (code) {
      'invalid_credentials' => AuthError.invalidCredentials,
      'email_not_confirmed' => AuthError.emailNotConfirmed,
      'user_already_exists' || 'email_exists' => AuthError.emailInUse,
      _ => AuthError.network,
    });
  }

  static AppUser? _toAppUser(supabase.User? user) {
    if (user == null) return null;
    final meta = user.userMetadata ?? const {};
    // Accounts created with a single full_name field have no first/last.
    final fullName = (meta['full_name'] as String? ?? '').trim();
    final space = fullName.indexOf(' ');
    return AppUser(
      id: user.id,
      email: user.email ?? '',
      firstName:
          meta['first_name'] as String? ??
          (space == -1 ? fullName : fullName.substring(0, space)),
      lastName:
          meta['last_name'] as String? ??
          (space == -1 ? '' : fullName.substring(space + 1)),
    );
  }
}
