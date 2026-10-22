import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../config.dart';
import '../main.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/fruit_bowl.dart';
import '../widgets/week_strip.dart';
import 'add.dart';
import 'add_food_button.dart';
import 'group.dart';

const _orange = Color(0xFFF57A1F);
const _green = Color(0xFF7CC242);
const _sand = Color(0xFFB8B39A);

/// Home: what needs attention, this week at a glance, and four cards.
/// A card shows only the label and a count. Tapping it opens every food for that label.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final nothingYet = store.activeAll.isEmpty && store.usedCount == 0;
        final attention = store.needsAttention.length;

        return Scaffold(
          floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
          floatingActionButton: const AddFoodButton(),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 130),
            children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(DateFormat('EEEE, MMMM d').format(DateTime.now()).toUpperCase(),
                        style: body(12, FontWeight.w800, Colors.black54).copyWith(letterSpacing: 1.1)),
                    const SizedBox(height: 4),
                    Text('YOUR FRIDGE,\nSORTED.', style: display(38)),
                  ]),
                ),
                if (!billing.isPremium)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('${store.itemCount}/${AppConfig.freeItemLimit} items',
                        style: body(12, FontWeight.w600, store.atItemLimit ? redDark : Colors.black54)),
                  ),
              ]),
              if (nothingYet)
                const _FirstFood()
              else ...[
                if (attention > 0) ...[
                  const SizedBox(height: 14),
                  _Attention(count: attention),
                ],
                const SizedBox(height: 8),
                WeekStrip(
                  selected: null,
                  onPick: (d) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => DayScreen(date: d))),
                ),
                const SizedBox(height: 10),
                _CardGrid(),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _Attention extends StatelessWidget {
  final int count;
  const _Attention({required this.count});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AttentionScreen())),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: lime, borderRadius: BorderRadius.circular(20)),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('NEEDS YOUR ATTENTION', style: body(11.5, FontWeight.w800).copyWith(letterSpacing: 1.1)),
              const SizedBox(height: 2),
              Text(count == 1 ? '1 item' : '$count items', style: display(30)),
              Text('Check these before they expire.', style: body(13.5)),
            ]),
          ),
          const Icon(Icons.arrow_forward, size: 28),
        ]),
      ),
    );
  }
}

/// Eat me first, Check before toss, Still fresh, Long keepers: two by two.
class _CardGrid extends StatelessWidget {
  const _CardGrid();

  @override
  Widget build(BuildContext context) {
    // Not const on purpose: the counts must refresh when the food list changes.
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) => _grid(),
    );
  }

  Widget _grid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 0.78,
      children: [
        _GroupCard(group: ShelfGroup.eatFirst, dot: _orange),
        _GroupCard(group: ShelfGroup.checkBeforeToss, dot: redDark),
        _GroupCard(group: ShelfGroup.stillFresh, dot: _green),
        _GroupCard(group: ShelfGroup.longKeepers, dot: _sand),
      ],
    );
  }
}

class _GroupCard extends StatelessWidget {
  final ShelfGroup group;
  final Color dot;
  const _GroupCard({required this.group, required this.dot});

  @override
  Widget build(BuildContext context) {
    final items = store.itemsIn(group);
    return Material(
      color: cardWhite,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => GroupScreen(group: group))),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.circle, size: 10, color: dot),
              const SizedBox(width: 6),
              Text(items.length == 1 ? '1 item' : '${items.length} items', style: body(12.5, FontWeight.w700)),
            ]),
            Expanded(child: Center(child: _art(items))),
            Text(group.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: body(16, FontWeight.w800, charcoal).copyWith(height: 1.15)),
            Text(group.sub, maxLines: 2, overflow: TextOverflow.ellipsis, style: body(12, FontWeight.w400, Colors.black54)),
          ]),
        ),
      ),
    );
  }

  /// A picture for the card: the fruit bowl for Eat me first, otherwise the icons of the first foods.
  Widget _art(List<FoodItem> items) {
    if (group == ShelfGroup.eatFirst) return const FruitBowl(width: 120);
    if (items.isEmpty) return const Text('✨', style: TextStyle(fontSize: 34));
    final emojis = items.take(4).map((i) => emojiFor(i.name)).toList();
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 4,
      runSpacing: 2,
      children: [for (final e in emojis) Text(e, style: const TextStyle(fontSize: 28))],
    );
  }
}

/// Friendly empty state, with a tip that depends on the onboarding answer.
class _FirstFood extends StatelessWidget {
  const _FirstFood();

  String get _tip => switch (store.problem) {
        'forget_fridge' => "Add what's in your fridge once. We'll remember it for you.",
        'expires_first' => "We'll nudge you before food runs out of time.",
        'buy_more' => 'Seeing everything in one list helps you buy only what you need.',
        'leftovers' => 'Add leftovers with a date, so they do not get lost at the back.',
        _ => 'Add your first food. It takes seconds.',
      };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 28),
      child: Column(children: [
        Container(
          width: 170,
          height: 170,
          decoration: const BoxDecoration(color: lime, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: const Text('🥬🥛\n🍓🧀', textAlign: TextAlign.center, style: TextStyle(fontSize: 46, height: 1.15)),
        ),
        const SizedBox(height: 22),
        Text('YOUR FRIDGE IS EMPTY', style: display(26), textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text(_tip, textAlign: TextAlign.center, style: body(16)),
        const SizedBox(height: 22),
        FilledButton(
          style: darkButton(),
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AddScreen())),
          child: const Text('Add your first food'),
        ),
      ]),
    );
  }
}
