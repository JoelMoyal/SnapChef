import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/auth_providers.dart';
import 'preferences_screen.dart';

/// Owner: Hetal — accounts & preferences (meal types, cuisines, allergens).
class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).valueOrNull;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.person_outline, size: 48),
          const SizedBox(height: 12),
          if (user != null) ...[
            Text(
              '${user.firstName} ${user.lastName}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(user.email),
            const SizedBox(height: 12),
          ],
          FilledButton.tonal(
            onPressed: () =>
                Navigator.of(context).push(PreferencesScreen.route()),
            child: const Text('Food preferences'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => ref.read(authRepositoryProvider).logOut(),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
  }
}
