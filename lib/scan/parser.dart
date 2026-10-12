/// Turns raw OCR text into a product name and expiry-date candidates.
/// Rules: never use a manufacture date, flag day/month ambiguity, let the user pick.
class DateCandidate {
  final DateTime date;
  final String evidence;
  final bool ambiguous; // day and month could be swapped, or the year was guessed
  final String type; // expiry | use_by | best_before | unknown
  final bool fromFocus; // found inside the scan frame
  DateCandidate(this.date, this.evidence, this.ambiguous, this.type, {this.fromFocus = false});

  String get typeName => switch (type) {
        'expiry' => 'Expiry date',
        'use_by' => 'Use by',
        'best_before' => 'Best before',
        _ => 'Date',
      };
}

class ScanResult {
  final String name;
  final List<DateCandidate> dates;
  ScanResult(this.name, this.dates);
}

const _monthNames = 'JAN|FEB|MAR|APR|MAY|JUN|JUL|AUG|SEP|OCT|NOV|DEC';
const _months = {
  'JAN': 1, 'FEB': 2, 'MAR': 3, 'APR': 4, 'MAY': 5, 'JUN': 6,
  'JUL': 7, 'AUG': 8, 'SEP': 9, 'OCT': 10, 'NOV': 11, 'DEC': 12,
};

// Labels printed next to dates. Checked on upper-case text.
final _mfgRe = RegExp(r'(?<![A-Z])(MFG|MFD|MFR|PKD|PKG|PACKED|PACKAGED|MANUF[A-Z]*|PRODUCED|PRODUCTION|DOM)(?![A-Z])');
final _bestRe = RegExp(r'(?<![A-Z])(BEST\s*BEFORE|BEST\s*BY|BEST\s*IF\s*USED\s*BY|BBE|BBD|BB|B/B)(?![A-Z])');
final _useByRe = RegExp(r'(?<![A-Z])(USE\s*BY|USE\s*BEFORE|CONSUME\s*BEFORE|SELL\s*BY)(?![A-Z])');
final _expRe = RegExp(r'(?<![A-Z])(EXPIRY|EXPIRES|EXPIRATION|EXPIRE|EXP|EXF|EXD)(?![A-Z])');

class _Label {
  final int start, end;
  final String type; // mfg | best_before | use_by | expiry
  _Label(this.start, this.end, this.type);
}

class _Hit {
  final int start, end;
  final DateTime date;
  final bool ambiguous;
  _Hit(this.start, this.end, this.date, this.ambiguous);
}

/// OCR often reads 0 as O, 1 as I or L, 5 as S inside numbers. Fix those.
String _fixDigits(String s) => s.replaceAllMapped(RegExp(r'(?<![A-Z0-9])[0-9OILS]{2,4}(?![A-Z0-9])'), (m) {
      final t = m[0]!;
      if (!RegExp(r'\d').hasMatch(t)) return t;
      return t.replaceAll('O', '0').replaceAll('I', '1').replaceAll('L', '1').replaceAll('S', '5');
    });

int _year(int y) => y < 100 ? 2000 + y : y;

DateTime? _valid(int y, int m, int d, DateTime now) {
  if (m < 1 || m > 12 || d < 1 || d > 31) return null;
  final dt = DateTime(y, m, d);
  if (dt.month != m || dt.day != d) return null; // e.g. 31 Feb rolled over
  if (dt.isBefore(DateTime(now.year - 5)) || dt.isAfter(DateTime(now.year + 12))) return null;
  return dt;
}

List<_Label> _labels(String up) {
  final out = <_Label>[];
  for (final m in _mfgRe.allMatches(up)) {
    out.add(_Label(m.start, m.end, 'mfg'));
  }
  for (final m in _useByRe.allMatches(up)) {
    out.add(_Label(m.start, m.end, 'use_by'));
  }
  for (final m in _bestRe.allMatches(up)) {
    out.add(_Label(m.start, m.end, 'best_before'));
  }
  for (final m in _expRe.allMatches(up)) {
    out.add(_Label(m.start, m.end, 'expiry'));
  }
  out.sort((a, b) => a.start.compareTo(b.start));
  return out;
}

