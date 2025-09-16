String two(int n) => n.toString().padLeft(2, '0');

/// Klucz dnia w lokalnym czasie (YYYY-MM-DD)
String dayKey(DateTime dt) => '${dt.year}-${two(dt.month)}-${two(dt.day)}';

/// Format HH:mm  YYYY-MM-DD
String fmtDateTimePretty(DateTime d) =>
    '${two(d.hour)}:${two(d.minute)}  ${d.year}-${two(d.month)}-${two(d.day)}';

/// Format czasu trwania w godzinach i minutach
String fmtDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  return '${h}h ${two(m)}m';
}
