import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../accounts/application/auth_providers.dart';
import '../application/recipe_providers.dart';
import 'recipe_editor.dart';

class RecipesScreen extends ConsumerStatefulWidget {
  const RecipesScreen({super.key});
  @override
  ConsumerState<RecipesScreen> createState() => _RecipesScreenState();
}

class _RecipesScreenState extends ConsumerState<RecipesScreen> {
  String _list = 'My recipes';
  String? _meal, _cuisine;
  int _page = 0;
  @override
  Widget build(BuildContext context) {
    final query = (list: _list, meal: _meal, cuisine: _cuisine, page: _page);
    final result = ref.watch(recipeListProvider(query));
    final options = ref.watch(recipeOptionsProvider).valueOrNull ?? [];
    final allergens = ref.watch(recipeAllergensProvider);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _list,
                      decoration: const InputDecoration(
                        labelText: 'Recipe list',
                      ),
                      items: ['My recipes', 'Community', 'Saved', 'Catalog']
                          .map(
                            (s) => DropdownMenuItem(value: s, child: Text(s)),
                          )
                          .toList(),
                      onChanged: (s) => setState(() {
                        _list = s!;
                        _page = 0;
                      }),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: () => _edit(context, ref),
                    icon: const Icon(Icons.add),
                    label: const Text('Create'),
                  ),
                ],
              ),
              if (_list == 'Community')
                Row(
                  children: [
                    for (final kind in ['meal', 'cuisine'])
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8, top: 8),
                          child: DropdownButtonFormField<String>(
                            initialValue: kind == 'meal' ? _meal : _cuisine,
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: kind == 'meal'
                                  ? 'Meal type'
                                  : 'Cuisine',
                            ),
                            items: [
                              const DropdownMenuItem<String>(
                                value: null,
                                child: Text('All'),
                              ),
                              ...options
                                  .where((o) => o['kind'] == kind)
                                  .map(
                                    (o) => DropdownMenuItem(
                                      value: o['value'] as String,
                                      child: Text(o['value'] as String),
                                    ),
                                  ),
                            ],
                            onChanged: (v) => setState(() {
                              if (kind == 'meal') {
                                _meal = v;
                              } else {
                                _cuisine = v;
                              }
                              _page = 0;
                            }),
                          ),
                        ),
                      ),
                  ],
                ),
              if (allergens.hasError)
                const Text(
                  'Allergen preferences could not be loaded. Check ingredients carefully.',
                ),
            ],
          ),
        ),
        Expanded(
          child: result.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(recipeError(e)),
                  ),
                  TextButton(
                    onPressed: () => ref.invalidate(recipeListProvider(query)),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
            data: (rows) => RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(recipeAllergensProvider);
                ref.invalidate(recipeListProvider(query));
                await ref.read(recipeListProvider(query).future);
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(12),
                children: [
                  if (rows.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'No recipes here yet. Create a recipe or explore the other lists.',
                      ),
                    ),
                  for (final row in rows)
                    Card(
                      child: ListTile(
                        leading: RecipeThumbnail(
                          path: row['photo_path'] as String?,
                        ),
                        title: Text(row['title'] as String),
                        subtitle: Text(
                          '${row['author_first_name']} · ${row['meal_type']} · ${row['cuisine']}\n'
                          '${row['visibility'] == 'private' ? 'Private' : 'Published'}'
                          '${_conflicts(row, allergens.valueOrNull ?? {}).isEmpty ? '' : '\nAllergen warning: ${_conflicts(row, allergens.valueOrNull ?? {}).join(', ')}'}',
                        ),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                RecipeDetailScreen(id: row['id'] as String),
                          ),
                        ),
                      ),
                    ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: _page == 0
                            ? null
                            : () => setState(() => _page--),
                        child: const Text('Previous'),
                      ),
                      Text('Page ${_page + 1}'),
                      TextButton(
                        onPressed: rows.length < 30
                            ? null
                            : () => setState(() => _page++),
                        child: const Text('Next'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

List<String> _conflicts(Map<String, dynamic> row, Set<String> selected) =>
    List<String>.from(row['allergens'] as List)
        .where(selected.contains)
        .toList();

class RecipeThumbnail extends ConsumerWidget {
  const RecipeThumbnail({super.key, this.path});
  final String? path;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (path == null) return const Icon(Icons.restaurant_menu);
    return ref
        .watch(recipePhotoProvider(path!))
        .when(
          loading: () => const SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(),
          ),
          error: (_, _) => const Icon(Icons.image_not_supported_outlined),
          data: (bytes) =>
              Image.memory(bytes, width: 48, height: 48, fit: BoxFit.cover),
        );
  }
}

