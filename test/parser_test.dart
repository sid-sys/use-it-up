import 'package:flutter_test/flutter_test.dart';
import 'package:use_it_up/scan/parser.dart';

final now = DateTime(2026, 10, 12);
ScanResult p(List<String> l, {List<String> focus = const []}) => parseLabel(l, focus: focus, now: now);

void main() {
  group('best before / expiry reading', () {
    test('MFG and EXP on the same line: only EXP is used', () {
      final r = p(['Fresh Whole Milk', 'MFG 01/10/26 EXP 12/11/26', 'Batch 99812']);
      expect(r.name, 'Fresh Whole Milk');
      expect(r.dates.first.date, DateTime(2026, 11, 12));
      expect(r.dates.first.type, 'expiry');
      expect(r.dates.first.ambiguous, isTrue);
      expect(r.dates.any((d) => d.date == DateTime(2026, 10, 1)), isFalse);
    });

    test('label on one line, date on the next', () {
      final r = p(['BEST BEFORE', '12 NOV 2026']);
      expect(r.dates.first.date, DateTime(2026, 11, 12));
      expect(r.dates.first.type, 'best_before');
    });

    test('month and year only: end of that month', () {
      expect(p(['BEST BEFORE END: DEC 2026']).dates.first.date, DateTime(2026, 12, 31));
      expect(p(['BB 03/27']).dates.first.date, DateTime(2027, 3, 31));
      expect(p(['EXP 11/2026']).dates.first.date, DateTime(2026, 11, 30));
    });

    test('OCR mixes letters and digits', () {
      final r = p(['EXP 1O/1l/2O26']);
      expect(r.dates.first.date, DateTime(2026, 11, 10)); // 1O/1l/2O26 is 10/11/2026
    });

    test('many styles', () {
      expect(p(['USE BY 14-NOV-26']).dates.first.date, DateTime(2026, 11, 14));
      expect(p(['EXP: 2026-11-12']).dates.first.date, DateTime(2026, 11, 12));
      expect(p(['BBE 12.11.2026']).dates.first.date, DateTime(2026, 11, 12));
      expect(p(['Best before NOV 12 2026']).dates.first.date, DateTime(2026, 11, 12));
      expect(p(['EXP 25 12 26']).dates.first.date, DateTime(2026, 12, 25));
      expect(p(['EXP 12NOV26']).dates.first.date, DateTime(2026, 11, 12));
    });

    test('day and month only guesses the year and says so', () {
      final r = p(['USE BY 14 NOV']);
      expect(r.dates.first.date, DateTime(2026, 11, 14));
      expect(r.dates.first.ambiguous, isTrue);
    });

    test('dates in the scan frame rank first', () {
      final r = p(['MRP 40.00', 'EXP 01/12/26'], focus: ['BB 05/11/26']);
      expect(r.dates.first.date, DateTime(2026, 11, 5));
    });

    test('no guessing', () {
      expect(p(['Tasty Bread', 'Keep cool']).dates, isEmpty);
      expect(p(['12:45:10']).dates, isEmpty, reason: 'a time of day is not a date');
      expect(p(['MFG 01/10/26']).dates, isEmpty, reason: 'manufacture date is never used');
      expect(p(['EXP 31/02/26']).dates, isEmpty, reason: 'impossible date');
    });
  });
}
