import 'package:flutter_test/flutter_test.dart';
import 'package:snapchef/src/core/models/ingredient.dart';

void main() {
  group('Ingredient.keyFor', () {
    test('ignores case, spacing and punctuation', () {
      expect(Ingredient.keyFor(' TOMATO '), 'tomato');
      expect(Ingredient.keyFor('Bell  Peppers!'), 'bell pepper');
      expect(Ingredient.keyFor('crème fraîche'), 'crème fraîche');
    });

    test('singular and plural share a key', () {
      const pairs = {
        'egg': 'eggs',
        'tomato': 'tomatoes',
        'mango': 'mangos',
        'peach': 'peaches',
        'radish': 'radishes',
        'berry': 'berries',
        'cherry tomato': 'cherry tomatoes',
        'cookie': 'cookies',
        'pie': 'pies',
        'olive': 'olives',
        'cheese': 'cheeses',
        'kiwi': 'kiwis',
        'pea': 'peas',
        'turkey': 'turkeys',
        'glass': 'glasses',
      };
      pairs.forEach((singular, plural) {
        expect(
          Ingredient.keyFor(plural),
          Ingredient.keyFor(singular),
          reason: '$singular / $plural',
        );
      });
    });

    test('leaves words that only look plural alone', () {
      for (final name in ['asparagus', 'hummus', 'couscous', 'swiss', 'jus']) {
        expect(Ingredient.keyFor(name), name);
      }
    });

    test('different ingredients keep different keys', () {
      expect(Ingredient.keyFor('pea'), isNot(Ingredient.keyFor('peach')));
      expect(Ingredient.keyFor('lime'), isNot(Ingredient.keyFor('lemon')));
    });

    test('is empty without letters or digits', () {
      expect(Ingredient.keyFor(''), '');
      expect(Ingredient.keyFor(' !? '), '');
    });
  });

  test('Ingredient.named tidies the display name', () {
    final ingredient = Ingredient.named('  cherry   tomatoes ');

    expect(ingredient.name, 'Cherry tomatoes');
    expect(ingredient.id, Ingredient.keyFor('cherry tomato'));
  });
}
