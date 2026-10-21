import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:use_it_up/review.dart';

void main() {
  test('asks once a week until the person has rated', () async {
    SharedPreferences.setMockInitialValues({});
    final start = DateTime(2026, 10, 1, 9);
    expect(await Review.isDue(start), isFalse, reason: 'first time: start counting, do not ask yet');
    expect(await Review.isDue(start.add(const Duration(days: 6, hours: 23))), isFalse);
    expect(await Review.isDue(start.add(const Duration(days: 7))), isTrue);

    // They said "not now": the clock starts again.
    await Review.markAsked(start.add(const Duration(days: 7)));
    expect(await Review.isDue(start.add(const Duration(days: 10))), isFalse);
    expect(await Review.isDue(start.add(const Duration(days: 14))), isTrue);

    // They rated: never ask again.
    await Review.markDone();
    expect(await Review.isDone(), isTrue);
    expect(await Review.isDue(start.add(const Duration(days: 400))), isFalse);
  });
}
