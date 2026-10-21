import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme.dart';
import 'models.dart';
import 'users_screen.dart';
import 'widgets.dart';

const _installGreen = Color(0xFF2E9E4F);
const _uninstallRed = Color(0xFFD93025);

/// ONE chart card with a switch at the top: "Active users" | "Installs and uninstalls".
/// Last 30 days, one group of bars per day. Slide sideways to see older days.
/// Tap a bar and the list of the real people behind it opens right away.
class ActivityCard extends StatefulWidget {
  final AdminStats stats;
  final List<AdminDevice> devices;
  const ActivityCard({super.key, required this.stats, required this.devices});

  @override
  State<ActivityCard> createState() => _ActivityCardState();
}

class _ActivityCardState extends State<ActivityCard> {
  final _scroll = ScrollController();
  int _view = 0; // 0 active users, 1 installs and uninstalls

  @override
  void initState() {
    super.initState();
    _toNewest();
  }

  void _toNewest() {
    // Start on the newest days.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  static const _barsH = 120.0;

  void _open(String title, List<AdminUser> users, String empty, String Function(AdminUser, AdminDevice?) time) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => UsersScreen(title: title, users: users, devices: widget.devices, emptyText: empty, timeLabel: time),
    ));
  }

  String _date(DateTime d) => DateFormat('EEE d MMM').format(d);

  @override
  Widget build(BuildContext context) {
    final s = widget.stats;
    return SectionCard(
      title: 'Last 30 days',
      sub: 'Tap a bar to see the people.',
      trailing: null,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<int>(
            showSelectedIcon: false,
            style: SegmentedButton.styleFrom(
              selectedBackgroundColor: lime,
              selectedForegroundColor: charcoal,
              foregroundColor: charcoal,
              textStyle: body(13, FontWeight.w700),
            ),
            segments: const [
              ButtonSegment(value: 0, label: Text('Active users')),
              ButtonSegment(value: 1, label: Text('Installs and uninstalls')),
            ],
            selected: {_view},
            onSelectionChanged: (v) {
              setState(() => _view = v.first);
              _toNewest();
            },
          ),
        ),
        const SizedBox(height: 12),
        if (_view == 0) _active(s) else _installs(s),
        const SizedBox(height: 4),
        const _HowCounted(),
      ]),
    );
  }

  // ---------------------------------------------------------------- Active users
  Widget _active(AdminStats s) {
    final maxV = s.active30.fold<int>(1, (a, d) => d.users.length > a ? d.users.length : a);
    if (s.active30.every((d) => d.users.isEmpty)) {
      return Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text('Nobody was active yet', style: body(14, FontWeight.w600, muted)));
    }
    return SizedBox(
      height: _barsH + 70,
      child: ListView.builder(
        key: const ValueKey('active-chart'),
        controller: _scroll,
        scrollDirection: Axis.horizontal,
        itemCount: s.active30.length,
        itemBuilder: (context, i) {
          final d = s.active30[i];
          final isToday = i == s.active30.length - 1;
          return SizedBox(
            width: 46,
            child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
              _Bar(
                key: ValueKey('bar-active-$i'),
                count: d.users.length,
                height: d.users.isEmpty ? 3.0 : (d.users.length / maxV * _barsH).clamp(3.0, _barsH),
                color: isToday ? charcoal : barLime,
                onTap: () => _open('Active on ${_date(d.day)}', d.users, 'Nobody was active that day', (u, _) {
                  final t = u.events.where((e) => DateUtils.isSameDay(e.time, d.day)).map((e) => e.time).fold<DateTime?>(null, (a, b) => a == null || b.isAfter(a) ? b : a);
                  return t == null ? '' : 'Last active ${DateFormat('h:mm a').format(t)}';
                }),
              ),
              const SizedBox(height: 6),
              Text(isToday ? 'Today' : DateFormat('d MMM').format(d.day), style: body(10.5, isToday ? FontWeight.w800 : FontWeight.w500, muted)),
            ]),
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------- Installs and uninstalls
  Widget _installs(AdminStats s) {
    final days = s.installs30;
    if (days.every((d) => d.installed.isEmpty && d.uninstalled.isEmpty)) {
      return Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text('No installs yet', style: body(14, FontWeight.w600, muted)));
    }
    final maxV = days.fold<int>(1, (a, d) {
      final m = d.installed.length > d.uninstalled.length ? d.installed.length : d.uninstalled.length;
      return m > a ? m : a;
    });
    final installs = days.fold<int>(0, (a, d) => a + d.installed.length);
    final uninstalls = days.fold<int>(0, (a, d) => a + d.uninstalled.length);
    final net = installs - uninstalls;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(spacing: 14, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
        _Key(color: _installGreen, label: 'Installed $installs'),
        _Key(color: _uninstallRed, label: 'Uninstalled $uninstalls'),
        Text(net > 0 ? 'Net gain +$net' : (net < 0 ? 'Net loss $net' : 'No change'), style: body(13, FontWeight.w800, net > 0 ? gain : (net < 0 ? loss : muted))),
      ]),
      const SizedBox(height: 10),
      SizedBox(
        height: _barsH + 100,
        child: ListView.builder(
          key: const ValueKey('installs-chart'),
          controller: _scroll,
          scrollDirection: Axis.horizontal,
          itemCount: days.length,
          itemBuilder: (context, i) {
            final d = days[i];
            final isToday = i == days.length - 1;
            return SizedBox(
              width: 76,
              child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                Row(crossAxisAlignment: CrossAxisAlignment.end, mainAxisAlignment: MainAxisAlignment.center, children: [
                  _Bar(
                    key: ValueKey('bar-installed-$i'),
                    count: d.installed.length,
                    height: d.installed.isEmpty ? 3.0 : (d.installed.length / maxV * _barsH).clamp(3.0, _barsH),
                    color: _installGreen,
                    onTap: () => _open('Installed on ${_date(d.day)}', d.installed, 'Nobody installed that day',
                        (u, dev) => dev == null ? '' : 'Installed ${DateFormat('h:mm a').format(dev.installedAt)}'),
                  ),
                  const SizedBox(width: 6),
                  _Bar(
                    key: ValueKey('bar-uninstalled-$i'),
                    count: d.uninstalled.length,
                    height: d.uninstalled.isEmpty ? 3.0 : (d.uninstalled.length / maxV * _barsH).clamp(3.0, _barsH),
                    color: _uninstallRed,
                    onTap: () => _open('Uninstalled on ${_date(d.day)}', d.uninstalled, 'Nobody uninstalled that day',
                        (u, dev) => dev?.uninstalledAt == null ? '' : 'Uninstalled ${DateFormat('h:mm a').format(dev!.uninstalledAt!)}'),
                  ),
                ]),
                const SizedBox(height: 6),
                Text(isToday ? 'Today' : DateFormat('d MMM').format(d.day), style: body(11, isToday ? FontWeight.w800 : FontWeight.w500, muted)),
                const SizedBox(height: 2),
                Text(
                  d.net > 0 ? 'Net gain\n+${d.net}' : (d.net < 0 ? 'Net loss\n${d.net}' : 'No\nchange'),
                  textAlign: TextAlign.center,
                  style: body(10.5, FontWeight.w800, d.net > 0 ? gain : (d.net < 0 ? loss : muted)).copyWith(height: 1.15),
                ),
              ]),
            );
          },
        ),
      ),
    ]);
  }
}

