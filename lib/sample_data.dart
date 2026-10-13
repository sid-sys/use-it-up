import 'models.dart';

/// Demo foods for MOCK builds: exactly 20, the free plan limit, spread across every card.
/// Ids start with "sample_" so they can be removed again without touching real food.
List<FoodItem> sampleFoods([DateTime? now]) {
  final n = now ?? DateTime.now();
  final today = DateTime(n.year, n.month, n.day);
  var i = 0;
  FoodItem f(String name, int days, {String? storage, int qty = 1}) => FoodItem(
        id: 'sample_${i++}',
        name: name,
        expiry: today.add(Duration(days: days)),
        quantity: qty,
        storage: storage,
      );

  return [
    // Check before toss: the date already passed
    f('Cucumber', -2, storage: 'Cut'),
    f('Falafel', -1, storage: 'Leftover'),
    // Eat me first: up to 7 days
    f('Fresh spinach', 0),
    f('Greek yogurt', 1),
    f('Milk', 1, storage: 'Fridge'),
    f('Chicken', 2),
    f('Strawberries', 3),
    f('Eggs', 4, qty: 6),
    f('Bread', 6),
    // Still fresh: 1 to 4 weeks
    f('Cheddar cheese', 10),
    f('Pear', 9),
    f('Grapes', 11),
    f('Carrot', 21),
    f('Dumplings', 26, storage: 'Freezer'),
    // Long keepers: 1 to 12 months
    f('Tomatoes', 120, storage: 'Canned'),
    f('Peas', 150, storage: 'Freezer'),
    f('Peanut butter', 180),
    f('Oats', 200),
    f('Rice', 270),
    f('Honey', 365),
  ];
}
