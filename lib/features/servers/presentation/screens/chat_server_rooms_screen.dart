import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:blind_social/features/servers/data/models/chat_server.dart';
import 'package:blind_social/features/servers/data/models/chat_server_room.dart';
import 'package:blind_social/features/servers/data/services/chat_server_service.dart';
import 'package:blind_social/core/utils/profanity_filter.dart';
import 'package:blind_social/features/servers/presentation/screens/chat_room_detail_screen.dart';
import 'package:blind_social/features/servers/presentation/screens/server_settings_screen.dart';

import 'package:pocketbase/pocketbase.dart';

class ChatServerRoomsScreen extends StatefulWidget {
  final ChatServer server;
  const ChatServerRoomsScreen({super.key, required this.server});

  @override
  State<ChatServerRoomsScreen> createState() => _ChatServerRoomsScreenState();
}

class _ChatServerRoomsScreenState extends State<ChatServerRoomsScreen> with WidgetsBindingObserver {
  late ChatServer _server;
  List<ChatServerRoom> _rooms = [];
  bool _isLoading = true;
  UnsubscribeFunc? _serverSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _server = widget.server;
    _fetchRooms();
    
    // Start Heartbeat
    ChatServerService().startHeartbeat(_server.id);
    
    // Monitor server deletion
    ChatServerService().subscribeToServers((e) {
      if (e.action == 'delete' && e.record?.id == _server.id) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sunucu kapatıldı. Ana sayfaya yönlendiriliyorsunuz.')));
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      }
    }).then((sub) => _serverSub = sub);
    
    // Ekran okuyucu için sunucuya katılma bildirimi
    SemanticsService.announce(
      "Şu anda ${ProfanityFilter.filter(_server.name)} isimli sunucuya bağlandınız.", 
      TextDirection.ltr,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ChatServerService().stopHeartbeat();
    _serverSub?.call();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      ChatServerService().stopHeartbeat();
    } else if (state == AppLifecycleState.resumed) {
      ChatServerService().startHeartbeat(_server.id);
    }
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
    final formKey = GlobalKey<FormState>();
    RoomType roomType = RoomType.hybrid;
    bool isSaving = false;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Yeni Oda Oluştur'),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameController,
                        autofocus: true,
                        decoration: const InputDecoration(
                          labelText: 'Oda Adı',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Oda adı boş olamaz';
                          }
                          if (value.trim().length < 2) {
                            return 'Oda adı en az 2 karakter olmalıdır';
                          }
                          return null;
                        },
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
                        items: [
                          const DropdownMenuItem(
                            value: RoomType.text,
                            child: Text('Sadece Mesaj'),
                          ),
                          const DropdownMenuItem(
                            value: RoomType.voice,
                            child: Text('Sadece Ses'),
                          ),
                          const DropdownMenuItem(
                            value: RoomType.hybrid,
                            child: Text('Karışık (Mesaj + Ses)'),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) setStateDialog(() => roomType = val);
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(context),
                  child: const Text('İptal'),
                ),
                ElevatedButton(
                  onPressed: isSaving ? null : () async {
                    if (!formKey.currentState!.validate()) return;
                    
                    final name = nameController.text.trim();
                    setStateDialog(() => isSaving = true);
                    try {
                      await ChatServerService().createRoom(
                        serverId: widget.server.id,
                        name: name,
                        description: descController.text.trim(),
                        type: roomType,
                      );
                      
                      SemanticsService.announce("$name isimli oda başarıyla oluşturulmuştur.", TextDirection.ltr);

                      if (context.mounted) {
                        Navigator.pop(context);
                        _fetchRooms();
                        ScaffoldMessenger.of(context).showSnackBar(
                           SnackBar(content: Text('$name isimli oda başarıyla oluşturuldu.')),
                        );
                      }
                    } catch (e) {
                      String errorMsg = e.toString();
                      if (errorMsg.contains('20 oda oluşturulabilir')) {
                        errorMsg = 'Bir sunucuda en fazla 20 oda oluşturulabilir.';
                      }
                      setStateDialog(() => isSaving = false);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $errorMsg')));
                      }
                    }
                  },
                  child: isSaving 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) 
                      : const Text('Oluştur'),
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
    final isCreator = _server.creatorId == ChatServerService().currentUserId;
    final canCreateRoom = isCreator || _server.canMembersCreateRooms;

    return Scaffold(
      appBar: AppBar(
        title: Text(ProfanityFilter.filter(_server.name)),
        actions: [
          if (isCreator || _server.admins.contains(ChatServerService().currentUserId))
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () async {
                final updated = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ServerSettingsScreen(server: _server),
                  ),
                );
                if (mounted) {
                  // Her durumda odaları yenile (oda silinmiş olabilir)
                  _fetchRooms();
                  
                  if (updated == true) {
                    // Server ayarları değişti, objeyi güncelle.
                    final updatedServer = await ChatServerService().getServer(_server.id);
                    if (mounted) {
                      setState(() {
                        _server = updatedServer;
                      });
                    }
                  }
                }
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
                      if (canCreateRoom) ...[
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _showCreateRoomDialog,
                          icon: const Icon(Icons.add),
                          label: const Text('İlk Odayı Oluştur'),
                        ),
                      ],
                    ],
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.9,
                  ),
                  itemCount: _rooms.length,
                  itemBuilder: (context, index) {
                    final room = _rooms[index];
                    final roomName = ProfanityFilter.filter(room.name);
                    final description = ProfanityFilter.filter(room.description);
                    
                    IconData roomIcon;
                    String semanticType;
                    Color iconBgColor;
                    Color iconColor;
                    
                    if (room.type == RoomType.voice) {
                      roomIcon = Icons.headset_mic_rounded;
                      semanticType = 'sesli oda';
                      iconBgColor = Colors.orange.withOpacity(0.15);
                      iconColor = Colors.orange.shade700;
                    } else if (room.type == RoomType.text) {
                      roomIcon = Icons.chat_bubble_rounded;
                      semanticType = 'mesaj odası';
                      iconBgColor = Colors.blue.withOpacity(0.15);
                      iconColor = Colors.blue.shade700;
                    } else {
                      roomIcon = Icons.forum_rounded;
                      semanticType = 'oda';
                      iconBgColor = Colors.purple.withOpacity(0.15);
                      iconColor = Colors.purple.shade700;
                    }

                    return Semantics(
                      label: '$roomName isimli $semanticType',
                      excludeSemantics: true,
                      button: true,
                      onTapHint: 'Odaya girmek için çift tıklayın',
                      child: Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        margin: EdgeInsets.zero,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ChatRoomDetailScreen(room: room),
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    CircleAvatar(
                                      radius: 20,
                                      backgroundColor: iconBgColor,
                                      child: Icon(roomIcon, color: iconColor, size: 20),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  roomName,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 6),
                                Expanded(
                                  child: Text(
                                    description.isEmpty ? 'Sohbet odası...' : description,
                                    style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodySmall?.color ?? Colors.grey),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: canCreateRoom 
          ? FloatingActionButton(
              onPressed: _showCreateRoomDialog,
              tooltip: 'Yeni oda oluştur',
              child: const Icon(Icons.add, color: Colors.black),
            )
          : null,
    );
  }
}
