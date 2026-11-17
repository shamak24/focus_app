import 'package:hive/hive.dart';

import '../../../core/storage/hive_fields.dart';

/// A group of tasks: either a built-in preset (a read-only template) or a
/// plan the user owns and can edit.
class Plan {
  const Plan({
    required this.id,
    required this.name,
    required this.colorValue,
    required this.createdAt,
    this.isPreset = false,
    this.defaultFocusMinutes = 25,
    this.description = '',
  });

  final String id;
  final String name;

  /// ARGB colour. Kept as an int so the data layer stays free of Flutter.
  final int colorValue;
  final bool isPreset;
  final int defaultFocusMinutes;
  final String description;
  final DateTime createdAt;

  Plan copyWith({
    String? id,
    String? name,
    int? colorValue,
    bool? isPreset,
    int? defaultFocusMinutes,
    String? description,
    DateTime? createdAt,
  }) => Plan(
    id: id ?? this.id,
    name: name ?? this.name,
    colorValue: colorValue ?? this.colorValue,
    isPreset: isPreset ?? this.isPreset,
    defaultFocusMinutes: defaultFocusMinutes ?? this.defaultFocusMinutes,
    description: description ?? this.description,
    createdAt: createdAt ?? this.createdAt,
  );
}

class PlanAdapter extends TypeAdapter<Plan> {
  @override
  final int typeId = 1;

  @override
  Plan read(BinaryReader reader) {
    final f = readFields(reader);
    return Plan(
      id: f[0] as String,
      name: f[1] as String,
      colorValue: f[2] as int,
      isPreset: f[3] as bool? ?? false,
      defaultFocusMinutes: f[4] as int? ?? 25,
      description: f[5] as String? ?? '',
      createdAt: f[6] as DateTime? ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  @override
  void write(BinaryWriter writer, Plan obj) => writeFields(writer, [
    obj.id,
    obj.name,
    obj.colorValue,
    obj.isPreset,
    obj.defaultFocusMinutes,
    obj.description,
    obj.createdAt,
  ]);
}
