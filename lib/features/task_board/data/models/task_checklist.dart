import 'package:pocketbase/pocketbase.dart';

class TaskChecklist {
  final String id;
  final String taskId;
  final String title;
  final bool isCompleted;
  final int order;
  final DateTime created;

  TaskChecklist({
    required this.id,
    required this.taskId,
    required this.title,
    required this.isCompleted,
    required this.order,
    required this.created,
  });

  factory TaskChecklist.fromRecord(RecordModel record) {
    return TaskChecklist(
      id: record.id,
      taskId: record.getStringValue('task_id'),
      title: record.getStringValue('title'),
      isCompleted: record.getBoolValue('is_completed'),
      order: record.getIntValue('order'),
      created: DateTime.parse(record.created).toLocal(),
    );
  }
}
