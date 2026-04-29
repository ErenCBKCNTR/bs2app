import 'package:pocketbase/pocketbase.dart';

class TaskItem {
  final String id;
  final String listId;
  final String title;
  final String description;
  final String createdBy;
  final List<String> assignees;
  final DateTime? dueDate;
  final int order;
  final bool isCompleted;
  final int taskNumber;
  final List<dynamic> labels;
  final DateTime created;

  TaskItem({
    required this.id,
    required this.listId,
    required this.title,
    required this.description,
    required this.createdBy,
    required this.assignees,
    this.dueDate,
    required this.order,
    required this.isCompleted,
    required this.taskNumber,
    required this.labels,
    required this.created,
  });

  factory TaskItem.fromRecord(RecordModel record) {
    DateTime? getDueDate() {
      final dateStr = record.getStringValue('due_date');
      if (dateStr.isEmpty) return null;
      try {
        return DateTime.parse(dateStr).toLocal();
      } catch (e) {
        return null;
      }
    }

    return TaskItem(
      id: record.id,
      listId: record.getStringValue('list_id'),
      title: record.getStringValue('title'),
      description: record.getStringValue('description'),
      createdBy: record.getStringValue('created_by'),
      assignees: record.getListValue<String>('assignees'),
      dueDate: getDueDate(),
      order: record.getIntValue('order'),
      isCompleted: record.getBoolValue('is_completed'),
      taskNumber: record.getIntValue('task_number'),
      labels: record.getListValue<dynamic>('labels'),
      created: DateTime.parse(record.created).toLocal(),
    );
  }
}
