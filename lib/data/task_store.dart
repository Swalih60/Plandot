import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/task.dart';
import '../util/dates.dart';

enum AppThemeMode { system, light, dark }

enum TaskFilter { all, high, medium, low }

/// All app data, persisted to a local JSON file. No servers, no accounts.
class TaskStore extends ChangeNotifier {
  TaskStore({this.fileOverride});
  final File? fileOverride;

  final List<Task> _tasks = [];
  final Map<String, String> _dayNotes = {};
  bool onboarded = false;
  bool loaded = false;
  AppThemeMode themeMode = AppThemeMode.system;
  int accent = 0;
  bool mondayFirst = true;
  bool soundsOn = true;
  bool paywallSeen = false;

  /// Home screen shows the hour timeline instead of the list (Pro).
  bool timelineView = false;
  int _nextNid = 1;

  List<Task> get allTasks => List.unmodifiable(_tasks);

  Task? byId(String id) {
    for (final t in _tasks) {
      if (t.id == id) return t;
    }
    return null;
  }

  // ---------- Queries ----------

  static int _priorityThenTime(Task a, Task b) {
    final p = b.priority.index.compareTo(a.priority.index);
    if (p != 0) return p;
    final ta = a.timeMinutes ?? 24 * 60, tb = b.timeMinutes ?? 24 * 60;
    if (ta != tb) return ta.compareTo(tb);
    return a.createdAt.compareTo(b.createdAt);
  }

  bool _matches(Task t, TaskFilter f) => switch (f) {
    TaskFilter.all => true,
    TaskFilter.high => t.priority == Priority.high,
    TaskFilter.medium => t.priority == Priority.medium,
    TaskFilter.low => t.priority == Priority.low,
  };

  List<Task> tasksOn(DateTime day, {TaskFilter filter = TaskFilter.all}) =>
      _tasks.where((t) => t.occursOn(day) && _matches(t, filter)).toList()
        ..sort(_priorityThenTime);

  List<Task> openOn(DateTime day, {TaskFilter filter = TaskFilter.all}) =>
      tasksOn(day, filter: filter).where((t) => !t.isDoneOn(day)).toList();

  List<Task> doneOn(DateTime day, {TaskFilter filter = TaskFilter.all}) =>
      tasksOn(day, filter: filter).where((t) => t.isDoneOn(day)).toList();

  List<Task> overdue({TaskFilter filter = TaskFilter.all}) {
    final today = dateOnly(DateTime.now());
    return _tasks
        .where((t) => t.isOverdue(today) && _matches(t, filter))
        .toList()
      ..sort(_priorityThenTime);
  }

  /// (done, total) for a day — drives the progress ring and week strip.
  (int, int) progressOn(DateTime day) {
    final list = tasksOn(day);
    return (list.where((t) => t.isDoneOn(day)).length, list.length);
  }