List<_Hit> _dates(String up, bool labelCtx, DateTime now) {
  final hits = <_Hit>[];
  bool free(int s, int e) => !hits.any((h) => s < h.end && e > h.start);
  void add(RegExpMatch m, DateTime? d, [bool amb = false]) {
    if (d != null && free(m.start, m.end)) hits.add(_Hit(m.start, m.end, d, amb));
  }

  // 2026-11-12
  for (final m in RegExp(r'(?<!\d)(20\d{2})[-/.](\d{1,2})[-/.](\d{1,2})(?!\d)').allMatches(up)) {
    add(m, _valid(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!), now));
  }
  // 12 NOV 2026, 12-NOV-26, 12NOV26
  for (final m in RegExp('(?<!\\d)(\\d{1,2})\\s?[-/. ]?\\s?($_monthNames)[A-Z]{0,6}\\.?\\s?[-/., ]?\\s?(\\d{4}|\\d{2})(?!\\d)')
      .allMatches(up)) {
    add(m, _valid(_year(int.parse(m[3]!)), _months[m[2]!]!, int.parse(m[1]!), now));
  }
  // NOV 12 2026
  for (final m in RegExp('($_monthNames)[A-Z]{0,6}\\.?\\s?(\\d{1,2})\\s?[,.]?\\s?(\\d{4})(?!\\d)').allMatches(up)) {
    add(m, _valid(int.parse(m[3]!), _months[m[1]!]!, int.parse(m[2]!), now));
  }
  // 12.11.2026 or 12/11/26
  for (final m in RegExp(r'(?<!\d)(\d{1,2})\s?[/.\-]\s?(\d{1,2})\s?[/.\-]\s?(\d{4}|\d{2})(?!\d)').allMatches(up)) {
    final a = int.parse(m[1]!), b = int.parse(m[2]!), y = _year(int.parse(m[3]!));
    final dayFirst = a >= 1 && a <= 31 && b >= 1 && b <= 12;
    final monthFirst = b >= 1 && b <= 31 && a >= 1 && a <= 12;
    if (!dayFirst && !monthFirst) continue;
    final amb = dayFirst && monthFirst && a != b;
    add(m, dayFirst ? _valid(y, b, a, now) : _valid(y, a, b, now), amb);
  }
  // With a label, spaces or colons can separate the parts: EXP 12 11 26
  if (labelCtx) {
    for (final m in RegExp(r'(?<!\d)(\d{1,2})[ :,](\d{1,2})[ :,](\d{4}|\d{2})(?!\d)').allMatches(up)) {
      final a = int.parse(m[1]!), b = int.parse(m[2]!), y = _year(int.parse(m[3]!));
      if (a < 1 || a > 31 || b < 1 || b > 12) continue;
      add(m, _valid(y, b, a, now), a <= 12 && a != b);
    }
  }
  // Month and year: DEC 2026, NOV26, DEC. 26 (label needed for 2-digit year)
  for (final m in RegExp('(?<!\\d)($_monthNames)[A-Z]{0,6}\\.?\\s?[-/., ]?\\s?(\\d{4}|\\d{2})(?!\\d)').allMatches(up)) {
    final ys = m[2]!;
    if (ys.length == 2 && !labelCtx) continue;
    final y = _year(int.parse(ys));
    final mon = _months[m[1]!]!;
    final last = _valid(y, mon, 1, now);
    if (last != null) add(m, DateTime(y, mon + 1, 0));
  }
  // 12/2026, or 03/27 when a label is present
  for (final m in RegExp(r'(?<![\d/.\-])(\d{1,2})\s?[/.\-]\s?(\d{4}|\d{2})(?![\d/.\-])').allMatches(up)) {
    final mon = int.parse(m[1]!), ys = m[2]!;
    if (mon < 1 || mon > 12) continue;
    final y = _year(int.parse(ys));
    if (ys.length == 2 && !(labelCtx && y >= 2024 && y <= 2045)) continue;
    if (_valid(y, mon, 1, now) != null) add(m, DateTime(y, mon + 1, 0));
  }
  // Day and month only: USE BY 14 OCT (year guessed, user must check)
  if (labelCtx) {
    for (final m in RegExp('(?<!\\d)(\\d{1,2})\\s?[-/. ]?\\s?($_monthNames)[A-Z]{0,6}(?![A-Z0-9])').allMatches(up)) {
      final d = int.parse(m[1]!), mon = _months[m[2]!]!;
      var y = now.year;
      var dt = _valid(y, mon, d, now);
      if (dt != null && dt.isBefore(now.subtract(const Duration(days: 30)))) dt = _valid(++y, mon, d, now);
      add(m, dt, true);
    }
  }
  hits.sort((a, b) => a.start.compareTo(b.start));
  return hits;
}

