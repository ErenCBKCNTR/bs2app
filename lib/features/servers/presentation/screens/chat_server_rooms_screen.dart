import 'package:flutter/material.dart';
import 'package:blind_social/features/servers/data/models/chat_server.dart';
import 'package:blind_social/features/servers/data/models/chat_server_room.dart';
import 'package:blind_social/features/servers/data/services/chat_server_service.dart';
import 'package:blind_social/core/utils/profanity_filter.dart';
import 'package:blind_social/features/servers/presentation/screens/chat_room_detail_screen.dart';

class ChatServerRoomsScreen extends StatefulWidget {
  final ChatServer server;
  const ChatServerRoomsScreen({super.key, required this.server});

  @override
  State<ChatServerRoomsScreen> createState() => _ChatServerRoomsScreenState();
}

class _ChatServerRoomsScreenState extends State<ChatServerRoomsScreen> {
  List<ChatServerRoom> _rooms = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchRooms();
  }

  Future<void> _fetchRooms() async {
    try {
      final rooms = await ChatServerService().getRooms(widget.server.id);
      if (mounted) {
        setState(() {
          _rooms = rooms;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
      }
    }
  }

  Future<void> _showCreateRoomDialog() async {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    RoomType roomType = RoomType.hybrid;
    bool isSaving = false;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Yeni Oda Oluştur'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'Oda Adı',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: descController,
                      decoration: const InputDecoration(
                        labelText: 'Açıklama',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<RoomType>(
                      value: roomType,
                      decoration: const InputDecoration(
                        labelText: 'Oda Türü',
                        border: OutlineInputBorder(),
                      ),
                      items: RoomType.values.map((type) {
                        return DropdownMenuItem(
                          value: type,
                          child: Text(type.name.toUpperCase()),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setStateDialog(() => roomType = val);
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(context),
                  child: const Text('İptal'),
                ),
                ElevatedButton(
                  onPressed: isSaving ? null : () async {
                    final name = nameController.text.trim();
                    if (name.isEmpty) return;
                    setStateDialog(() => isSaving = true);
                    try {
                      await ChatServerService().createRoom(
                        serverId: widget.server.id,
                        name: name,
                        description: descController.text.trim(),
                        type: roomType,
                      );
                      if (context.mounted) {
                        Navigator.pop(context);
                        _fetchRooms();
                      }
                    } catch (e) {
                      setStateDialog(() => isSaving = false);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
                      }
                    }
                  },
                  child: isSaving ? const CircularProgressIndicator() : const Text('Oluştur'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(ProfanityFilter.filter(widget.server.name)),
        actions: [
          if (widget.server.creatorId == ChatServerService()._pb.authStore.model.id ||
              widget.server.admins.contains(ChatServerService()._pb.authStore.model.id))
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () {
                // TODO: Implement server settings / admin management
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Sunucu ayarları yakında eklenecek.')),
                );
              },
              tooltip: 'Sunucu Ayarları',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _rooms.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Bu sunucuda henüz oda yok.'),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _showCreateRoomDialog,
                        icon: const Icon(Icons.add),
                        label: const Text('İlk Odayı Oluştur'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _rooms.length,
                  itemBuilder: (context, index) {
                    final room = _rooms[index];
                    return ListTile(
                      leading: Icon(
                        room.type == RoomType.voice
                            ? Icons.volume_up
                            : room.type == RoomType.text
                                ? Icons.chat
                                : Icons.forum,
                      ),
                      title: Text(ProfanityFilter.filter(room.name)),
                      subtitle: Text(ProfanityFilter.filter(room.description)),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatRoomDetailScreen(room: room),
                          ),
                        );
                      },
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateRoomDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
