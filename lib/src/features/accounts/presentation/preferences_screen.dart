import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/food_preferences.dart';
import '../application/profile_providers.dart';
import '../data/profile_repository.dart';

/// Dietary preferences, meal types, cuisines, and allergens to avoid.
/// Originally built by Hetal on the `hetal` branch.
class PreferencesScreen extends ConsumerStatefulWidget {
  const PreferencesScreen({super.key});

  static Route<void> route() =>
      MaterialPageRoute(builder: (_) => const PreferencesScreen());

  @override
  ConsumerState<PreferencesScreen> createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends ConsumerState<PreferencesScreen> {
  final _dietary = <String>{};
  final _meals = <String>{};
  final _cuisines = <String>{};
  final _allergens = <String>{};
  final _other = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _other.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final prefs = await ref.read(profileRepositoryProvider).loadPreferences();
      if (!mounted) return;
      setState(() {
        _dietary
          ..clear()
          ..addAll(prefs.dietary);
        _meals
          ..clear()
          ..addAll(prefs.mealTypes);
        _cuisines
          ..clear()
          ..addAll(prefs.cuisines);
        _allergens
          ..clear()
          ..addAll(prefs.allergens);
        _other.text = prefs.otherAllergens;
      });
    } on ProfileException catch (e) {
      if (mounted) setState(() => _loadError = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(profileRepositoryProvider)
          .savePreferences(
            FoodPreferences(
              dietary: {..._dietary},
              mealTypes: {..._meals},
              cuisines: {..._cuisines},
              allergens: {..._allergens},
              otherAllergens: _other.text,
            ),
          );
      messenger.showSnackBar(
        const SnackBar(content: Text('Your preferences have been saved.')),
      );
    } on ProfileException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Your food preferences')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
          ? _LoadError(message: _loadError!, onRetry: _load)
          : _form(context),
    );
  }

  Widget _form(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return AbsorbPointer(
      absorbing: _saving,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Make it your kind of delicious.',
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          const Text('Choose the flavors you love and ingredients you avoid.'),
          _Section(
            title: 'Dietary preferences',
            options: FoodPreferences.dietaryOptions,
            selected: _dietary,
            onChanged: () => setState(() {}),
          ),
          _Section(
            title: 'Meal types',
            options: FoodPreferences.mealTypeOptions,
            selected: _meals,
            onChanged: () => setState(() {}),
          ),
          _Section(
            title: 'Favorite cuisines',
            subtitle: 'Pick as many as you like, or leave blank.',
            options: FoodPreferences.cuisineOptions,
            selected: _cuisines,
            onChanged: () => setState(() {}),
          ),
          _Section(
            title: 'Allergens to avoid',
            subtitle: 'Select all that apply (optional).',
            options: FoodPreferences.allergenOptions,
            selected: _allergens,
            onChanged: () => setState(() {}),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _other,
            maxLength: 200,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Other ingredients to avoid',
              hintText: 'For example: mustard',
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.secondaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Preferences do not guarantee allergen-free meals. '
              'Always check ingredients and cross-contact information.',
              style: TextStyle(color: colors.onSecondaryContainer),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Saving…' : 'Save preferences'),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final List<String> options;
  final Set<String> selected;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final option in options)
                FilterChip(
                  label: Text(option),
                  selected: selected.contains(option),
                  onSelected: (on) {
                    on ? selected.add(option) : selected.remove(option);
                    onChanged();
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
