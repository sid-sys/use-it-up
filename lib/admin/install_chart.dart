import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme.dart';
import 'models.dart';
import 'users_screen.dart';
import 'widgets.dart';

/// One group of bars per day, last 30 days. Slide sideways to see older days.
/// Under each group: the net result in words. Tap a day to see who installed and who uninstalled.
class InstallsChart extends StatefulWidget {
  final List<DayInstalls> days; // oldest first
  final List<AdminDevice> devices;
  const InstallsChart({super.key, required this.days, required this.devices});

  @override
  State<InstallsChart> createState() => _InstallsChartState();
}

class _InstallsChartState extends State<InstallsChart> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
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

  static const _groupW = 68.0;
  static const _barsH = 120.0;

  @override
  Widget build(BuildContext context) {
    final maxV = widget.days.fold<int>(1, (a, d) {
      final m = d.installed.length > d.uninstalled.length ? d.installed.length : d.uninstalled.length;
      return m > a ? m : a;
    });
    final installs = widget.days.fold<int>(0, (a, d) => a + d.installed.length);
    final uninstalls = widget.days.fold<int>(0, (a, d) => a + d.uninstalled.length);
    final net = installs - uninstalls;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(spacing: 14, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
        _Key(color: barLime, label: 'Installed $installs'),
        _Key(color: charcoal, label: 'Uninstalled $uninstalls'),
        Text(net > 0 ? 'Net gain +$net' : (net < 0 ? 'Net loss $net' : 'No change'),
            style: body(13, FontWeight.w800, net > 0 ? gain : (net < 0 ? loss : muted))),
      ]),
      const SizedBox(height: 10),
      SizedBox(
        height: _barsH + 96,
        child: ListView.builder(
          controller: _scroll,
          scrollDirection: Axis.horizontal,
          itemCount: widget.days.length,
          itemBuilder: (context, i) {
            final d = widget.days[i];
            final h1 = d.installed.isEmpty ? 3.0 : (d.installed.length / maxV * _barsH).clamp(3.0, _barsH);
            final h2 = d.uninstalled.isEmpty ? 3.0 : (d.uninstalled.length / maxV * _barsH).clamp(3.0, _barsH);
            final isToday = i == widget.days.length - 1;
            return InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => DayInstallsScreen(day: d, devices: widget.devices))),
              child: SizedBox(
                width: _groupW,
                child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.end, mainAxisAlignment: MainAxisAlignment.center, children: [
                    _Bar(count: d.installed.length, height: h1, color: barLime),
                    const SizedBox(width: 4),
                    _Bar(count: d.uninstalled.length, height: h2, color: charcoal),
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
              ),
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

class _Bar extends StatelessWidget {
  final int count;
  final double height;
  final Color color;
  const _Bar({required this.count, required this.height, required this.color});

  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, children: [
        Text('$count', style: body(11, FontWeight.w700)),
        const SizedBox(height: 2),
        Container(
          width: 22,
          height: height,
          decoration: BoxDecoration(color: color, border: Border.all(color: charcoal), borderRadius: BorderRadius.circular(5)),
        ),
      ]);
}

/// One day: two big buttons, "Installed N" and "Uninstalled N".
class DayInstallsScreen extends StatelessWidget {
  final DayInstalls day;
  final List<AdminDevice> devices;
  const DayInstallsScreen({super.key, required this.day, required this.devices});

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('EEE d MMM').format(day.day);
    final net = day.net;
    return Scaffold(
      appBar: AppBar(title: Text(date.toUpperCase())),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 32), children: [
        Text(day.netWords, style: body(22, FontWeight.w800, net > 0 ? gain : (net < 0 ? loss : muted))),
        const SizedBox(height: 4),
        Text('${day.installed.length} installed, ${day.uninstalled.length} uninstalled', style: body(14, FontWeight.w400, muted)),
        const SizedBox(height: 16),
        _Big(
          label: 'Installed ${day.installed.length}',
          color: lime,
          textColor: charcoal,
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => UsersScreen(
              title: 'Installed on $date',
              users: day.installed,
              devices: devices,
              emptyText: 'Nobody installed',
              timeLabel: (u, dev) => dev == null ? '' : 'Installed ${DateFormat('h:mm a').format(dev.installedAt)}',
            ),
          )),
        ),
        const SizedBox(height: 12),
        _Big(
          label: 'Uninstalled ${day.uninstalled.length}',
          color: charcoal,
          textColor: Colors.white,
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => UsersScreen(
              title: 'Uninstalled on $date',
              users: day.uninstalled,
              devices: devices,
              emptyText: 'Nobody uninstalled',
              timeLabel: (u, dev) => dev?.uninstalledAt == null ? '' : 'Uninstalled ${DateFormat('h:mm a').format(dev!.uninstalledAt!)}',
            ),
          )),
        ),
      ]),
    );
  }
}

class _Big extends StatelessWidget {
  final String label;
  final Color color;
  final Color textColor;
  final VoidCallback onTap;
  const _Big({required this.label, required this.color, required this.textColor, required this.onTap});

  @override
  Widget build(BuildContext context) => Material(
        color: color,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Row(children: [
              Expanded(child: Text(label, style: display(28, textColor))),
              Icon(Icons.chevron_right, color: textColor),
            ]),
          ),
        ),
      );
}
