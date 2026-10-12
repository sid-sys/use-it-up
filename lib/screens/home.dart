import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../config.dart';
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
        final nothingYet = store.activeAll.isEmpty && store.usedCount == 0;
        final attention = store.fresh.where((i) => i.daysLeft() <= 3).length + store.expired.length;

        final header = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(DateFormat('EEEE, MMMM d').format(DateTime.now()).toUpperCase(),
                      style: body(12, FontWeight.w800, Colors.black54).copyWith(letterSpacing: 1.1)),
                  const SizedBox(height: 4),
                  Text('YOUR FRIDGE,\nSORTED.', style: display(38)),
                ]),
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                IconButton.filled(
                  style: IconButton.styleFrom(backgroundColor: cardWhite, foregroundColor: charcoal),
                  tooltip: 'Search',
                  icon: Icon(_searching ? Icons.close : Icons.search),
                  onPressed: () => setState(() {
                    _searching = !_searching;
                    if (!_searching) _query = '';
                  }),
                ),
                if (!billing.isPremium)
                  Padding(
                    padding: const EdgeInsets.only(right: 8, top: 4),
                    child: Text('${store.fresh.length}/${AppConfig.freeItemLimit} items',
                        style: body(12, FontWeight.w600, Colors.black54)),
                  ),
              ]),
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
          if (attention > 0)
            Container(
              margin: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: lime, borderRadius: BorderRadius.circular(20)),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('NEEDS YOUR ATTENTION', style: body(11.5, FontWeight.w800).copyWith(letterSpacing: 1.1)),
                    const SizedBox(height: 2),
                    Text(attention == 1 ? '1 item' : '$attention items', style: display(30)),
                    Text('Check these before they expire.', style: body(13.5)),
                  ]),
                ),
                const Icon(Icons.notifications_active_outlined, size: 30),
              ]),
            ),
          _WeekStrip(
            selected: _day,
            onPick: (d) => setState(() => _day = (_day != null && _day == d) ? null : d),
          ),
        ]);

        final addButton = Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Material(
            color: lime,
            elevation: 3,
            shadowColor: Colors.black26,
            borderRadius: BorderRadius.circular(22),
            child: InkWell(
              borderRadius: BorderRadius.circular(22),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AddScreen())),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                child: Row(children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: const BoxDecoration(color: charcoal, shape: BoxShape.circle),
                    child: const Icon(Icons.add, color: lime, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                      Text('Add food', style: body(17, FontWeight.w800)),
                      Text('Scan a label or enter a date', style: body(12.5)),
                    ]),
                  ),
                  const Icon(Icons.photo_camera_outlined),
                ]),
              ),
            ),
          ),
        );

        return Scaffold(
          floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
          floatingActionButton: addButton,
          body: nothingYet
              ? ListView(padding: const EdgeInsets.only(bottom: 120), children: [header, const _FirstFood()])
              : DefaultTabController(
                  length: 3,
                  child: NestedScrollView(
                    headerSliverBuilder: (context, _) => [
                      SliverToBoxAdapter(child: header),
                      SliverPersistentHeader(
                        pinned: true,
                        delegate: _TabsDelegate(TabBar(
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
                        )),
                      ),
                    ],
                    body: TabBarView(children: [
                      _FoodsTab(items: fresh, empty: store.fresh.isEmpty),
                      _ExpiredTab(items: expired),
                      _UsedTab(items: used),
                    ]),
                  ),
                ),
        );
      },
    );
  }
}

class _TabsDelegate extends SliverPersistentHeaderDelegate {
  final TabBar bar;
  _TabsDelegate(this.bar);

  @override
  double get minExtent => bar.preferredSize.height;
  @override
  double get maxExtent => bar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => ColoredBox(color: ivory, child: bar);

  @override
  bool shouldRebuild(_TabsDelegate old) => true;
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
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
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
            child: Text(items.length == 1 ? '1 item' : '${items.length} items', style: body(12, FontWeight.w700)),
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
