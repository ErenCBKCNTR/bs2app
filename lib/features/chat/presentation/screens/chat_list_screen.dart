import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:blind_social/features/chat/presentation/screens/voice_rooms_screen.dart';
import 'package:blind_social/features/profile/presentation/screens/my_profile_screen.dart';
import 'package:blind_social/features/profile/presentation/screens/user_profile_screen.dart';
import 'package:blind_social/features/developer/presentation/screens/developer_logs_screen.dart';
import 'package:blind_social/features/chat/presentation/screens/blog_screen.dart';
import 'package:blind_social/core/utils/logger.dart';
import 'dart:async';
import 'chat_detail_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _refreshKey = 0;
  
  List<Map<String, dynamic>> _chats = [];
  bool _isLoadingChats = true;
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() {});
    });
    
    _fetchChats();
    _pollingTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      _fetchChats(isBackground: true);
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchChats({bool isBackground = false}) async {
    try {
      final response = await Supabase.instance.client
          .from('chats')
          .select('*, chat_participants(user_id)')
          .order('updated_at', ascending: false);
          
      if (mounted) {
        setState(() {
          _chats = List<Map<String, dynamic>>.from(response);
          _isLoadingChats = false;
        });
      }
    } catch (e) {
      if (!isBackground) {
        AppLogger.instance.error('Sohbetler yüklenirken hata: $e');
      }
    }
  }

  void _refresh() {
    AppLogger.instance.info('Sohbet listesi yenilendi.');
    setState(() {
      _refreshKey++;
    });
    _fetchChats();
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
          Semantics(
            label: "Kullanıcı Ara",
            child: IconButton(
              icon: const Icon(Icons.search, size: 28),
              onPressed: _showUserSearchDialog,
              tooltip: "Kullanıcı Ara",
            ),
          ),
          IconButton(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh, size: 28),
            tooltip: "Sayfayı Yenile",
          ),
          PopupMenuButton<String>(
            tooltip: "Diğer Seçenekler",
            onSelected: (value) {
              if (value == 'dev') {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const DeveloperLogsScreen()));
              } else if (value == 'profile') {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const MyProfileScreen()));
              }
            },
            itemBuilder: (BuildContext context) {
              return [
                const PopupMenuItem<String>(
                  value: 'profile',
                  child: Text('Profil Ayarları'),
                ),
                const PopupMenuItem<String>(
                  value: 'dev',
                  child: Text('Geliştirici Modu / Loglar'),
                ),
              ];
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Theme.of(context).colorScheme.primary,
          labelColor: Theme.of(context).colorScheme.primary,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(text: "Sohbetler"),
            Tab(text: "Blog"),
            Tab(text: "Odalar"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildChatList(),
          const BlogScreen(),
          VoiceRoomsScreen(key: ValueKey(_refreshKey)),
        ],
      ),
      floatingActionButton: _buildFAB(),
    );
  }

  Widget? _buildFAB() {
    if (_tabController.index == 0) {
      return FloatingActionButton(
        onPressed: _showUserSearchDialog,
        backgroundColor: Theme.of(context).colorScheme.primary,
        tooltip: "Yeni Sohbet Başlat",
        child: const Icon(Icons.message, color: Colors.black),
      );
    } else if (_tabController.index == 2) {
      return FloatingActionButton(
        onPressed: _showCreateVoiceRoomDialog,
        backgroundColor: Theme.of(context).colorScheme.primary,
        tooltip: "Yeni Sesli Oda Oluştur",
        child: const Icon(Icons.add_call, color: Colors.black),
      );
    }
    return null;
  }

  Future<void> _showUserSearchDialog() async {
    final searchController = TextEditingController();
    bool isSearching = false;
    String? errorMessage;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Kullanıcı Ara'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: searchController,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: 'Kullanıcı Adı',
                      hintText: 'Örn: ahmet123',
                      border: const OutlineInputBorder(),
                      errorText: errorMessage,
                    ),
                    onSubmitted: (val) {
                      // Trigger search programmatically ? No simple handle for dialog.
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isSearching ? null : () => Navigator.pop(context),
                  child: const Text('İptal'),
                ),
                ElevatedButton(
                  onPressed: isSearching ? null : () async {
                    final username = searchController.text.trim();
                    if (username.isEmpty) return;
                    
                    final currentUserId = Supabase.instance.client.auth.currentUser!.id;

                    setStateDialog(() {
                      isSearching = true;
                      errorMessage = null;
                    });
                    
                    try {
                      final response = await Supabase.instance.client
                          .from('users')
                          .select()
                          .eq('username', username)
                          .maybeSingle();

                      if (response == null) {
                         setStateDialog(() {
                           isSearching = false;
                           errorMessage = "Böyle bir kullanıcı bulunamadı.";
                         });
                      } else if (response['id'] == currentUserId) {
                         setStateDialog(() {
                           isSearching = false;
                           errorMessage = "Kendinizle sohbet edemezsiniz.";
                         });
                      } else {
                         // Found! Start chat.
                         if (context.mounted) {
                           Navigator.pop(context);
                           _createOrOpenChat(response);
                         }
                      }
                    } catch (e) {
                      AppLogger.instance.error('Kullanıcı arama hatası: $e');
                      setStateDialog(() {
                        isSearching = false;
                        errorMessage = "Bir hata oluştu.";
                      });
                    }
                  },
                  child: isSearching 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Ara & Mesaj At'),
                ),
              ],
            );
          }
        );
      }
    );
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
                      AppLogger.instance.error('Oda oluşturulurken hata: $e');
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

  Future<void> _createOrOpenChat(Map<String, dynamic> targetUser) async {
    try {
      final myId = Supabase.instance.client.auth.currentUser!.id;
      final targetId = targetUser['id'];
      
      // Sohbet oluştur
      final chatRes = await Supabase.instance.client.from('chats').insert({
        'is_group': false,
        'name': '${targetUser['username']}', 
        'created_by': myId,
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
      AppLogger.instance.info('Sohbet oluşturuldu: $chatId');
      _refresh(); // Listeyi yenile
    } catch (e) {
      AppLogger.instance.error('Sohbet oluşturulurken hata: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
      }
    }
  }

  Widget _buildChatList() {
    if (_isLoadingChats) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_chats.isEmpty) {
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
      itemCount: _chats.length,
      separatorBuilder: (context, index) => const Divider(height: 1, color: Colors.white10),
      itemBuilder: (context, index) {
        final chat = _chats[index];
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
  }
}
