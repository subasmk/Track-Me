import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/quest.dart';
import 'hive_service.dart';

/// Daily local-notification reminders for quests with a reminderTime.
///
/// Uses inexact alarms (no SCHEDULE_EXACT_ALARM permission needed), so a
/// reminder can arrive a few minutes late on some devices. One notification
/// id per quest per weekday, so quests limited to some days only fire on
/// those days.
class ReminderService {
  ReminderService._();

  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  static const _channel = AndroidNotificationDetails(
    'quest_reminders',
    'Quest reminders',
    channelDescription: 'Daily nudges for your quests',
    importance: Importance.high,
    priority: Priority.high,
  );

  static Future<void> init() async {
    if (_ready || kIsWeb) return;
    try {
      tzdata.initializeTimeZones();
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name));
      await _plugin.initialize(const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ));
      _ready = true;
    } catch (e) {
      debugPrint('ReminderService.init failed: $e');
    }
  }

  /// Asks for notification permission (Android 13+). Returns true if granted.
  static Future<bool> requestPermission() async {
    await init();
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    return await android?.requestNotificationsPermission() ?? false;
  }

  /// Stable per-quest, per-weekday notification id.
  static int idFor(String questId, int weekday) =>
      (questId.hashCode & 0x0FFFFFFF) * 8 + weekday;

  /// Parses "HH:mm". Returns null for anything else.
  static ({int hour, int minute})? parseTime(String? value) {
    if (value == null) return null;
    final parts = value.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null || h < 0 || h > 23 || m < 0 || m > 59) return null;
    return (hour: h, minute: m);
  }

  /// Next occurrence of [weekday] at [hour]:[minute] strictly after [from].
  static DateTime nextOccurrence(DateTime from, int weekday, int hour, int minute) {
    var d = DateTime(from.year, from.month, from.day, hour, minute);
    var add = (weekday - d.weekday) % 7;
    d = d.add(Duration(days: add));
    if (!d.isAfter(from)) d = d.add(const Duration(days: 7));
    return d;
  }

  static Future<void> cancel(Quest quest) async {
    if (!_ready) return;
    for (var wd = 1; wd <= 7; wd++) {
      await _plugin.cancel(idFor(quest.id, wd));
    }
  }

  static const keyRemindersEnabled = 'reminders_enabled';
  static const keyStreakNudge = 'streak_nudge_enabled';
  static const keyStreakNudgeTime = 'streak_nudge_time';

  /// Id of the daily "keep your streak" notification (quest ids are >= 8).
  static const streakNudgeId = 1;

  static bool _flag(String key, bool fallback) {
    try {
      return (HiveService.settingsBox.get(key) as bool?) ?? fallback;
    } catch (_) {
      return fallback;
    }
  }

  /// Master switch from Settings. When off, no quest reminder is scheduled.
  static bool get enabled => _flag(keyRemindersEnabled, true);

  static Future<void> schedule(Quest quest) async {
    await init();
    if (!_ready) return;
    await cancel(quest);
    if (!enabled) return;
    final t = parseTime(quest.reminderTime);
    if (t == null) return;
    final now = tz.TZDateTime.now(tz.local);
    for (final wd in quest.days) {
      final at = nextOccurrence(now, wd, t.hour, t.minute);
      try {
        await _plugin.zonedSchedule(
          idFor(quest.id, wd),
          '${quest.emoji} ${quest.title}',
          quest.items.isEmpty
              ? 'Time for your quest. Keep the ${quest.streak}-day streak going!'
              : 'Next up: ${quest.items.first.name}. +${quest.xp} XP waiting.',
          tz.TZDateTime(tz.local, at.year, at.month, at.day, at.hour, at.minute),
          const NotificationDetails(android: _channel),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
          payload: 'trackme://quest?id=${quest.id}',
        );
      } catch (e) {
        debugPrint('ReminderService.schedule failed: $e');
      }
    }
  }

  /// Re-schedules every quest (e.g. at startup after an app update).
  static Future<void> rescheduleAll(Iterable<Quest> quests) async {
    for (final q in quests) {
      if (q.reminderTime != null) {
        await schedule(q);
      } else {
        await cancel(q);
      }
    }
    await scheduleStreakNudge();
  }

  /// One daily evening nudge to protect the streak, at the time chosen in
  /// Settings (default 20:00). Cancelled when reminders or the nudge are off.
  static Future<void> scheduleStreakNudge() async {
    await init();
    if (!_ready) return;
    await _plugin.cancel(streakNudgeId);
    if (!enabled || !_flag(keyStreakNudge, true)) return;
    String? raw;
    try {
      raw = HiveService.settingsBox.get(keyStreakNudgeTime) as String?;
    } catch (_) {}
    final t = parseTime(raw ?? '20:00') ?? (hour: 20, minute: 0);
    final now = tz.TZDateTime.now(tz.local);
    var at = tz.TZDateTime(tz.local, now.year, now.month, now.day, t.hour, t.minute);
    if (!at.isAfter(now)) at = at.add(const Duration(days: 1));
    try {
      await _plugin.zonedSchedule(
        streakNudgeId,
        'Your streak is waiting',
        "Haven't checked anything off today? Do one now to keep your streak alive.",
        at,
        const NotificationDetails(android: _channel),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: 'trackme://quests',
      );
    } catch (e) {
      debugPrint('ReminderService.scheduleStreakNudge failed: $e');
    }
  }
}
