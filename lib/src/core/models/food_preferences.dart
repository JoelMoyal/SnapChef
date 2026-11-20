/// A user's food preferences. Shared so recipe matching and ranking can filter
/// on allergens, cuisines, and meal types.
class FoodPreferences {
  const FoodPreferences({
    this.dietary = const {},
    this.mealTypes = const {},
    this.cuisines = const {},
    this.allergens = const {},
    this.otherAllergens = '',
  });

  static const dietaryOptions = [
    'Vegetarian',
    'Vegan',
    'Gluten-free',
    'Dairy-free',
  ];
  static const mealTypeOptions = [
    'Breakfast',
    'Lunch',
    'Dinner',
    'Snack',
    'Dessert',
  ];
  static const cuisineOptions = [
    'Indian',
    'Italian',
    'Mexican',
    'Chinese',
    'Thai',
    'Japanese',
    'Korean',
    'Mediterranean',
    'Middle Eastern',
    'American',
  ];
  static const allergenOptions = [
    'Milk',
    'Eggs',
    'Peanuts',
    'Tree nuts',
    'Wheat',
    'Soy',
    'Fish',
    'Shellfish',
    'Sesame',
  ];

  final Set<String> dietary;
  final Set<String> mealTypes;
  final Set<String> cuisines;
  final Set<String> allergens;

  /// Free text for anything not in [allergenOptions], e.g. "mustard".
  final String otherAllergens;
}
