import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:ticklist/data/task_store.dart';
import 'package:ticklist/models/task.dart';
import 'package:ticklist/services/pro_service.dart';
import 'package:ticklist/ui/focus_screen.dart';
import 'package:ticklist/ui/home_screen.dart';
import 'package:ticklist/ui/onboarding_screen.dart';
import 'package:ticklist/ui/stats_screen.dart';
import 'package:ticklist/ui/settings_screen.dart';
import 'package:ticklist/ui/task_editor.dart';
import 'package:ticklist/ui/theme.dart';
import 'package:ticklist/ui/widgets/timeline_view.dart';
import 'package:ticklist/util/dates.dart';

Future<TaskStore> _store() async {
  final dir = await Directory.systemTemp.createTemp('tl');
  final s = TaskStore(fileOverride: File('${dir.path}/d.json'));
  await s.load();
  final today = dateOnly(DateTime.now());
  s.addTask(title: 'High one', date: today, priority: Priority.high, tag: 'Work',
      timeMinutes: 600, subtasks: [Subtask(id: 'a', title: 'step')]);
  s.addTask(title: 'Low one', date: today, priority: Priority.low, notes: 'n');
  for (var i = 1; i <= 5; i++) {
    s.addTask(title: 'Old $i', date: addDays(today, -i));
  }
  s.toggleDone(s.tasksOn(today).last, today);
  s.completeOnboarding();
  return s;
}

Widget _wrap(TaskStore s, Widget child,
        {Brightness b = Brightness.light, ProService? pro}) =>
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: s),
        ChangeNotifierProvider.value(value: pro ?? ProService()),
      ],
      child: MaterialApp(theme: buildTheme(b, accents[0].$2), home: child),
    );

void main() {
  for (final b in Brightness.values) {
    testWidgets('home renders ($b)', (t) async {
      t.view.physicalSize = const Size(1170, 5000);
      t.view.devicePixelRatio = 2.5;
      addTearDown(t.view.reset);
      final s = await t.runAsync(_store);
      await t.pumpWidget(_wrap(s!, const HomeScreen(), b: b));
      await t.pump(const Duration(seconds: 2));
      expect(find.textContaining('more'), findsOneWidget); // overdue collapsed
      expect(find.text('High one'), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  }

  testWidgets('editor opens, parses and saves', (t) async {
    final s = await t.runAsync(_store);
    await t.pumpWidget(_wrap(s!, Builder(
      builder: (c) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () => showTaskEditor(c, day: DateTime.now()),
            child: const Text('open'),
          ),
        ),
      ),
    )));
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField).first, 'Gym tomorrow 7am !high #health');
    await t.pumpAndSettle();
    expect(find.textContaining('7:00 AM'), findsWidgets);
    await t.tap(find.text('More options'));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    await t.ensureVisible(find.text('Add task'));
    await t.tap(find.text('Add task'));
    await t.pumpAndSettle();
    final gym = s.allTasks.firstWhere((x) => x.title == 'Gym');
    expect(gym.priority, Priority.high);
    expect(gym.tag, 'Health');
    expect(gym.timeMinutes, 7 * 60);
  });

  testWidgets('stats, settings, onboarding render', (t) async {
    final s = await t.runAsync(_store);
    for (final w in [const StatsScreen(), const SettingsScreen(), const OnboardingScreen()]) {
      await t.pumpWidget(_wrap(s!, w));
      await t.pump(const Duration(seconds: 2));
      expect(t.takeException(), isNull);
    }
  });

  // Many short frames, so tickers (scroll-to-now, entrances) actually run.
  // pumpAndSettle can't be used: the focus ring and now-dot pulse forever.
  Future<void> frames(WidgetTester t, [int n = 20]) async {
    for (var i = 0; i < n; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
  }

  void tall(WidgetTester t) {
    t.view.physicalSize = const Size(1170, 5000);
    t.view.devicePixelRatio = 2.5;
    addTearDown(t.view.reset);
  }

  for (final b in Brightness.values) {
    testWidgets('focus screen runs, pauses and stops ($b)', (t) async {
      // iPhone SE size: the full-screen layout must fit without overflow.
      t.view.physicalSize = const Size(750, 1334);
      t.view.devicePixelRatio = 2;
      addTearDown(t.view.reset);
      final s = await t.runAsync(_store);
      final task = s!.tasksOn(DateTime.now()).first;
      await t.pumpWidget(_wrap(s, FocusScreen(task: task, day: DateTime.now()), b: b));
      await frames(t, 10);
      expect(find.text('25:00'), findsOneWidget);
      await t.tap(find.text('45 min', findRichText: true));
      await frames(t, 10);
      expect(find.text('45:00'), findsOneWidget);
      await t.tap(find.byKey(const Key('focus-play')));
      for (var i = 0; i < 10; i++) {
        await t.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('Paused'), findsNothing);
      await t.tap(find.byKey(const Key('focus-play')));
      await frames(t, 10);
      expect(find.text('Paused'), findsOneWidget);
      await t.tap(find.byKey(const Key('focus-stop')));
      await frames(t, 10);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    });
  }

  for (final b in Brightness.values) {
    testWidgets('home timeline renders ($b)', (t) async {
      tall(t);
      final s = await t.runAsync(_store);
      final today = dateOnly(DateTime.now());
      // Overlapping and early tasks exercise the column layout.
      s!.addTask(title: 'Clash', date: today, timeMinutes: 610, priority: Priority.medium);
      s.addTask(title: 'Early', date: today, timeMinutes: 5 * 60 + 30);
      s.setTimelineView(true);
      final pro = ProService()..toggleDebugPro();
      await t.pumpWidget(_wrap(s, const HomeScreen(), b: b, pro: pro));
      await frames(t);
      expect(find.byType(DayTimeline), findsOneWidget);
      expect(find.text('High one'), findsOneWidget);
      expect(find.text('Clash'), findsOneWidget);
      expect(find.text('Low one'), findsOneWidget); // anytime strip
      expect(find.text('5 AM'), findsOneWidget); // range grows for early tasks
      expect(t.takeException(), isNull);
      // Tapping a block opens the editor.
      await t.tap(find.text('High one'));
      await frames(t, 10);
      expect(find.text('Edit task'), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  }

  testWidgets('timeline toggle and quick-menu focus', (t) async {
    tall(t);
    final s = await t.runAsync(_store);
    final pro = ProService()..toggleDebugPro();
    await t.pumpWidget(_wrap(s!, const HomeScreen(), pro: pro));
    await frames(t);
    await t.tap(find.byKey(const Key('view-timeline')));
    await frames(t, 10);
    expect(s.timelineView, isTrue);
    expect(find.byType(DayTimeline), findsOneWidget);
    // The timeline scrolled to "now"; go back up to reach the toggle.
    t.state<ScrollableState>(find.byType(Scrollable).first).position.jumpTo(0);
    await frames(t, 5);
    await t.tap(find.byKey(const Key('view-list')));
    await frames(t, 10);
    expect(find.byType(DayTimeline), findsNothing);
    await t.longPress(find.text('High one'));
    await frames(t, 10);
    await t.tap(find.text('Focus'));
    await frames(t, 10);
    expect(find.byType(FocusScreen), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
