import 'package:flutter/material.dart';

/// Owner: Newton — recipe authoring & community feed.
///
/// Placeholder. Build this feature under `lib/src/features/recipes/` following
/// the same data / application / presentation layout as the ingredients
/// feature.
class RecipesScreen extends StatelessWidget {
  const RecipesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _ComingSoon(
      icon: Icons.restaurant_menu,
      title: 'Recipes',
      owner: 'Newton',
    );
  }
}

class _ComingSoon extends StatelessWidget {
  const _ComingSoon({
    required this.icon,
    required this.title,
    required this.owner,
  });

  final IconData icon;
  final String title;
  final String owner;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48),
          const SizedBox(height: 12),
          Text('$title — coming soon'),
          const SizedBox(height: 4),
          Text('Owner: $owner', style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
