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
  bool weekly;
  ReminderPrefs({this.threeDays = true, this.oneDay = true, this.onDay = true, this.weekly = false});
}

/// Local notifications. No-op on web. Every one is also written to [NotificationLog]
/// so the admin panel can list them.
class Notifier {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;
  static bool get supported => !kIsWeb;

  static Future<void> init() async {
    if (!supported || _ready) return;
    tzdata.initializeTimeZones();
    try {
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name.identifier));
    } catch (_) {}
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
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
  static Future<void> requestPermission() async {
    if (!supported) return;
    await init();
    await _plugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
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
    if (p.threeDays) await at(0, 3, 'Your ${i.name} is coming up on its date.');
    if (p.oneDay) await at(1, 1, 'Use your ${i.name} soon. Its date is tomorrow.');
    if (p.onDay) await at(2, 0, 'Check your ${i.name} today.');
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
    final id = now.millisecondsSinceEpoch & 0x3FFFFFFF;
    await _plugin.show(
      id: id,
      title: 'Use It Up (test)',
      body: 'Test notification sent at ${_hm(now)}.',
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
      body: 'Scheduled test, set at ${_hm(now)}.',
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
