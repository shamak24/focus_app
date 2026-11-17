import 'dart:math';

final _random = Random();
int _counter = 0;

/// Short unique id: time, a per-run counter and a random suffix.
String newId() {
  final time = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
  final count = (_counter++ % 1296).toRadixString(36).padLeft(2, '0');
  final rand = _random.nextInt(1679616).toRadixString(36).padLeft(4, '0');
  return '$time$count$rand';
}
