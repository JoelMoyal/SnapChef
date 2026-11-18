import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snapchef/src/core/models/ingredient.dart';
import 'package:snapchef/src/features/accounts/application/auth_providers.dart';
import 'package:snapchef/src/features/accounts/data/auth_repository.dart';
import 'package:snapchef/src/features/ingredients/application/ingredient_providers.dart';
import 'package:snapchef/src/features/ingredients/application/ingredient_scan_controller.dart';
import 'package:snapchef/src/features/ingredients/data/ingredient_repository.dart';
import 'package:snapchef/src/features/ingredients/data/photo_picker.dart';

import 'fakes.dart';

late FakePhotoPicker picker;
late FakeIngredientRepository repo;
late StubAuthRepository auth;
late ProviderContainer container;

IngredientScanController get scanner =>
    container.read(ingredientScanProvider.notifier);
IngredientScanState get scan => container.read(ingredientScanProvider);
List<String> get names => [for (final i in scan.ingredients) i.name];

void main() {
  setUp(() {
    picker = FakePhotoPicker();
    repo = FakeIngredientRepository();
    auth = StubAuthRepository(latency: Duration.zero);
    container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        photoPickerProvider.overrideWithValue(picker),
        ingredientRepositoryProvider.overrideWithValue(repo),
      ],
    );
    // Keep the scan alive between reads, as the screen does.
    container.listen(ingredientScanProvider, (_, _) {});
  });

  tearDown(() => container.dispose());

  group('scan', () {
    test('adds recognized ingredients, combining duplicates', () async {
      repo.answers.add(['tomato', 'Tomatoes', 'egg']);

      await scanner.scan(PhotoSource.camera);

      expect(picker.sources, [PhotoSource.camera]);
      expect(repo.photos, [testPhoto]);
      expect(names, ['Tomato', 'Egg']);
      expect(
        scan.status,
        isA<ScanSucceeded>().having((s) => s.added, 'added', 2),
      );
    });

    test('a second photo adds only new ingredients, newest first', () async {
      repo.answers
        ..add(['tomato', 'egg'])
        ..add(['eggs', 'basil'])
        ..add(['egg']);

      await scanner.scan(PhotoSource.gallery);
      await scanner.scan(PhotoSource.gallery);
      expect(names, ['Basil', 'Tomato', 'Egg']);
      expect(
        scan.status,
        isA<ScanSucceeded>().having((s) => s.added, 'added', 1),
      );

      await scanner.scan(PhotoSource.gallery);
      expect(names, ['Basil', 'Tomato', 'Egg']);
      expect(
        scan.status,
        isA<ScanSucceeded>().having((s) => s.added, 'added', 0),
      );
    });

    test('shows analyzing until recognition answers', () async {
      repo
        ..gate = Completer()
        ..answers.add(['egg']);

      final scanning = scanner.scan(PhotoSource.camera);
      await pumpEventQueue();
      expect(scan.status, isA<ScanAnalyzing>());
      expect(scan.analyzing, isTrue);

      repo.gate!.complete();
      await scanning;
      expect(scan.analyzing, isFalse);
      expect(names, ['Egg']);
    });

    test('a photo with no food reports that and keeps the list', () async {
      scanner.add('milk');
      repo.answers.add(<String>[]);

      await scanner.scan(PhotoSource.camera);

      expect(scan.status, isA<ScanFoundNothing>());
      expect(names, ['Milk']);
    });

    test('a cancelled pick changes nothing', () async {
      picker.next = null;

      await scanner.scan(PhotoSource.camera);

      expect(scan.status, isA<ScanIdle>());
      expect(repo.photos, isEmpty);
    });

    test(
      'denied camera access is reported without calling recognition',
      () async {
        picker.next = const PhotoPickerException(PhotoPickerError.accessDenied);

        await scanner.scan(PhotoSource.camera);

        expect(
          scan.status,
          isA<ScanPickFailed>()
              .having((s) => s.source, 'source', PhotoSource.camera)
              .having((s) => s.error, 'error', PhotoPickerError.accessDenied),
        );
        expect(repo.photos, isEmpty);
      },
    );

    test('retry sends the same photo again after a failure', () async {
      repo.answers
        ..add(IngredientDetectionError.offline)
        ..add(['egg']);

      await scanner.scan(PhotoSource.camera);
      expect(
        scan.status,
        isA<ScanFailed>().having(
          (s) => s.error,
          'error',
          IngredientDetectionError.offline,
        ),
      );
      expect(scan.ingredients, isEmpty);

      await scanner.retry();
      expect(repo.photos, [testPhoto, testPhoto]);
      expect(names, ['Egg']);
    });

    test('retry does nothing when retrying cannot help', () async {
      repo.answers.add(IngredientDetectionError.signedOut);

      await scanner.scan(PhotoSource.camera);
      await scanner.retry();

      expect(repo.photos, hasLength(1));
      expect(scan.status, isA<ScanFailed>());
    });

    test('an unexpected error still ends the scan', () async {
      container.dispose();
      container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          photoPickerProvider.overrideWithValue(picker),
          ingredientRepositoryProvider.overrideWithValue(_BrokenRepository()),
        ],
      );
      container.listen(ingredientScanProvider, (_, _) {});

      await expectLater(scanner.scan(PhotoSource.camera), throwsStateError);
      expect(
        scan.status,
        isA<ScanFailed>().having(
          (s) => s.error,
          'error',
          IngredientDetectionError.failed,
        ),
      );
    });
  });

  group('editing', () {
    test('add splits on commas and skips blanks and duplicates', () {
      expect(scanner.add('eggs, Milk ,, egg'), 2);
      expect(names, ['Eggs', 'Milk']);

      expect(scanner.add('milk'), 0);
      expect(scanner.add('   '), 0);
      expect(names, ['Eggs', 'Milk']);
    });

    test('rename changes an ingredient in place', () {
      scanner.add('tomato, egg, onion');

      scanner.rename(Ingredient.keyFor('egg'), 'duck egg');
      expect(names, ['Tomato', 'Duck egg', 'Onion']);

      scanner.rename(Ingredient.keyFor('onion'), 'ONION');
      expect(names, ['Tomato', 'Duck egg', 'ONION']);

      scanner.rename(Ingredient.keyFor('tomato'), '  ');
      expect(names, ['Tomato', 'Duck egg', 'ONION']);
    });

    test('renaming to an ingredient already listed combines them', () {
      scanner.add('tomato, red onion, onion');

      scanner.rename(Ingredient.keyFor('red onion'), 'onions');

      expect(names, ['Tomato', 'Onion']);
    });

    test('remove can be undone in the same position', () {
      scanner.add('tomato, egg, onion');
      final egg = scan.ingredients[1];

      final index = scanner.remove(egg.id);
      expect(names, ['Tomato', 'Onion']);

      scanner.restore(index, egg);
      expect(names, ['Tomato', 'Egg', 'Onion']);

      scanner.restore(index, egg);
      expect(names, ['Tomato', 'Egg', 'Onion']);
    });
  });

  test('confirm hands the list to recommendations', () {
    scanner.add('tomato, egg');

    scanner.confirm();

    expect(container.read(confirmedIngredientsProvider), scan.ingredients);
  });

  test('logging out clears the list and drops a scan in progress', () async {
    await auth.signUp(
      firstName: 'Ana',
      lastName: 'Lopez',
      email: 'ana@example.com',
      password: 'password123',
    );
    await pumpEventQueue();
    scanner
      ..add('tomato')
      ..confirm();
    repo
      ..gate = Completer()
      ..answers.add(['egg']);
    final scanning = scanner.scan(PhotoSource.camera);
    await pumpEventQueue();

    await auth.logOut();
    await pumpEventQueue();
    repo.gate!.complete();
    await scanning;

    expect(scan.ingredients, isEmpty);
    expect(scan.status, isA<ScanIdle>());
    expect(container.read(confirmedIngredientsProvider), isEmpty);
  });
}

class _BrokenRepository implements IngredientRepository {
  @override
  Future<List<Ingredient>> detectFromPhoto(Photo photo) async =>
      throw StateError('bug');
}
