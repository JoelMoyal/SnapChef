import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snapchef/src/features/accounts/application/auth_providers.dart';
import 'package:snapchef/src/features/accounts/data/auth_repository.dart';
import 'package:snapchef/src/features/ingredients/application/ingredient_providers.dart';
import 'package:snapchef/src/features/ingredients/data/ingredient_repository.dart';
import 'package:snapchef/src/features/ingredients/data/photo_picker.dart';
import 'package:snapchef/src/features/ingredients/presentation/ingredients_screen.dart';

import 'fakes.dart';

late FakePhotoPicker picker;
late FakeIngredientRepository repo;

Future<void> _pumpScreen(WidgetTester tester) async {
  picker = FakePhotoPicker();
  repo = FakeIngredientRepository();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(
          StubAuthRepository(latency: Duration.zero),
        ),
        photoPickerProvider.overrideWithValue(picker),
        ingredientRepositoryProvider.overrideWithValue(repo),
      ],
      child: const MaterialApp(home: Scaffold(body: IngredientsScreen())),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _type(WidgetTester tester, String text) async {
  await tester.enterText(
    find.widgetWithText(TextField, 'Add an ingredient'),
    text,
  );
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pumpAndSettle();
}

Finder _chip(String name) => find.widgetWithText(InputChip, name);

FilledButton _button(WidgetTester tester, String label) =>
    tester.widget<FilledButton>(
      find.ancestor(of: find.text(label), matching: find.byType(FilledButton)),
    );

void main() {
  testWidgets('starts with photo buttons and manual entry', (tester) async {
    await _pumpScreen(tester);

    expect(find.text('Take photo'), findsOneWidget);
    expect(find.text('Choose photo'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Add an ingredient'), findsOneWidget);
    expect(find.textContaining('Nothing here yet'), findsOneWidget);
    expect(_button(tester, 'Find recipes').onPressed, isNull);
  });

  testWidgets('photo → analyzing → fix the list → find recipes', (
    tester,
  ) async {
    await _pumpScreen(tester);
    repo
      ..gate = Completer()
      ..answers.add(['tomato', 'egg', 'onion']);

    await tester.tap(find.text('Take photo'));
    await tester.pump();
    expect(find.text('Finding ingredients…'), findsOneWidget);
    expect(_button(tester, 'Take photo').onPressed, isNull);

    repo.gate!.complete();
    await tester.pumpAndSettle();
    expect(
      find.text('Added 3 ingredients from your photo. Check them below.'),
      findsOneWidget,
    );
    expect(_chip('Tomato'), findsOneWidget);
    expect(_chip('Egg'), findsOneWidget);
    expect(_chip('Onion'), findsOneWidget);

    // Rename a wrong guess.
    await _tap(tester, _chip('Egg'));
    await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Duck egg');
    await _tap(tester, find.text('Save'));
    expect(_chip('Egg'), findsNothing);
    expect(_chip('Duck egg'), findsOneWidget);

    // Remove one, then undo.
    await _tap(tester, find.byTooltip('Remove Onion'));
    expect(_chip('Onion'), findsNothing);
    await _tap(tester, find.text('Undo'));
    expect(_chip('Onion'), findsOneWidget);

    // Add what the photo missed.
    await _type(tester, 'spinach, garlic');
    expect(_chip('Spinach'), findsOneWidget);
    expect(_chip('Garlic'), findsOneWidget);
    expect(find.text('Your ingredients (5)'), findsOneWidget);

    await _tap(tester, find.text('Find recipes'));
    expect(find.text('Recipe suggestions are coming soon'), findsOneWidget);
    for (final name in ['Garlic', 'Spinach', 'Tomato', 'Duck egg', 'Onion']) {
      expect(find.widgetWithText(Chip, name), findsOneWidget);
    }
  });

  testWidgets('a failed analysis can be retried', (tester) async {
    await _pumpScreen(tester);
    repo.answers
      ..add(IngredientDetectionError.offline)
      ..add(['egg']);

    await _tap(tester, find.text('Choose photo'));
    expect(find.textContaining('You’re offline'), findsOneWidget);

    await _tap(tester, find.text('Try again'));
    expect(repo.photos, [testPhoto, testPhoto]);
    expect(find.textContaining('You’re offline'), findsNothing);
    expect(_chip('Egg'), findsOneWidget);
  });

  testWidgets('denied camera access explains and offers typing instead', (
    tester,
  ) async {
    await _pumpScreen(tester);
    picker.next = const PhotoPickerException(PhotoPickerError.accessDenied);

    await _tap(tester, find.text('Take photo'));
    expect(find.textContaining('can’t use your camera'), findsOneWidget);
    expect(find.text('Try again'), findsNothing);

    await _tap(tester, find.text('Type instead'));
    final field = tester.widget<TextField>(
      find.widgetWithText(TextField, 'Add an ingredient'),
    );
    expect(field.focusNode!.hasFocus, isTrue);

    await _type(tester, 'eggs');
    expect(_chip('Eggs'), findsOneWidget);
    expect(_button(tester, 'Find recipes').onPressed, isNotNull);
  });

  testWidgets('says so when a photo shows no ingredients', (tester) async {
    await _pumpScreen(tester);
    repo.answers.add(<String>[]);

    await _tap(tester, find.text('Take photo'));

    expect(
      find.textContaining('couldn’t spot any ingredients'),
      findsOneWidget,
    );
    expect(find.textContaining('Nothing here yet'), findsOneWidget);
  });

  testWidgets('typing a listed ingredient says it is already there', (
    tester,
  ) async {
    await _pumpScreen(tester);

    await _type(tester, 'tomato');
    await _type(tester, 'Tomatoes');

    expect(_chip('Tomato'), findsOneWidget);
    expect(find.text('That’s already on your list.'), findsOneWidget);
  });
}
