import 'package:hive/hive.dart';

/// Field-map helpers shared by the hand-written adapters.
///
/// The byte layout (count, then index/value pairs) matches what
/// `hive_generator` produces, so the adapters can be swapped for generated
/// ones later without a data migration. Fields are only ever appended, and
/// readers fall back to defaults for fields an older build did not write.
Map<int, dynamic> readFields(BinaryReader reader) {
  final count = reader.readByte();
  return {for (var i = 0; i < count; i++) reader.readByte(): reader.read()};
}

void writeFields(BinaryWriter writer, List<dynamic> values) {
  writer.writeByte(values.length);
  for (var i = 0; i < values.length; i++) {
    writer
      ..writeByte(i)
      ..write(values[i]);
  }
}
