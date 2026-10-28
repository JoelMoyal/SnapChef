import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/auth_providers.dart';

/// Owner: Hetal — accounts & preferences (meal types, cuisines, allergens).
///
/// Placeholder. Build this feature under `lib/src/features/accounts/` following
/// the same data / application / presentation layout as the ingredients
/// feature.
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
          const Text('Account & preferences — coming soon'),
          const SizedBox(height: 4),
          Text('Owner: Hetal', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 24),
          OutlinedButton(
            onPressed: () => ref.read(authRepositoryProvider).logOut(),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
  }
}
