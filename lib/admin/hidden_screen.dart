import 'package:flutter/material.dart';
import '../theme.dart';
import 'models.dart';
import 'user_detail.dart';
import 'widgets.dart';

/// The accounts "Real users only" leaves out, each with the reason, so you can check that no
/// real person is hidden. The rules are in admin_config.dart.
class HiddenAccountsScreen extends StatelessWidget {
  final List<AdminUser> hidden;
  const HiddenAccountsScreen({super.key, required this.hidden});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('HIDDEN ACCOUNTS')),
      body: hidden.isEmpty
          ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('No accounts are hidden.', style: body(15))))
          : ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 24), children: [
              Text('These are left out of every number, chart and list while "Real users only" is on. Tap one to look at it.',
                  style: body(13.5, FontWeight.w400, muted)),
              const SizedBox(height: 12),
              for (final u in hidden)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: cardWhite,
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => UserDetailScreen(user: u))),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(children: [
                          UserAvatar(u),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(u.displayName, style: body(15, FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                              Text(u.subtitleLine, style: body(12, FontWeight.w400, muted), maxLines: 1, overflow: TextOverflow.ellipsis),
                            ]),
                          ),
                          const SizedBox(width: 8),
                          Tag(u.hiddenReason ?? '', color: charcoal, textColor: Colors.white),
                        ]),
                      ),
                    ),
                  ),
                ),
            ]),
    );
  }
}
