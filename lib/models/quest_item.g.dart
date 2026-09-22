// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'quest_item.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class QuestItemAdapter extends TypeAdapter<QuestItem> {
  @override
  final int typeId = 3;

  @override
  QuestItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return QuestItem(
      id: fields[0] as String,
      name: fields[1] as String,
      target: fields[2] as int,
      sets: fields[3] as int,
      unit: fields[4] as String,
      isDone: (fields[5] as bool?) ?? false,
    );
  }

  @override
  void write(BinaryWriter writer, QuestItem obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.target)
      ..writeByte(3)
      ..write(obj.sets)
      ..writeByte(4)
      ..write(obj.unit)
      ..writeByte(5)
      ..write(obj.isDone);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QuestItemAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
