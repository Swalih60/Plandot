import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/task.dart' hide Priority;
import '../models/task.dart' as model show Priority;

/// On-device task reminders. No push server.
class Reminders {
  Reminders._();
  static final instance = Reminders._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  Future<void> init() async {
    if (!(Platform.isIOS || Platform.isAndroid)) return;
    try {
      tzdata.initializeTimeZones();
      final info = await FlutterTimezone.getLocalTimezone();
      try {
        tz.setLocalLocation(tz.getLocation(info.identifier));
      } catch (_) {
        tz.setLocalLocation(tz.UTC);
      }
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@drawable/ic_notification'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
      );
      _ready = true;
    } catch (e) {
      debugPrint('Reminders init failed: $e');
    }
  }

  Future<bool> requestPermission() async {
    if (!_ready) return false;
    if (Platform.isAndroid) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >()
              ?.requestNotificationsPermission() ??
          false;
    }
    return await _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >()
            ?.requestPermissions(alert: true, badge: false, sound: true) ??
        false;
  }

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'task_reminders',
      'Task reminders',
      channelDescription: 'Reminders for your planned tasks',
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(),
  );

  Future<void> cancelFor(Task t) async {
    if (!_ready) return;
    for (var i = 0; i <= 7; i++) {
      await _plugin.cancel(id: t.notificationId * 10 + i);
    }
  }

  Future<void> scheduleFor(Task t) async {
    if (!_ready) return;
    await cancelFor(t);
    final m = t.timeMinutes;
    if (!t.remind || m == null) return;
    final now = tz.TZDateTime.now(tz.local);
    final title = t.title;
    final body = t.notes.isNotEmpty
        ? t.notes
        : '${t.priority == model.Priority.high ? '🔴 High priority · ' : ''}Time to get it done.';

    tz.TZDateTime first(DateTime from, {int? weekday}) {
      var x = tz.TZDateTime(
        tz.local,
        from.year,
        from.month,
        from.day,
        m ~/ 60,
        m % 60,
      );
      while (x.isBefore(now) || (weekday != null && x.weekday != weekday)) {
        x = tz.TZDateTime(
          tz.local,
          x.year,
          x.month,
          x.day + 1,
          x.hour,
          x.minute,
        );
      }
      return x;
    }

    Future<void> sched(
      int slot,
      tz.TZDateTime when,
      DateTimeComponents? match,
    ) => _plugin.zonedSchedule(
      id: t.notificationId * 10 + slot,
      scheduledDate: when,
      notificationDetails: _details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      title: title,
      body: body,
      matchDateTimeComponents: match,
    );

    try {
      final start = t.date.isAfter(now) ? t.date : now;
      switch (t.repeat) {
        case Repeat.none:
          final when = tz.TZDateTime(
            tz.local,
            t.date.year,
            t.date.month,
            t.date.day,
            m ~/ 60,
            m % 60,
          );
          if (when.isAfter(now)) await sched(0, when, null);
        case Repeat.daily:
          await sched(0, first(start), DateTimeComponents.time);
        case Repeat.weekdays:
          for (var wd = 1; wd <= 5; wd++) {
            await sched(
              wd,
              first(start, weekday: wd),
              DateTimeComponents.dayOfWeekAndTime,
            );
          }
        case Repeat.weekly:
          await sched(
            0,
            first(start, weekday: t.date.weekday),
            DateTimeComponents.dayOfWeekAndTime,
          );
      }
    } catch (e) {
      debugPrint('Scheduling failed: $e');
    }
  }

  /// Fixed id for the "focus session finished" alert (task ids are nid*10+slot).
  static const _focusId = 2147480000;

  /// Alerts when a focus session ends while the app is in the background.
  Future<void> scheduleFocusEnd(
    DateTime when,
    String title,
    String body,
  ) async {
    if (!_ready || !when.isAfter(DateTime.now())) return;
    try {
      await _plugin.zonedSchedule(
        id: _focusId,
        scheduledDate: tz.TZDateTime.from(when, tz.local),
        notificationDetails: _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        title: title,
        body: body,
      );
    } catch (e) {
      debugPrint('Focus alert failed: $e');
    }
  }

  Future<void> cancelFocusEnd() async {
    if (!_ready) return;
    await _plugin.cancel(id: _focusId);
  }

  Future<void> rescheduleAll(Iterable<Task> tasks) async {
    if (!_ready) return;
    await _plugin.cancelAll();
    for (final t in tasks) {
      await scheduleFor(t);
    }
  }
}
