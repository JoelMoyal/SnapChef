import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/ingredient_providers.dart';

/// Owner: Joël — ingredient capture & recommendations.
///
/// This is a demo of the Riverpod pattern the whole team should follow:
/// `ConsumerWidget` -> `ref.watch(provider)` -> handle loading/error/data.
class IngredientsScreen extends ConsumerWidget {
  const IngredientsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ingredients = ref.watch(detectedIngredientsProvider);

    return ingredients.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Something went wrong: $error')),
      data: (items) => ListView(
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Detected ingredients (stub data)'),
          ),
          for (final item in items)
            ListTile(
              leading: const Icon(Icons.eco_outlined),
              title: Text(item.name),
            ),
        ],
      ),
    );
  }
}
