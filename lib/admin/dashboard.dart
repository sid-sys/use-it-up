import 'package:flutter/material.dart';
import '../auth.dart';
import '../config.dart';
import '../notification_log.dart';
import '../theme.dart';
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
  List<AdminUser>? _users;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final u = await _repo.loadUsers();
      if (mounted) setState(() => _users = u);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final users = _users;
    return Scaffold(
      appBar: AppBar(
        title: const Text('ADMIN'),
        actions: [
          if (AppConfig.mock) const Padding(padding: EdgeInsets.only(right: 4), child: Center(child: MockTag())),
          IconButton(tooltip: 'Refresh', icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _error != null
          ? Center(child: Padding(padding: const EdgeInsets.all(20), child: Text('Could not load: $_error')))
          : users == null
              ? const Center(child: CircularProgressIndicator(color: charcoal))
              : _body(users),
    );
  }

  Widget _body(List<AdminUser> users) {
    final s = AdminStats.from(users, DateTime.now());
    final email = Auth.email ?? AppConfig.adminEmail;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        Text('Signed in as $email', style: body(13, FontWeight.w500, Colors.black54)),
        const SizedBox(height: 12),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.3,
          children: [
            MetricCard(color: pLime, emoji: '👥', title: 'Total users', value: '${s.totalUsers}', sub: '+${s.newThisWeek} this week'),
            MetricCard(
              color: pLilac,
              emoji: '💎',
              title: 'Subscribed',
              value: '${s.subscribed}',
              sub: '${s.subscribedPct.round()}% of users · ${s.payingNow} paying · ${s.lifetime} lifetime',
            ),
            MetricCard(color: pSky, emoji: '⚡', title: 'Active today', value: '${s.activeToday}', sub: '${s.activeWeek} active this week'),
            MetricCard(
              color: pMint,
              emoji: '💰',
              title: 'Revenue',
              value: AppConfig.moneyShort(s.revenueTotal),
              sub: '${AppConfig.moneyShort(s.revenue30)} last 30 days',
            ),
            MetricCard(
              color: pPeach,
              emoji: '📈',
              title: 'Profit before store cut',
              value: AppConfig.moneyShort(s.profitBefore),
              sub: '30 days. Costs ${AppConfig.moneyShort(s.costs30)} (AI ${AppConfig.moneyShort(s.aiCost30)} + fixed ${AppConfig.moneyShort(s.fixedCost30)})',
            ),
            MetricCard(
              color: pPink,
              emoji: '🏦',
              title: 'Profit after store cut',
              value: AppConfig.moneyShort(s.profitAfter),
              sub: '30 days. After ${(AppConfig.storeCut * 100).round()}% store share',
            ),
          ],
        ),
        const SizedBox(height: 16),
        SectionCard(title: 'Daily active users', sub: 'Last 14 days', child: DauChart(values: s.dau14)),
        const SizedBox(height: 16),
        SectionCard(
          title: 'From joining to subscribing',
          child: Column(children: [
            for (final (i, label) in const [
              'Joined',
              'Finished onboarding',
              'Added first food',
              'Reached paywall',
              'Tried to pay',
              'Subscribed',
            ].indexed)
              FunnelRow(label: label, count: s.funnel[i], total: s.funnel[0]),
          ]),
        ),
        const SizedBox(height: 16),
        ListenableBuilder(
          listenable: NotificationLog.instance,
          builder: (context, _) => _NavCard(
            emoji: '🔔',
            title: 'Notifications',
            sub: '${NotificationLog.instance.entries.length} logged on this phone. Send a test.',
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NotificationsScreen())),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(
          style: darkButton(),
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => UsersScreen(users: users))),
          child: Text('See all ${users.length} users'),
        ),
      ],
    );
  }
}

class _NavCard extends StatelessWidget {
  final String emoji;
  final String title;
  final String sub;
  final VoidCallback onTap;
  const _NavCard({required this.emoji, required this.title, required this.sub, required this.onTap});

  @override
  Widget build(BuildContext context) => Material(
        color: pLime,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Text(emoji, style: const TextStyle(fontSize: 26)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: body(16, FontWeight.w800)),
                  Text(sub, style: body(12.5, FontWeight.w400, Colors.black54)),
                ]),
              ),
              const Icon(Icons.chevron_right),
            ]),
          ),
        ),
      );
}
