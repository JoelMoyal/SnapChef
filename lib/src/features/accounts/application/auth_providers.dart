import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;

import '../../../core/models/app_user.dart';
import '../data/auth_repository.dart';
import '../data/supabase_auth_repository.dart';

/// Which auth implementation the app uses. Tests override this with
/// `StubAuthRepository`.
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => SupabaseAuthRepository(Supabase.instance.client.auth),
);

/// True while a password reset is in progress. Verifying the emailed code
/// signs the user in, and the auth gate then asks for a new password instead
/// of opening the main app.
final passwordRecoveryProvider = StateProvider<bool>((ref) => false);

/// The signed-in user, or null when logged out. The auth gate watches this.
final authStateProvider = StreamProvider<AppUser?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges();
});
