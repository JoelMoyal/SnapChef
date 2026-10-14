import 'package:flutter/material.dart';

/// Owner: Hetal — accounts & preferences (meal types, cuisines, allergens).
///
/// Placeholder. Build this feature under `lib/src/features/accounts/` following
/// the same data / application / presentation layout as the ingredients
/// feature.
class AccountsScreen extends StatelessWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.person_outline, size: 48),
          const SizedBox(height: 12),
          const Text('Account & preferences — coming soon'),
          const SizedBox(height: 4),
          Text('Owner: Hetal', style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
