/// Small date helpers. All of them work on local calendar days.
library;

DateTime dayOf(DateTime t) => DateTime(t.year, t.month, t.day);

bool isSameDay(DateTime? a, DateTime? b) =>
    a != null && b != null && a.year == b.year && a.month == b.month && a.day == b.day;

/// Whole calendar days from [from] to [to]. Negative when [to] is earlier.
/// Uses UTC dates so daylight-saving shifts never produce 23 or 25 hour days.
int daysBetween(DateTime from, DateTime to) => DateTime.utc(
  to.year,
  to.month,
  to.day,
).difference(DateTime.utc(from.year, from.month, from.day)).inDays;

DateTime addDays(DateTime t, int days) =>
    DateTime(t.year, t.month, t.day + days, t.hour, t.minute, t.second);

/// Monday of the week containing [t], at midnight.
DateTime startOfWeek(DateTime t) => DateTime(t.year, t.month, t.day - (t.weekday - 1));

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String weekdayShort(DateTime t) => _weekdays[t.weekday - 1];

String formatClock(DateTime t) {
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final m = t.minute.toString().padLeft(2, '0');
  return '$h:$m ${t.hour < 12 ? 'AM' : 'PM'}';
}

String formatMinuteOfDay(int minuteOfDay) =>
    formatClock(DateTime(2000, 1, 1, minuteOfDay ~/ 60, minuteOfDay % 60));

/// "Today 6:00 PM", "Tomorrow", "Mon 6:00 PM", "12 Mar".
String formatDeadline(DateTime deadline, DateTime now) {
  final days = daysBetween(now, deadline);
  final time = formatClock(deadline);
  if (days == 0) return 'Today $time';
  if (days == 1) return 'Tomorrow $time';
  if (days == -1) return 'Yesterday';
  if (days > 1 && days < 7) return '${weekdayShort(deadline)} $time';
  final sameYear = deadline.year == now.year;
  return '${deadline.day} ${_months[deadline.month - 1]}${sameYear ? '' : ' ${deadline.year}'}';
}

/// "1h 25m", "40m", "0m".
String formatDuration(int seconds) {
  final minutes = seconds ~/ 60;
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h == 0) return '${m}m';
  return m == 0 ? '${h}h' : '${h}h ${m}m';
}

/// "24:59" countdown text. Hours are folded into minutes ("90:00").
String formatCountdown(int seconds) {
  final s = seconds < 0 ? 0 : seconds;
  return '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
}
