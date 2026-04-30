import 'package:pocketbase/pocketbase.dart';

class TaskComment {
  final String id;
  final String taskId;
  final String userId;
  final String content;
  final String voiceNote;
  final DateTime created;
  
  // Expand data for UI
  final String userName;
  final String userAvatar;

  TaskComment({
    required this.id,
    required this.taskId,
    required this.userId,
    required this.content,
    required this.voiceNote,
    required this.created,
    required this.userName,
    required this.userAvatar,
  });

  factory TaskComment.fromRecord(RecordModel record) {
    String uName = 'Bilinmeyen Kullanıcı';
    String uAvatar = '';

    final expand = record.expand;
    if (expand.containsKey('user_id') && expand['user_id'] != null) {
      final userRecord = expand['user_id']![0];
      uName = userRecord.getStringValue('full_name');
      if (uName.isEmpty) uName = userRecord.getStringValue('username');
      uAvatar = userRecord.getStringValue('avatar');
    }

    return TaskComment(
      id: record.id,
      taskId: record.getStringValue('task_id'),
      userId: record.getStringValue('user_id'),
      content: record.getStringValue('content'),
      voiceNote: record.getStringValue('voice_note'),
      created: DateTime.parse(record.getStringValue('created')).toLocal(),
      userName: uName,
      userAvatar: uAvatar,
    );
  }
}
