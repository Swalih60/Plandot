DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Calendar-safe day arithmetic (immune to DST hour shifts).
DateTime addDays(DateTime d, int n) => DateTime(d.year, d.month, d.day + n);

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String _two(int n) => n.toString().padLeft(2, '0');

String dayKey(DateTime d) => '${d.year}-${_two(d.month)}-${_two(d.day)}';

DateTime? parseDayKey(String k) {
  final p = k.split('-');
  if (p.length != 3) return null;
  final y = int.tryParse(p[0]), m = int.tryParse(p[1]), d = int.tryParse(p[2]);
  if (y == null || m == null || d == null) return null;
  return DateTime(y, m, d);
}

/// Start of the week containing [d]. [mondayFirst] picks Monday or Sunday.
DateTime startOfWeek(DateTime d, {bool mondayFirst = true}) {
  final day = dateOnly(d);
  final offset = mondayFirst ? (day.weekday - 1) : (day.weekday % 7);
  return addDays(day, -offset);
}

const weekdayShort = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const weekdayLetter = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

String formatMinutes(int minutes) {
  final h = minutes ~/ 60, m = minutes % 60;
  final h12 = h % 12 == 0 ? 12 : h % 12;
  return '$h12:${_two(m)} ${h < 12 ? 'AM' : 'PM'}';
}