Future<void> _edit(
  BuildContext context,
  WidgetRef ref, [
  Map<String, dynamic>? recipe,
]) async {
  final saved = await Navigator.of(
    context,
  ).push<bool>(MaterialPageRoute(builder: (_) => RecipeEditor(recipe: recipe)));
  if (!context.mounted) return;
  if (saved == true) {
    ref.invalidate(recipeListProvider);
    ref.invalidate(recipeDetailProvider);
    ref.invalidate(recipePhotoProvider);
  }
}

class RecipeDetailScreen extends ConsumerStatefulWidget {
  const RecipeDetailScreen({super.key, required this.id});
  final String id;
  @override
  ConsumerState<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends ConsumerState<RecipeDetailScreen> {
  bool _busy = false;
  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(recipeError(e))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(authStateProvider).valueOrNull;
    final saved = ref.watch(recipeSavedProvider(widget.id));
    final preferences = ref.watch(recipeAllergensProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Recipe')),
      body: ref
          .watch(recipeDetailProvider(widget.id))
          .when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('This recipe may be unavailable or private.'),
                  TextButton(
                    onPressed: () =>
                        ref.invalidate(recipeDetailProvider(widget.id)),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
            data: (r) {
              final own =
                  r['owner_id'] == currentUser?.id && currentUser != null;
              final conflicts = _conflicts(r, preferences.valueOrNull ?? {});
              return ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  if (r['photo_path'] != null)
                    ref
                        .watch(recipePhotoProvider(r['photo_path'] as String))
                        .when(
                          loading: () => const LinearProgressIndicator(),
                          error: (_, _) => const Text('Photo unavailable.'),
                          data: (bytes) => Image.memory(
                            bytes,
                            height: 220,
                            fit: BoxFit.cover,
                          ),
                        ),
                  Text(
                    r['title'] as String,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  Text(
                    '${r['author_first_name']} · ${r['meal_type']} · ${r['cuisine']} · ${r['visibility']}',
                  ),
                  if (conflicts.isNotEmpty)
                    Text(
                      'Allergen warning: ${conflicts.join(', ')}',
                      style: const TextStyle(color: Colors.red),
                    ),
                  if (preferences.isLoading || preferences.hasError)
                    const Text(
                      'Allergen preferences are unavailable. Check ingredients before cooking.',
                    ),
                  Text(
                    'Declared allergens: ${(r['allergens'] as List).isEmpty ? 'None' : (r['allergens'] as List).join(', ')}',
                  ),
                  const Text(
                    'Always check ingredients and cross-contact information.',
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Ingredients',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  for (final i in r['ingredients'] as List)
                    Text('• ${i['quantity']} ${i['unit']} ${i['name']}'),
                  const SizedBox(height: 20),
                  Text(
                    'Preparation',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  for (final s in (r['steps'] as List).asMap().entries)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Text('${s.key + 1}. ${s.value}'),
                    ),
                  const SizedBox(height: 20),
                  if (r['visibility'] == 'published')
                    FilledButton.tonal(
                      onPressed: _busy || !saved.hasValue
                          ? null
                          : () => _run(() async {
                              final repo = ref.read(recipeRepositoryProvider);
                              if (saved.value!) {
                                await repo.unsave(widget.id);
                              } else {
                                await repo.save(widget.id);
                              }
                              ref.invalidate(recipeSavedProvider(widget.id));
                              ref.invalidate(recipeListProvider);
                            }),
                      child: Text(
                        saved.valueOrNull == true
                            ? 'Remove from saved'
                            : 'Save recipe',
                      ),
                    ),
                  if (saved.hasError)
                    TextButton(
                      onPressed: () =>
                          ref.invalidate(recipeSavedProvider(widget.id)),
                      child: const Text('Retry bookmark status'),
                    ),
                  if (own) ...[
                    OutlinedButton(
                      onPressed: _busy ? null : () => _edit(context, ref, r),
                      child: const Text('Edit recipe'),
                    ),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () async {
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (c) => AlertDialog(
                                  title: const Text('Delete recipe?'),
                                  content: const Text(
                                    'The recipe and its bookmarks will be removed. This cannot be undone.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(c, false),
                                      child: const Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.pop(c, true),
                                      child: const Text('Delete'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirmed != true || !context.mounted) return;
                              await _run(() async {
                                await ref
                                    .read(recipeRepositoryProvider)
                                    .delete(widget.id);
                                ref.invalidate(recipeListProvider);
                                if (context.mounted) Navigator.pop(context);
                              });
                            },
                      child: const Text('Delete recipe'),
                    ),
                  ],
                ],
              );
            },
          ),
    );
  }
}
