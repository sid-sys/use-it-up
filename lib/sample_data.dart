import 'models.dart';

/// Demo foods for MOCK builds, spread across every group so the layout can be judged.
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
    // Past the date
    f('Cucumber', -2, storage: 'Cut'),
    f('Falafel', -1, storage: 'Leftover'),
    // Eat me first: up to 7 days
    f('Fresh spinach', 0),
    f('Greek yogurt', 1),
    f('Milk', 1, storage: 'Fridge'),
    f('Chicken', 2),
    f('Strawberries', 3),
    f('Eggs', 4, qty: 6),
    f('Bananas', 5),
    f('Bread', 6),
    f('Blueberries', 7),
    // Still fresh: 1 to 4 weeks
    f('Cheddar cheese', 10),
    f('Plain yogurt', 12),
    f('String cheese', 14),
    f('Pear', 9),
    f('Grapes', 11),
    f('Lettuce', 9),
    f('Bell pepper', 13),
    f('Celery', 15),
    f('Zucchini', 12),
    f('Carrot', 21),
    f('Yellow onion', 24),
    f('Bacon', 18),
    f('Beef', 16),
    f('Meatballs', 20),
    f('Turkey sausage', 17),
    f('Frozen pizza', 25, storage: 'Freezer'),
    f('Dumplings', 26, storage: 'Freezer'),
    f('Flat bread', 14),
    f('Waffle', 27, storage: 'Freezer'),
    // Long keepers: 1 to 12 months
    f('Tomatoes', 120, storage: 'Canned'),
    f('Peas', 150, storage: 'Freezer'),
    f('Maple syrup', 300),
    f('Balsamic vinegar', 360),
    f('Oats', 200),
    f('Rice', 270),
    f('Rotini pasta', 330),
    f('Honey', 365),
    f('Peanut butter', 180),
    f('Chickpeas', 240, storage: 'Canned'),
  ];
}
