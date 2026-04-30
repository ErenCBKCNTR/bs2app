import 'package:pocketbase/pocketbase.dart';

class TaskBoard {
  final String id;
  final String name;
  final String description;
  final String ownerId;
  final List<String> members;
  final List<String> editors;
  final List<String> favoritedBy;
  final DateTime created;

  TaskBoard({
    required this.id,
    required this.name,
    required this.description,
    required this.ownerId,
    required this.members,
    required this.editors,
    required this.favoritedBy,
    required this.created,
  });

  factory TaskBoard.fromRecord(RecordModel record) {
    return TaskBoard(
      id: record.id,
      name: record.getStringValue('name'),
      description: record.getStringValue('description'),
      ownerId: record.getStringValue('owner_id'),
      members: record.getListValue<String>('members'),
      editors: record.getListValue<String>('editors'),
      favoritedBy: record.getListValue<String>('favorited_by'),
      created: DateTime.parse(record.created).toLocal(),
    );
  }
}
