import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../config.dart';
import '../main.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/fruit_bowl.dart';
import 'add.dart';
import 'add_food_button.dart';
import 'group.dart';

const _orange = Color(0xFFF57A1F);
const _yellow = Color(0xFFF2B600);
const _green = Color(0xFF7CC242);
const _sand = Color(0xFFB8B39A);

/// Home: what needs attention, then foods grouped by how long they last.
/// Each group is a card of small pills (icon + name). The full lists live in Foods.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final fresh = store.fresh;
        List<FoodItem> of(ShelfGroup g) => fresh.where((i) => shelfGroupOf(i.daysLeft()) == g).toList();
        final eatFirst = of(ShelfGroup.eatFirst);
        final stillFresh = of(ShelfGroup.stillFresh);
        final longKeepers = of(ShelfGroup.longKeepers);
        final expired = store.expired;
        final nothingYet = store.activeAll.isEmpty && store.usedCount == 0;
        final attention = fresh.where((i) => i.daysLeft() <= 3).length + expired.length;

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
                    child: Text('${fresh.length}/${AppConfig.freeItemLimit} items',
                        style: body(12, FontWeight.w600, Colors.black54)),
                  ),
              ]),
              if (nothingYet)
                const _FirstFood()
              else ...[
                if (attention > 0) ...[
                  const SizedBox(height: 14),
                  _Attention(count: attention),
                ],
                if (eatFirst.isNotEmpty) _EatFirstCard(items: eatFirst),
                if (expired.isNotEmpty) _ToastCard(items: expired),
                if (stillFresh.isNotEmpty)
                  _ChipGroup(group: ShelfGroup.stillFresh, items: stillFresh, dot: _green),
                if (longKeepers.isNotEmpty)
                  _ChipGroup(group: ShelfGroup.longKeepers, items: longKeepers, dot: _sand, fullButton: true),
              ],
              if (AppConfig.mock) const _SampleData(),
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
      onTap: () => openFoods.value = FoodsRequest(0),
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
          const Icon(Icons.notifications_active_outlined, size: 30),
        ]),
      ),
    );
  }
}

/// Max pills shown on a card. The rest are one tap away.
const _maxPills = 12;

Widget _pills(BuildContext context, List<FoodItem> items, VoidCallback onMore) {
  final shown = items.take(_maxPills).toList();
  return Wrap(spacing: 8, runSpacing: 8, children: [
    for (final i in shown) FoodPill(item: i),
    if (items.length > _maxPills)
      GestureDetector(
        onTap: onMore,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: const Color(0xFFF4F3EC), borderRadius: BorderRadius.circular(16)),
          child: Text('+${items.length - _maxPills} more', style: body(13, FontWeight.w700)),
        ),
      ),
  ]);
}

void _openGroup(BuildContext context, ShelfGroup g) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => GroupScreen(group: g)));

/// "Eat me first": up to 7 days. Pills, the fruit bowl, and ASAP / This week counts.
class _EatFirstCard extends StatelessWidget {
  final List<FoodItem> items;
  const _EatFirstCard({required this.items});

  @override
  Widget build(BuildContext context) {
    final asap = items.where((i) => i.daysLeft() <= 2).length;
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.fromLTRB(18, 16, 14, 14),
      decoration: BoxDecoration(color: cardWhite, borderRadius: BorderRadius.circular(26)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(ShelfGroup.eatFirst.title, style: body(22, FontWeight.w800))),
          _CountPill(count: items.length, dot: _orange),
        ]),
        Text(ShelfGroup.eatFirst.sub, style: body(13, FontWeight.w400, Colors.black54)),
        const SizedBox(height: 12),
        _pills(context, items, () => _openGroup(context, ShelfGroup.eatFirst)),
        const SizedBox(height: 6),
        const Center(child: FruitBowl(width: 200)),
        Row(children: [
          _DotLabel('ASAP $asap', _orange),
          const SizedBox(width: 10),
          _DotLabel('This week ${items.length - asap}', _yellow),
          const Spacer(),
          GestureDetector(onTap: () => _openGroup(context, ShelfGroup.eatFirst), child: const _ArrowButton()),
        ]),
      ]),
    );
  }
}

