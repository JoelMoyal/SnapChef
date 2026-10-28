import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/app_user.dart';
import '../data/auth_repository.dart';

/// Which auth implementation the app uses. Swap the stub here (or override it
/// in tests) when the real backend is ready.
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => StubAuthRepository(),
);

/// The signed-in user, or null when logged out. The auth gate watches this.
final authStateProvider = StreamProvider<AppUser?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges();
});
