import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/ingredient.dart';
import '../../accounts/application/auth_providers.dart';
import '../data/ingredient_repository.dart';
import '../data/photo_picker.dart';
import 'ingredient_providers.dart';

/// What the scanner is doing, or how the last scan went.
sealed class ScanStatus {
  const ScanStatus();
}

/// Nothing scanned yet.
final class ScanIdle extends ScanStatus {
  const ScanIdle();
}

/// [photo] is being analyzed.
final class ScanAnalyzing extends ScanStatus {
  const ScanAnalyzing(this.photo);

  final Photo photo;
}

/// The last photo added [added] ingredients, or none when everything in it was
/// already on the list.
final class ScanSucceeded extends ScanStatus {
  const ScanSucceeded(this.added);

  final int added;
}

/// The last photo was analyzed, but no ingredients were recognized.
final class ScanFoundNothing extends ScanStatus {
  const ScanFoundNothing();
}

/// The photo couldn't be taken or opened.
final class ScanPickFailed extends ScanStatus {
  const ScanPickFailed(this.source, this.error);

  final PhotoSource source;
  final PhotoPickerError error;
}

/// Recognition failed for [photo]; [IngredientScanController.retry] sends it
/// again.
final class ScanFailed extends ScanStatus {
  const ScanFailed(this.photo, this.error);

  final Photo photo;
  final IngredientDetectionError error;
}

class IngredientScanState {
  const IngredientScanState({
    this.ingredients = const [],
    this.status = const ScanIdle(),
  });

  /// Newest first. Editable whatever [status] is, so a failed scan never
  /// blocks typing ingredients in.
  final List<Ingredient> ingredients;
  final ScanStatus status;

  bool get analyzing => status is ScanAnalyzing;

  IngredientScanState copyWith({
    List<Ingredient>? ingredients,
    ScanStatus? status,
  }) => IngredientScanState(
    ingredients: ingredients ?? this.ingredients,
    status: status ?? this.status,
  );
}

/// The ingredient list built from photos and typing, before the user confirms
/// it with "Find recipes".
final ingredientScanProvider =
    NotifierProvider<IngredientScanController, IngredientScanState>(
      IngredientScanController.new,
    );

class IngredientScanController extends Notifier<IngredientScanState> {
  @override
  IngredientScanState build() {
    // Start fresh for each signed-in user.
    ref.watch(authStateProvider.select((auth) => auth.valueOrNull?.id));
    return const IngredientScanState();
  }

  /// Takes or chooses a photo and adds the ingredients recognized in it.
  Future<void> scan(PhotoSource source) async {
    if (state.analyzing) return;
    final Photo? photo;
    try {
      photo = await ref.read(photoPickerProvider).pick(source);
    } on PhotoPickerException catch (e) {
      state = state.copyWith(status: ScanPickFailed(source, e.error));
      return;
    }
    if (photo != null) await _analyze(photo);
  }

  /// Sends the photo from a failed scan again.
  Future<void> retry() async {
    final status = state.status;
    if (status is ScanFailed && status.error.isRetryable) {
      await _analyze(status.photo);
    }
  }

  Future<void> _analyze(Photo photo) async {
    final analyzing = ScanAnalyzing(photo);
    state = state.copyWith(status: analyzing);

    final List<Ingredient> found;
    try {
      found = await ref
          .read(ingredientRepositoryProvider)
          .detectFromPhoto(photo);
    } catch (e) {
      // Unexpected errors end the scan too, so the spinner can't get stuck.
      if (identical(state.status, analyzing)) {
        final error = e is IngredientDetectionException
            ? e.error
            : IngredientDetectionError.failed;
        state = state.copyWith(status: ScanFailed(photo, error));
      }
      if (e is IngredientDetectionException) return;
      rethrow;
    }

    // Drop the answer if the scan was reset meanwhile, e.g. by logging out.
    if (!identical(state.status, analyzing)) return;
    final ingredients = _merge(found, state.ingredients);
    final added = ingredients.length - state.ingredients.length;
    state = IngredientScanState(
      ingredients: ingredients,
      status: found.isEmpty ? const ScanFoundNothing() : ScanSucceeded(added),
    );
  }

  /// Adds typed ingredients; commas separate several ("eggs, milk"). Returns
  /// how many were new.
  int add(String text) {
    final typed = [for (final name in text.split(',')) Ingredient.named(name)];
    final ingredients = _merge(typed, state.ingredients);
    final added = ingredients.length - state.ingredients.length;
    state = state.copyWith(ingredients: ingredients);
    return added;
  }

  /// Renames an ingredient in place. Renaming it to something already on the
  /// list combines the two.
  void rename(String id, String name) {
    final renamed = Ingredient.named(name);
    if (renamed.id.isEmpty) return;
    final duplicate =
        renamed.id != id && state.ingredients.any((i) => i.id == renamed.id);
    state = state.copyWith(
      ingredients: [
        for (final ingredient in state.ingredients)
          if (ingredient.id != id) ingredient else if (!duplicate) renamed,
      ],
    );
  }

  /// Removes an ingredient and returns its position, for [restore].
  int remove(String id) {
    final index = state.ingredients.indexWhere((i) => i.id == id);
    if (index >= 0) {
      state = state.copyWith(
        ingredients: [...state.ingredients]..removeAt(index),
      );
    }
    return index;
  }

  /// Puts back an ingredient taken out by [remove].
  void restore(int index, Ingredient ingredient) {
    final ingredients = state.ingredients;
    if (ingredients.any((i) => i.id == ingredient.id)) return;
    state = state.copyWith(
      ingredients: [...ingredients]
        ..insert(index.clamp(0, ingredients.length), ingredient),
    );
  }

  /// Hands the current list to recommendations.
  void confirm() {
    ref.read(confirmedIngredientsProvider.notifier).state = state.ingredients;
  }

  /// [incoming] first, skipping blanks and names already in [existing].
  static List<Ingredient> _merge(
    List<Ingredient> incoming,
    List<Ingredient> existing,
  ) {
    final ids = {for (final ingredient in existing) ingredient.id};
    return [
      for (final ingredient in incoming)
        if (ingredient.id.isNotEmpty && ids.add(ingredient.id)) ingredient,
      ...existing,
    ];
  }
}
