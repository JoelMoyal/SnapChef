import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/models/food_preferences.dart';

/// Thrown when preferences can't be loaded or saved; [message] is shown to
/// the user as-is.
class ProfileException implements Exception {
  const ProfileException(this.message);

  final String message;

  @override
  String toString() => 'ProfileException($message)';
}

/// Contract for the signed-in user's stored food preferences.
abstract interface class ProfileRepository {
  Future<FoodPreferences> loadPreferences();
  Future<void> savePreferences(FoodPreferences preferences);
}

/// In-memory stub for tests.
class StubProfileRepository implements ProfileRepository {
  FoodPreferences _stored = const FoodPreferences();

  @override
  Future<FoodPreferences> loadPreferences() async => _stored;

  @override
  Future<void> savePreferences(FoodPreferences preferences) async {
    _stored = preferences;
  }
}

/// Stores preferences in the `snapchef_profiles` table, one row per user.
class SupabaseProfileRepository implements ProfileRepository {
  SupabaseProfileRepository(this._client);

  final SupabaseClient _client;

  static const _table = 'snapchef_profiles';

  @override
  Future<FoodPreferences> loadPreferences() async {
    final user = _requireUser();
    try {
      var row = await _client
          .from(_table)
          .select()
          .eq('id', user.id)
          .maybeSingle();
      // Accounts created before the table existed have no row yet.
      row ??= await _client
          .from(_table)
          .upsert({
            'id': user.id,
            'full_name': user.userMetadata?['full_name'] ?? '',
            'dietary_preferences':
                user.userMetadata?['dietary_preferences'] ?? const <String>[],
          })
          .select()
          .single();
      return FoodPreferences(
        dietary: _set(row['dietary_preferences']),
        mealTypes: _set(row['meal_types']),
        cuisines: _set(row['cuisines']),
        allergens: _set(row['allergens']),
        otherAllergens: row['other_allergens'] as String? ?? '',
      );
    } catch (error) {
      throw _map(error);
    }
  }

  @override
  Future<void> savePreferences(FoodPreferences preferences) async {
    final user = _requireUser();
    try {
      await _client.from(_table).upsert({
        'id': user.id,
        'dietary_preferences': preferences.dietary.toList(),
        'meal_types': preferences.mealTypes.toList(),
        'cuisines': preferences.cuisines.toList(),
        'allergens': preferences.allergens.toList(),
        'other_allergens': preferences.otherAllergens.trim(),
      });
    } catch (error) {
      throw _map(error);
    }
  }

  User _requireUser() {
    final user = _client.auth.currentUser;
    if (user == null) throw const ProfileException('Please log in again.');
    return user;
  }

  static Set<String> _set(Object? value) => {
    ...List<String>.from(value as List? ?? const []),
  };

  static ProfileException _map(Object error) {
    if (error is PostgrestException) {
      if (error.code == '42P01' || error.code == 'PGRST205') {
        return const ProfileException(
          'The profile table is not set up yet. '
          'Run supabase/setup.sql in the Supabase SQL Editor, then retry.',
        );
      }
      return const ProfileException(
        'Could not load or save your preferences. Please try again.',
      );
    }
    return const ProfileException(
      'Unable to connect. Check your internet connection and try again.',
    );
  }
}
