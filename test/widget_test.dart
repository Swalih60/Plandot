import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ticklist/data/task_store.dart';
import 'package:ticklist/models/task.dart';
import 'package:ticklist/util/dates.dart';
import 'package:ticklist/util/quick_parse.dart';

void main() {
  final now = DateTime(2026, 11, 21); // Saturday

  group('quick add parser', () {
    test('date, time, priority and tag', () {
      final p = parseQuickAdd('Call mom tomorrow 5pm !high #personal', now: now);
      expect(p.title, 'Call mom');
      expect(p.date, DateTime(2026, 11, 22));
      expect(p.timeMinutes, 17 * 60);
      expect(p.priority, Priority.high);
      expect(p.tag, 'Personal');
    });
    test('"at 7:30am on friday"', () {
      final p = parseQuickAdd('Standup at 7:30am on friday !m', now: now);
      expect(p.title, 'Standup');
      expect(p.date, DateTime(2026, 11, 27));
      expect(p.timeMinutes, 7 * 60 + 30);
      expect(p.priority, Priority.medium);
    });
    test('plain text stays untouched', () {
      final p = parseQuickAdd('Buy milk', now: now);
      expect(p.title, 'Buy milk');
      expect(p.hasTokens, isFalse);
    });
    test('tonight sets 8pm', () {
      final p = parseQuickAdd('Read 20 min tonight !low', now: now);
      expect(p.title, 'Read 20 min');
      expect(p.timeMinutes, 20 * 60);
      expect(p.priority, Priority.low);
    });
  });

  group('recurrence', () {
    Task make(Repeat r) => Task(
        id: 'x', title: 't', date: DateTime(2026, 11, 16), notificationId: 1, repeat: r);
    test('weekdays skips weekend', () {
      final t = make(Repeat.weekdays);
      expect(t.occursOn(DateTime(2026, 11, 20)), isTrue); // Fri
      expect(t.occursOn(DateTime(2026, 11, 21)), isFalse); // Sat
      expect(t.occursOn(DateTime(2026, 11, 13)), isFalse); // before start
    });
    test('weekly on same weekday', () {
      final t = make(Repeat.weekly);
      expect(t.occursOn(DateTime(2026, 11, 23)), isTrue);
      expect(t.occursOn(DateTime(2026, 11, 24)), isFalse);
    });
    test('completion is per day for repeating tasks', () {
      final t = make(Repeat.daily)..setDone(now, true);
      expect(t.isDoneOn(now), isTrue);
      expect(t.isDoneOn(addDays(now, 1)), isFalse);
    });
  });

  test('store: sorting, overdue, persistence', () async {
    final dir = await Directory.systemTemp.createTemp('tl');
    final f = File('${dir.path}/d.json');
    final s = TaskStore(fileOverride: f);
    await s.load();
    final today = dateOnly(DateTime.now());
    s.addTask(title: 'low', date: today, priority: Priority.low);
    s.addTask(title: 'high', date: today, priority: Priority.high);
    final old = s.addTask(title: 'old', date: addDays(today, -2));
    expect(s.tasksOn(today).map((t) => t.title), ['high', 'low']);
    expect(s.overdue().single.title, 'old');
    expect(s.moveOverdueToToday(), 1);
    expect(old.date, today);
    s.setDayNote(today, 'hello');
    await s.save();
    final r = TaskStore(fileOverride: f);
    await r.load();
    expect(r.allTasks.length, 3);
    expect(r.dayNote(today), 'hello');
    await dir.delete(recursive: true);
  });

  group('focus minutes', () {
    test('logged per task per day and persisted', () async {
      final dir = await Directory.systemTemp.createTemp('tl');
      final f = File('${dir.path}/d.json');
      final s = TaskStore(fileOverride: f);
      await s.load();
      final today = dateOnly(DateTime.now());
      final a = s.addTask(title: 'write', date: today);
      final b = s.addTask(title: 'read', date: today);
      s.addFocusMinutes(a, today, 25);
      s.addFocusMinutes(a, today, 10);
      s.addFocusMinutes(b, addDays(today, -2), 45);
      s.addFocusMinutes(b, today, 0); // ignored
      expect(a.focusOn(today), 35);
      expect(s.focusMinutesOn(today), 35);
      expect(s.focusMinutesBetween(addDays(today, -6), today), 80);
      await s.save();
      final r = TaskStore(fileOverride: f);
      await r.load();
      expect(r.byId(a.id)!.focusOn(today), 35);
      expect(r.byId(b.id)!.focusOn(addDays(today, -2)), 45);
      expect(r.focusMinutesBetween(addDays(today, -6), today), 80);
      await dir.delete(recursive: true);
    });

    test('old tasks without focus field load fine', () {
      final t = Task.fromJson({'id': 'x', 'title': 'legacy', 'date': '2026-11-21'});
      expect(t.focus, isEmpty);
      expect(t.focusOn(DateTime(2026, 11, 21)), 0);
      expect(t.toJson().containsKey('focus'), isFalse);
      final back = Task.fromJson(
          (t..focus['2026-11-21'] = 15).toJson().cast<String, dynamic>());
      expect(back.focusOn(DateTime(2026, 11, 21)), 15);
    });
  });
}