class _Key extends StatelessWidget {
  final Color color;
  final String label;
  const _Key({required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 14, height: 14, decoration: BoxDecoration(color: color, border: Border.all(color: charcoal), borderRadius: BorderRadius.circular(4))),
        const SizedBox(width: 6),
        Text(label, style: body(13, FontWeight.w700)),
      ]);
}

/// One bar with its number on top. The whole thing is a button, also when the number is zero.
class _Bar extends StatelessWidget {
  final int count;
  final double height;
  final Color color;
  final VoidCallback onTap;
  const _Bar({super.key, required this.count, required this.height, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('$count', style: body(11, FontWeight.w700)),
            const SizedBox(height: 2),
            Container(
              width: 24,
              height: height,
              decoration: BoxDecoration(color: color, border: Border.all(color: charcoal), borderRadius: BorderRadius.circular(5)),
            ),
          ]),
        ),
      );
}

/// "How is this counted?" in plain words. Matches how the server must record installs.
class _HowCounted extends StatelessWidget {
  const _HowCounted();

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 8),
        title: Text('How is this counted?', style: body(14, FontWeight.w700)),
        children: [
          for (final t in const [
            'Active users: how many people opened the app that day.',
            'Each phone tells our server about itself once a day. The server keeps one record per phone, so a phone counts once even if many accounts use it.',
            'An install is counted on the day Android says the app was installed on that phone. A phone that only updated the app still counts on its real install day. The person shown is the one who signed up or opened the app first on that phone.',
            'An uninstall is counted when Google tells us the phone no longer has the app. Nothing is guessed. Once a day the server asks Google to check every phone quietly, and nobody gets a message.',
            'An uninstall can show a day or two late. A phone that was switched off for a long time is only noticed when Google answers. If a phone reports in again later, the uninstall is removed.',
            'The net for a day is installs minus uninstalls.',
            'With "Real users only" on, only phones owned by real people are counted.',
            'This is measured on Android. On iPhone, Apple does not tell apps when someone deletes them, so uninstalls cannot be counted there.',
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('•  ', style: body(13, FontWeight.w700)),
                Expanded(child: Text(t, style: body(13, FontWeight.w400, muted))),
              ]),
            ),
        ],
      ),
    );
  }
}
