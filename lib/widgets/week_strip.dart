import 'package:flutter/material.dart';
import '../main.dart';
import '../theme.dart';

/// This week, Monday to Sunday.
/// Dots: foods that expire that day (1 to 3 dots, never more). Red dots mean within a week.
/// Cross: a food passed its date on that day and is still not used.
class WeekStrip extends StatelessWidget {
  final DateTime? selected;
  final ValueChanged<DateTime> onPick;
  const WeekStrip({super.key, required this.selected, required this.onPick});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final monday = today.subtract(Duration(days: today.weekday - 1));
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(0, 6, 0, 4),
        child: Row(children: [
          for (var i = 0; i < 7; i++) Expanded(child: _day(monday.add(Duration(days: i)), names[i], today)),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(width: 7, height: 7, decoration: const BoxDecoration(color: redDark, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text('food expiring', style: body(11.5, FontWeight.w500, Colors.black54)),
          const SizedBox(width: 14),
          const Icon(Icons.close, size: 12, color: redDark),
          const SizedBox(width: 4),
          Text('passed its date', style: body(11.5, FontWeight.w500, Colors.black54)),
        ]),
      ),
    ]);
  }

  Widget _day(DateTime d, String name, DateTime today) {
    final count = store.activeAll.where((f) => DateTime(f.expiry.year, f.expiry.month, f.expiry.day) == d).length;
    final isToday = d == today;
    final isSel = selected == d;
    final past = d.isBefore(today);
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: () => onPick(d),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSel ? charcoal : (isToday ? lime : Colors.transparent),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(children: [
          Text(name, style: body(11, FontWeight.w600, isSel ? Colors.white70 : Colors.black54)),
          const SizedBox(height: 4),
          Text('${d.day}', style: body(16, FontWeight.w800, isSel ? Colors.white : charcoal)),
          const SizedBox(height: 4),
          SizedBox(
            height: 12,
            child: count == 0
                ? null
                : (past
                    ? Icon(Icons.close, size: 12, color: isSel ? Colors.white : redDark)
                    : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        for (var k = 0; k < count.clamp(1, 3); k++)
                          Container(
                            width: 6,
                            height: 6,
                            margin: const EdgeInsets.symmetric(horizontal: 1),
                            decoration: BoxDecoration(color: isSel ? Colors.white : redDark, shape: BoxShape.circle),
                          ),
                      ])),
          ),
        ]),
      ),
    );
  }
}