  List<Task> search(String q) {
    final s = q.trim().toLowerCase();
    if (s.isEmpty) return const [];
    return _tasks
        .where(
          (t) =>
              t.title.toLowerCase().contains(s) ||
              t.notes.toLowerCase().contains(s) ||
              (t.tag ?? '').toLowerCase().contains(s) ||
              t.subtasks.any((x) => x.title.toLowerCase().contains(s)),
        )
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  /// Consecutive days (ending today or yesterday) where every task was done.
  int perfectDayStreak() {
    var day = dateOnly(DateTime.now());
    final (d0, t0) = progressOn(day);
    if (t0 == 0 || d0 < t0) day = addDays(day, -1);
    var streak = 0;
    for (var i = 0; i < 3650; i++) {
      final (d, t) = progressOn(day);
      if (t == 0) {
        day = addDays(day, -1);
        if (i > 60 && streak == 0) break;
        continue; // empty days don't break a streak
      }
      if (d < t) break;
      streak++;
      day = addDays(day, -1);
    }
    return streak;
  }

  String dayNote(DateTime day) => _dayNotes[dayKey(day)] ?? '';

  /// Focus minutes logged across all tasks on [day].
  int focusMinutesOn(DateTime day) =>
      _tasks.fold<int>(0, (s, t) => s + t.focusOn(day));

  /// Focus minutes logged from [from] to [to], both days inclusive.
  int focusMinutesBetween(DateTime from, DateTime to) {
    var sum = 0;
    for (var d = dateOnly(from); !d.isAfter(dateOnly(to)); d = addDays(d, 1)) {
      sum += focusMinutesOn(d);
    }
    return sum;
  }

  // ---------- Mutations ----------

  Task addTask({
    required String title,
    required DateTime date,
    String notes = '',
    Priority priority = Priority.none,
    int? timeMinutes,
    String? tag,
    Repeat repeat = Repeat.none,
    bool remind = false,
    bool anytime = false,
    List<Subtask>? subtasks,
  }) {
    final t = Task(
      anytime: anytime,
      id: newId(),
      title: title,
      date: dateOnly(date),
      notes: notes,
      priority: priority,
      timeMinutes: timeMinutes,
      tag: tag,
      repeat: anytime ? Repeat.none : repeat,
      remind: anytime ? false : remind,
      subtasks: subtasks,
      notificationId: _nextNid++,
    );
    _tasks.add(t);
    _changed();
    return t;
  }

  /// Re-insert a task (used by undo after delete).
  void restore(Task t) {
    _tasks.add(t);
    _changed();
  }

  void update(Task t) => _changed();

  void delete(Task t) {
    _tasks.removeWhere((x) => x.id == t.id);
    _changed();
  }

  void toggleDone(Task t, DateTime day) {
    if (t.anytime) {
      // Done once: record today (the day it was finished) or reopen it.
      t.isComplete ? t.doneDays.clear() : t.setDone(DateTime.now(), true);
    } else {
      t.setDone(day, !t.isDoneOn(day));
    }
    _changed();
  }

  void toggleSubtask(Task t, Subtask s) {
    s.done = !s.done;
    _changed();
  }

  /// Logs [minutes] of focus time for [t] on [day].
  void addFocusMinutes(Task t, DateTime day, int minutes) {
    if (minutes <= 0) return;
    final k = dayKey(day);
    t.focus[k] = (t.focus[k] ?? 0) + minutes;
    _changed();
  }

  /// Plans [t] on [day]. An anytime task leaves the Tasks list.
  void moveTo(Task t, DateTime day) {
    if (t.anytime) {
      t.anytime = false;
      t.doneDays.clear();
    }
    t.date = dateOnly(day);
    _changed();
  }

  /// Sends [t] to the Tasks list (no particular day).
  void moveToList(Task t) {
    t
      ..anytime = true
      ..repeat = Repeat.none
      ..remind = false
      ..doneDays.clear();
    _changed();
  }

  // ---------- Tasks list (anytime) ----------

  List<Task> listOpen({TaskFilter filter = TaskFilter.all}) =>
      _tasks
          .where((t) => t.anytime && !t.isComplete && _matches(t, filter))
          .toList()
        ..sort(_priorityThenTime);

  List<Task> listDone({TaskFilter filter = TaskFilter.all}) =>
      _tasks
          .where((t) => t.anytime && t.isComplete && _matches(t, filter))
          .toList()
        ..sort(
          (a, b) => (b.completedOn ?? b.createdAt).compareTo(
            a.completedOn ?? a.createdAt,
          ),
        );

  int get listOpenCount =>
      _tasks.where((t) => t.anytime && !t.isComplete).length;

  /// Moves every overdue task to today. Returns how many moved.
  int moveOverdueToToday() {
    final list = overdue();
    final today = dateOnly(DateTime.now());
    for (final t in list) {
      t.date = today;
    }
    if (list.isNotEmpty) _changed();
    return list.length;
  }

  void setDayNote(DateTime day, String text) {
    final k = dayKey(day);
    text.trim().isEmpty ? _dayNotes.remove(k) : _dayNotes[k] = text;
    _changed();
  }

  void completeOnboarding() {
    onboarded = true;
    _changed();
  }

  void markPaywallSeen() {
    paywallSeen = true;
    _changed();
  }

  void setThemeMode(AppThemeMode m) {
    themeMode = m;
    _changed();
  }

  void setAccent(int i) {
    accent = i;
    _changed();
  }

  void setTimelineView(bool v) {
    timelineView = v;
    _changed();
  }

  void setSoundsOn(bool v) {
    soundsOn = v;
    _changed();
  }

  void setMondayFirst(bool v) {
    mondayFirst = v;
    _changed();
  }

  static String newId() =>
      '${DateTime.now().microsecondsSinceEpoch}${Random().nextInt(99999)}';

  // ---------- Persistence ----------

  Future<File> _file() async {
    if (fileOverride != null) return fileOverride!;
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/ticklist.json');
  }

  Future<void> load() async {
    try {
      final f = await _file();
      final src = await f.exists() ? f : File('${f.path}.bak');
      if (await src.exists()) {
        _apply(jsonDecode(await src.readAsString()) as Map<String, dynamic>);
      }
    } catch (e) {
      debugPrint('TaskStore load failed: $e');
    }
    loaded = true;
    notifyListeners();
  }

  void _apply(Map<String, dynamic> j) {
    _tasks
      ..clear()
      ..addAll(
        ((j['tasks'] as List?) ?? const []).map(
          (e) => Task.fromJson(Map<String, dynamic>.from(e as Map)),
        ),
      );
    _dayNotes
      ..clear()
      ..addAll(
        ((j['dayNotes'] as Map?) ?? const {}).map(
          (k, v) => MapEntry(k as String, v as String),
        ),
      );
    final s = Map<String, dynamic>.from((j['settings'] as Map?) ?? const {});
    onboarded = s['onboarded'] as bool? ?? onboarded;
    themeMode = AppThemeMode.values.firstWhere(
      (m) => m.name == s['theme'],
      orElse: () => AppThemeMode.system,
    );
    accent = (s['accent'] as num?)?.toInt() ?? 0;
    mondayFirst = s['mondayFirst'] as bool? ?? true;
    soundsOn = s['sounds'] as bool? ?? true;
    paywallSeen = s['paywallSeen'] as bool? ?? false;
    timelineView = s['timelineView'] as bool? ?? false;
    _nextNid = _tasks.fold<int>(0, (m, t) => max(m, t.notificationId)) + 1;
  }

  Map<String, dynamic> toJson() => {
    'app': 'ticklist',
    'version': 1,
    'exportedAt': DateTime.now().toIso8601String(),
    'settings': {
      'onboarded': onboarded,
      'theme': themeMode.name,
      'accent': accent,
      'mondayFirst': mondayFirst,
      'sounds': soundsOn,
      'paywallSeen': paywallSeen,
      'timelineView': timelineView,
    },
    'dayNotes': _dayNotes,
    'tasks': _tasks.map((t) => t.toJson()).toList(),
  };

  Future<void>? _pending;
  bool _dirty = false;

  Future<void> save() async {
    _dirty = true;
    if (_pending != null) return _pending;
    _pending = () async {
      while (_dirty) {
        _dirty = false;
        try {
          final f = await _file();
          final tmp = File('${f.path}.tmp');
          await tmp.writeAsString(jsonEncode(toJson()), flush: true);
          if (await f.exists()) await f.copy('${f.path}.bak');
          await tmp.rename(f.path);
        } catch (e) {
          debugPrint('TaskStore save failed: $e');
        }
      }
    }();
    await _pending;
    _pending = null;
  }

  void _changed() {
    notifyListeners();
    save();
  }

  String exportJson() => const JsonEncoder.withIndent(' ').convert(toJson());

  Future<int> importJson(String text) async {
    final d = jsonDecode(text);
    if (d is! Map || d['app'] != 'ticklist') {
      throw const FormatException('This file is not a Plandot backup.');
    }
    final was = onboarded;
    _apply(Map<String, dynamic>.from(d));
    onboarded = was || onboarded;
    _changed();
    return _tasks.length;
  }
}
