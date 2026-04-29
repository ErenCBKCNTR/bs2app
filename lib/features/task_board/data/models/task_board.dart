import 'package:pocketbase/pocketbase.dart';

class TaskBoard {
  final String id;
  final String name;
  final String description;
  final String ownerId;
  final List<String> members;
  final DateTime created;

  TaskBoard({
    required this.id,
    required this.name,
    required this.description,
    required this.ownerId,
    required this.members,
    required this.created,
  });

  factory TaskBoard.fromRecord(RecordModel record) {
    return TaskBoard(
      id: record.id,
      name: record.getStringValue('name'),
      description: record.getStringValue('description'),
      ownerId: record.getStringValue('owner_id'),
      members: record.getListValue<String>('members'),
      created: DateTime.parse(record.created).toLocal(),
    );
  }
}
