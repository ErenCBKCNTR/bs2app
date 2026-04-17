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
  bool _showArchived = false;

  final ScrollController _chatListScrollController = ScrollController();
  bool _archivedVisible = false;

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
    
    _chatListScrollController.addListener(_scrollListener);
  }

  void _scrollListener() {
    if (_chatListScrollController.offset < -60 && !_archivedVisible && !_showArchived) {
      setState(() {
        _archivedVisible = true;
      });
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _tabController.dispose();
    _chatListScrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchChats({bool isBackground = false}) async {
    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      final response = await Supabase.instance.client
          .from('chats')
          .select('*, chat_participants!inner(user_id, last_read_message_id, is_archived), messages(id, content, sender_id, created_at)')
          .order('updated_at', ascending: false);
          
      if (mounted) {
        setState(() {
          _chats = List<Map<String, dynamic>>.from(response);
          // Only keep chats where current user is a participant (simulated local filter to ease complex RLS inner joins in single select)
          _chats = _chats.where((c) {
             final participants = c['chat_participants'] as List<dynamic>? ?? [];
             return participants.any((p) => p['user_id'] == userId);
          }).toList();
          
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

  Future<void> _toggleArchive(String chatId, bool currentStatus) async {
    try {
      final myId = Supabase.instance.client.auth.currentUser!.id;
      await Supabase.instance.client
          .from('chat_participants')
          .update({'is_archived': !currentStatus})
          .eq('chat_id', chatId)
          .eq('user_id', myId);
          
      await _fetchChats();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(!currentStatus ? 'Sohbet arşivlendi' : 'Sohbet arşivden çıkarıldı'),
            duration: const Duration(seconds: 2),
          )
        );
      }
    } catch (e) {
      AppLogger.instance.error('Arşivleme hatası: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: _showArchived && _tabController.index == 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _showArchived = false),
                tooltip: "Sohbetlere dön",
              )
            : null,
        title: Semantics(
          label: _showArchived && _tabController.index == 0 ? "Arşivlenmiş Sohbetler" : "Blind Social Ana Sayfa",
          header: true,
          child: Text(
            _showArchived && _tabController.index == 0 ? "Arşivlenmiş" : 'Blind Social',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
          ),
        ),
        actions: [
          if (!_showArchived || _tabController.index != 0) ...[
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
          ]
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Theme.of(context).colorScheme.primary,
          labelColor: Theme.of(context).colorScheme.primary,
          unselectedLabelColor: Colors.grey,
          tabs: [
            Tab(child: Semantics(label: "Sohbetler", excludeSemantics: true, child: const Text("Sohbetler"))),
            Tab(child: Semantics(label: "Blog", excludeSemantics: true, child: const Text("Blog"))),
            Tab(child: Semantics(label: "Odalar", excludeSemantics: true, child: const Text("Odalar"))),
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

  Future<void> _navigateToChat(String chatId, String chatName) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatDetailScreen(chat: {'id': chatId, 'name': chatName}),
      ),
    );
    _fetchChats();
  }

  Future<void> _createOrOpenChat(Map<String, dynamic> targetUser) async {
    try {
      final myId = Supabase.instance.client.auth.currentUser!.id;
      final targetId = targetUser['id'];
      
      // 1. Önce bu kullanıcıyla mevcut bir özel sohbet (dm) var mı kontrol et
      // Bu sorgu: both usersin katıldığı ve is_group = false olan sohbetleri getirir
      final existingChatRes = await Supabase.instance.client
          .from('chat_participants')
          .select('chat_id, chats!inner(is_group)')
          .eq('user_id', myId)
          .eq('chats.is_group', false);

      final myPrivateChatIds = (existingChatRes as List).map((p) => p['chat_id']).toList();

      if (myPrivateChatIds.isNotEmpty) {
        final findTargetRes = await Supabase.instance.client
            .from('chat_participants')
            .select('chat_id')
            .filter('chat_id', 'in', myPrivateChatIds)
            .eq('user_id', targetId)
            .maybeSingle();

        if (findTargetRes != null) {
          final chatId = findTargetRes['chat_id'];
          AppLogger.instance.info('Mevcut sohbet bulundu: $chatId');
          if (mounted) {
            _navigateToChat(chatId, targetUser['username']);
          }
          return;
        }
      }

      // 2. Mevcut sohbet yoksa yeni oluştur
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
        _navigateToChat(chatId, targetUser['username']);
      }
      AppLogger.instance.info('Sohbet oluşturuldu: $chatId');
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

    final currentUserId = Supabase.instance.client.auth.currentUser?.id;

    final filteredChats = _chats.where((c) {
       final participants = c['chat_participants'] as List<dynamic>? ?? [];
       final myPart = participants.firstWhere((p) => p['user_id'] == currentUserId, orElse: () => null);
       final isArchived = myPart != null ? (myPart['is_archived'] ?? false) : (c['is_archived'] ?? false);
       return isArchived == _showArchived;
    }).toList();

    if (filteredChats.isEmpty) {
      return Column(
        children: [
          if (!_showArchived) _buildArchiveToggle(),
          Expanded(
            child: Center(
              child: Text(
                _showArchived 
                    ? 'Arşivlenmiş sohbet yok.' 
                    : 'Henüz bir sohbetiniz yok.\nYeni bir sohbet başlatın.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        if (!_showArchived && _archivedVisible) _buildArchiveToggle(),
        Expanded(
          child: ListView.separated(
            controller: _chatListScrollController,
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            itemCount: filteredChats.length,
            separatorBuilder: (context, index) => const Divider(height: 1, color: Colors.white10),
            itemBuilder: (context, index) {
              final chat = filteredChats[index];
              final chatName = chat['name'] ?? 'İsimsiz Sohbet';
              
              // Katılımcı bilgisinden arşiv durumunu al
              final participants = chat['chat_participants'] as List<dynamic>? ?? [];
              final myPart = participants.firstWhere((p) => p['user_id'] == currentUserId, orElse: () => null);
              final isArchived = myPart != null ? (myPart['is_archived'] ?? false) : (chat['is_archived'] ?? false);
              
              String? targetUserId;
              String? lastReadId;
              for (var p in participants) {
                if (p['user_id'] != currentUserId) {
                  targetUserId = p['user_id'];
                } else {
                   lastReadId = p['last_read_message_id'];
                }
              }
              
              final messages = chat['messages'] as List<dynamic>? ?? [];
              messages.sort((a, b) => b['created_at'].compareTo(a['created_at'])); // sort descending
              final lastMessage = messages.isNotEmpty ? messages.first : null;
              
              String subtitleText = 'Sohbete gitmek için dokunun';
              bool isUnread = false;
              
              if (lastMessage != null) {
                 final content = lastMessage['content'].toString();
                 subtitleText = content.startsWith('[VOICE]') ? 'Sesli Mesaj' : content;
                 
                 if (lastMessage['sender_id'] != currentUserId) {
                    if (lastReadId == null || lastReadId != lastMessage['id']) {
                       isUnread = true;
                    }
                 }
              }
              
              final semanticUnreadSuffix = isUnread ? "Okunmamış yeni mesajınız var." : "";
              final semanticSubtitle = lastMessage != null ? "Son mesaj: $subtitleText." : "";
              
              return Semantics(
                label: "$chatName. $semanticSubtitle $semanticUnreadSuffix",
                button: true,
                onTapHint: "Sohbeti açmak için çift dokunun",
                customSemanticsActions: {
                  CustomSemanticsAction(label: isArchived ? 'Arşivden Çıkar' : 'Arşivle'): () {
                    _toggleArchive(chat['id'], isArchived);
                  },
                },
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
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: Colors.grey[800],
                              child: Text(
                                chatName.toString().split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join(''),
                                style: const TextStyle(fontSize: 16, color: Colors.white),
                              ),
                            ),
                            if (isUnread)
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  width: 14,
                                  height: 14,
                                  decoration: const BoxDecoration(
                                    color: Colors.green,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  title: Text(
                    chatName.toString(),
                    style: TextStyle(fontWeight: isUnread ? FontWeight.w900 : FontWeight.bold, fontSize: 16),
                  ),
                  subtitle: Text(
                    subtitleText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 14, color: isUnread ? Colors.white : Colors.grey, fontWeight: isUnread ? FontWeight.bold : FontWeight.normal),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onLongPress: () {
                    _showChatOptions(chat);
                  },
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChatDetailScreen(chat: chat),
                      ),
                    );
                    _fetchChats();
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildArchiveToggle() {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final archivedCount = _chats.where((c) {
      final participants = c['chat_participants'] as List<dynamic>? ?? [];
      final myPart = participants.firstWhere((p) => p['user_id'] == currentUserId, orElse: () => null);
      return myPart != null ? (myPart['is_archived'] == true) : false;
    }).length;
    
    if (archivedCount == 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: const Icon(Icons.archive, color: Colors.blue, size: 28),
        title: Text(
          "Arşivlenmiş",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade300),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            archivedCount.toString(),
            style: const TextStyle(color: Colors.blue, fontSize: 12),
          ),
        ),
        onTap: () {
          setState(() {
            _showArchived = true;
          });
        },
      ),
    );
  }

  void _showChatOptions(Map<String, dynamic> chat) {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final participants = chat['chat_participants'] as List<dynamic>? ?? [];
    final myPart = participants.firstWhere((p) => p['user_id'] == currentUserId, orElse: () => null);
    final isArchived = myPart != null ? (myPart['is_archived'] ?? false) : (chat['is_archived'] ?? false);

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(isArchived ? Icons.unarchive : Icons.archive),
              title: Text(isArchived ? 'Arşivden Çıkar' : 'Arşivle'),
              onTap: () {
                Navigator.pop(context);
                _toggleArchive(chat['id'], isArchived);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Sohbeti Sil', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                // Sohbet silme mantığı buraya eklenebilir
              },
            ),
          ],
        );
      }
    );
  }
}
