import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/models/ingredient.dart';
import 'ingredient_repository.dart';
import 'photo_picker.dart';

/// Recognizes ingredients with the `detect-ingredients` Edge Function
/// (`supabase/functions/detect-ingredients`), which calls the vision model
/// with a key that never leaves the server. Photos are not stored.
class SupabaseIngredientRepository implements IngredientRepository {
  SupabaseIngredientRepository(
    this._functions, {
    this.timeout = const Duration(seconds: 45),
  });

  final FunctionsClient _functions;

  /// Longer than the function's own provider timeout, so a slow answer
  /// usually arrives as the function's 504 rather than a dropped request.
  final Duration timeout;

  static const _function = 'detect-ingredients';

  /// Formats the function accepts.
  static const supportedMimeTypes = {
    'image/jpeg',
    'image/png',
    'image/webp',
    'image/heic',
    'image/heif',
  };

  @override
  Future<List<Ingredient>> detectFromPhoto(Photo photo) async {
    final mimeType = photo.mimeType;
    if (!supportedMimeTypes.contains(mimeType)) {
      throw const IngredientDetectionException(
        IngredientDetectionError.invalidPhoto,
      );
    }

    final FunctionResponse response;
    try {
      response = await _functions
          .invoke(
            _function,
            body: {'image': base64Encode(photo.bytes), 'mimeType': mimeType},
          )
          .timeout(timeout);
    } on TimeoutException {
      throw const IngredientDetectionException(
        IngredientDetectionError.timeout,
      );
    } on FunctionsFetchException {
      throw const IngredientDetectionException(
        IngredientDetectionError.offline,
      );
    } on FunctionException catch (e) {
      final error = switch (e.status) {
        400 || 413 || 415 => IngredientDetectionError.invalidPhoto,
        401 => IngredientDetectionError.signedOut,
        429 => IngredientDetectionError.busy,
        504 => IngredientDetectionError.timeout,
        _ => IngredientDetectionError.failed,
      };
      if (error == IngredientDetectionError.failed) {
        // For example 404 when the function hasn't been deployed.
        debugPrint('$_function failed: ${e.status} ${e.details}');
      }
      throw IngredientDetectionException(error);
    }
    return _parse(response.data);
  }

  static List<Ingredient> _parse(Object? data) {
    final items = data is Map ? data['ingredients'] : null;
    if (items is! List) {
      throw const IngredientDetectionException(IngredientDetectionError.failed);
    }
    return [
      for (final item in items)
        if (item case {'name': final String name}) Ingredient.named(name),
    ].where((ingredient) => ingredient.id.isNotEmpty).toList();
  }
}
