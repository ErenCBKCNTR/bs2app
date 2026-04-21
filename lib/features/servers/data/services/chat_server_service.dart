import 'package:blind_social/features/servers/data/models/chat_server.dart';
import 'package:blind_social/features/servers/data/models/chat_server_room.dart';
import 'package:blind_social/features/servers/data/models/server_message.dart';
import 'package:blind_social/core/services/pocketbase_service.dart';
import 'package:pocketbase/pocketbase.dart';

class ChatServerService {
  static final ChatServerService _instance = ChatServerService._internal();
  factory ChatServerService() => _instance;
  ChatServerService._internal();

  final _pb = PocketBaseService.client;

  // Servers
  Future<List<ChatServer>> getServers() async {
    final records = await _pb.collection('chat_servers').getFullList(
      sort: '-created',
    );
    return records.map((r) => ChatServer.fromRecord(r)).toList();
  }

  Future<ChatServer> createServer({
    required String name,
    required String description,
    required int capacity,
  }) async {
    final body = {
      'name': name,
      'description': description,
      'capacity': capacity,
      'creator': _pb.authStore.model.id,
      'admins': [_pb.authStore.model.id],
    };
    final record = await _pb.collection('chat_servers').create(body: body);
    
    // Auto join creator
    await joinServer(record.id);
    
    return ChatServer.fromRecord(record);
  }

  // Rooms
  Future<List<ChatServerRoom>> getRooms(String serverId) async {
    final records = await _pb.collection('chat_server_rooms').getFullList(
      filter: 'server_id = "$serverId"',
      sort: 'created',
    );
    return records.map((r) => ChatServerRoom.fromRecord(r)).toList();
  }

  Future<ChatServerRoom> createRoom({
    required String serverId,
    required String name,
    required String description,
    required RoomType type,
  }) async {
    // 2. Create the room
    final body = {
      'server_id': serverId,
      'name': name,
      'description': description,
      'type': type.name,
    };
    final record = await _pb.collection('chat_server_rooms').create(body: body);
    
    return ChatServerRoom.fromRecord(record);
  }

  // Messages
  Future<List<ServerMessage>> getRoomMessages(String roomId) async {
    final records = await _pb.collection('server_messages').getFullList(
      filter: 'room_id = "$roomId"',
      sort: 'created',
      expand: 'sender_id',
    );
    return records.map((r) => ServerMessage.fromRecord(r)).toList();
  }

  Future<ServerMessage> sendRoomMessage({
    required String roomId,
    required String content,
  }) async {
    final body = {
      'room_id': roomId,
      'sender_id': _pb.authStore.model.id,
      'content': content,
    };
    final record = await _pb.collection('server_messages').create(
      body: body,
      expand: 'sender_id',
    );
    return ServerMessage.fromRecord(record);
  }

  // Memberships
  Future<void> joinServer(String serverId) async {
    final body = {
      'server_id': serverId,
      'user_id': _pb.authStore.model.id,
    };
    await _pb.collection('server_memberships').create(body: body);
  }

  Future<void> leaveServer(String serverId) async {
    final record = await _pb.collection('server_memberships').getFirstListItem(
      'server_id = "$serverId" && user_id = "${_pb.authStore.model.id}"',
    );
    await _pb.collection('server_memberships').delete(record.id);
  }

  Future<bool> isMember(String serverId) async {
    try {
      await _pb.collection('server_memberships').getFirstListItem(
        'server_id = "$serverId" && user_id = "${_pb.authStore.model.id}"',
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}
