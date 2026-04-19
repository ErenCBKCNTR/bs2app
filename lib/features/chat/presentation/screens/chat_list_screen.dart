import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:blind_social/core/services/pocketbase_service.dart';
import 'package:pocketbase/pocketbase.dart' hide SettingsService;
import 'package:blind_social/features/chat/presentation/screens/voice_rooms_screen.dart';
import 'package:blind_social/features/profile/presentation/screens/my_profile_screen.dart';
import 'package:blind_social/features/profile/presentation/screens/user_profile_screen.dart';
import 'package:blind_social/features/profile/presentation/screens/app_settings_screen.dart';
import 'package:blind_social/features/developer/presentation/screens/developer_logs_screen.dart';
import 'package:blind_social/features/chat/presentation/screens/blog_screen.dart';
import 'package:blind_social/core/utils/logger.dart';
import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';
import 'package:blind_social/core/services/settings_service.dart';
import 'chat_detail_screen.dart';
import 'call_screen.dart';
import 'favorite_messages_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _refreshKey = 0;
  
  List<RecordModel> _chats = [];
  bool _isLoadingChats = true;
  bool _isDeleting = false;
  final Set<String> _pendingOperations = {}; // İşlem gören chat ID'leri
  Timer? _pollingTimer;
  UnsubscribeFunc? _realtimeMessagesUnsub;
  UnsubscribeFunc? _realtimeChatsUnsub;
  UnsubscribeFunc? _realtimeParticipantsUnsub;
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
    _setupRealtime();
    _pollingTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _fetchChats(isBackground: true);
    });
    
    _chatListScrollController.addListener(_scrollListener);
  }

  void _setupRealtime() async {
    final myId = PocketBaseService.client.authStore.model?.id;
    if (myId == null) return;
    
    // Mesajlar eklendiğinde
    _realtimeMessagesUnsub = await PocketBaseService.client.collection('messages').subscribe('*', (e) async {
       if (e.action == 'create') {
         final msg = e.record;
         if (msg != null && msg.getStringValue('sender_id') != myId) {
            final content = msg.getStringValue('content');
            final chatId = msg.getStringValue('chat_id');
            final senderId = msg.getStringValue('sender_id');

            // Eğer sohbet gizliyse, yeni mesaj gelince onu göster (WhatsApp tarzı unhide)
            try {
              final myPart = await PocketBaseService.client.collection('chat_participants').getFirstListItem('chat_id = "$chatId" && user_id = "$myId"');
              if (myPart.getBoolValue('is_hidden')) {
                await PocketBaseService.client.collection('chat_participants').update(myPart.id, body: {
                  'is_hidden': false
                });
              }
            } catch (_) {}

            // Gelen mesaj bir arama ise direkt CallScreen'e yönlendir
            if (content == '[VOICE_CALL_STARTED]' || content == '[VIDEO_CALL_STARTED]') {
              try {
                final senderRecord = await PocketBaseService.client.collection('users').getOne(senderId);
                final senderName = senderRecord.getStringValue('username');
                
                if (mounted) {
                  Navigator.push(context, MaterialPageRoute(
                    builder: (context) => CallScreen(
                      chatId: chatId,
                      targetUserId: senderId,
                      targetUsername: senderName,
                      isVideo: content == '[VIDEO_CALL_STARTED]',
                      isIncoming: true,
                    )
                  ));
                }
              } catch (_) {}
            } else {
              // Normal mesaj ise genel bildirim çal (titreşim+ses)
              final settings = SettingsService();
              if (settings.messageVibrationEnabled) {
                Vibration.vibrate(duration: 100);
              }
              if (settings.messageSoundEnabled) {
                final player = AudioPlayer();
                player.play(AssetSource('sounds/message_received.mp3')).catchError((_) => null);
              }
            }
         }
       }
       _fetchChats(isBackground: true);
    });

    // Sohbet eklendiğinde
    _realtimeChatsUnsub = await PocketBaseService.client.collection('chats').subscribe('*', (e) {
       _fetchChats(isBackground: true);
    });

    // Katılımcı eklendiğinde
    _realtimeParticipantsUnsub = await PocketBaseService.client.collection('chat_participants').subscribe('*', (e) {
       _fetchChats(isBackground: true);
    });
  }

  void _scrollListener() {
    if (_tabController.index != 0) return;
    
    // WhatsApp tarzı arşiv görünürlüğü: Listenin en başındayken aşağıya doğru çekme (overscroll)
    // Offset negatif olduğunda (iOS bounc veya Android glow/overscroll) tetiklenir
    if (_chatListScrollController.position.pixels < -30 && !_archivedVisible && !_showArchived) {
      if (mounted) {
        setState(() {
          _archivedVisible = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _realtimeMessagesUnsub?.call();
    _realtimeChatsUnsub?.call();
    _realtimeParticipantsUnsub?.call();
    _tabController.dispose();
    _chatListScrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchChats({bool isBackground = false}) async {
    if (_isDeleting && isBackground) return; 
    
    try {
      final userId = PocketBaseService.client.authStore.model?.id;
      if (userId == null) return;
      
      // PocketBase'de önce kullanıcının katılımcı olduğu chat ID'lerini bulalım.
      final myParticipants = await PocketBaseService.client.collection('chat_participants').getFullList(
         filter: 'user_id = "$userId"',
         expand: 'chat_id,chat_id.chat_participants_via_chat_id,chat_id.chat_participants_via_chat_id.user_id,chat_id.messages_via_chat_id'
      );
      
      List<RecordModel> chatRecords = [];
      for(var p in myParticipants) {
         if (p.getBoolValue('is_hidden')) continue;
         if (p.expand['chat_id'] != null) {
            final chatData = p.expand['chat_id']!.first as RecordModel;
            // Kendi katılımcı kaydımızı (arşiv ve last read) chat nesnesine ekle (kolay işlem için)
            chatData.data['my_participant'] = p;
            chatRecords.add(chatData);
         }
      }
      
      // Chatleri updated veya son mesaja göre sırala
      chatRecords.sort((a, b) {
         return b.updated.compareTo(a.updated);
      });
          
      if (mounted) {
        setState(() {
          _chats = chatRecords.where((c) => !_pendingOperations.contains(c.id)).toList();
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
    // Yerel UI güncelemesi (Optimizasyon)
    setState(() {
      _pendingOperations.add(chatId);
      final chatIndex = _chats.indexWhere((c) => c.id == chatId);
      if (chatIndex != -1) {
         final myPart = _chats[chatIndex].data['my_participant'] as RecordModel?;
         if (myPart != null) {
            myPart.data['is_archived'] = !currentStatus;
            _chats[chatIndex].data['my_participant'] = myPart;
         }
      }
    });

    try {
      final chatIndex = _chats.indexWhere((c) => c.id == chatId);
      final myPart = _chats[chatIndex].data['my_participant'] as RecordModel?;
      if (myPart != null) {
         await PocketBaseService.client.collection('chat_participants').update(myPart.id, body: {
            'is_archived': !currentStatus
         });
      }
          
      _fetchChats(isBackground: true);
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
    } finally {
       if (mounted) {
         setState(() {
           _pendingOperations.remove(chatId);
         });
       }
    }
  }


  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;

        // Async işlemler için ayrı bir fonksiyon çağırıyoruz
        _handleBackNavigation();
      },
      child: Scaffold(
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
                  icon: const Icon(Icons.search, size: 18), // Biraz daha küçük ikon
                  onPressed: _showUserSearchDialog,
                  tooltip: "Kullanıcı Ara",
                ),
              ),
              IconButton(
                onPressed: _refresh,
                icon: const Icon(Icons.refresh, size: 18),
                tooltip: "Sayfayı Yenile",
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
        drawer: _buildDrawer(context),
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildChatList(),
            const BlogScreen(),
            VoiceRoomsScreen(key: ValueKey(_refreshKey)),
          ],
        ),
        floatingActionButton: _buildFAB(),
      ),
    );
  }

  Future<void> _handleBackNavigation() async {
    if (_showArchived) {
      setState(() => _showArchived = false);
      return;
    }

    if (_tabController.index != 0) {
      _tabController.animateTo(0);
      return;
    }

    final exitConfirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Uygulamadan Çık'),
        content: const Text('Uygulamadan çıkmak istediğinize emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İPTAL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ÇIK', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (exitConfirmed == true && mounted) {
      SystemNavigator.pop();
    }
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
                    
                    final currentUserId = PocketBaseService.client.authStore.model!.id;

                    setStateDialog(() {
                      isSearching = true;
                      errorMessage = null;
                    });
                    
                    try {
                      final response = await PocketBaseService.client.collection('users').getFirstListItem('username = "$username"');

                      if (response.id == currentUserId) {
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
                        errorMessage = "Böyle bir kullanıcı bulunamadı.";
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
                      final userId = PocketBaseService.client.authStore.model!.id;
                      await PocketBaseService.client.collection('voice_rooms').create(body: {
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

  Future<void> _createOrOpenChat(RecordModel targetUser) async {
    try {
      final myId = PocketBaseService.client.authStore.model!.id;
      final targetId = targetUser.id;
      
      // 1. Önce bu kullanıcıyla mevcut bir özel sohbet (dm) var mı kontrol et
      final existingChatRes = await PocketBaseService.client.collection('chat_participants').getFullList(
          filter: 'user_id = "$myId"',
          expand: 'chat_id'
      );

      final myPrivateChatIds = existingChatRes
          .where((p) => p.expand['chat_id'] != null && p.expand['chat_id']!.first.data['is_group'] == false)
          .map((p) => p.getStringValue('chat_id'))
          .toList();

      if (myPrivateChatIds.isNotEmpty) {
        // filter: "chat_id ?= 'id1' || chat_id ?= 'id2' ..." is not standard, we can fetch target's participation
        final findTargetRes = await PocketBaseService.client.collection('chat_participants').getFullList(
            filter: 'user_id = "$targetId"'
        );
        
        final targetChatIds = findTargetRes.map((p) => p.getStringValue('chat_id')).toList();
        
        // Kesişim bul (ikisinin de olduğu dm odası)
        final intersection = myPrivateChatIds.toSet().intersection(targetChatIds.toSet());

        if (intersection.isNotEmpty) {
          final chatId = intersection.first;
          AppLogger.instance.info('Mevcut sohbet bulundu: $chatId');
          
          // Eger bu sohbet A kullanıcısı tarafından silinmişse (is_hidden ise), onu tekrar aktif et
          try {
             final myPart = existingChatRes.firstWhere((p) => p.getStringValue('chat_id') == chatId);
             if (myPart.getBoolValue('is_hidden')) {
               await PocketBaseService.client.collection('chat_participants').update(myPart.id, body: {
                 'is_hidden': false
               });
             }
          } catch (_) {}

          if (mounted) {
            _navigateToChat(chatId, targetUser.getStringValue('username'));
          }
          return;
        }
      }

      // 2. Mevcut sohbet yoksa yeni oluştur
      final chatRes = await PocketBaseService.client.collection('chats').create(body: {
        'is_group': false,
        'name': targetUser.getStringValue('username'), 
        'created_by': myId,
      });
      
      final chatId = chatRes.id;
      
      // Katılımcıları ekle
      await PocketBaseService.client.collection('chat_participants').create(body: {
         'chat_id': chatId, 'user_id': myId
      });
      await PocketBaseService.client.collection('chat_participants').create(body: {
         'chat_id': chatId, 'user_id': targetId
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sohbet oluşturuldu!')));
        _navigateToChat(chatId, targetUser.getStringValue('username'));
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

    final currentUserId = PocketBaseService.client.authStore.model?.id;

    final filteredChats = _chats.where((c) {
       final myPart = c.data['my_participant'] as RecordModel?;
       final isArchived = myPart != null ? (myPart.data['is_archived'] ?? false) : false;
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

    return ListView.separated(
      controller: _chatListScrollController,
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      itemCount: filteredChats.length + 1,
      separatorBuilder: (context, index) {
        if (index == 0 && (!_archivedVisible || _showArchived)) return const SizedBox.shrink();
        return const Divider(height: 1, color: Colors.white10);
      },
      itemBuilder: (context, index) {
        if (index == 0) {
          if (!_archivedVisible || _showArchived) return const SizedBox.shrink();
          return _buildArchiveToggle();
        }
        
        final chat = filteredChats[index - 1];
        final myPart = chat.data['my_participant'] as RecordModel?;
        final isArchived = myPart != null ? (myPart.data['is_archived'] ?? false) : false;
        
        String? targetUserId;
        String? lastReadId;
        String displayChatName = chat.getStringValue('name');
        if (displayChatName.isEmpty) displayChatName = 'İsimsiz Sohbet';

        final participants = chat.expand['chat_participants_via_chat_id'] ?? [];
        final messages = chat.expand['messages_via_chat_id'] ?? [];

        if (chat.getBoolValue('is_group') == false) {
          for (var p in participants) {
            final uid = p.getStringValue('user_id');
            if (uid != currentUserId) {
              targetUserId = uid;
              if (p.expand['user_id'] != null) {
                 displayChatName = p.expand['user_id']!.first.getStringValue('username');
              }
            } else {
              lastReadId = p.getStringValue('last_read_message_id');
            }
          }
        } else {
          for (var p in participants) {
            if (p.getStringValue('user_id') == currentUserId) {
              lastReadId = p.getStringValue('last_read_message_id');
            }
          }
        }
        
        // Sorting messages ascending originally means last is at end.
        // If sorting descending then last is first. Let's find latest by created date.
        messages.sort((a, b) => b.created.compareTo(a.created)); 
        final lastMessage = messages.isNotEmpty ? messages.first : null;
        
        String subtitleText = 'Sohbete gitmek için dokunun';
        bool isUnread = false;
        
        if (lastMessage != null) {
           final content = lastMessage.getStringValue('content');
           subtitleText = content.startsWith('[VOICE]') ? 'Sesli Mesaj' : content;
           
           if (lastMessage.getStringValue('sender_id') != currentUserId) {
              if (lastReadId == null || lastReadId != lastMessage.id) {
                 isUnread = true;
              }
           }
        }
        
        final semanticUnreadSuffix = isUnread ? "Okunmamış yeni mesajınız var." : "";
        final semanticSubtitle = lastMessage != null ? "Son mesaj: $subtitleText." : "";
        
        return Semantics(
          label: "$displayChatName. $semanticSubtitle $semanticUnreadSuffix",
          button: true,
          onTapHint: "Sohbeti açmak için çift dokunun",
          customSemanticsActions: {
            CustomSemanticsAction(label: isArchived ? 'Arşivden Çıkar' : 'Arşivle'): () {
              _toggleArchive(chat.id, isArchived);
            },
            CustomSemanticsAction(label: 'Sohbeti Sil'): () {
              _confirmDeleteChat(chat);
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
                          displayChatName.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join(''),
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
              displayChatName,
              style: TextStyle(fontWeight: isUnread ? FontWeight.w900 : FontWeight.bold, fontSize: 16),
            ),
            subtitle: Row(
              children: [
                if (lastMessage != null && lastMessage.getStringValue('sender_id') == currentUserId) ...[
                  _buildSmallReadStatus(chat, lastMessage),
                  const SizedBox(width: 4),
                ],
                Expanded(
                  child: Text(
                    subtitleText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14, 
                      color: isUnread ? Colors.white : Colors.grey, 
                      fontWeight: isUnread ? FontWeight.bold : FontWeight.normal
                    ),
                  ),
                ),
              ],
            ),
            trailing: const Icon(Icons.chevron_right),
            onLongPress: () {
              _showChatOptions(chat);
            },
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  // Pass a simple map to ChatDetailScreen to simulate how it used it
                  builder: (context) => ChatDetailScreen(chat: {'id': chat.id, 'name': displayChatName, 'is_group': chat.getBoolValue('is_group')}),
                ),
              );
              _fetchChats();
            },
          ),
        );
      },
    );
  }

  Widget _buildArchiveToggle() {
    final currentUserId = PocketBaseService.client.authStore.model?.id;
    final archivedCount = _chats.where((c) {
      final myPart = c.data['my_participant'] as RecordModel?;
      return myPart != null ? (myPart.data['is_archived'] == true) : false;
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

  void _showChatOptions(RecordModel chat) {
    final currentUserId = PocketBaseService.client.authStore.model?.id;
    final myPart = chat.data['my_participant'] as RecordModel?;
    final isArchived = myPart != null ? (myPart.data['is_archived'] ?? false) : false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  ListTile(
                    leading: Icon(isArchived ? Icons.unarchive : Icons.archive),
                    title: Text(isArchived ? 'Arşivden Çıkar' : 'Arşivle'),
                    onTap: () {
                      Navigator.pop(context);
                      _toggleArchive(chat.id, isArchived);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.delete_outline, color: Colors.red),
                    title: const Text('Sohbeti Sil', style: TextStyle(color: Colors.red)),
                    onTap: () {
                      Navigator.pop(context);
                      _confirmDeleteChat(chat);
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      }
    );
  }

  Widget _buildDrawer(BuildContext context) {
    final user = PocketBaseService.client.authStore.model;
    final email = user?.getStringValue('email') ?? 'Hesap Bilgisi Yok';
    
    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            accountName: const Text('Blind Social'),
            accountEmail: Text(email),
            currentAccountPicture: const CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(Icons.person, color: Color(0xFF075E54), size: 40),
            ),
            decoration: const BoxDecoration(
              color: Color(0xFF075E54),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('Profilim'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const MyProfileScreen()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.star_outline),
            title: const Text('Yıldızlı Mesajlar'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const FavoriteMessagesScreen()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: const Text('Uygulama Ayarları'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const AppSettingsScreen()));
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.bug_report_outlined),
            title: const Text('Geliştirici Modu / Loglar'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const DeveloperLogsScreen()));
            },
          ),
          const Spacer(),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Versiyon 1.0.0',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmallReadStatus(RecordModel chat, RecordModel lastMessage) {
    final currentUserId = PocketBaseService.client.authStore.model?.id;
    final participants = chat.expand['chat_participants_via_chat_id'] ?? [];
    
    String? otherLastReadId;
    for (var p in participants) {
      if (p.getStringValue('user_id') != currentUserId) {
        otherLastReadId = p.getStringValue('last_read_message_id');
        break;
      }
    }

    // Basitleştirilmiş karşılaştırma: Son mesaj okunan mesaj ise veya ondan önceyse
    // List screen'de tüm mesaj listesi elimizde olmadığı için sadece son mesaj-okunan ID eşitliğini kontrol ediyoruz.
    // Gelişmiş durumda 'messages' listesindeki sıralamaya bakılabilir.
    // Ancak genellikle lastMessage okunduysa isRead true'dur.
    
    bool isRead = otherLastReadId != null && otherLastReadId == lastMessage.id;
    
    return Icon(
      isRead ? Icons.done_all : Icons.done,
      size: 14,
      color: isRead ? Colors.blueAccent : Colors.grey,
    );
  }

  void _confirmDeleteChat(RecordModel chat) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sohbeti Silinecek'),
        content: const Text('Bu sohbeti silmek istediğinize emin misiniz? Bu işlem geri alınamaz.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İPTAL'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteChat(chat.id);
            },
            child: const Text('SİL', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteChat(String chatId) async {
    // Yerel UI güncellemesi (Anlık tepki için)
    setState(() {
      _isDeleting = true;
      _pendingOperations.add(chatId);
      _chats.removeWhere((c) => c.id == chatId);
    });

    try {
      final myId = PocketBaseService.client.authStore.model!.id;
      final myPart = await PocketBaseService.client.collection('chat_participants').getFirstListItem('chat_id = "$chatId" && user_id = "$myId"');
      
      // Önce yerel önbelleği temizleyelim ki girince eskiler gözükmesin
      ChatDetailScreen.clearCache(chatId);
      
      // WhatsApp mantığı: sohbet odasını veya katılımcıyı tamamen silmek yerine katılımcı listesinde kendimiz için "is_hidden" işaretliyoruz.
      // Eşzamanlı olarak geçmiş mesajları görmemek için "cleared_at" ayarlıyoruz. 
      await PocketBaseService.client.collection('chat_participants').update(myPart.id, body: {
         'is_hidden': true,
         'cleared_at': DateTime.now().toUtc().toIso8601String() 
      });
      
      _fetchChats(isBackground: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sohbet silindi.')));
      }
    } catch (e) {
      AppLogger.instance.error('Sohbet silme hatası: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sohbet silinemedi: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
           _isDeleting = false;
           _pendingOperations.remove(chatId);
        });
      }
    }
  }
}
