import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;

import '../../../core/models/ingredient.dart';
import '../../accounts/application/auth_providers.dart';
import '../data/ingredient_repository.dart';
import '../data/photo_picker.dart';
import '../data/supabase_ingredient_repository.dart';

/// Camera and photo library access. Tests override this with a fake.
final photoPickerProvider = Provider<PhotoPicker>(
  (ref) => ImagePickerPhotoPicker(),
);

/// Which recognition implementation the app uses. Run with
/// `--dart-define=STUB_DETECTION=true` to try the flow without the
/// `detect-ingredients` Edge Function; tests override this with fakes.
final ingredientRepositoryProvider = Provider<IngredientRepository>((ref) {
  if (const bool.fromEnvironment('STUB_DETECTION')) {
    return StubIngredientRepository();
  }
  return SupabaseIngredientRepository(Supabase.instance.client.functions);
});

/// The list the user confirmed with "Find recipes". Recommendations rank
/// recipes against it.
final confirmedIngredientsProvider = StateProvider<List<Ingredient>>((ref) {
  // Start empty for each signed-in user.
  ref.watch(authStateProvider.select((auth) => auth.valueOrNull?.id));
  return const [];
});
