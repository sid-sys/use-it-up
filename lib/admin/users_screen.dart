import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme.dart';
import 'models.dart';
import 'user_detail.dart';
import 'widgets.dart';

enum UserFilter { all, subscribed, free, activeToday }

enum UserSort { signedUp, lastSeen, installed, uninstalled }

/// A list of people. Used for "All users" and for every list opened from a number, chart or bar.
class UsersScreen extends StatefulWidget {
  final String title;
  final List<AdminUser> users;
  final List<AdminDevice> devices;
  final UserFilter initialFilter;
  final String emptyText;

  /// Extra line on each row, for example "Installed 9:14 AM". Optional.
  final String Function(AdminUser user, AdminDevice? device)? timeLabel;

  const UsersScreen({
    super.key,
    this.title = 'Users',
    required this.users,
    this.devices = const [],
    this.initialFilter = UserFilter.all,
    this.emptyText = 'No users match.',
    this.timeLabel,
  });

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  String _q = '';
  late UserFilter _f = widget.initialFilter;
  UserSort _sort = UserSort.lastSeen;

  AdminDevice? _deviceOf(AdminUser u) {
    for (final d in widget.devices) {
      if (d.ownerId == u.id) return d;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final far = DateTime.fromMillisecondsSinceEpoch(0);
    final list = widget.users.where((u) {
      if (_q.isNotEmpty && !('${u.displayName} ${u.name} ${u.email}'.toLowerCase().contains(_q.toLowerCase()))) return false;
      return switch (_f) {
        UserFilter.all => true,
        UserFilter.subscribed => u.plan != AdminPlan.none,
        UserFilter.free => u.plan == AdminPlan.none,
        UserFilter.activeToday => u.activeOn(now),
      };
    }).toList()
      ..sort((a, b) => switch (_sort) {
            UserSort.signedUp => b.joinedAt.compareTo(a.joinedAt),
            UserSort.lastSeen => b.lastSeen.compareTo(a.lastSeen),
            UserSort.installed => (_deviceOf(b)?.installedAt ?? far).compareTo(_deviceOf(a)?.installedAt ?? far),
            UserSort.uninstalled => (_deviceOf(b)?.uninstalledAt ?? far).compareTo(_deviceOf(a)?.uninstalledAt ?? far),
          });

    return Scaffold(
      appBar: AppBar(title: Text(widget.title.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis)),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: TextField(
            onChanged: (v) => setState(() => _q = v),
            decoration: const InputDecoration(hintText: 'Search by name or email', prefixIcon: Icon(Icons.search)),
          ),
        ),
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              for (final (f, label) in const [
                (UserFilter.all, 'All'),
                (UserFilter.subscribed, 'Subscribed'),
                (UserFilter.free, 'Free'),
                (UserFilter.activeToday, 'Active today'),
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
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 2, 16, 0),
          child: Row(children: [
            Text('${list.length} ${list.length == 1 ? 'person' : 'people'}', style: body(13, FontWeight.w600, muted)),
            const Spacer(),
            Text('Sort: ', style: body(13, FontWeight.w600, muted)),
            DropdownButton<UserSort>(
              value: _sort,
              underline: const SizedBox.shrink(),
              style: body(13, FontWeight.w700),
              items: const [
                DropdownMenuItem(value: UserSort.signedUp, child: Text('Signed up')),
                DropdownMenuItem(value: UserSort.lastSeen, child: Text('Last seen')),
                DropdownMenuItem(value: UserSort.installed, child: Text('Installed')),
                DropdownMenuItem(value: UserSort.uninstalled, child: Text('Uninstalled')),
              ],
              onChanged: (v) => setState(() => _sort = v ?? _sort),
            ),
          ]),
        ),
        Expanded(
          child: list.isEmpty
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(widget.emptyText, style: body(15))))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: list.length,
                  itemBuilder: (_, i) => UserRow(
                    user: list[i],
                    devices: widget.devices,
                    device: _deviceOf(list[i]),
                    extra: widget.timeLabel?.call(list[i], _deviceOf(list[i])),
                  ),
                ),
        ),
      ]),
    );
  }
}

class UserRow extends StatelessWidget {
  final AdminUser user;
  final AdminDevice? device;
  final List<AdminDevice> devices;
  final String? extra;
  const UserRow({super.key, required this.user, this.device, this.devices = const [], this.extra});

  @override
  Widget build(BuildContext context) {
    final hidden = user.hiddenReason;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: cardWhite,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => UserDetailScreen(user: user, device: device))),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              UserAvatar(user),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(user.displayName, style: body(15, FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(user.subtitleLine, style: body(12, FontWeight.w400, muted), maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text('Joined ${DateFormat('d MMM').format(user.joinedAt)} · Seen ${timeAgo(user.lastSeen)}',
                      style: body(11.5, FontWeight.w400, muted), maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (extra != null && extra!.isNotEmpty) Text(extra!, style: body(11.5, FontWeight.w700)),
                  if (user.isGuest || user.testPurchase || hidden != null || (device?.uninstalled ?? false))
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Wrap(spacing: 6, runSpacing: 4, children: [
                        if (user.isGuest) const Tag('Guest'),
                        if (user.testPurchase) const Tag('Test purchase', color: paleLime),
                        if (device?.uninstalled ?? false) const Tag('Uninstalled'),
                        if (hidden != null) Tag('Hidden: $hidden', color: charcoal, textColor: Colors.white),
                      ]),
                    ),
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
