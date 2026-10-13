import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../main.dart';
import '../models.dart';
import '../theme.dart';
import 'food_card.dart';

/// A full list of foods behind a Home card. Stays in sync with the store.
class FoodListScreen extends StatelessWidget {
  final String title;
  final String sub;
  final String emptyText;
  final List<FoodItem> Function() items;
  const FoodListScreen({super.key, required this.title, required this.sub, required this.emptyText, required this.items});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final list = items();
        return Scaffold(
          appBar: AppBar(title: Text(title.toUpperCase())),
          body: list.isEmpty
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(emptyText, textAlign: TextAlign.center, style: body(16))))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                  children: [
                    Text(sub, style: body(14, FontWeight.w400, Colors.black54)),
                    const SizedBox(height: 14),
                    for (final i in list) FoodCard(item: i),
                  ],
                ),
        );
      },
    );
  }
}

/// Foods behind one of the four Home cards.
class GroupScreen extends StatelessWidget {
  final ShelfGroup group;
  const GroupScreen({super.key, required this.group});

  @override
  Widget build(BuildContext context) {
    return FoodListScreen(
      title: group.title,
      sub: group.sub,
      emptyText: 'Nothing here right now.',
      items: () => store.itemsIn(group),
    );
  }
}

/// The foods behind the Home "Needs your attention" card: past the date or due in 3 days.
class AttentionScreen extends StatelessWidget {
  const AttentionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return FoodListScreen(
      title: 'Needs your attention',
      sub: 'Check these before they expire.',
      emptyText: 'All clear. Nothing needs attention.',
      items: () => store.needsAttention,
    );
  }
}

/// Foods that expire on one day, opened from the week strip on Home.
class DayScreen extends StatelessWidget {
  final DateTime date;
  const DayScreen({super.key, required this.date});

  @override
  Widget build(BuildContext context) {
    final day = DateTime(date.year, date.month, date.day);
    return FoodListScreen(
      title: DateFormat('EEE d MMM').format(day),
      sub: 'Foods with this date.',
      emptyText: 'No food has this date.',
      items: () => store.activeAll
          .where((i) => DateTime(i.expiry.year, i.expiry.month, i.expiry.day) == day)
          .toList()
        ..sort((a, b) => a.name.compareTo(b.name)),
    );
  }
}
