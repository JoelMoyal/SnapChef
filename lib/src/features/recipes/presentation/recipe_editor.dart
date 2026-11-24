import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../accounts/application/auth_providers.dart';
import '../../ingredients/application/ingredient_providers.dart';
import '../../ingredients/data/photo_picker.dart';
import '../application/recipe_providers.dart';

class RecipeEditor extends ConsumerStatefulWidget {
  const RecipeEditor({super.key, this.recipe});
  final Map<String, dynamic>? recipe;
  @override
  ConsumerState<RecipeEditor> createState() => _RecipeEditorState();
}

class _IngredientFields {
  _IngredientFields([Map<String, dynamic>? value])
    : name = TextEditingController(text: value?['name'] as String? ?? ''),
      quantity = TextEditingController(
        text: value?['quantity']?.toString() ?? '',
      ),
      unit = value?['unit'] as String?;
  final TextEditingController name, quantity;
  String? unit;
  void dispose() {
    name.dispose();
    quantity.dispose();
  }
}

class _RecipeEditorState extends ConsumerState<RecipeEditor> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _title;
  final _ingredients = <_IngredientFields>[];
  final _steps = <TextEditingController>[];
  final _allergens = <String>{}, _dietary = <String>{};
  String? _meal, _cuisine, _savedId;
  bool _declared = false, _published = false, _busy = false;
  Photo? _photo;

  @override
  void initState() {
    super.initState();
    final r = widget.recipe;
    _title = TextEditingController(text: r?['title'] as String? ?? '');
    _savedId = r?['id'] as String?;
    _meal = r?['meal_type'] as String?;
    _cuisine = r?['cuisine'] as String?;
    _published = r?['visibility'] == 'published';
    _declared = r?['allergens_declared'] == true;
    _allergens.addAll(List<String>.from(r?['allergens'] as List? ?? []));
    _dietary.addAll(List<String>.from(r?['dietary_tags'] as List? ?? []));
    for (final i in r?['ingredients'] as List? ?? []) {
      _ingredients.add(_IngredientFields(Map<String, dynamic>.from(i as Map)));
    }
    if (_ingredients.isEmpty) _ingredients.add(_IngredientFields());
    for (final s in r?['steps'] as List? ?? []) {
      _steps.add(TextEditingController(text: s as String));
    }
    if (_steps.isEmpty) _steps.add(TextEditingController());
  }

  @override
  void dispose() {
    _title.dispose();
    for (final i in _ingredients) {
      i.dispose();
    }
    for (final s in _steps) {
      s.dispose();
    }
    super.dispose();
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Required' : null;

  Future<void> _pick(PhotoSource source) async {
    setState(() => _busy = true);
    try {
      final photo = await ref.read(photoPickerProvider).pick(source);
      if (photo == null || !mounted) return;
      if (!{'image/jpeg', 'image/png', 'image/webp'}.contains(photo.mimeType) ||
          photo.bytes.length > 5242880) {
        throw StateError('Choose a JPEG, PNG or WebP photo under 5 MB.');
      }
      setState(() => _photo = photo);
    } catch (_) {
      if (mounted) {
        _message(
          'Could not use that photo. Allow photo/camera access and choose a JPEG, PNG or WebP image under 5 MB.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) {
      _message('Please log in again.');
      return;
    }
    setState(() => _busy = true);
    bool recipeSaved = false;
    try {
      final draft = RecipeDraft(
        title: _title.text,
        mealType: _meal!,
        cuisine: _cuisine!,
        ingredients: _ingredients
            .map(
              (i) => RecipeIngredient(
                i.name.text,
                num.parse(i.quantity.text.trim()),
                i.unit!,
              ),
            )
            .toList(),
        steps: _steps.map((s) => s.text.trim()).toList(),
        allergens: _allergens.toList(),
        allergensDeclared: _declared,
        dietaryTags: _dietary.toList(),
        published: _published,
        authorFirstName: user.firstName.isEmpty
            ? 'Community member'
            : user.firstName,
      );
      final repo = ref.read(recipeRepositoryProvider);
      final row = _savedId == null
          ? await repo.create(draft)
          : await repo.update(_savedId!, draft);
      _savedId = row['id'] as String;
      recipeSaved = true;
      ref.invalidate(recipeListProvider);
      ref.invalidate(recipeDetailProvider);
      if (_photo != null) {
        await repo.uploadPhoto(
          _savedId!,
          _photo!.bytes,
          contentType: _photo!.mimeType!,
        );
        ref.invalidate(recipePhotoProvider);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        _message(
          recipeSaved
              ? 'Recipe saved, but the photo upload failed. Tap Save again to retry without creating a duplicate.'
              : recipeError(e),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.recipe == null ? 'Create recipe' : 'Edit recipe'),
    ),
    body: ref
        .watch(recipeOptionsProvider)
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(recipeError(e)),
                TextButton(
                  onPressed: () => ref.invalidate(recipeOptionsProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
          data: (options) {
            List<String> choices(String kind) => options
                .where((o) => o['kind'] == kind)
                .map((o) => o['value'] as String)
                .toList();
            Widget dropdown(
              String label,
              String? value,
              List<String> values,
              ValueChanged<String?> changed,
            ) => DropdownButtonFormField<String>(
              initialValue: values.contains(value) ? value : null,
              decoration: InputDecoration(labelText: label),
              isExpanded: true,
              items: values
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              validator: _required,
              onChanged: changed,
            );
            return AbsorbPointer(
              absorbing: _busy,
              child: Form(
                key: _form,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _title,
                        maxLength: 160,
                        validator: _required,
                        decoration: const InputDecoration(
                          labelText: 'Recipe title',
                        ),
                      ),
                      dropdown(
                        'Meal type',
                        _meal,
                        choices('meal'),
                        (v) => setState(() => _meal = v),
                      ),
                      dropdown(
                        'Cuisine',
                        _cuisine,
                        choices('cuisine'),
                        (v) => setState(() => _cuisine = v),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Ingredients',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      for (final i in _ingredients)
                        Card(
                          key: ObjectKey(i),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              children: [
                                TextFormField(
                                  controller: i.name,
                                  maxLength: 120,
                                  validator: _required,
                                  decoration: const InputDecoration(
                                    labelText: 'Ingredient name',
                                  ),
                                ),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        controller: i.quantity,
                                        keyboardType:
                                            const TextInputType.numberWithOptions(
                                              decimal: true,
                                            ),
                                        decoration: const InputDecoration(
                                          labelText: 'Quantity',
                                        ),
                                        validator: (v) {
                                          final n = num.tryParse(
                                            v?.trim() ?? '',
                                          );
                                          return n == null ||
                                                  !n.isFinite ||
                                                  n <= 0
                                              ? 'Enter a positive number'
                                              : null;
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: dropdown(
                                        'Unit',
                                        i.unit,
                                        choices('unit'),
                                        (v) => setState(() => i.unit = v),
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Remove ingredient',
                                      onPressed: _ingredients.length == 1
                                          ? null
                                          : () {
                                              setState(
                                                () => _ingredients.remove(i),
                                              );
                                              // Dispose after the TextFields have detached from their controllers.
                                              WidgetsBinding.instance
                                                  .addPostFrameCallback(
                                                    (_) => i.dispose(),
                                                  );
                                            },
                                      icon: const Icon(
                                        Icons.remove_circle_outline,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      TextButton.icon(
                        onPressed: () => setState(
                          () => _ingredients.add(_IngredientFields()),
                        ),
                        icon: const Icon(Icons.add),
                        label: const Text('Add ingredient'),
                      ),
                      Text(
                        'Preparation',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      for (final s in _steps)
                        Row(
                          key: ObjectKey(s),
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: s,
                                maxLines: null,
                                validator: _required,
                                decoration: InputDecoration(
                                  labelText: 'Step ${_steps.indexOf(s) + 1}',
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Remove step',
                              onPressed: _steps.length == 1
                                  ? null
                                  : () {
                                      setState(() => _steps.remove(s));
                                      WidgetsBinding.instance
                                          .addPostFrameCallback(
                                            (_) => s.dispose(),
                                          );
                                    },
                              icon: const Icon(Icons.remove_circle_outline),
                            ),
                          ],
                        ),
                      TextButton.icon(
                        onPressed: () =>
                            setState(() => _steps.add(TextEditingController())),
                        icon: const Icon(Icons.add),
                        label: const Text('Add step'),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Allergens contained',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Wrap(
                        spacing: 8,
                        children: choices('allergen')
                            .map(
                              (s) => FilterChip(
                                label: Text(s),
                                selected: _allergens.contains(s),
                                onSelected: (v) => setState(() {
                                  v ? _allergens.add(s) : _allergens.remove(s);
                                  _declared = false;
                                }),
                              ),
                            )
                            .toList(),
                      ),
                      FormField<bool>(
                        validator: (_) => _declared
                            ? null
                            : 'Confirm your allergen declaration.',
                        builder: (field) => Column(
                          children: [
                            CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              value: _declared,
                              title: Text(
                                _allergens.isEmpty
                                    ? 'I confirm this recipe contains none of the listed allergens'
                                    : 'I confirm the selected allergens',
                              ),
                              onChanged: (v) {
                                setState(() => _declared = v ?? false);
                                field.didChange(v);
                              },
                            ),
                            if (field.hasError)
                              Text(
                                field.errorText!,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const Text(
                        'Declarations do not guarantee allergen-free meals. Check ingredients and cross-contact information.',
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Dietary tags',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Wrap(
                        spacing: 8,
                        children: choices('dietary')
                            .map(
                              (s) => FilterChip(
                                label: Text(s),
                                selected: _dietary.contains(s),
                                onSelected: (v) => setState(() {
                                  v ? _dietary.add(s) : _dietary.remove(s);
                                }),
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 16),
                      if (_photo != null)
                        Image.memory(
                          _photo!.bytes,
                          height: 150,
                          fit: BoxFit.cover,
                        ),
                      if (_photo == null &&
                          widget.recipe?['photo_path'] != null)
                        const Text(
                          'Existing photo will be kept unless replaced.',
                        ),
                      Wrap(
                        spacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => _pick(PhotoSource.gallery),
                            icon: const Icon(Icons.photo_library_outlined),
                            label: const Text('Choose photo'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => _pick(PhotoSource.camera),
                            icon: const Icon(Icons.camera_alt_outlined),
                            label: const Text('Take photo'),
                          ),
                          if (_photo != null)
                            TextButton(
                              onPressed: () => setState(() => _photo = null),
                              child: const Text('Cancel new photo'),
                            ),
                        ],
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Publish to community'),
                        subtitle: Text(
                          _published
                              ? 'Other signed-in users can see and save this recipe.'
                              : 'Only you can read this recipe.',
                        ),
                        value: _published,
                        onChanged: (v) => setState(() => _published = v),
                      ),
                      FilledButton(
                        onPressed: _busy ? null : _save,
                        child: Text(_busy ? 'Saving…' : 'Save recipe'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
  );
}
