import '../util/dates.dart';

enum Priority { none, low, medium, high }

extension PriorityX on Priority {
  String get label => switch (this) {
        Priority.none => 'None',
        Priority.low => 'Low',
        Priority.medium => 'Medium',
        Priority.high => 'High',
      };
}

enum Repeat { none, daily, weekdays, weekly }

extension RepeatX on Repeat {
  String get label => switch (this) {
        Repeat.none => 'Never',
        Repeat.daily => 'Every day',
        Repeat.weekdays => 'Weekdays',
        Repeat.weekly => 'Weekly',
      };
}

class Subtask {
  Subtask({required this.id, required this.title, this.done = false});
  final String id;
  String title;
  bool done;

  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'done': done};
  factory Subtask.fromJson(Map<String, dynamic> j) => Subtask(
        id: j['id'] as String,
        title: j['title'] as String? ?? '',
        done: j['done'] as bool? ?? false,
      );
}

class Task {
  Task({
    required this.id,
    required this.title,
    required this.date,
    required this.notificationId,
    this.notes = '',
    this.priority = Priority.none,
    this.timeMinutes,
    this.tag,
    this.repeat = Repeat.none,
    this.remind = false,
    List<Subtask>? subtasks,
    Set<String>? doneDays,
    Map<String, int>? focus,
    DateTime? createdAt,
  })  : subtasks = subtasks ?? [],
        doneDays = doneDays ?? <String>{},
        focus = focus ?? <String, int>{},
        createdAt = createdAt ?? DateTime.now();

  final String id;
  String title;
  String notes;
  Priority priority;

  /// The day the task is planned for (start day for repeating tasks).
  DateTime date;

  /// Optional time of day, minutes after midnight.
  int? timeMinutes;
  String? tag;
  Repeat repeat;
  bool remind;
  final int notificationId;
  final List<Subtask> subtasks;

  /// Days (dayKey) on which this task was completed.
  final Set<String> doneDays;

  /// Focus-timer minutes logged per day (dayKey → minutes).
  final Map<String, int> focus;
  final DateTime createdAt;

  int focusOn(DateTime day) => focus[dayKey(day)] ?? 0;

  bool occursOn(DateTime day) {
    final d = dateOnly(day), start = dateOnly(date);
    switch (repeat) {
      case Repeat.none:
        return isSameDay(d, start);
      case Repeat.daily:
        return !d.isBefore(start);
      case Repeat.weekdays:
        return !d.isBefore(start) && d.weekday <= 5;
      case Repeat.weekly:
        return !d.isBefore(start) && d.weekday == start.weekday;
    }
  }

  bool isDoneOn(DateTime day) => doneDays.contains(dayKey(day));

  void setDone(DateTime day, bool done) {
    final k = dayKey(day);
    done ? doneDays.add(k) : doneDays.remove(k);
  }

  /// A one-off task from an earlier day that was never completed.
  bool isOverdue(DateTime today) =>
      repeat == Repeat.none &&
      dateOnly(date).isBefore(dateOnly(today)) &&
      !isDoneOn(date);

  int get subtasksDone => subtasks.where((s) => s.done).length;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'notes': notes,
        'priority': priority.name,
        'date': dayKey(date),
        'time': timeMinutes,
        'tag': tag,
        'repeat': repeat.name,
        'remind': remind,
        'nid': notificationId,
        'subtasks': subtasks.map((s) => s.toJson()).toList(),
        'done': doneDays.toList()..sort(),
        if (focus.isNotEmpty) 'focus': focus,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Task.fromJson(Map<String, dynamic> j) => Task(
        id: j['id'] as String,
        title: j['title'] as String? ?? '',
        notes: j['notes'] as String? ?? '',
        priority: Priority.values.firstWhere((p) => p.name == j['priority'],
            orElse: () => Priority.none),
        date: parseDayKey(j['date'] as String? ?? '') ?? dateOnly(DateTime.now()),
        timeMinutes: (j['time'] as num?)?.toInt(),
        tag: j['tag'] as String?,
        repeat: Repeat.values.firstWhere((r) => r.name == j['repeat'],
            orElse: () => Repeat.none),
        remind: j['remind'] as bool? ?? false,
        notificationId: (j['nid'] as num?)?.toInt() ?? 1,
        subtasks: ((j['subtasks'] as List?) ?? const [])
            .map((e) => Subtask.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        doneDays: ((j['done'] as List?) ?? const []).cast<String>().toSet(),
        focus: ((j['focus'] as Map?) ?? const {}).map(
            (k, v) => MapEntry(k as String, (v as num?)?.toInt() ?? 0)),
        createdAt: DateTime.tryParse(j['createdAt'] as String? ?? ''),
      );
}

/// Built-in tags with an emoji and a colour index into [tagColors].
class TagDef {
  const TagDef(this.name, this.emoji, this.color);
  final String name;
  final String emoji;
  final int color;
}

const builtInTags = [
  TagDef('Work', '💼', 0),
  TagDef('Personal', '🌿', 1),
  TagDef('Health', '💪', 2),
  TagDef('Study', '📚', 3),
  TagDef('Errands', '🛒', 4),
  TagDef('Home', '🏠', 5),
];

TagDef? tagByName(String? n) {
  for (final t in builtInTags) {
    if (t.name == n) return t;
  }
  return null;
}
