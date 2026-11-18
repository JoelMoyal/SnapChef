import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/ingredient_providers.dart';

/// Owner: Joël — recommendations (Phase 4).
///
/// Placeholder until ranking exists: shows the confirmed ingredients that
/// recipes will be matched against.
class RecommendationsScreen extends ConsumerWidget {
  const RecommendationsScreen({super.key});

  static Route<void> route() =>
      MaterialPageRoute(builder: (_) => const RecommendationsScreen());

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ingredients = ref.watch(confirmedIngredientsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Recipe ideas')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Recipe suggestions are coming soon',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          const Text('We’ll match recipes to these ingredients:'),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final ingredient in ingredients)
                Chip(label: Text(ingredient.name)),
            ],
          ),
        ],
      ),
    );
  }
}
