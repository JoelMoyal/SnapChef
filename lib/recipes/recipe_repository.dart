import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

/// A complete recipe is saved in one database statement. Array order is the
/// display order for ingredients and preparation steps.
class RecipeDraft {
  const RecipeDraft({
    required this.title,
    required this.mealType,
    required this.cuisine,
    required this.ingredients,
    required this.steps,
    required this.allergens,
    required this.allergensDeclared,
    this.dietaryTags = const [],
    this.published = false,
    this.authorFirstName = 'Community member',
  });

  final String title;
  final String mealType;
  final String cuisine;
  final List<RecipeIngredient> ingredients;
  final List<String> steps;
  final List<String> allergens;
  final bool allergensDeclared;
  final List<String> dietaryTags;
  final bool published;
  final String authorFirstName;

  Map<String, dynamic> toJson() => {
    'title': title.trim(),
    'meal_type': mealType,
    'cuisine': cuisine,
    'ingredients': ingredients.map((i) => i.toJson()).toList(),
    'steps': steps.map((s) => s.trim()).toList(),
    'allergens': allergens,
    'allergens_declared': allergensDeclared,
    'dietary_tags': dietaryTags,
    'visibility': published ? 'published' : 'private',
    'author_first_name': authorFirstName.trim(),
  };
}

class RecipeIngredient {
  const RecipeIngredient(this.name, this.quantity, this.unit);

  final String name;
  final num quantity;
  final String unit;

  Map<String, dynamic> toJson() => {
    'name': name.trim(), 'quantity': quantity, 'unit': unit,
  };
}

/// Uses the caller's existing Supabase session. Database policies remain the
/// authority for access, even if a caller bypasses this repository.
class RecipeRepository {
  RecipeRepository(this.client);

  final SupabaseClient client;
  static const photoBucket = 'recipe-photos';

  String get _userId {
    final id = client.auth.currentUser?.id;
    if (id == null) throw StateError('Please log in again.');
    return id;
  }

  Future<List<Map<String, dynamic>>> options() async =>
      await client.from('recipe_options').select().order('kind').order('value');

  Future<Map<String, dynamic>> create(RecipeDraft draft) async =>
      await client.from('recipes').insert({
        ...draft.toJson(), 'owner_id': _userId,
      }).select().single();

  Future<Map<String, dynamic>> update(String id, RecipeDraft draft) async =>
      await client.from('recipes').update(draft.toJson())
          .eq('id', id).eq('owner_id', _userId).select().single();

  Future<Map<String, dynamic>> get(String id) async =>
      await client.from('recipes').select().eq('id', id).single();

  Future<List<Map<String, dynamic>>> mine({int offset = 0}) async =>
      await client.from('recipes').select().eq('owner_id', _userId)
          .order('created_at', ascending: false).order('id')
          .range(_offset(offset), _offset(offset) + 29);

  /// Community excludes the caller's own recipes and the curated catalog.
  Future<List<Map<String, dynamic>>> community({
    String? mealType, String? cuisine, int offset = 0,
  }) async {
    var query = client.from('recipes').select()
        .eq('source', 'community').eq('visibility', 'published')
        .or('owner_id.neq.$_userId,owner_id.is.null');
    if (mealType != null) query = query.eq('meal_type', mealType);
    if (cuisine != null) query = query.eq('cuisine', cuisine);
    return await query.order('published_at', ascending: false).order('id')
        .range(_offset(offset), _offset(offset) + 29);
  }

  Future<List<Map<String, dynamic>>> catalog({int offset = 0}) async =>
      await client.from('recipes').select().eq('source', 'catalog')
          .order('title').order('id')
          .range(_offset(offset), _offset(offset) + 29);

  /// The UI must obtain confirmation before calling this method.
  Future<void> delete(String id) async {
    await client.from('recipes').delete().eq('id', id)
        .eq('owner_id', _userId).select().single();
  }

  Future<void> save(String recipeId) async {
    await client.from('saved_recipes').upsert({
      'user_id': _userId, 'recipe_id': recipeId,
    }, onConflict: 'user_id,recipe_id', ignoreDuplicates: true);
  }

  Future<void> unsave(String recipeId) async {
    await client.from('saved_recipes').delete()
        .eq('user_id', _userId).eq('recipe_id', recipeId);
  }

  /// An unavailable (unpublished) original is omitted by the inner join/RLS.
  Future<List<Map<String, dynamic>>> saved({int offset = 0}) async =>
      await client.from('saved_recipes')
          .select('saved_at, recipes!inner(*)').eq('user_id', _userId)
          .order('saved_at', ascending: false).order('recipe_id')
          .range(_offset(offset), _offset(offset) + 29);

  Future<List<Map<String, dynamic>>> recommend(List<String> ingredients) async {
    _userId;
    final result = await client.rpc('recommend_recipes', params: {
      'p_ingredients': ingredients, 'p_limit': 30,
    });
    return List<Map<String, dynamic>>.from(result as List);
  }

  Future<void> uploadPhoto(String recipeId, Uint8List bytes, {
    required String contentType,
  }) async {
    _userId;
    final path = '$recipeId/photo';
    await client.storage.from(photoBucket).uploadBinary(path, bytes,
      fileOptions: FileOptions(upsert: true, contentType: contentType));
    // If linking fails, retry; deleting the recipe also queues this fixed path.
    await client.from('recipes').update({'photo_path': path})
        .eq('id', recipeId).eq('owner_id', _userId).select().single();
  }

  Future<Uint8List> downloadPhoto(String path) =>
      client.storage.from(photoBucket).download(path);

  /// Caller must first show the confirmation and explicit keep/discard choice.
  Future<void> deleteAccount({required bool keepPublished}) async {
    _userId;
    final response = await client.functions.invoke('delete-account', body: {
      'confirmation': 'DELETE', 'keepPublished': keepPublished,
    });
    if (response.status != 200 || response.data is! Map ||
        response.data['deleted'] != true) {
      throw StateError('Account deletion failed. Please retry.');
    }
    await client.auth.signOut(scope: SignOutScope.local);
  }

  int _offset(int offset) {
    if (offset < 0) throw ArgumentError.value(offset, 'offset');
    return offset;
  }
}
