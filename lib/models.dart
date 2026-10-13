class FoodItem {
  final String id;
  String name;
  DateTime expiry; // date only
  int quantity;
  String? storage; // Fridge, Freezer, Pantry, Canned, Leftover, Cut
  bool used;
  DateTime? usedAt;
  DateTime addedAt;

  FoodItem({
    required this.id,
    required this.name,
    required this.expiry,
    this.quantity = 1,
    this.storage,
    this.used = false,
    this.usedAt,
    DateTime? addedAt,
  }) : addedAt = addedAt ?? DateTime.now();

  int daysLeft([DateTime? now]) {
    final n = now ?? DateTime.now();
    final today = DateTime(n.year, n.month, n.day);
    return DateTime(expiry.year, expiry.month, expiry.day).difference(today).inDays;
  }

  bool get isExpired => !used && daysLeft() < 0;

  /// Date is within one week, or already passed. Shown in red.
  bool get isUrgent => !used && daysLeft() <= 7;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'expiry': expiry.toIso8601String(),
        'quantity': quantity,
        'storage': storage,
        'used': used,
        'usedAt': usedAt?.toIso8601String(),
        'addedAt': addedAt.toIso8601String(),
      };

  factory FoodItem.fromJson(Map<String, dynamic> j) => FoodItem(
        id: j['id'],
        name: j['name'],
        expiry: DateTime.parse(j['expiry']),
        quantity: j['quantity'] ?? 1,
        storage: j['storage'],
        used: j['used'] ?? false,
        usedAt: j['usedAt'] == null ? null : DateTime.parse(j['usedAt']),
        addedAt: DateTime.parse(j['addedAt']),
      );
}

const storageTags = ['Fridge', 'Freezer', 'Pantry', 'Canned', 'Leftover', 'Cut'];

/// Status shown with icon + words, never color alone.
enum Urgency { expired, today, soon, later }

Urgency urgencyOf(int days) {
  if (days < 0) return Urgency.expired;
  if (days == 0) return Urgency.today;
  if (days <= 7) return Urgency.soon;
  return Urgency.later;
}

String daysLabel(int d) {
  if (d < -1) return 'Passed ${-d} days ago';
  if (d == -1) return 'Passed yesterday';
  if (d == 0) return 'Check today';
  if (d == 1) return 'Tomorrow';
  return 'In $d days';
}

const _emoji = {
  'chickpea': '🫘', 'peanut': '🥜',
  'milk': '🥛', 'yogurt': '🥛', 'yoghurt': '🥛', 'curd': '🥛', 'cheese': '🧀', 'paneer': '🧀',
  'butter': '🧈', 'egg': '🥚', 'bread': '🍞', 'bun': '🍞', 'waffle': '🧇',
  'apple': '🍎', 'banana': '🍌', 'pear': '🍐', 'grape': '🍇', 'orange': '🍊', 'lemon': '🍋',
  'strawberr': '🍓', 'berry': '🫐', 'mango': '🥭', 'tomato': '🍅', 'potato': '🥔', 'onion': '🧅',
  'carrot': '🥕', 'corn': '🌽', 'pepper': '🫑', 'chili': '🌶️', 'cucumber': '🥒', 'lettuce': '🥬',
  'spinach': '🥬', 'broccoli': '🥦', 'garlic': '🧄', 'mushroom': '🍄', 'chicken': '🍗', 'meat': '🥩',
  'beef': '🥩', 'bacon': '🥓', 'fish': '🐟', 'prawn': '🍤', 'rice': '🍚', 'noodle': '🍜',
  'pasta': '🍝', 'soup': '🥣', 'juice': '🧃', 'honey': '🍯', 'jam': '🍯', 'oats': '🌾',
  'cereal': '🥣', 'biscuit': '🍪', 'cookie': '🍪', 'cake': '🍰', 'chocolate': '🍫', 'ice': '🍨',
  'peas': '🫛', 'zucchini': '🥒', 'celery': '🥬', 'turkey': '🦃', 'meatball': '🍖', 'dumpling': '🥟',
  'falafel': '🧆', 'vinegar': '🍶', 'syrup': '🍯', 'rotini': '🍝', 'sausage': '🌭', 'flat bread': '🫓',
  'blueberr': '🫐', 'bean': '🫘', 'dal': '🫘', 'nut': '🥜', 'oil': '🫒', 'sauce': '🥫', 'can': '🥫',
};

String emojiFor(String name) {
  final n = name.toLowerCase();
  for (final e in _emoji.entries) {
    if (n.contains(e.key)) return e.value;
  }
  return '🍽️';
}

/// Shelf-life groups on Home.
/// Eat me first: up to 1 week. Still fresh: 1 to 4 weeks. Long keepers: 1 to 12 months.
enum ShelfGroup { eatFirst, stillFresh, longKeepers }

ShelfGroup shelfGroupOf(int daysLeft) {
  if (daysLeft <= 7) return ShelfGroup.eatFirst;
  if (daysLeft <= 28) return ShelfGroup.stillFresh;
  return ShelfGroup.longKeepers;
}

extension ShelfGroupText on ShelfGroup {
  String get title => switch (this) {
        ShelfGroup.eatFirst => 'Eat me first',
        ShelfGroup.stillFresh => 'Still fresh',
        ShelfGroup.longKeepers => 'Long keepers',
      };

  String get sub => switch (this) {
        ShelfGroup.eatFirst => 'Lasts up to 7 days',
        ShelfGroup.stillFresh => 'Lasts 1–4 weeks',
        ShelfGroup.longKeepers => 'Lasts 1–12 months',
      };
}
