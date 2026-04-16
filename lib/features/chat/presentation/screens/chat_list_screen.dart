import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:blind_social/features/chat/presentation/screens/voice_rooms_screen.dart';
import 'package:blind_social/features/profile/presentation/screens/user_profile_screen.dart';
import 'chat_detail_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  int _currentIndex = 0;
  int _refreshKey = 0;

  void _refresh() {
    setState(() {
      _refreshKey++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Semantics(
          label: "Blind Social Ana Sayfa",
          header: true,
          child: const Text(
            'Blind Social',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
          ),
        ),
        actions: [
          IconButton(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh, size: 28),
            tooltip: "Sayfayı Yenile",
          ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble),
            label: 'Sohbetler',
          ),
          NavigationDestination(
            icon: Icon(Icons.article_outlined),
            selectedIcon: Icon(Icons.article),
            label: 'Blog',
          ),
          NavigationDestination(
            icon: Icon(Icons.headset_mic_outlined),
            selectedIcon: Icon(Icons.headset_mic),
            label: 'Odalar',
          ),
        ],
      ),
      floatingActionButton: _buildFAB(),
    );
  }

  Widget _buildBody() {
    switch (_currentIndex) {
      case 0:
        return _buildChatList();
      case 1:
        return const Center(child: Text("Blog İçeriği Çok Yakında", style: TextStyle(fontSize: 18)));
      case 2:
        return VoiceRoomsScreen(key: ValueKey(_refreshKey));
      default:
        return _buildChatList();
    }
  }

  Widget? _buildFAB() {
    if (_currentIndex == 0) {
      return FloatingActionButton(
        onPressed: _showUsersListToStartChat,
        backgroundColor: Theme.of(context).colorScheme.primary,
        tooltip: "Yeni Sohbet Başlat",
        child: const Icon(Icons.message, color: Colors.black),
      );
    } else if (_currentIndex == 2) {
      return FloatingActionButton(
        onPressed: _showCreateVoiceRoomDialog,
        backgroundColor: Theme.of(context).colorScheme.primary,
        tooltip: "Yeni Sesli Oda Oluştur",
        child: const Icon(Icons.add_call, color: Colors.black),
      );
    }
    return null;
  }

  Future<void> _showCreateVoiceRoomDialog() async {
    final titleController = TextEditingController();
    bool isSaving = false;
    
    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Yeni Sesli Oda'),
              content: TextField(
                controller: titleController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Oda Adı',
                  hintText: 'Örn: Teknoloji Sohbetleri',
                  border: OutlineInputBorder(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(context),
                  child: const Text('İptal'),
                ),
                ElevatedButton(
                  onPressed: isSaving ? null : () async {
                    final name = titleController.text.trim();
                    if (name.isEmpty) return;
                    
                    setStateDialog(() => isSaving = true);
                    
                    try {
                      final userId = Supabase.instance.client.auth.currentUser!.id;
                      await Supabase.instance.client.from('voice_rooms').insert({
                        'name': name,
                        'created_by': userId,
                        'is_active': true,
                      });
                      
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Oda başarıyla oluşturuldu!')),
                        );
                      }
                      _refresh(); // Odalar listesini yenile
                    } catch (e) {
                      setStateDialog(() => isSaving = false);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Hata: $e')),
                        );
                      }
                    }
                  },
                  child: isSaving 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Oluştur'),
                ),
              ],
            );
          }
        );
      }
    );
  }

  Future<void> _showUsersListToStartChat() async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
         borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          builder: (context, scrollController) {
            return Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text("Kullanıcı Seç", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                ),
                Expanded(
                  child: FutureBuilder<List<Map<String, dynamic>>>(
                    future: Supabase.instance.client
                        .from('users')
                        .select()
                        .neq('id', Supabase.instance.client.auth.currentUser!.id),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return Center(child: Text("Hata: ${snapshot.error}"));
                      }
                      final users = snapshot.data ?? [];
                      if (users.isEmpty) {
                        return const Center(child: Text("Henüz sistemde başka kullanıcı yok."));
                      }
                      
                      return ListView.builder(
                        controller: scrollController,
                        itemCount: users.length,
                        itemBuilder: (context, index) {
                          final user = users[index];
                          final username = user['username'] ?? 'İsimsiz';
                          final targetUserId = user['id'];
                          
                          return ListTile(
                            leading: GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => UserProfileScreen(userId: targetUserId),
                                  ),
                                );
                              },
                              child: Semantics(
                                label: "Profili gör",
                                button: true,
                                child: Hero(
                                  tag: 'avatar_$targetUserId',
                                  child: CircleAvatar(
                                    backgroundColor: Colors.green.shade800,
                                    child: Text(username[0].toUpperCase(), style: const TextStyle(color: Colors.white)),
                                  ),
                                ),
                              ),
                            ),
                            title: Text(username, style: const TextStyle(fontSize: 18)),
                            subtitle: const Text("Mesajlaşmak için tıklayın"),
                            trailing: const Icon(Icons.chat),
                            onTap: () {
                              Navigator.pop(context);
                              _createOrOpenChat(user);
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          }
        );
      },
    );
  }

  Future<void> _createOrOpenChat(Map<String, dynamic> targetUser) async {
    try {
      final myId = Supabase.instance.client.auth.currentUser!.id;
      final targetId = targetUser['id'];
      
      // Sohbet oluştur
      final chatRes = await Supabase.instance.client.from('chats').insert({
        'is_group': false,
        'name': '${targetUser['username']}', 
      }).select().single();
      
      final chatId = chatRes['id'];
      
      // Katılımcıları ekle
      await Supabase.instance.client.from('chat_participants').insert([
        {'chat_id': chatId, 'user_id': myId},
        {'chat_id': chatId, 'user_id': targetId},
      ]);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sohbet oluşturuldu!')));
      }
      _refresh(); // Listeyi yenile
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
      }
    }
  }

  Widget _buildChatList() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      key: ValueKey(_refreshKey),
      future: Supabase.instance.client
          .from('chats')
          .select('*, chat_participants(user_id)')
          .order('updated_at', ascending: false),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Hata: ${snapshot.error}'));
        }

        final chats = snapshot.data ?? [];

        if (chats.isEmpty) {
          return const Center(
            child: Text(
              'Henüz bir sohbetiniz yok.\nYeni bir sohbet başlatın.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          );
        }

        final currentUserId = Supabase.instance.client.auth.currentUser?.id;

        return ListView.separated(
          itemCount: chats.length,
          separatorBuilder: (context, index) => const Divider(height: 1, color: Colors.white10),
          itemBuilder: (context, index) {
            final chat = chats[index];
            final chatName = chat['name'] ?? 'İsimsiz Sohbet';
            
            // Diğer katılımcının ID'sini bul
            final participants = chat['chat_participants'] as List<dynamic>? ?? [];
            String? targetUserId;
            for (var p in participants) {
              if (p['user_id'] != currentUserId) {
                targetUserId = p['user_id'];
                break;
              }
            }
            
            return Semantics(
              label: "$chatName ile sohbet.",
              button: true,
              onTapHint: "Sohbeti açmak için çift dokunun",
              child: ListTile(
                leading: GestureDetector(
                  onTap: () {
                    if (targetUserId != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => UserProfileScreen(userId: targetUserId!),
                        ),
                      );
                    }
                  },
                  child: Semantics(
                    label: "Profili gör",
                    button: true,
                    child: Hero(
                      tag: 'chat_avatar_$targetUserId',
                      child: CircleAvatar(
                        radius: 24,
                        backgroundColor: Colors.grey[800],
                        child: Text(
                          chatName.toString().split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join(''),
                          style: const TextStyle(fontSize: 16, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ),
                title: Text(
                  chatName.toString(),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                subtitle: const Text(
                  'Sohbete gitmek için dokunun',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChatDetailScreen(chat: chat),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}
