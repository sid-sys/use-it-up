/// Turns raw OCR text into a product name and expiry-date candidates.
/// Rules: never use a manufacture date, flag day/month ambiguity, let the user pick.
class DateCandidate {
  final DateTime date;
  final String evidence;
  final bool ambiguous; // day and month could be swapped
  final String type; // use_by | best_before | unknown
  DateCandidate(this.date, this.evidence, this.ambiguous, this.type);
}

class ScanResult {
  final String name;
  final List<DateCandidate> dates;
  ScanResult(this.name, this.dates);
}

const _months = {
  'JAN': 1, 'FEB': 2, 'MAR': 3, 'APR': 4, 'MAY': 5, 'JUN': 6,
  'JUL': 7, 'AUG': 8, 'SEP': 9, 'OCT': 10, 'NOV': 11, 'DEC': 12,
};

final _mfg = RegExp(r'\b(MFG|MFD|PKD|PACKED|MANUF\w*|PROD\w*)\b');
final _useBy = RegExp(r'\b(USE\s*BY|EXP\w*)\b');
final _bestBefore = RegExp(r'\b(BEST\s*BEFORE|BBE?|B/B)\b');

int _year(int y) => y < 100 ? 2000 + y : y;

ScanResult parseLabel(List<String> rawLines) {
  final lines = rawLines.map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
  final found = <DateCandidate>[];

  final numeric = RegExp(r'(\d{1,2})\s*[/.\-]\s*(\d{1,2})\s*[/.\-]\s*(\d{2,4})');
  final named = RegExp(
      r'(\d{1,2})?\s*[ \-/]?\s*(JAN|FEB|MAR|APR|MAY|JUN|JUL|AUG|SEP|OCT|NOV|DEC)[A-Z]*\.?\s*[ \-/,]?\s*(\d{2,4})');
  final monthYear = RegExp(r'\b(\d{1,2})\s*[/.\-]\s*(20\d{2})\b');

  for (var idx = 0; idx < lines.length; idx++) {
    final up = lines[idx].toUpperCase();
    // Use the previous line too, for labels like "EXP" on their own line.
    final ctx = idx > 0 ? '${lines[idx - 1].toUpperCase()} $up' : up;
    final isMfg = _mfg.hasMatch(up) && !_useBy.hasMatch(up) && !_bestBefore.hasMatch(up);
    if (isMfg) continue;
    final type = _useBy.hasMatch(ctx)
        ? 'use_by'
        : (_bestBefore.hasMatch(ctx) ? 'best_before' : 'unknown');

    for (final m in numeric.allMatches(up)) {
      final a = int.parse(m.group(1)!), b = int.parse(m.group(2)!), y = _year(int.parse(m.group(3)!));
      if (y < 2000 || y > 2100) continue;
      final dayFirst = a >= 1 && a <= 31 && b >= 1 && b <= 12;
      final monthFirst = b >= 1 && b <= 31 && a >= 1 && a <= 12;
      if (!dayFirst && !monthFirst) continue;
      final ambiguous = dayFirst && monthFirst && a != b;
      final day = dayFirst ? a : b;
      final month = dayFirst ? b : a;
      found.add(DateCandidate(DateTime(y, month, day), m.group(0)!, ambiguous, type));
    }
    for (final m in named.allMatches(up)) {
      final mon = _months[m.group(2)!]!;
      final y = _year(int.parse(m.group(3)!));
      if (y < 2000 || y > 2100) continue;
      final day = m.group(1) == null ? null : int.tryParse(m.group(1)!);
      final date = day != null && day >= 1 && day <= 31
          ? DateTime(y, mon, day)
          : DateTime(y, mon + 1, 0); // month only: last day of month
      found.add(DateCandidate(date, m.group(0)!.trim(), false, type));
    }
    for (final m in monthYear.allMatches(up)) {
      final mon = int.parse(m.group(1)!);
      if (mon < 1 || mon > 12) continue;
      final y = int.parse(m.group(2)!);
      if (found.any((c) => c.evidence.contains(m.group(0)!))) continue;
      found.add(DateCandidate(DateTime(y, mon + 1, 0), m.group(0)!, false, type));
    }
  }

  // Dates marked use-by / best-before first, then the later date first.
  found.sort((a, b) {
    final ra = a.type == 'unknown' ? 1 : 0, rb = b.type == 'unknown' ? 1 : 0;
    if (ra != rb) return ra - rb;
    return b.date.compareTo(a.date);
  });

  return ScanResult(_guessName(lines), found);
}

String _guessName(List<String> lines) {
  final skip = RegExp(
      r'(\d{1,2}[/.\-]\d{1,2}[/.\-]\d{2,4})|\b(EXP|BEST|USE|BY|MFG|MFD|BATCH|LOT|NET|WT|MRP|PRICE|INGREDIENTS|STORE|KEEP|PKD)\b|\d{5,}');
  var best = '';
  for (final l in lines) {
    final up = l.toUpperCase();
    if (skip.hasMatch(up)) continue;
    final letters = RegExp(r'[A-Za-z]').allMatches(l).length;
    if (letters < 3 || letters < l.length * 0.6) continue;
    if (l.length > best.length && l.length <= 40) best = l;
  }
  return best
      .split(' ')
      .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1).toLowerCase())
      .join(' ');
}
