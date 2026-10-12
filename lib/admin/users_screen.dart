import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme.dart';
import 'models.dart';
import 'user_detail.dart';
import 'widgets.dart';

class UsersScreen extends StatefulWidget {
  final List<AdminUser> users;
  const UsersScreen({super.key, required this.users});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

enum _Filter { all, subscribed, free, activeToday }

class _UsersScreenState extends State<UsersScreen> {
  String _q = '';
  _Filter _f = _Filter.all;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final list = widget.users.where((u) {
      if (_q.isNotEmpty && !('${u.name} ${u.email}'.toLowerCase().contains(_q.toLowerCase()))) return false;
      return switch (_f) {
        _Filter.all => true,
        _Filter.subscribed => u.plan != AdminPlan.none,
        _Filter.free => u.plan == AdminPlan.none,
        _Filter.activeToday => u.activeOn(now),
      };
    }).toList()
      ..sort((a, b) => b.lastSeen.compareTo(a.lastSeen));

    return Scaffold(
      appBar: AppBar(title: const Text('USERS')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: TextField(
            onChanged: (v) => setState(() => _q = v),
            decoration: const InputDecoration(hintText: 'Search name or email', prefixIcon: Icon(Icons.search)),
          ),
        ),
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              for (final (f, label) in const [
                (_Filter.all, 'All'),
                (_Filter.subscribed, 'Subscribed'),
                (_Filter.free, 'Free'),
                (_Filter.activeToday, 'Active today'),
              ])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(label),
                    selected: _f == f,
                    selectedColor: lime,
                    onSelected: (_) => setState(() => _f = f),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: list.isEmpty
              ? Center(child: Text('No users match.', style: body(15)))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: list.length,
                  itemBuilder: (_, i) => _UserRow(user: list[i]),
                ),
        ),
      ]),
    );
  }
}

class _UserRow extends StatelessWidget {
  final AdminUser user;
  const _UserRow({required this.user});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: cardWhite,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => UserDetailScreen(user: user))),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              CircleAvatar(backgroundColor: planColor(user.plan), child: Text(initials(user.name), style: body(14, FontWeight.w800))),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(user.name, style: body(15, FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(user.email, style: body(12, FontWeight.w400, Colors.black54), maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text('Joined ${DateFormat('d MMM').format(user.joinedAt)} · Seen ${timeAgo(user.lastSeen)}',
                      style: body(11.5, FontWeight.w400, Colors.black45), maxLines: 1, overflow: TextOverflow.ellipsis),
                ]),
              ),
              const SizedBox(width: 8),
              PlanPill(user.plan),
            ]),
          ),
        ),
      ),
    );
  }
}
