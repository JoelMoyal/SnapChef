import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snapchef/src/core/models/app_user.dart';
import 'package:snapchef/src/features/accounts/application/auth_providers.dart';
import 'package:snapchef/src/features/accounts/application/profile_providers.dart';
import 'package:snapchef/src/features/accounts/data/profile_repository.dart';
import 'package:snapchef/src/features/recipes/application/recipe_providers.dart';
import 'package:snapchef/src/features/recipes/presentation/recipes_screen.dart';

final _row = <String, dynamic>{
  'id': 'recipe-a',
  'owner_id': 'user-a',
  'title': 'Private tomato supper',
  'author_first_name': 'Alex',
  'meal_type': 'Dinner',
  'cuisine': 'Italian',
  'visibility': 'private',
  'ingredients': [
    {'name': 'tomato', 'quantity': 2, 'unit': 'piece'},
  ],
  'steps': ['Cook the tomatoes.'],
  'allergens': <String>[],
  'allergens_declared': true,
  'dietary_tags': <String>[],
};

class _Recipes extends Fake implements RecipeDataSource {
  int saves = 0;
  @override
  Future<List<Map<String, dynamic>>> options() async => [
    {'kind': 'meal', 'value': 'Dinner'},
    {'kind': 'cuisine', 'value': 'Italian'},
    {'kind': 'unit', 'value': 'piece'},
    {'kind': 'allergen', 'value': 'Milk'},
  ];
  @override
  Future<List<Map<String, dynamic>>> mine({int offset = 0}) async => [_row];
  @override
  Future<List<Map<String, dynamic>>> community({
    String? mealType,
    String? cuisine,
    int offset = 0,
  }) async => [];
  @override
  Future<Map<String, dynamic>> get(String id) async => _row;
  @override
  Future<bool> isSaved(String id) async => false;
  @override
  Future<Map<String, dynamic>> create(RecipeDraft draft) async {
    saves++;
    return _row;
  }
}

Future<void> _pump(
  WidgetTester tester,
  _Recipes repo, {
  String userId = 'user-a',
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        recipeRepositoryProvider.overrideWithValue(repo),
        profileRepositoryProvider.overrideWithValue(StubProfileRepository()),
        authStateProvider.overrideWith(
          (ref) => Stream.value(
            AppUser(
              id: userId,
              email: 'test@example.com',
              firstName: 'Alex',
              lastName: 'Tester',
            ),
          ),
        ),
      ],
      child: const MaterialApp(home: Scaffold(body: RecipesScreen())),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('opens private recipe details and shows owner actions', (
    tester,
  ) async {
    await _pump(tester, _Recipes());
    await tester.tap(find.text('Private tomato supper'));
    await tester.pumpAndSettle();
    expect(find.textContaining('2 piece tomato'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Edit recipe'), 250);
    expect(find.text('Edit recipe'), findsOneWidget);
    expect(find.text('Delete recipe'), findsOneWidget);
    expect(find.text('Save recipe'), findsNothing);
  });

  testWidgets('does not render edit/delete actions for another owner', (
    tester,
  ) async {
    // The fake intentionally supplies a foreign private row to exercise the UI
    // ownership guard independently; real database RLS excludes this row.
    await _pump(tester, _Recipes(), userId: 'user-b');
    await tester.tap(find.text('Private tomato supper'));
    await tester.pumpAndSettle();
    expect(find.text('Edit recipe'), findsNothing);
    expect(find.text('Delete recipe'), findsNothing);
  });

  testWidgets('rejects an incomplete recipe without writing to storage', (
    tester,
  ) async {
    final repo = _Recipes();
    await _pump(tester, repo);
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Save recipe'),
      350,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Save recipe'));
    await tester.pumpAndSettle();
    expect(repo.saves, 0);
    await tester.scrollUntilVisible(
      find.text('Confirm your allergen declaration.'),
      -150,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Confirm your allergen declaration.'), findsOneWidget);
  });
}
