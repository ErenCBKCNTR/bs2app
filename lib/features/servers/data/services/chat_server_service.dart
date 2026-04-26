import 'dart:async';
import 'package:blind_social/features/servers/data/models/chat_server.dart';
import 'package:blind_social/features/servers/data/models/chat_server_room.dart';
import 'package:blind_social/features/servers/data/models/server_message.dart';
import 'package:blind_social/core/services/pocketbase_service.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:http/http.dart' as http;

class ChatServerService {
  static final ChatServerService _instance = ChatServerService._internal();
  factory ChatServerService() => _instance;
  ChatServerService._internal();

  final _pb = PocketBaseService.client;

  String get currentUserId => _pb.authStore.model.id;

  // Servers
  Future<List<ChatServer>> getServers() async {
    final records = await _pb.collection('chat_servers').getFullList(
      sort: '-created',
    );
    return records.map((r) => ChatServer.fromRecord(r)).toList();
  }

  Future<ChatServer> getServer(String serverId) async {
    final record = await _pb.collection('chat_servers').getOne(serverId);
    return ChatServer.fromRecord(record);
  }

  Future<ChatServer> updateServer({
    required String serverId,
    String? name,
    String? description,
    int? capacity,
    bool? canMembersCreateRooms,
    String? password,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (description != null) body['description'] = description;
    if (capacity != null) body['capacity'] = capacity;
    if (canMembersCreateRooms != null) body['can_members_create_rooms'] = canMembersCreateRooms;
    if (password != null) body['password'] = password;

    final record = await _pb.collection('chat_servers').update(serverId, body: body);
    return ChatServer.fromRecord(record);
  }

  Future<UnsubscribeFunc> subscribeToServers(void Function(RecordSubscriptionEvent) onEvent) {
    return _pb.collection('chat_servers').subscribe('*', onEvent);
  }

  Future<ChatServer> createServer({
    required String name,
    required String description,
    required int capacity,
    bool canMembersCreateRooms = false,
    String? password,
  }) async {
    final body = {
      'name': name,
      'description': description,
      'capacity': capacity,
      'can_members_create_rooms': canMembersCreateRooms,
      'password': password ?? '',
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

  Future<ServerMessage> sendRoomAudio({
    required String roomId,
    required String audioPath,
  }) async {
    final body = {
      'room_id': roomId,
      'sender_id': _pb.authStore.model.id,
      'content': '[VOICE]',
    };

    final file = await http.MultipartFile.fromPath('file', audioPath);

    final record = await _pb.collection('server_messages').create(
      body: body,
      files: [file],
      expand: 'sender_id',
    );
    return ServerMessage.fromRecord(record);
  }

  Future<UnsubscribeFunc> subscribeToRoomMessages(String roomId, void Function(RecordSubscriptionEvent) onEvent) {
    return _pb.collection('server_messages').subscribe('*', onEvent, filter: 'room_id = "$roomId"', expand: 'sender_id');
  }

  // Memberships
  Future<List<RecordModel>> getServerMembers(String serverId) async {
    final records = await _pb.collection('server_memberships').getFullList(
      filter: 'server_id = "$serverId"',
      expand: 'user_id',
    );
    return records;
  }

  Future<void> removeMember(String serverId, String userId) async {
    final record = await _pb.collection('server_memberships').getFirstListItem(
      'server_id = "$serverId" && user_id = "$userId"',
    );
    await _pb.collection('server_memberships').delete(record.id);
  }

  Future<void> joinServer(String serverId) async {
    final body = {
      'server_id': serverId,
      'user_id': _pb.authStore.model.id,
    };
    await _pb.collection('server_memberships').create(body: body);
  }

  Future<void> leaveServer(String serverId) async {
    try {
      final record = await _pb.collection('server_memberships').getFirstListItem(
        'server_id = "$serverId" && user_id = "${currentUserId}"',
      );
      await _pb.collection('server_memberships').delete(record.id);
    } catch (_) {}
  }

  Future<void> banMember(String serverId, String userId) async {
    // 1. Üyeyi sil
    try {
      await removeMember(serverId, userId);
    } catch (_) {}

    // 2. Ban tablosuna ekle
    try {
      await _pb.collection('server_bans').create(body: {
        'server_id': serverId,
        'user_id': userId,
      });
    } catch (_) {}
  }

  Future<List<RecordModel>> getServerBans(String serverId) async {
    final records = await _pb.collection('server_bans').getFullList(
      filter: 'server_id = "$serverId"',
      expand: 'user_id',
    );
    return records;
  }

  Future<void> unbanMember(String serverId, String userId) async {
    final record = await _pb.collection('server_bans').getFirstListItem(
      'server_id = "$serverId" && user_id = "$userId"',
    );
    await _pb.collection('server_bans').delete(record.id);
  }

  Future<bool> isBanned(String serverId) async {
    try {
      await _pb.collection('server_bans').getFirstListItem(
        'server_id = "$serverId" && user_id = "${currentUserId}"',
      );
      return true; // Ban bulunursa true
    } catch (_) {
      return false; // Ban yoksa false
    }
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

  // PRESENCE & CAPACITY
  Timer? _heartbeatTimer;

  Future<int> getOnlineMemberCount(String serverId) async {
    try {
      final nowStr = DateTime.now().toUtc().subtract(const Duration(seconds: 45)).toIsoString().replaceAll('T', ' ');
      final records = await _pb.collection('server_memberships').getFullList(
        filter: 'server_id = "$serverId" && last_active >= "$nowStr"',
      );
      return records.length;
    } catch (_) {
      return 0;
    }
  }

  void startHeartbeat(String serverId) {
    _heartbeatTimer?.cancel();
    _pingPresence(serverId);
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 20), (timer) {
      _pingPresence(serverId);
    });
  }

  void stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  Future<void> _pingPresence(String serverId) async {
    try {
      final record = await _pb.collection('server_memberships').getFirstListItem(
        'server_id = "$serverId" && user_id = "$currentUserId"',
      );
      await _pb.collection('server_memberships').update(record.id, body: {
        'last_active': DateTime.now().toUtc().toIsoString(),
      });
    } catch (_) {}
  }

  Future<void> cleanupGhostUsers() async {
    try {
      final nowStr = DateTime.now().toUtc().subtract(const Duration(seconds: 45)).toIsoString().replaceAll('T', ' ');
      final records = await _pb.collection('server_memberships').getFullList(
        filter: 'last_active < "$nowStr"',
      );
      for (final r in records) {
        await _pb.collection('server_memberships').delete(r.id);
      }
    } catch (_) {}
  }
}