List<DateCandidate> _extract(List<String> rawLines, bool focus, DateTime now) {
  final lines = rawLines.map((l) => _fixDigits(l.toUpperCase().trim())).where((l) => l.isNotEmpty).toList();
  final out = <DateCandidate>[];
  String? carry; // label at the end of the previous line, waiting for a date

  for (final up in lines) {
    final labels = _labels(up);
    final hits = _dates(up, labels.isNotEmpty || carry != null, now);

    for (var i = 0; i < hits.length; i++) {
      final h = hits[i];
      final prevEnd = i == 0 ? 0 : hits[i - 1].end;
      // Nearest label before this date on the same line.
      _Label? before;
      for (final l in labels) {
        if (l.end <= h.start && l.start >= prevEnd) before = l;
      }
      String type;
      var evStart = h.start;
      if (before != null) {
        type = before.type;
        evStart = before.start;
      } else {
        // A label right after the date: "12/11/26 BEST BEFORE"
        final after = labels.where((l) => l.start >= h.end && (i + 1 >= hits.length || l.end <= hits[i + 1].start));
        if (after.isNotEmpty) {
          type = after.first.type;
        } else if (i == 0 && carry != null) {
          type = carry;
        } else {
          type = 'unknown';
        }
      }
      if (type == 'mfg') continue; // never use a manufacture date
      out.add(DateCandidate(h.date, up.substring(evStart, h.end).trim(), h.ambiguous, type, fromFocus: focus));
    }

    // Remember a label that ends the line with no date after it.
    carry = null;
    if (labels.isNotEmpty) {
      final last = labels.last;
      final tail = up.substring(last.end);
      if (!RegExp(r'\d').hasMatch(tail)) carry = last.type;
    }
  }
  return out;
}

/// [all] is every line the reader saw. [focus] is the text found inside the scan frame
/// after cropping and contrast boost. Dates found in the frame rank first.
ScanResult parseLabel(List<String> all, {List<String> focus = const [], DateTime? now}) {
  final n = now ?? DateTime.now();
  final found = <DateCandidate>[
    ..._extract(focus, true, n),
    ..._extract(all, false, n),
  ];

  // One entry per date. Keep the one with the best label, then the one from the frame.
  int labelRank(String t) => t == 'unknown' ? 1 : 0;
  final byDate = <DateTime, DateCandidate>{};
  for (final c in found) {
    final old = byDate[c.date];
    if (old == null ||
        labelRank(c.type) < labelRank(old.type) ||
        (labelRank(c.type) == labelRank(old.type) && c.fromFocus && !old.fromFocus)) {
      byDate[c.date] = c;
    }
  }
  final list = byDate.values.toList()
    ..sort((a, b) {
      final r = labelRank(a.type) - labelRank(b.type);
      if (r != 0) return r;
      if (a.fromFocus != b.fromFocus) return a.fromFocus ? -1 : 1;
      return b.date.compareTo(a.date); // later date first
    });

  return ScanResult(_guessName([...all]), list);
}

String _guessName(List<String> lines) {
  final skip = RegExp(
      r'(\d{1,2}[/.\-]\d{1,2}[/.\-]\d{2,4})|\b(EXP\w*|BEST|BEFORE|USE|BY|MFG|MFD|BATCH|LOT|NET|WT|MRP|PRICE|INGREDIENTS|STORE|KEEP|PKD|BB|BBE|DATE)\b|\d{5,}');
  var best = '';
  for (final l in lines) {
    final t = l.trim();
    if (skip.hasMatch(t.toUpperCase())) continue;
    final letters = RegExp(r'[A-Za-z]').allMatches(t).length;
    if (letters < 3 || letters < t.length * 0.6) continue;
    if (t.length > best.length && t.length <= 40) best = t;
  }
  return best
      .split(' ')
      .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1).toLowerCase())
      .join(' ');
}
