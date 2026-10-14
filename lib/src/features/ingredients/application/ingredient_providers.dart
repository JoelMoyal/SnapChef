import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/ingredient.dart';
import '../data/ingredient_repository.dart';

/// Which repository implementation the app uses. Swap the stub here (or
/// override it in tests) when the real one is ready.
final ingredientRepositoryProvider = Provider<IngredientRepository>(
  (ref) => StubIngredientRepository(),
);

/// Ingredients detected from the latest photo. Screens `watch` this.
final detectedIngredientsProvider = FutureProvider<List<Ingredient>>((ref) {
  return ref.watch(ingredientRepositoryProvider).detectFromPhoto();
});
