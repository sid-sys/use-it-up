import 'package:flutter/material.dart';
import '../auth.dart';
import '../config.dart';
import '../notification_log.dart';
import '../theme.dart';
import '../widgets/app_logo.dart';
import 'feedback_screen.dart';
import 'hidden_screen.dart';
import 'install_chart.dart';
import 'models.dart';
import 'notifications_screen.dart';
import 'repository.dart';
import 'users_screen.dart';
import 'widgets.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final AdminRepository _repo = createAdminRepository();
  AdminData? _data;
  String? _error;
  bool _realOnly = true; // hides test, review, robot and my own accounts from EVERYTHING below

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final d = await _repo.load();
      if (mounted) setState(() => _data = d);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    return Scaffold(
      appBar: AppBar(
        title: const Text('ADMIN PANEL'),
        actions: [
          if (AppConfig.mock) const Padding(padding: EdgeInsets.only(right: 4), child: Center(child: MockTag())),
          IconButton(tooltip: 'Refresh', icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _error != null
          ? Center(child: Padding(padding: const EdgeInsets.all(20), child: Text('Could not load: $_error')))
          : data == null
              ? const Center(child: CircularProgressIndicator(color: charcoal))
              : _body(data),
    );
  }

  void _open(Widget screen) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

  Widget _body(AdminData data) {
    final hidden = data.users.where((u) => u.hiddenReason != null).toList();
    final shown = _realOnly ? data.users.where((u) => u.hiddenReason == null).toList() : data.users;
    final s = AdminStats.from(shown, data.devices, DateTime.now());
    final email = Auth.email ?? AppConfig.adminEmail;
    List<AdminDevice> devices() => data.devices;

    void list(String title, List<AdminUser> users, {UserFilter filter = UserFilter.all}) =>
        _open(UsersScreen(title: title, users: users, devices: devices(), initialFilter: filter));

    final header = Row(children: [
      const AppLogo(textColor: charcoal, size: 30),
      const Spacer(),
      Flexible(child: Text('Signed in as\n$email', textAlign: TextAlign.end, style: body(12, FontWeight.w500, muted))),
    ]);

    final notice = data.serverConnected || AppConfig.mock
        ? null
        : Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: paleLime, borderRadius: BorderRadius.circular(16)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.info_outline, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'No server is connected yet, so this panel shows only this phone. Nothing is made up. '
                  'Installs, uninstalls and money numbers need the server. See the README.',
                  style: body(13, FontWeight.w600),
                ),
              ),
            ]),
          );

    final realUsers = Material(
      color: cardWhite,
      borderRadius: BorderRadius.circular(20),
      child: Column(children: [
        SwitchListTile(
          activeTrackColor: charcoal,
          title: Text('Real users only', style: body(16, FontWeight.w800)),
          subtitle: Text('Leaves out test, review, robot and my own accounts everywhere below', style: body(12.5, FontWeight.w400, muted)),
          value: _realOnly,
          onChanged: (v) => setState(() => _realOnly = v),
        ),
        InkWell(
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
          onTap: () => _open(HiddenAccountsScreen(hidden: hidden)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
            child: Row(children: [
              const Icon(Icons.visibility_off_outlined, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  hidden.isEmpty
                      ? 'No accounts are hidden'
                      : _realOnly
                          ? 'Hiding ${hidden.length} test, review and my own accounts'
                          : 'Showing everything, including ${hidden.length} test, review and my own accounts',
                  style: body(13, FontWeight.w700).copyWith(decoration: TextDecoration.underline),
                ),
              ),
              const Icon(Icons.chevron_right, size: 18),
            ]),
          ),
        ),
      ]),
    );

    final cards = GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.12,
      children: [
        MetricCard(
          highlight: true,
          icon: Icons.groups_outlined,
          title: 'Total users',
          value: '${s.totalUsers}',
          sub: '+${s.newThisWeek} this week',
          onTap: () => list('All users', s.users),
        ),
        MetricCard(
          icon: Icons.workspace_premium_outlined,
          title: 'Subscribed',
          value: '${s.subscribed.length}',
          sub: '${s.subscribedPct.round()}% of users · ${s.payingNow} paying · ${s.lifetime} lifetime',
          onTap: () => list('Subscribed', s.subscribed),
        ),
        MetricCard(
          icon: Icons.bolt_outlined,
          title: 'Active today',
          value: '${s.activeToday.length}',
          sub: '${s.activeWeek} active this week',
          onTap: () => list('Active today', s.activeToday),
        ),
        MetricCard(
          icon: Icons.payments_outlined,
          title: 'Revenue (last 30 days)',
          value: AppConfig.moneyShort(s.revenue30),
          sub: '${AppConfig.moneyShort(s.revenueTotal)} since the start',
          onTap: () => list('Paid in the last 30 days', s.paidLast30),
        ),
        MetricCard(
          icon: Icons.trending_up,
          title: 'Profit before store cut',
          value: AppConfig.moneyShort(s.profitBefore),
          sub: '30 days. Costs ${AppConfig.moneyShort(s.costs30)} (AI ${AppConfig.moneyShort(s.aiCost30)} + fixed ${AppConfig.moneyShort(s.fixedCost30)})',
          onTap: () => list('Paid in the last 30 days', s.paidLast30),
        ),
        MetricCard(
          icon: Icons.account_balance_outlined,
          title: 'Profit after store cut',
          value: AppConfig.moneyShort(s.profitAfter),
          sub: '30 days. After ${(AppConfig.storeCut * 100).round()}% store share',
          onTap: () => list('Paid in the last 30 days', s.paidLast30),
        ),
      ],
    );

    final anyInstalls = s.installs30.any((d) => d.installed.isNotEmpty || d.uninstalled.isNotEmpty);
    final installs = SectionCard(
      title: 'Installs and uninstalls',
      sub: 'Last 30 days. Tap a day to see who.',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (anyInstalls)
          InstallsChart(days: s.installs30, devices: data.devices)
        else
          Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text('No installs yet', style: body(14, FontWeight.w600, muted))),
        const _HowCounted(),
      ]),
    );

    final dau = SectionCard(
      title: 'Daily active users',
      sub: 'Last 14 days',
      child: s.dau14.every((v) => v == 0)
          ? Text('Nobody was active yet', style: body(14, FontWeight.w600, muted))
          : DauChart(values: s.dau14),
    );

    final funnel = SectionCard(
      title: 'From joining to subscribing',
      sub: s.biggestDropIndex < 0
          ? 'Tap a step to see who reached it'
          : 'Most people leave at "${s.funnel[s.biggestDropIndex].label}" (${s.funnel[s.biggestDropIndex - 1].count - s.funnel[s.biggestDropIndex].count} left)',
      child: s.totalUsers == 0
          ? Text('No users yet', style: body(14, FontWeight.w600, muted))
          : Column(children: [
              for (var i = 0; i < s.funnel.length; i++)
                FunnelRow(
                  label: s.funnel[i].label,
                  count: s.funnel[i].count,
                  total: s.funnel[0].count,
                  biggestDrop: i == s.biggestDropIndex,
                  onTap: () => list('Reached: ${s.funnel[i].label}', s.funnel[i].users),
                ),
            ]),
    );

    final problemTotal = s.payProblems.values.fold<int>(0, (a, l) => a + l.length);
    final problems = SectionCard(
      title: 'When paying did not happen',
      sub: 'People who tried to pay and it did not work out',
      child: problemTotal == 0
          ? Text('No payment problems yet', style: body(14, FontWeight.w600, muted))
          : Column(children: [
              for (final k in AdminStats.payProblemLabels.keys)
                BarRow(
                  label: AdminStats.payProblemLabels[k]!,
                  count: s.payProblems[k]!.length,
                  max: s.payProblems.values.fold<int>(1, (a, l) => l.length > a ? l.length : a),
                  onTap: () => list(AdminStats.payProblemLabels[k]!, s.payProblems[k]!),
                ),
              const SizedBox(height: 6),
              for (final f in _recentFailures(s).take(4))
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(children: [
                    Expanded(child: Text('${f.$1}: ${f.$2.detail.isEmpty ? AdminStats.payProblemLabels[f.$2.reason] : f.$2.detail}', style: body(12.5, FontWeight.w500, muted))),
                    Text(timeAgo(f.$2.time), style: body(12, FontWeight.w500, muted)),
                  ]),
                ),
            ]),
    );

    final heardAnswered = s.sources.entries.where((e) => e.key != 'none').fold<int>(0, (a, e) => a + e.value.length);
    final maxSource = s.sources.values.fold<int>(1, (a, l) => l.length > a ? l.length : a);
    final sources = SectionCard(
      title: 'Where people heard about us',
      sub: 'Tap a bar to see the people',
      child: heardAnswered == 0
          ? Text('Nobody has answered yet', style: body(14, FontWeight.w600, muted))
          : Column(children: [
              for (final k in [...heardLabels.keys, 'none'])
                BarRow(
                  label: k == 'none' ? 'Did not answer' : heardLabels[k]!,
                  count: s.sources[k]!.length,
                  max: maxSource,
                  onTap: () => list(k == 'none' ? 'Did not answer' : heardLabels[k]!, s.sources[k]!),
                ),
            ]),
    );

    final notifications = ListenableBuilder(
      listenable: NotificationLog.instance,
      builder: (context, _) => _NavCard(
        icon: Icons.notifications_active_outlined,
        title: 'Notifications',
        sub: '${NotificationLog.instance.entries.length} logged on this phone. Send a test.',
        onTap: () => _open(const NotificationsScreen()),
      ),
    );

    final buttons = Column(children: [
      FilledButton(
        style: darkButton(),
        onPressed: () => list('All users', s.users),
        child: Text('See all ${s.users.length} users'),
      ),
      const SizedBox(height: 10),
      OutlinedButton(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          foregroundColor: charcoal,
          side: const BorderSide(color: charcoal, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: body(16, FontWeight.w600),
        ),
        onPressed: () => _open(FeedbackScreen(items: data.feedback, saveOnPhone: !AppConfig.mock)),
        child: Text('Feedback and bug reports (${data.feedback.where((f) => !f.handled).length} open)'),
      ),
    ]);

    return LayoutBuilder(builder: (context, c) {
      const gap = SizedBox(height: 16);
      final wide = c.maxWidth >= 900;
      final top = <Widget>[header, ?notice, realUsers];
      final left = <Widget>[cards, installs, problems];
      final right = <Widget>[dau, funnel, sources];
      final bottom = <Widget>[notifications, buttons];
      Widget stack(List<Widget> l) => Column(children: [for (final w in l) ...[w, gap]]);
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            children: [
              stack(top),
              if (wide)
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: stack(left)),
                  const SizedBox(width: 16),
                  Expanded(child: stack(right)),
                ])
              else ...[stack(left), stack(right)],
              stack(bottom),
            ],
          ),
        ),
      );
    });
  }

  List<(String, AdminPayFailure)> _recentFailures(AdminStats s) {
    final all = <(String, AdminPayFailure)>[
      for (final u in s.users)
        for (final f in u.failures) (u.displayName, f),
    ]..sort((a, b) => b.$2.time.compareTo(a.$2.time));
    return all;
  }
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
            'Each phone tells our server about itself once a day. The server keeps one record per phone, so a phone counts once even if many accounts use it.',
            'An install is counted on the day Android says the app was installed on that phone. A phone that only updated the app still counts on its real install day.',
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

class _NavCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String sub;
  final VoidCallback onTap;
  const _NavCard({required this.icon, required this.title, required this.sub, required this.onTap});

  @override
  Widget build(BuildContext context) => Material(
        color: paleLime,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Icon(icon, size: 26),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: body(16, FontWeight.w800)),
                  Text(sub, style: body(12.5, FontWeight.w400, muted)),
                ]),
              ),
              const Icon(Icons.chevron_right),
            ]),
          ),
        ),
      );
}
