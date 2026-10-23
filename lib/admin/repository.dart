import '../analytics.dart';
import '../auth.dart';
import '../billing.dart';
import '../feedback_log.dart';
import '../install_id.dart';
import '../install_info.dart';
import '../main.dart' show billing, store;
import 'models.dart';

/// Every admin screen reads data ONLY through this. A Firestore version can replace
/// [LocalAdminRepository] without touching any screen.
///
/// SECURITY: a real version MUST check on the server that the caller is an admin
/// (see firestore.rules). Hiding the button in the app is not security.
abstract class AdminRepository {
  Future<AdminData> load();
}

AdminRepository createAdminRepository() => LocalAdminRepository();

/// Real build, before a backend exists: shows only this phone, as one user.
/// Nothing is invented. The screens say that no server is connected.
class LocalAdminRepository implements AdminRepository {
  @override
  Future<AdminData> load() async {
    final ev = Analytics.instance.events;
    final now = DateTime.now();
    final events = [for (final e in ev) AdminEvent(e.time, e.type, e.detail)];
    final first = events.isEmpty ? now : events.last.time;
    final last = events.isEmpty ? now : events.first.time;
    final plan = switch (billing.plan) {
      PlanKind.monthly => AdminPlan.monthly,
      PlanKind.yearly => AdminPlan.yearly,
      PlanKind.lifetime => AdminPlan.lifetime,
      _ => AdminPlan.none,
    };
    final failures = [
      for (final e in events.where((e) => e.type == Ev.payFailed)) AdminPayFailure(e.time, e.detail, ''),
    ];
    final signedIn = Auth.signedIn;
    final installId = await InstallId.get();
    final install = InstallInfo.current ?? await InstallInfo.collect();
    final user = AdminUser(
      id: installId,
      name: signedIn ? Auth.displayName : '',
      email: Auth.email ?? '',
      country: '-',
      joinedAt: first,
      lastSeen: last,
      isGuest: !signedIn,
      paywallViews: events.where((e) => e.type == Ev.paywallView).length,
      paymentAttempts: events.where((e) => e.type == Ev.paymentAttempt).length,
      plan: plan,
      subscribedAt: events.where((e) => e.type == Ev.subscribed).map((e) => e.time).fold<DateTime?>(null, (a, b) => a ?? b),
      payments: const [],
      failures: failures,
      events: events,
      streak: 0,
      heardFrom: store.heardFrom,
      answers: {
        if (install?.label != null) 'Came from': install!.label!,
        if (store.problem != null) 'What usually gets forgotten': store.problem!,
        if (store.household != null) 'People shopping for': store.household!,
        'Reminders': store.remindWhen,
      },
    );
    final feedback = [
      for (final f in FeedbackLog.instance.entries)
        AdminFeedback(id: f.id, name: user.displayName, kind: f.kind, text: f.text, time: f.time, handled: f.handled),
    ];
    return AdminData(
      users: [user],
      devices: [AdminDevice(installId: installId, ownerId: user.id, installedAt: install?.firstInstallTime ?? first, lastSeen: last)],
      feedback: feedback,
      serverConnected: false,
    );
  }
}
