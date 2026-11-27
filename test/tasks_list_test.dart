import 'dart:io';

import 'package:flutter/services.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:ticklist/data/task_store.dart';
import 'package:ticklist/models/task.dart';
import 'package:ticklist/services/pro_service.dart';
import 'package:ticklist/ui/root_shell.dart';
import 'package:ticklist/ui/tasks_screen.dart';
import 'package:ticklist/ui/theme.dart';
import 'package:ticklist/util/dates.dart';
import 'package:ticklist/util/quick_parse.dart';

Future<TaskStore> _store() async {
  final dir = await Directory.systemTemp.createTemp('tl');
  final s = TaskStore(fileOverride: File('${dir.path}/d.json'));
  await s.load();
  return s;
}

Widget _wrap(TaskStore s, Widget child) => MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: s),
        ChangeNotifierProvider.value(value: ProService()),
      ],
      child: MaterialApp(theme: buildTheme(Brightness.light, accents[0].$2), home: child),
    );

void main() {
  final today = dateOnly(DateTime.now());

  test('anytime tasks never appear on a day and are never overdue', () async {
    final s = await _store();
    final t = s.addTask(title: 'Renew passport', date: addDays(today, -10), anytime: true);
    expect(s.tasksOn(today), isEmpty);
    expect(s.overdue(), isEmpty);
    expect(s.listOpen().single.id, t.id);
    s.toggleDone(t, today);
    expect(t.isComplete, isTrue);
    expect(s.listOpen(), isEmpty);
    expect(s.listDone().single.id, t.id);
    s.toggleDone(t, today);
    expect(t.isComplete, isFalse);
  });

  test('moving between the list and a day', () async {
    final s = await _store();
    final t = s.addTask(title: 'Fix bike', date: today, repeat: Repeat.daily, remind: true);
    s.moveToList(t);
    expect(t.anytime, isTrue);
    expect(t.repeat, Repeat.none);
    expect(t.remind, isFalse);
    expect(s.tasksOn(today), isEmpty);
    s.moveTo(t, addDays(today, 1));
    expect(t.anytime, isFalse);
    expect(s.tasksOn(addDays(today, 1)).single.id, t.id);
  });

  test('anytime survives save/load and old data defaults to dated', () async {
    final dir = await Directory.systemTemp.createTemp('tl');
    final f = File('${dir.path}/d.json');
    final s = TaskStore(fileOverride: f);
    await s.load();
    s.addTask(title: 'Learn guitar', date: today, anytime: true);
    s.addTask(title: 'Dated', date: today);
    await s.save();
    final r = TaskStore(fileOverride: f);
    await r.load();
    expect(r.listOpen().single.title, 'Learn guitar');
    expect(r.tasksOn(today).single.title, 'Dated');
    expect(Task.fromJson({'id': 'x', 'title': 'old', 'date': '2026-01-01'}).anytime, isFalse);
  });

  test('parser: someday goes to the list, a date wins over someday', () {
    final p = parseQuickAdd('Renew passport someday !high');
    expect(p.title, 'Renew passport');
    expect(p.anytime, isTrue);
    expect(p.priority, Priority.high);
    expect(parseQuickAdd('Call mom someday tomorrow').anytime, isFalse);
    expect(parseQuickAdd('Plan trip #list').anytime, isTrue);
  });

  testWidgets('Tasks screen: quick add, complete, empty state', (t) async {
    t.view.physicalSize = const Size(1170, 4000);
    t.view.devicePixelRatio = 2.5;
    addTearDown(t.view.reset);
    final s = await t.runAsync(_store);
    await t.pumpWidget(_wrap(s!, const TasksScreen()));
    await t.pump(const Duration(seconds: 1));
    expect(find.text('Your list is empty'), findsOneWidget);
    await t.enterText(find.byType(TextField).first, 'Buy a new charger !h');
    await t.testTextInput.receiveAction(TextInputAction.done);
    await t.pump(const Duration(seconds: 1));
    expect(s.listOpen().single.title, 'Buy a new charger');
    expect(s.listOpen().single.priority, Priority.high);
    expect(find.text('Buy a new charger'), findsOneWidget);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 1));
  });

  testWidgets('Root shell switches between Today and Tasks', (t) async {
    t.view.physicalSize = const Size(1170, 4000);
    t.view.devicePixelRatio = 2.5;
    addTearDown(t.view.reset);
    final s = await t.runAsync(_store);
    s!.addTask(title: 'List item', date: today, anytime: true);
    await t.pumpWidget(_wrap(s, const RootShell()));
    await t.pump(const Duration(seconds: 1));
    await t.tap(find.text('Tasks').first);
    await t.pump(const Duration(seconds: 1));
    expect(find.text('My Tasks'), findsOneWidget);
    expect(find.text('List item'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  setUpAll(() async {
    // Use the real app font so overflow checks match the phone.
    final loader = FontLoader('Jakarta');
    for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold']) {
      loader.addFont(rootBundle.load('assets/fonts/PlusJakartaSans-$w.ttf'));
    }
    await loader.load();
  });

  for (final tab in [0, 1]) {
    testWidgets('S24 size + 130% font: tab $tab has no overflow', (t) async {
      t.view.physicalSize = const Size(1080, 2340); // Galaxy S24
      t.view.devicePixelRatio = 2.625;
      addTearDown(t.view.reset);
      final s = await t.runAsync(_store);
      s!.addTask(title: 'A fairly long task title that wraps onto two lines', date: today, priority: Priority.high, tag: 'Work', timeMinutes: 600);
      s.addTask(title: 'Renew passport', date: today, anytime: true, priority: Priority.medium, tag: 'Errands');
      await t.pumpWidget(MediaQuery(
        data: const MediaQueryData(
          size: Size(411.4, 891.4),
          devicePixelRatio: 2.625,
          textScaler: TextScaler.linear(1.3),
        ),
        child: _wrap(s, RootShell(initialTab: tab)),
      ));
      await t.pump(const Duration(seconds: 2));
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 1));
    });
  }
}
