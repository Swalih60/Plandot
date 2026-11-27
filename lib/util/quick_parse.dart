import '../models/task.dart';
import 'dates.dart';

/// Result of parsing a natural-language quick-add line such as
/// "Call mom tomorrow 5pm !high #personal".
class ParsedTask {
  ParsedTask({
    required this.title,
    this.date,
    this.timeMinutes,
    this.priority,
    this.tag,
    this.anytime = false,
  });
  final String title;

  /// "someday" / "anytime": goes to the Tasks list, not a particular day.
  final bool anytime;
  final DateTime? date;
  final int? timeMinutes;
  final Priority? priority;
  final String? tag;

  bool get hasTokens =>
      date != null ||
      timeMinutes != null ||
      priority != null ||
      tag != null ||
      anytime;
}

const _weekdays = {
  'mon': 1, 'monday': 1, 'tue': 2, 'tues': 2, 'tuesday': 2, //
  'wed': 3, 'wednesday': 3, 'thu': 4, 'thur': 4, 'thurs': 4, 'thursday': 4,
  'fri': 5, 'friday': 5, 'sat': 6, 'saturday': 6, 'sun': 7, 'sunday': 7,
};

ParsedTask parseQuickAdd(String input, {DateTime? now}) {
  final today = dateOnly(now ?? DateTime.now());
  final words = input.trim().split(RegExp(r'\s+'));
  final kept = <String>[];
  DateTime? date;
  int? time;
  Priority? priority;
  String? tag;
  var anytime = false;

  for (var i = 0; i < words.length; i++) {
    final raw = words[i];
    final w = raw.toLowerCase();
    if (w.isEmpty) continue;

    // Priority: !high !h !!! !med !m !! !low !l !
    if (w.startsWith('!')) {
      final p = switch (w) {
        '!high' || '!h' || '!!!' || '!1' => Priority.high,
        '!medium' || '!med' || '!m' || '!!' || '!2' => Priority.medium,
        '!low' || '!l' || '!' || '!3' => Priority.low,
        _ => null,
      };
      if (p != null) {
        priority = p;
        continue;
      }
    }

    // Tag: #work
    if (w.startsWith('#') && w.length > 1 && w != '#list') {
      final name = w.substring(1);
      for (final t in builtInTags) {
        if (t.name.toLowerCase() == name) tag = t.name;
      }
      if (tag != null) continue;
    }

    // No particular day -> Tasks list
    if (w == 'someday' || w == 'anytime' || w == '#list') {
      anytime = true;
      continue;
    }

    // Dates
    if (w == 'today' || w == 'tonight') {
      date = today;
      if (w == 'tonight' && time == null) time = 20 * 60;
      continue;
    }
    if (w == 'tomorrow' || w == 'tmrw' || w == 'tmr') {
      date = addDays(today, 1);
      continue;
    }
    if (_weekdays.containsKey(w)) {
      // "on friday" -> next occurrence (today counts if it matches? no: next)
      final target = _weekdays[w]!;
      var diff = (target - today.weekday) % 7;
      if (diff == 0) diff = 7;
      date = addDays(today, diff);
      if (kept.isNotEmpty && kept.last.toLowerCase() == 'on') kept.removeLast();
      continue;
    }

    // Times: 5pm, 5:30pm, 17:30, "at 5"
    final t = _parseTime(w);
    if (t != null) {
      time = t;
      if (kept.isNotEmpty && kept.last.toLowerCase() == 'at') kept.removeLast();
      continue;
    }
    if (w == 'at' && i + 1 < words.length) {
      final n = int.tryParse(words[i + 1]);
      if (n != null && n >= 1 && n <= 12) {
        // "at 5" -> assume afternoon for 1-7, morning otherwise
        time = (n == 12 ? 12 : (n <= 7 ? n + 12 : n)) * 60;
        i++;
        continue;
      }
    }

    kept.add(raw);
  }

  return ParsedTask(
    title: kept.join(' ').trim(),
    date: date,
    timeMinutes: time,
    priority: priority,
    tag: tag,
    anytime: anytime && date == null,
  );
}

int? _parseTime(String w) {
  final m = RegExp(r'^(\d{1,2})(?::(\d{2}))?(am|pm)$').firstMatch(w);
  if (m != null) {
    var h = int.parse(m.group(1)!);
    final min = int.parse(m.group(2) ?? '0');
    if (h < 1 || h > 12 || min > 59) return null;
    if (m.group(3) == 'pm' && h != 12) h += 12;
    if (m.group(3) == 'am' && h == 12) h = 0;
    return h * 60 + min;
  }
  final m24 = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(w);
  if (m24 != null) {
    final h = int.parse(m24.group(1)!), min = int.parse(m24.group(2)!);
    if (h > 23 || min > 59) return null;
    return h * 60 + min;
  }
  return null;
}
