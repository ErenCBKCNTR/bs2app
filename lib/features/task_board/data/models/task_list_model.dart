import 'package:pocketbase/pocketbase.dart';

class TaskListM {
  final String id;
  final String boardId;
  final String name;
  final int order;
  final DateTime created;

  TaskListM({
    required this.id,
    required this.boardId,
    required this.name,
    required this.order,
    required this.created,
  });

  factory TaskListM.fromRecord(RecordModel record) {
    return TaskListM(
      id: record.id,
      boardId: record.getStringValue('board_id'),
      name: record.getStringValue('name'),
      order: record.getIntValue('order'),
      created: DateTime.parse(record.created).toLocal(),
    );
  }
}
