import 'package:pocketbase/pocketbase.dart';

enum RoomType { text, voice, hybrid }

class ChatServerRoom {
  final String id;
  final String serverId;
  final String name;
  final String description;
  final RoomType type;
  final DateTime created;
  final DateTime updated;

  ChatServerRoom({
    required this.id,
    required this.serverId,
    required this.name,
    required this.description,
    required this.type,
    required this.created,
    required this.updated,
  });

  factory ChatServerRoom.fromRecord(RecordModel record) {
    RoomType type;
    switch (record.getStringValue('type')) {
      case 'text':
        type = RoomType.text;
        break;
      case 'voice':
        type = RoomType.voice;
        break;
      case 'hybrid':
      default:
        type = RoomType.hybrid;
    }

    return ChatServerRoom(
      id: record.id,
      serverId: record.getStringValue('server_id'),
      name: record.getStringValue('name'),
      description: record.getStringValue('description'),
      type: type,
      created: DateTime.parse(record.created),
      updated: DateTime.parse(record.updated),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'server_id': serverId,
      'name': name,
      'description': description,
      'type': type.name,
    };
  }
}
