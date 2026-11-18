/// A single ingredient. Shared across features (capture, recipes, matching).
class Ingredient {
  const Ingredient({required this.id, required this.name});

  /// Builds an ingredient from typed or detected text such as
  /// "  cherry tomatoes": tidies the display name and derives [id] with
  /// [keyFor].
  factory Ingredient.named(String name) {
    final tidy = name.trim().replaceAll(RegExp(r'\s+'), ' ');
    return Ingredient(
      id: keyFor(tidy),
      name: tidy.isEmpty ? tidy : tidy[0].toUpperCase() + tidy.substring(1),
    );
  }

  /// Canonical id for comparing names: "Tomatoes", "tomato" and " TOMATO "
  /// share a key, so duplicates combine and recipes match however a name was
  /// typed or detected. Empty when [name] has no letters or digits.
  static String keyFor(String name) {
    final words = name
        .toLowerCase()
        .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ')
        .trim()
        .split(' ');
    words.last = _singular(words.last);
    return words.join(' ');
  }

  /// Folds common English plurals so both forms share a key. Keys only need to
  /// be consistent, not real words: "berry" and "berries" both become
  /// "berri".
  static String _singular(String word) {
    var stem = word;
    if (stem.length > 3) {
      if (stem.endsWith('ies')) {
        stem = '${stem.substring(0, stem.length - 3)}i';
      } else if (RegExp(r'(o|ch|sh|ss|x|z)es$').hasMatch(stem)) {
        stem = stem.substring(0, stem.length - 2);
      } else if (stem.endsWith('s') &&
          !stem.endsWith('ss') &&
          !stem.endsWith('us')) {
        stem = stem.substring(0, stem.length - 1);
      }
    }
    // "cookie" → "cooki" to match "cookies"; "cherry" → "cherri" to match
    // "cherries".
    if (stem.endsWith('ie')) return stem.substring(0, stem.length - 1);
    if (RegExp(r'[^aeiou]y$').hasMatch(stem)) {
      return '${stem.substring(0, stem.length - 1)}i';
    }
    return stem;
  }

  final String id;
  final String name;

  @override
  bool operator ==(Object other) =>
      other is Ingredient && other.id == id && other.name == name;

  @override
  int get hashCode => Object.hash(id, name);

  @override
  String toString() => 'Ingredient($id, $name)';
}
