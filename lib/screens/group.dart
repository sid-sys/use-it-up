import 'package:flutter/material.dart';
import '../main.dart';
import '../models.dart';
import '../theme.dart';
import 'details.dart';
import 'food_card.dart';

/// Every food in one shelf-life group, with the same quick actions as Home.
class GroupScreen extends StatelessWidget {
  final ShelfGroup group;
  const GroupScreen({super.key, required this.group});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final items = store.fresh.where((i) => shelfGroupOf(i.daysLeft()) == group).toList();
        return Scaffold(
          appBar: AppBar(title: Text(group.title.toUpperCase())),
          body: items.isEmpty
              ? Center(child: Text('Nothing here right now.', style: body(16)))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                  children: [
                    Text(group.sub, style: body(14, FontWeight.w400, Colors.black54)),
                    const SizedBox(height: 14),
                    for (final i in items) FoodCard(item: i),
                  ],
                ),
        );
      },
    );
  }
}

/// A small rounded pill: emoji, name, and a tag such as frozen or canned.
class FoodPill extends StatelessWidget {
  final FoodItem item;
  const FoodPill({super.key, required this.item});

  static const _tags = {'Freezer': 'frozen', 'Canned': 'canned', 'Cut': 'cut', 'Leftover': 'leftover'};

  @override
  Widget build(BuildContext context) {
    final tag = _tags[item.storage];
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => DetailsScreen(item: item))),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        decoration: BoxDecoration(color: const Color(0xFFF4F3EC), borderRadius: BorderRadius.circular(16)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(emojiFor(item.name), style: const TextStyle(fontSize: 15)),
          const SizedBox(width: 6),
          Flexible(child: Text(item.name.toLowerCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: body(13.5, FontWeight.w600))),
          if (tag != null) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(color: const Color(0xFFDDEFF2), borderRadius: BorderRadius.circular(8)),
              child: Text(tag, style: body(10.5, FontWeight.w600, Colors.black54)),
            ),
          ],
        ]),
      ),
    );
  }
}
