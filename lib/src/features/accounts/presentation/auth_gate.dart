import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/app_user.dart';
import '../../../core/widgets/snapchef_logo.dart';
import '../application/auth_providers.dart';
import 'welcome_screen.dart';

/// Open app → "Already logged in?" → main app, or the welcome screen.
/// See `docs/login-flow.png`.
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key, required this.signedIn});

  /// Shown once a user is signed in.
  final Widget signedIn;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Login and sign-up screens are pushed on top of the welcome screen. Clear
    // them whenever the user signs in or out so the gate's child is visible.
    ref.listen<AsyncValue<AppUser?>>(authStateProvider, (previous, next) {
      if (previous?.valueOrNull?.id != next.valueOrNull?.id) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    });

    return ref
        .watch(authStateProvider)
        .when(
          data: (user) => user == null ? const WelcomeScreen() : signedIn,
          loading: () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (_, _) => const _RestoreFailed(),
        );
  }
}

/// "Network or server error" → "Show failure / allow retry".
class _RestoreFailed extends ConsumerWidget {
  const _RestoreFailed();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(child: SnapChefLogo()),
              const SizedBox(height: 24),
              Text(
                'We couldn’t connect',
                style: text.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Check your connection and try again.',
                style: text.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => ref.invalidate(authStateProvider),
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
