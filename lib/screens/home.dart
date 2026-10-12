import 'package:flutter/material.dart';
import '../main.dart';
import '../models.dart';
import '../theme.dart';
import 'add.dart';
import 'food_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _searching = false;
  String _query = '';
  DateTime? _day; // filter by tapped day in the week strip

  List<FoodItem> _filter(List<FoodItem> l, {bool useDay = true}) {
    return l.where((i) {
      if (_query.isNotEmpty && !i.name.toLowerCase().contains(_query.toLowerCase())) return false;
      if (useDay && _day != null) {
        final e = i.expiry;
        if (!(e.year == _day!.year && e.month == _day!.month && e.day == _day!.day)) return false;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final fresh = _filter(store.fresh);
        final expired = _filter(store.expired);
        final used = _filter(store.usedItems, useDay: false);
        return DefaultTabController(
          length: 3,
          child: Scaffold(
            floatingActionButton: FloatingActionButton.extended(
              backgroundColor: lime,
              foregroundColor: charcoal,
              elevation: 0,
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AddScreen())),
              icon: const Icon(Icons.add),
              label: Text('Add food', style: body(16, FontWeight.w600)),
            ),
            body: Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
                child: Row(children: [
                  Expanded(child: Text('MY FOOD', style: display(38))),
                  IconButton.filled(
                    style: IconButton.styleFrom(backgroundColor: cardWhite, foregroundColor: charcoal),
                    tooltip: 'Search',
                    icon: Icon(_searching ? Icons.close : Icons.search),
                    onPressed: () => setState(() {
                      _searching = !_searching;
                      if (!_searching) _query = '';
                    }),
                  ),
                ]),
              ),
              if (_searching)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                  child: TextField(
                    autofocus: true,
                    onChanged: (v) => setState(() => _query = v),
                    decoration: const InputDecoration(hintText: 'Search your food', prefixIcon: Icon(Icons.search)),
                  ),
                ),
              _WeekStrip(
                selected: _day,
                onPick: (d) => setState(() => _day = (_day != null && _day == d) ? null : d),
              ),
              TabBar(
                labelColor: charcoal,
                unselectedLabelColor: Colors.black54,
                indicatorColor: charcoal,
                dividerColor: Colors.transparent,
                labelStyle: body(15, FontWeight.w800),
                unselectedLabelStyle: body(15, FontWeight.w600),
                tabs: [
                  Tab(text: 'Foods ${store.fresh.length}'),
                  Tab(text: 'Expired ${store.expired.length}'),
                  Tab(text: 'Used ${store.usedItems.length}'),
                ],
              ),
              Expanded(
                child: TabBarView(children: [
                  _FoodsTab(items: fresh, empty: store.fresh.isEmpty),
                  _ExpiredTab(items: expired),
                  _UsedTab(items: used),
                ]),
              ),
            ]),
          ),
        );
      },
    );
  }
}

/// Monday to Sunday of this week. A dot means something expires that day. A cross means
/// something passed its date on that day and is still not used.
class _WeekStrip extends StatelessWidget {
  final DateTime? selected;
  final ValueChanged<DateTime> onPick;
  const _WeekStrip({required this.selected, required this.onPick});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final monday = today.subtract(Duration(days: today.weekday - 1));
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 8),
      child: Row(children: [
        for (var i = 0; i < 7; i++)
          Expanded(child: _day(monday.add(Duration(days: i)), names[i], today)),
      ]),
    );
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
                            decoration: BoxDecoration(
                                color: isSel ? Colors.white : (d.difference(today).inDays <= 2 ? amber : charcoal),
                                shape: BoxShape.circle),
                          ),
                      ])),
          ),
        ]),
      ),
    );
  }
}

class _FoodsTab extends StatelessWidget {
  final List<FoodItem> items;
  final bool empty;
  const _FoodsTab({required this.items, required this.empty});

  @override
  Widget build(BuildContext context) {
    if (empty) return const _Empty('Nothing here yet', 'Add your first food. It takes seconds.', Icons.kitchen_outlined);
    if (items.isEmpty) return const _Empty('No match', 'Try a different day or word.', Icons.search_off);
    final eatFirst = items.where((i) => i.daysLeft() <= 7).toList();
    final fresh = items.where((i) => i.daysLeft() > 7 && i.daysLeft() <= 30).toList();
    final long = items.where((i) => i.daysLeft() > 30).toList();
    final asap = eatFirst.where((i) => i.daysLeft() <= 2).length;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
      children: [
        if (eatFirst.isNotEmpty)
          _Group(
            title: 'Eat me first',
            sub: 'Lasts up to 7 days',
            items: eatFirst,
            chips: [('ASAP $asap', amber), ('This week ${eatFirst.length - asap}', charcoal)],
            highlight: true,
          ),
        if (fresh.isNotEmpty) _Group(title: 'Still fresh', sub: 'Lasts 1 to 4 weeks', items: fresh),
        if (long.isNotEmpty) _Group(title: 'Long keepers', sub: 'Lasts 1 month or more', items: long),
      ],
    );
  }
}

class _Group extends StatelessWidget {
  final String title;
  final String sub;
  final List<FoodItem> items;
  final List<(String, Color)> chips;
  final bool highlight;
  const _Group({required this.title, required this.sub, required this.items, this.chips = const [], this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 4),
      decoration: BoxDecoration(
        color: highlight ? lime.withValues(alpha: 0.35) : Colors.white.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(title, style: body(19, FontWeight.w800))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: cardWhite, borderRadius: BorderRadius.circular(20)),
            child: Text('${items.length} items', style: body(12, FontWeight.w700)),
          ),
        ]),
        Text(sub, style: body(13, FontWeight.w400, Colors.black54)),
        if (chips.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [
            for (final (label, c) in chips)
              Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.circle, size: 9, color: c),
                const SizedBox(width: 4),
                Text(label, style: body(12, FontWeight.w700)),
              ]),
          ]),
        ],
        const SizedBox(height: 10),
        for (final i in items) FoodCard(item: i),
      ]),
    );
  }
}

class _ExpiredTab extends StatelessWidget {
  final List<FoodItem> items;
  const _ExpiredTab({required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const _Empty('Nothing expired', 'Foods past their date show here.', Icons.verified_outlined);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 110),
      children: [
        Text('Check before toss', style: body(19, FontWeight.w800)),
        const SizedBox(height: 2),
        Text('These passed their date. Check the label and the food before you decide.',
            style: body(13, FontWeight.w400, Colors.black54)),
        const SizedBox(height: 12),
        for (final i in items) FoodCard(item: i),
      ],
    );
  }
}

class _UsedTab extends StatelessWidget {
  final List<FoodItem> items;
  const _UsedTab({required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const _Empty('Nothing used yet', 'Food you mark as used shows here.', Icons.check_circle_outline);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 110),
      children: [
        Text(billing.isPremium ? 'Your full history' : 'Last 7 days. Premium keeps everything.',
            style: body(13, FontWeight.w400, Colors.black54)),
        const SizedBox(height: 12),
        for (final i in items) FoodCard(item: i),
      ],
    );
  }
}

class _Empty extends StatelessWidget {
  final String title;
  final String sub;
  final IconData icon;
  const _Empty(this.title, this.sub, this.icon);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 54),
          const SizedBox(height: 12),
          Text(title, style: body(20, FontWeight.w800)),
          const SizedBox(height: 6),
          Text(sub, textAlign: TextAlign.center, style: body(15)),
        ]),
      ),
    );
  }
}
