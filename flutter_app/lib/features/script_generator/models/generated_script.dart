import 'package:hive/hive.dart';

/// Persisted representation of a generated script stored on-device.
class GeneratedScript {
  GeneratedScript({
    required this.id,
    required this.topic,
    required this.style,
    required this.content,
    required this.createdAt,
    required this.usedHostedGenerator,
  });

  final String id;
  final String topic;
  final String style;
  final String content;
  final DateTime createdAt;
  final bool usedHostedGenerator;
}

/// Hive adapter to serialize [GeneratedScript] instances.
class GeneratedScriptAdapter extends TypeAdapter<GeneratedScript> {
  @override
  final int typeId = 0;

  @override
  GeneratedScript read(BinaryReader reader) {
    final int numOfFields = reader.readByte();
    final Map<int, dynamic> fields = <int, dynamic>{};
    for (int i = 0; i < numOfFields; i++) {
      fields[reader.readByte()] = reader.read();
    }

    return GeneratedScript(
      id: fields[0] as String,
      topic: fields[1] as String,
      style: fields[2] as String,
      content: fields[3] as String,
      createdAt: fields[4] as DateTime,
      usedHostedGenerator: fields[5] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, GeneratedScript obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.topic)
      ..writeByte(2)
      ..write(obj.style)
      ..writeByte(3)
      ..write(obj.content)
      ..writeByte(4)
      ..write(obj.createdAt)
      ..writeByte(5)
      ..write(obj.usedHostedGenerator);
  }
}
