import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'models.dart';
import 'notification_log.dart';

class ReminderPrefs {
  bool threeDays;
  bool oneDay;
  bool onDay;
  bool weekly; // weekly overview
  bool reengage; // gentle nudge after a few days away
  ReminderPrefs({
    this.threeDays = true,
    this.oneDay = true,
    this.onDay = true,
    this.weekly = true,
    this.reengage = true,
  });
}

/// Local notifications. No-op on web. Every one is also written to [NotificationLog]
/// so the admin panel can list them.
class Notifier {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;
  static bool get supported => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  static Future<void> init() async {
    if (!supported || _ready) return;
    tzdata.initializeTimeZones();
    try {
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name.identifier));
    } catch (_) {}
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_stat_useitup'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    _ready = true;
  }

  /// Ask when the first item is added, when the value is obvious.
  /// Returns true if the user allowed notifications.
  static Future<bool> requestPermission() async {
    if (!supported) return false;
    await init();
    final ios = await _plugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    final android = await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    return (ios ?? android ?? false) == true;
  }

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails('expiry', 'Expiry reminders',
        channelDescription: 'Reminders to check food before its date',
        importance: Importance.high,
        priority: Priority.high),
    iOS: DarwinNotificationDetails(),
  );

  static int _id(String itemId, int slot) => (itemId.hashCode & 0x3FFFFFF) * 4 + slot;

  static Future<void> cancelFor(FoodItem i) async {
    if (!supported) return;
    await init();
    for (var s = 0; s < 3; s++) {
      await _plugin.cancel(id: _id(i.id, s));
      await NotificationLog.instance.markCancelled(_id(i.id, s));
    }
  }

  static Future<void> scheduleFor(FoodItem i, ReminderPrefs p) async {
    if (!supported) return;
    await init();
    await cancelFor(i);
    if (i.used) return;
    final now = tz.TZDateTime.now(tz.local);
    Future<void> at(int slot, int daysBefore, String msg) async {
      final when = tz.TZDateTime(tz.local, i.expiry.year, i.expiry.month, i.expiry.day, 9)
          .subtract(Duration(days: daysBefore));
      if (!when.isAfter(now)) return;
      final id = _id(i.id, slot);
      await _plugin.zonedSchedule(
        id: id,
        title: 'Use It Up',
        body: msg,
        scheduledDate: when,
        notificationDetails: _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
      await NotificationLog.instance.add(NotifEntry(
        id: id,
        kind: 'reminder',
        title: 'Use It Up',
        body: msg,
        createdAt: DateTime.now(),
        fireAt: when,
      ));
    }

    // Wording asks the user to check the label and the food. It never says safe or unsafe.
    final n = i.name.toLowerCase();
    final e = emojiFor(i.name);
    if (p.threeDays) await at(0, 3, '$e Your $n is coming up on its date.');
    if (p.oneDay) await at(1, 1, '⚠️ Use your $n soon. It expires tomorrow.');
    if (p.onDay) await at(2, 0, '🔔 Check your $n today.');
  }

  static const _trialId = 900000200;

  /// "Your trial ends in 2 days." This is the reminder the trial screen promises.
  /// Planned for 10:00, two days before the trial ends.
  static Future<void> scheduleTrialReminder(DateTime trialStart, int trialDays) async {
    if (!supported) return;
    try {
      await init();
      final end = trialStart.add(Duration(days: trialDays));
      final when = tz.TZDateTime(tz.local, end.year, end.month, end.day, 10).subtract(const Duration(days: 2));
      if (!when.isAfter(tz.TZDateTime.now(tz.local))) return;
      const msg = '⏰ Your free trial ends in 2 days. You can cancel any time in your store settings.';
      await _plugin.cancel(id: _trialId);
      await _plugin.zonedSchedule(
        id: _trialId,
        title: 'Use It Up',
        body: msg,
        scheduledDate: when,
        notificationDetails: _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
      await NotificationLog.instance.add(NotifEntry(
        id: _trialId,
        kind: 'trial',
        title: 'Use It Up',
        body: msg,
        createdAt: DateTime.now(),
        fireAt: when,
      ));
    } catch (e) {
      debugPrint('Could not plan the trial reminder: $e');
    }
  }

  static Future<void> cancelTrialReminder() async {
    if (!supported) return;
    try {
      await init();
      await _plugin.cancel(id: _trialId);
      await NotificationLog.instance.markCancelled(_trialId);
    } catch (_) {}
  }

  static const _weeklyBase = 900000000;
  static const _inactiveId = 900000100;

  /// Weekly overview and the "we miss you" nudge. A local notification cannot count items
  /// at the moment it fires, so these are re-planned every time the app opens or food
  /// changes. The count is worked out for each of the next 4 Mondays.
  static Future<void> refreshGeneral(List<FoodItem> active, ReminderPrefs p) async {
    if (!supported) return;
    await init();
    final now = tz.TZDateTime.now(tz.local);

    // Weekly: next 4 Mondays at 9:00.
    for (var w = 0; w < 4; w++) {
      await _plugin.cancel(id: _weeklyBase + w);
      await NotificationLog.instance.markCancelled(_weeklyBase + w);
    }
    if (p.weekly) {
      var monday = tz.TZDateTime(tz.local, now.year, now.month, now.day, 9);
      monday = monday.add(Duration(days: (8 - now.weekday) % 7));
      if (!monday.isAfter(now)) monday = monday.add(const Duration(days: 7));
      for (var w = 0; w < 4; w++) {
        final when = monday.add(Duration(days: 7 * w));
        final weekEnd = DateTime(when.year, when.month, when.day).add(const Duration(days: 6));
        final count = active.where((x) => !x.expiry.isAfter(weekEnd)).length;
        if (count == 0) continue; // nothing to say this week
        final msg = '📅 You have $count ${count == 1 ? 'item' : 'items'} to use soon.';
        await _plugin.zonedSchedule(
          id: _weeklyBase + w,
          title: 'Use It Up',
          body: msg,
          scheduledDate: when,
          notificationDetails: _details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
        await NotificationLog.instance.add(NotifEntry(
          id: _weeklyBase + w,
          kind: 'weekly',
          title: 'Use It Up',
          body: msg,
          createdAt: DateTime.now(),
          fireAt: when,
        ));
      }
    }

    // Re-engagement: 3 days after the app was last opened, at 18:00.
    await _plugin.cancel(id: _inactiveId);
    await NotificationLog.instance.markCancelled(_inactiveId);
    if (p.reengage) {
      final when = tz.TZDateTime(tz.local, now.year, now.month, now.day, 18).add(const Duration(days: 3));
      const msg = '🛒 Got new groceries? Add their dates in seconds.';
      await _plugin.zonedSchedule(
        id: _inactiveId,
        title: 'Use It Up',
        body: msg,
        scheduledDate: when,
        notificationDetails: _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
      await NotificationLog.instance.add(NotifEntry(
        id: _inactiveId,
        kind: 'inactive',
        title: 'Use It Up',
        body: msg,
        createdAt: DateTime.now(),
        fireAt: when,
      ));
    }
  }

  static Future<void> cancelAll() async {
    if (!supported) return;
    await init();
    await _plugin.cancelAll();
  }

  static Future<void> rescheduleAll(Iterable<FoodItem> items, ReminderPrefs p) async {
    if (!supported) return;
    for (final i in items) {
      await scheduleFor(i, p);
    }
  }

  /// Admin test: one notification right now, and one that fires in about a minute.
  static Future<void> sendTest() async {
    if (!supported) return;
    await init();
    final now = DateTime.now();
    final id = 1000000000 + (now.millisecondsSinceEpoch % 100000000);
    await _plugin.show(
      id: id,
      title: 'Use It Up (test)',
      body: '🧪 Test notification sent at ${_hm(now)}.',
      notificationDetails: _details,
    );
    await NotificationLog.instance.add(NotifEntry(
      id: id,
      kind: 'test',
      title: 'Use It Up (test)',
      body: 'Sent right now',
      createdAt: now,
      fireAt: now,
    ));
    final later = tz.TZDateTime.now(tz.local).add(const Duration(minutes: 1));
    final id2 = id + 1;
    await _plugin.zonedSchedule(
      id: id2,
      title: 'Use It Up (test)',
      body: '🧪 Scheduled test, set at ${_hm(now)}.',
      scheduledDate: later,
      notificationDetails: _details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
    await NotificationLog.instance.add(NotifEntry(
      id: id2,
      kind: 'test',
      title: 'Use It Up (test)',
      body: 'Scheduled for about 1 minute later',
      createdAt: now,
      fireAt: later,
    ));
  }

  static String _hm(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}
