import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

SupabaseClient get backend => Supabase.instance.client;

Future<Map<String, dynamic>> loadProfile() async {
  final user = backend.auth.currentUser;
  if (user == null) throw StateError('Please log in again.');
  final row = await backend.from('snapchef_profiles').select().eq('id', user.id).maybeSingle();
  if (row != null) return row;
  // Handles accounts created before the database setup script was installed.
  final profile = <String, dynamic>{
    'id': user.id,
    'full_name': user.userMetadata?['full_name'] ?? '',
    'dietary_preferences': user.userMetadata?['dietary_preferences'] ?? <String>[],
  };
  return await backend.from('snapchef_profiles').upsert(profile).select().single();
}

Future<void> saveProfile(Map<String, dynamic> values) async {
  final user = backend.auth.currentUser;
  if (user == null) throw StateError('Please log in again.');
  await backend.from('snapchef_profiles').upsert({...values, 'id': user.id});
}

String backendError(Object error) {
  if (error is AuthException) return error.message;
  if (error is PostgrestException) {
    if (error.code == '42P01' || error.code == 'PGRST205') {
      return 'The profile table is not set up yet. Run supabase/setup.sql in your Supabase SQL Editor, then retry.';
    }
    return 'Could not load or save your profile. Check the database setup and access policies, then retry.';
  }
  return 'Unable to connect. Check your internet connection and try again.';
}

void showBackendError(BuildContext context, Object error) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(backendError(error))));
}
