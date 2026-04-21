import 'package:flutter/material.dart';
import 'package:blind_social/features/servers/data/models/chat_server_room.dart';
import 'package:blind_social/features/servers/presentation/screens/server_room_chat_screen.dart';
import 'package:blind_social/features/chat/presentation/screens/active_voice_room_screen.dart';
import 'package:blind_social/core/utils/profanity_filter.dart';
import 'package:blind_social/features/servers/data/services/chat_server_service.dart';

class ChatRoomDetailScreen extends StatefulWidget {
  final ChatServerRoom room;
  const ChatRoomDetailScreen({super.key, required this.room});

  @override
  State<ChatRoomDetailScreen> createState() => _ChatRoomDetailScreenState();
}

class _ChatRoomDetailScreenState extends State<ChatRoomDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final roomName = ProfanityFilter.filter(widget.room.name);
    
    return Scaffold(
      appBar: AppBar(
        title: Text(roomName),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.chat), text: 'Mesajlar'),
            Tab(icon: Icon(Icons.mic), text: 'Sesli Sohbet'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Messaging Tab
          ServerRoomChatScreen(room: widget.room),

          // Voice Tab
          ActiveVoiceRoomScreen(
            roomId: widget.room.id,
            roomName: roomName,
          ),
        ],
      ),
    );
  }
}
