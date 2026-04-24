import 'package:pocketbase/pocketbase.dart';

class ChatServer {
  final String id;
  final String name;
  final String description;
  final String creatorId;
  final List<String> admins;
  final int capacity;
  final String? avatar;
  final bool canMembersCreateRooms;
  final String? password;
  final DateTime created;
  final DateTime updated;

  ChatServer({
    required this.id,
    required this.name,
    required this.description,
    required this.creatorId,
    required this.admins,
    required this.capacity,
    this.avatar,
    this.canMembersCreateRooms = false,
    this.password,
    required this.created,
    required this.updated,
  });

  factory ChatServer.fromRecord(RecordModel record) {
    return ChatServer(
      id: record.id,
      name: record.getStringValue('name'),
      description: record.getStringValue('description'),
      creatorId: record.getStringValue('creator'),
      admins: record.getListValue<String>('admins'),
      capacity: record.getIntValue('capacity'),
      avatar: record.getStringValue('avatar'),
      canMembersCreateRooms: record.getBoolValue('can_members_create_rooms'),
      password: record.getStringValue('password'),
      created: DateTime.parse(record.created),
      updated: DateTime.parse(record.updated),
    );
  }

  factory ChatServer.fromJson(Map<String, dynamic> json) {
    return ChatServer(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      creatorId: json['creator'] ?? '',
      admins: List<String>.from(json['admins'] ?? []),
      capacity: json['capacity'] ?? 100,
      avatar: json['avatar'],
      canMembersCreateRooms: json['can_members_create_rooms'] ?? false,
      password: json['password'],
      created: json['created'] != null ? DateTime.parse(json['created']) : DateTime.now(),
      updated: json['updated'] != null ? DateTime.parse(json['updated']) : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'creator': creatorId,
      'admins': admins,
      'capacity': capacity,
      'avatar': avatar,
      'can_members_create_rooms': canMembersCreateRooms,
      'password': password,
      'created': created.toIso8601String(),
      'updated': updated.toIso8601String(),
    };
  }
}
