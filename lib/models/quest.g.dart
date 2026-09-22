// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'quest.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class QuestAdapter extends TypeAdapter<Quest> {
  @override
  final int typeId = 2;

  @override
  Quest read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Quest(
      id: fields[0] as String,
      title: fields[1] as String,
      emoji: fields[2] as String,
      type: fields[3] as String,
      difficulty: fields[4] as String,
      startTime: fields[5] as String?,
      endTime: fields[6] as String?,
      streak: fields[7] as int,
      longestStreak: fields[8] as int,
      items: (fields[9] as List).cast<QuestItem>(),
      xp: fields[10] as int,
      gold: fields[11] as int,
      focusStats: fields[12] as String,
      lastCompleted: fields[13] as DateTime?,
      createdAt: fields[14] as DateTime?,
      targetDays: (fields[15] as List?)?.cast<int>(),
      lastItemToggleDate: fields[16] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, Quest obj) {
    writer
      ..writeByte(17)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.emoji)
      ..writeByte(3)
      ..write(obj.type)
      ..writeByte(4)
      ..write(obj.difficulty)
      ..writeByte(5)
      ..write(obj.startTime)
      ..writeByte(6)
      ..write(obj.endTime)
      ..writeByte(7)
      ..write(obj.streak)
      ..writeByte(8)
      ..write(obj.longestStreak)
      ..writeByte(9)
      ..write(obj.items)
      ..writeByte(10)
      ..write(obj.xp)
      ..writeByte(11)
      ..write(obj.gold)
      ..writeByte(12)
      ..write(obj.focusStats)
      ..writeByte(13)
      ..write(obj.lastCompleted)
      ..writeByte(14)
      ..write(obj.createdAt)
      ..writeByte(15)
      ..write(obj.targetDays)
      ..writeByte(16)
      ..write(obj.lastItemToggleDate);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QuestAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
