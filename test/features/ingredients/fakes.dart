import 'dart:async';
import 'dart:typed_data';

import 'package:snapchef/src/core/models/ingredient.dart';
import 'package:snapchef/src/features/ingredients/data/ingredient_repository.dart';
import 'package:snapchef/src/features/ingredients/data/photo_picker.dart';

final testPhoto = Photo(
  bytes: Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0]),
  mimeType: 'image/jpeg',
);

/// Returns [next] from every pick: a [Photo], null for a cancelled pick, or a
/// [PhotoPickerException] to throw.
class FakePhotoPicker implements PhotoPicker {
  Object? next = testPhoto;
  final sources = <PhotoSource>[];

  @override
  Future<Photo?> pick(PhotoSource source) async {
    sources.add(source);
    final next = this.next;
    if (next is PhotoPickerException) throw next;
    return next as Photo?;
  }
}

/// Answers detections in order from [answers]: a list of names, or an
/// [IngredientDetectionError] to throw. While [gate] is set, detection waits
/// for it to complete.
class FakeIngredientRepository implements IngredientRepository {
  final answers = <Object>[];
  final photos = <Photo>[];
  Completer<void>? gate;

  @override
  Future<List<Ingredient>> detectFromPhoto(Photo photo) async {
    photos.add(photo);
    await gate?.future;
    final answer = answers.removeAt(0);
    if (answer is IngredientDetectionError) {
      throw IngredientDetectionException(answer);
    }
    return [for (final name in answer as List<String>) Ingredient.named(name)];
  }
}
