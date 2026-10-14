import '../../../core/models/ingredient.dart';

/// Contract for getting ingredients. The UI depends on this interface, never on
/// a concrete data source, so we can swap the stub for a real (Firebase +
/// image-recognition) implementation later without touching the screens.
abstract interface class IngredientRepository {
  /// Returns the ingredients detected from a photo.
  Future<List<Ingredient>> detectFromPhoto();
}

/// Temporary stub so the app runs end-to-end before real recognition exists.
/// Replace with a backend-backed implementation in Phase 3.
class StubIngredientRepository implements IngredientRepository {
  @override
  Future<List<Ingredient>> detectFromPhoto() async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    return const [
      Ingredient(id: 'tomato', name: 'Tomato'),
      Ingredient(id: 'egg', name: 'Egg'),
      Ingredient(id: 'onion', name: 'Onion'),
    ];
  }
}
