import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../recipes/recipe_repository.dart';
import '../../accounts/application/auth_providers.dart';
import '../../accounts/application/profile_providers.dart';

export '../../../../recipes/recipe_repository.dart'
    show RecipeDraft, RecipeIngredient, RecipeDataSource;

final recipeRepositoryProvider = Provider<RecipeDataSource>((ref) {
  ref.watch(authStateProvider);
  return RecipeRepository(Supabase.instance.client);
});
final recipeOptionsProvider = FutureProvider.autoDispose(
  (ref) => ref.watch(recipeRepositoryProvider).options(),
);
typedef RecipeQuery = ({String list, String? meal, String? cuisine, int page});
final recipeListProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, RecipeQuery>((ref, query) async {
      final repo = ref.watch(recipeRepositoryProvider);
      final offset = query.page * 30;
      switch (query.list) {
        case 'Community':
          return repo.community(
            mealType: query.meal,
            cuisine: query.cuisine,
            offset: offset,
          );
        case 'Saved':
          final rows = await repo.saved(offset: offset);
          return rows
              .map((r) => Map<String, dynamic>.from(r['recipes'] as Map))
              .toList();
        case 'Catalog':
          return repo.catalog(offset: offset);
        default:
          return repo.mine(offset: offset);
      }
    });
final recipeDetailProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String>(
      (ref, id) => ref.watch(recipeRepositoryProvider).get(id),
    );
final recipeSavedProvider = FutureProvider.autoDispose.family<bool, String>(
  (ref, id) => ref.watch(recipeRepositoryProvider).isSaved(id),
);
final recipePhotoProvider = FutureProvider.autoDispose
    .family<Uint8List, String>(
      (ref, path) => ref.watch(recipeRepositoryProvider).downloadPhoto(path),
    );
final recipeAllergensProvider = FutureProvider.autoDispose((ref) async {
  ref.watch(authStateProvider);
  return (await ref.watch(profileRepositoryProvider).loadPreferences())
      .allergens;
});

String recipeError(Object error) {
  if (error is PostgrestException &&
      {'42P01', 'PGRST205'}.contains(error.code)) {
    return 'Recipe storage is not set up yet. Ask the team to apply the reviewed recipe migrations.';
  }
  return 'Could not load or save the recipe. Check your connection and try again.';
}