/// "Check before toss": past the date. Opens the Expired tab in Foods.
class _ToastCard extends StatelessWidget {
  final List<FoodItem> items;
  const _ToastCard({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: cardWhite, borderRadius: BorderRadius.circular(26)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('Check before toss', style: body(20, FontWeight.w800))),
          _CountPill(count: items.length, dot: redDark),
        ]),
        Text('Past best-by', style: body(13, FontWeight.w400, Colors.black54)),
        const SizedBox(height: 14),
        _pills(context, items, () => openFoods.value = FoodsRequest(1)),
        const SizedBox(height: 14),
        Align(
          alignment: Alignment.centerRight,
          child: GestureDetector(onTap: () => openFoods.value = FoodsRequest(1), child: const _ArrowButton()),
        ),
      ]),
    );
  }
}

/// "Still fresh" (1 to 4 weeks) and "Long keepers" (1 to 12 months).
class _ChipGroup extends StatelessWidget {
  final ShelfGroup group;
  final List<FoodItem> items;
  final Color dot;
  final bool fullButton;
  const _ChipGroup({required this.group, required this.items, required this.dot, this.fullButton = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: cardWhite, borderRadius: BorderRadius.circular(26)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(group.title, style: body(20, FontWeight.w800))),
          _CountPill(count: items.length, dot: dot),
        ]),
        Text(group.sub, style: body(13, FontWeight.w400, Colors.black54)),
        const SizedBox(height: 14),
        _pills(context, items, () => _openGroup(context, group)),
        const SizedBox(height: 14),
        if (fullButton)
          FilledButton(
            style: darkButton().merge(FilledButton.styleFrom(minimumSize: const Size.fromHeight(50))),
            onPressed: () => _openGroup(context, group),
            child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text('Full inventory'),
              SizedBox(width: 8),
              Icon(Icons.arrow_forward, size: 18),
            ]),
          )
        else
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(onTap: () => _openGroup(context, group), child: const _ArrowButton()),
          ),
      ]),
    );
  }
}

class _CountPill extends StatelessWidget {
  final int count;
  final Color dot;
  const _CountPill({required this.count, required this.dot});

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.circle, size: 10, color: dot),
        const SizedBox(width: 6),
        Text(count == 1 ? '1 item' : '$count items', style: body(12.5, FontWeight.w700)),
      ]);
}

class _DotLabel extends StatelessWidget {
  final String text;
  final Color color;
  const _DotLabel(this.text, this.color);

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.circle, size: 9, color: color),
        const SizedBox(width: 5),
        Text(text, style: body(12.5, FontWeight.w700)),
      ]);
}

class _ArrowButton extends StatelessWidget {
  const _ArrowButton();

  @override
  Widget build(BuildContext context) => Container(
        width: 48,
        height: 48,
        decoration: const BoxDecoration(color: charcoal, shape: BoxShape.circle),
        child: const Icon(Icons.arrow_forward, color: Colors.white),
      );
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

/// Demo helper, shown only in MOCK builds: fills the app with sample foods so the
/// layout can be judged. Never shown in a real build.
class _SampleData extends StatelessWidget {
  const _SampleData();

  @override
  Widget build(BuildContext context) {
    final has = store.hasSamples;
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Center(
        child: OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: charcoal,
            side: const BorderSide(color: Colors.black26),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: () => has ? store.removeSamples() : store.loadSamples(),
          icon: Icon(has ? Icons.delete_sweep_outlined : Icons.science_outlined, size: 18),
          label: Text(has ? 'Remove sample foods (demo)' : 'Load sample foods (demo)'),
        ),
      ),
    );
  }
}
