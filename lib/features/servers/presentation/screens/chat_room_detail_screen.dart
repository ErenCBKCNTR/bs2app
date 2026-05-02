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
  late final List<({Tab tab, Widget view})> _tabs;

  @override
  void initState() {
    super.initState();
    _setupTabs();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  void _setupTabs() {
    final roomName = ProfanityFilter.filter(widget.room.name);
    _tabs = [];

    // Add Text Tab if hybrid or text
    if (widget.room.type == RoomType.text || widget.room.type == RoomType.hybrid) {
      _tabs.add((
        tab: const Tab(icon: Icon(Icons.chat), text: 'Mesajlar'),
        view: ServerRoomChatScreen(room: widget.room),
      ));
    }

    // Add Voice Tab if hybrid or voice
    if (widget.room.type == RoomType.voice || widget.room.type == RoomType.hybrid) {
      _tabs.add((
        tab: const Tab(icon: Icon(Icons.mic), text: 'Sesli Sohbet'),
        view: ActiveVoiceRoomScreen(
          roomId: widget.room.id,
          roomName: roomName,
        ),
      ));
    }

    // Fallback in case something is wrong (should not happen with logic above)
    if (_tabs.isEmpty) {
      _tabs.add((
        tab: const Tab(icon: Icon(Icons.error), text: 'Hata'),
        view: const Center(child: Text('Oda türü geçersiz')),
      ));
    }
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
      backgroundColor: const Color(0xFF101820),
      appBar: AppBar(
        title: Text(roomName),
        bottom: _tabs.length > 1 
          ? TabBar(
              controller: _tabController,
              tabs: _tabs.map((t) => t.tab).toList(),
            )
          : null,
      ),
      body: _tabs.length > 1
        ? TabBarView(
            controller: _tabController,
            children: _tabs.map((t) => t.view).toList(),
          )
        : _tabs.first.view,
    );
  }
}
