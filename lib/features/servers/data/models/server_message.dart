import 'package:pocketbase/pocketbase.dart';

class ServerMessage {
  final String id;
  final String roomId;
  final String senderId;
  final String content;
  final String? file;
  final DateTime created;
  final DateTime updated;
  Map<String, dynamic>? expand;

  ServerMessage({
    required this.id,
    required this.roomId,
    required this.senderId,
    required this.content,
    this.file,
    required this.created,
    required this.updated,
    this.expand,
  });

  factory ServerMessage.fromRecord(RecordModel record) {
    return ServerMessage(
      id: record.id,
      roomId: record.getStringValue('room_id'),
      senderId: record.getStringValue('sender_id'),
      content: record.getStringValue('content'),
      file: record.getStringValue('file'),
      created: DateTime.parse(record.created),
      updated: DateTime.parse(record.updated),
      expand: record.expand.map((key, value) {
        if (value.isNotEmpty) {
          return MapEntry(key, value.first.toJson());
        }
        return MapEntry(key, value);
      }),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'room_id': roomId,
      'sender_id': senderId,
      'content': content,
      'file': file,
    };
  }
}
