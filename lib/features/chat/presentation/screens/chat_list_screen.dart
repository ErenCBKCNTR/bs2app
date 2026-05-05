import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:blind_social/core/services/pocketbase_service.dart';
import 'package:pocketbase/pocketbase.dart' hide SettingsService;
import 'package:blind_social/features/chat/presentation/widgets/chat_list_item.dart';
import 'package:blind_social/features/profile/presentation/screens/my_profile_screen.dart';
import 'package:blind_social/features/profile/presentation/screens/user_profile_screen.dart';
import 'package:blind_social/features/profile/presentation/screens/app_settings_screen.dart';
import 'package:blind_social/features/developer/presentation/screens/developer_logs_screen.dart';
import 'package:blind_social/core/utils/json_utils.dart';
import 'package:blind_social/features/games/presentation/screens/games_screen.dart' as blind_social_games;
import 'package:blind_social/features/games/presentation/screens/quiz_game_screen.dart' as quiz_game;
import 'package:blind_social/features/chat/presentation/screens/blog_screen.dart';
import 'package:blind_social/core/utils/logger.dart';
import 'package:blind_social/core/utils/profanity_filter.dart';
import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';
import 'package:blind_social/core/services/settings_service.dart';
import 'package:blind_social/features/servers/data/services/chat_server_service.dart';
import 'package:blind_social/features/servers/presentation/screens/chat_servers_screen.dart';
import 'package:blind_social/features/servers/presentation/screens/chat_server_rooms_screen.dart' as blind_social_server_rooms;
import 'package:blind_social/features/admin/presentation/screens/admin_panel_screen.dart';
import 'package:blind_social/features/admin/data/services/admin_service.dart';
import 'chat_detail_screen.dart';
import 'call_screen.dart';
import 'favorite_messages_screen.dart';
import 'archived_messages_screen.dart';
import 'package:blind_social/features/campaigns/presentation/screens/campaigns_screen.dart';
import '../../../radio/presentation/screens/radio_list_screen.dart';
import 'package:blind_social/features/tools/presentation/screens/tools_screen.dart' as blind_social_tools;

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
  bool _showArchived = false;
  final Set<String> _pendingOperations = {}; 
  final Map<String, String> _userNameCache = {};
  Timer? _pollingTimer;
  UnsubscribeFunc? _realtimeMessagesUnsub;
  UnsubscribeFunc? _realtimeChatsUnsub;
  UnsubscribeFunc? _realtimeParticipantsUnsub;
  UnsubscribeFunc? _realtimeGamesUnsub;

  final ScrollController _chatListScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() {});
    });
    
    _fetchChats();
    _checkPendingGameInvites();
    _setupRealtime();
    _pollingTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _fetchChats(isBackground: true);
    });
    
    _chatListScrollController.addListener(_scrollListener);
  }

  Future<void> _checkPendingGameInvites() async {
    try {
      final myId = PocketBaseService.client.authStore.model?.id;
      if (myId == null) return;
      final pendingGames = await PocketBaseService.client.collection('quiz_games').getList(
        filter: 'player2_id = "$myId" && status = "waiting"',
      );
      for (var game in pendingGames.items) {
        String inviterName = "Bir kullanıcı";
        try {
          final player1Id = game.getStringValue('player1_id');
          if (player1Id.isNotEmpty) {
            final user = await PocketBaseService.client.collection('users').getOne(player1Id);
            final name = user.getStringValue('username');
            if (name.isNotEmpty) {
              inviterName = name;
            }
          }
        } catch (_) {}
        if (mounted) {
          _showGameInviteDialog(game, inviterName);
        }
      }
    } catch (e) {
      AppLogger.instance.warning('Bekleyen oyunlar alınamadı: $e');
    }
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
              if (CallScreen.isInCall) {
                // Zaten görüşmede, arayan kişiye BUSY (meşgul) mesajı gönder
                AppLogger.instance.info('Kullanıcı görüşmede, gelen arama meşgule atılıyor.');
                try {
                  if (!kIsWeb) {
                    const MethodChannel('com.example.blind_social/lockscreen')
                        .invokeMethod('playTone', {'type': 'start', 'duration': 100}); // Arka planda gelen çağrı uyarı sisi
                  }
                  await PocketBaseService.client.collection('messages').update(msg.id, body: {
                     'content': '[CALL_BUSY]',
                  });
                } catch (e) {
                   AppLogger.instance.error('Meşgul mesajı gönderilemedi: $e');
                }
                return;
              }

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
                      messageId: msg.id,
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

    _realtimeGamesUnsub = await PocketBaseService.client.collection('quiz_games').subscribe('*', (e) async {
      if (e.action == 'create' && e.record != null) {
        final r = e.record!;
        if (r.getStringValue('player2_id') == myId && r.getStringValue('status') == 'waiting') {
           String inviterName = "Bir kullanıcı";
           try {
             final player1Id = r.getStringValue('player1_id');
             if (player1Id.isNotEmpty) {
               final user = await PocketBaseService.client.collection('users').getOne(player1Id);
               final name = user.getStringValue('username');
               if (name.isNotEmpty) {
                 inviterName = name;
               }
             }
           } catch (_) {}
           _showGameInviteDialog(r, inviterName);
        }
      }
    });
  }

  void _showGameInviteDialog(RecordModel game, String inviterName) {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Oyun İsteği'),
          content: Text('$inviterName isimli kullanıcı size bilgi yarışması için oyun daveti gönderdi.'),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                try {
                  await PocketBaseService.client.collection('quiz_games').update(game.id, body: {
                    'status': 'finished'
                  });
                } catch (_) {}
              },
              child: const Text('Reddet'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                try {
                  await PocketBaseService.client.collection('quiz_games').update(game.id, body: {
                    'status': 'active'
                  });
                  if (mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => quiz_game.QuizGameScreen(gameId: game.id, isSinglePlayer: false)),
                    );
                  }
                } catch (e) {
                  AppLogger.instance.error('Game accept error: $e');
                }
              },
              child: const Text('Kabul Et'),
            ),
          ],
        );
      }
    );
  }

  void _scrollListener() {                
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _realtimeMessagesUnsub?.call();
    _realtimeChatsUnsub?.call();
    _realtimeParticipantsUnsub?.call();
    _realtimeGamesUnsub?.call();
    _tabController.dispose();
    _chatListScrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchChats({bool isBackground = false}) async {
    if (_isDeleting && isBackground) return; 
    
    try {
      final userId = PocketBaseService.client.authStore.model?.id;
      if (userId == null) {
        if (mounted && !isBackground) setState(() => _isLoadingChats = false);
        return;
      }

      // 1. Önce önbellekten yükle
      bool loadedFromCache = false;
      if (!isBackground && _chats.isEmpty) {
        try {
          final prefs = await SharedPreferences.getInstance();
          final cachedChatsStr = prefs.getString('cached_chat_list_$userId');
          if (cachedChatsStr != null) {
            final List<dynamic> decoded = jsonDecode(cachedChatsStr);
            if (mounted) {
              setState(() {
                final parsedChats = <RecordModel>[];
                for (var e in decoded) {
                  try {
                    final eMap = e as Map<String, dynamic>;
                    RecordModel chat;
                    
                    if (eMap.containsKey('chat')) {
                      final chatRaw = eMap['chat'] as Map<String, dynamic>;
                      chat = JsonUtils.deeplyDeserializeRecord(chatRaw);
                      if (eMap['my_participant'] != null) {
                        chat.data['my_participant'] = JsonUtils.deeplyDeserializeRecord(eMap['my_participant'] as Map<String, dynamic>);
                      }
                    } else {
                      chat = JsonUtils.deeplyDeserializeRecord(eMap);
                      if (chat.data['my_participant'] != null && chat.data['my_participant'] is Map) {
                        chat.data['my_participant'] = JsonUtils.deeplyDeserializeRecord(Map<String, dynamic>.from(chat.data['my_participant']));
                      }
                    }
                    parsedChats.add(chat);
                  } catch (itemErr) {
                    AppLogger.instance.error('Tekil sohbet çözme hatası: \$itemErr');
                  }
                }
                _chats = parsedChats;
                _isLoadingChats = false;
              });
              loadedFromCache = true;
            }
          }
        } catch (e) {
          AppLogger.instance.error('Sohbet önbelleği okuma hatası: $e');
        }
      }
      
      // İnternet kontrolü yap (Kullanıcı talebi: İnternetsiz açıldığında API denemesin)
      bool hasInternet = true;
      if (!kIsWeb) {
        try {
          final result = await InternetAddress.lookup('api.cabukcan.com').timeout(const Duration(seconds: 3));
          if (result.isEmpty || result[0].rawAddress.isEmpty) {
            hasInternet = false;
          }
        } catch (_) {
          hasInternet = false;
        }
      }

      if (!hasInternet && loadedFromCache) {
        AppLogger.instance.info('İnternet bağlantısı yok, var olan önbellek kullanılacak.');
        return;
      }
      
      // PocketBase'de önce kullanıcının katılımcı olduğu chat ID'lerini bulalım.
      final myParticipants = await PocketBaseService.client.collection('chat_participants').getFullList(
         filter: 'user_id = "$userId"',
         expand: 'chat_id,chat_id.chat_participants_via_chat_id,chat_id.chat_participants_via_chat_id.user_id,chat_id.messages_via_chat_id',
         headers: kIsWeb ? {'Cache-Control': 'no-cache', 'Pragma': 'no-cache'} : const {},
      ).timeout(const Duration(seconds: 15));
      
      List<RecordModel> chatRecords = [];
      for(var p in myParticipants) {
         if (p.getBoolValue('is_hidden')) continue;
         if (p.expand['chat_id'] != null && p.expand['chat_id']!.isNotEmpty) {
            final chatData = p.expand['chat_id']!.first as RecordModel;
            // Kendi katılımcı kaydımızı (arşiv ve last read) chat nesnesine ekle (kolay işlem için)
            chatData.data['my_participant'] = p;
            chatRecords.add(chatData);
         }
      }

      // Fetch missing side participants for 1-1 chats (If expand was blocked by rule limit)
      for (var chat in chatRecords) {
        if (chat.getBoolValue('is_group') == false) {
           final participants = (chat.expand['chat_participants_via_chat_id'] as List<dynamic>?)?.cast<RecordModel>() ?? [];
           bool hasOther = participants.any((p) => p.getStringValue('user_id') != userId);
           if (!hasOther) {
              try {
                final otherParts = await PocketBaseService.client.collection('chat_participants').getFullList(
                  filter: 'chat_id = "${chat.id}" && user_id != "$userId"',
                  expand: 'user_id'
                );
                if (otherParts.isNotEmpty) {
                   participants.addAll(otherParts);
                   chat.expand['chat_participants_via_chat_id'] = participants;
                }
              } catch (e) {
                 AppLogger.instance.error('Diğer katılımcıyı çekerken hata: $e');
              }
           }
        }
      }
      
      // Chatleri sabitlemeye ve güncellenme tarihine göre sırala
      chatRecords.sort((a, b) {
         final dynamic aPartRaw = a.data['my_participant'];
         final dynamic bPartRaw = b.data['my_participant'];
         
         if (aPartRaw is! RecordModel || bPartRaw is! RecordModel) return 0;
         
         final aPinned = aPartRaw.getBoolValue('is_pinned');
         final bPinned = bPartRaw.getBoolValue('is_pinned');

         if (aPinned != bPinned) {
           return aPinned ? -1 : 1;
         }
         return b.updated.compareTo(a.updated);
      });
          
      if (mounted) {
        setState(() {
          _chats = chatRecords.where((c) => !_pendingOperations.contains(c.id)).toList();
          _isLoadingChats = false;
        });
        
        // Yenisini önbelleğe al
        try {
          final prefs = await SharedPreferences.getInstance();
          final encoded = jsonEncode(_chats.map((e) {
            final myPart = e.data['my_participant'] as RecordModel?;
            return {
              'chat': JsonUtils.deeplySerializeRecord(e),
              'my_participant': myPart != null ? JsonUtils.deeplySerializeRecord(myPart) : null,
            };
          }).toList());
          prefs.setString('cached_chat_list_$userId', encoded);
        } catch(e) {
          AppLogger.instance.error('Sohbet önbelleği yazma hatası: $e');
        }
      }
    } catch (e) {
      if (!isBackground) {
        AppLogger.instance.error('Sohbetler yüklenirken hata: $e');
        if (mounted) {
          setState(() => _isLoadingChats = false);
        }
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

  Future<void> _togglePin(String chatId, bool currentStatus) async {
    setState(() {
      _pendingOperations.add(chatId);
      final chatIndex = _chats.indexWhere((c) => c.id == chatId);
      if (chatIndex != -1) {
         final myPart = _chats[chatIndex].data['my_participant'] as RecordModel?;
         if (myPart != null) {
            myPart.data['is_pinned'] = !currentStatus;
            _chats[chatIndex].data['my_participant'] = myPart;
         }
      }
    });

    try {
      final chatIndex = _chats.indexWhere((c) => c.id == chatId);
      final myPart = _chats[chatIndex].data['my_participant'] as RecordModel?;
      if (myPart != null) {
         await PocketBaseService.client.collection('chat_participants').update(myPart.id, body: {
            'is_pinned': !currentStatus
         });
      }
           
      _fetchChats(isBackground: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(!currentStatus ? 'Sohbet sabitlendi' : 'Sohbet sabitlemesi kaldırıldı'),
            duration: const Duration(seconds: 2),
          )
        );
      }
    } catch (e) {
      AppLogger.instance.error('Sabitleme hatası: $e');
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


  Future<void> _fetchUserAndCache(String userId) async {
    if (_userNameCache.containsKey(userId)) return;
    try {
      final user = await PocketBaseService.client.collection('users').getOne(userId);
      final fullName = user.getStringValue('full_name');
      final username = user.getStringValue('username');
      final finalName = fullName.isNotEmpty ? fullName : username;
      if (mounted) {
        setState(() {
          _userNameCache[userId] = finalName;
        });
      }
    } catch (e) {
      AppLogger.instance.error('Kullanıcı bilgisi alınamadı: $e');
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
          title: Semantics(
            label: "Blind Social Ana Sayfa",
            header: true,
            child: const Text(
              'Blind Social',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
          ),
          actions: const [],
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: Theme.of(context).colorScheme.primary,
            labelColor: Theme.of(context).colorScheme.primary,
            unselectedLabelColor: Colors.grey,
            tabs: [
              Tab(child: Semantics(label: "Sohbetler", excludeSemantics: true, child: const Text("Sohbetler"))),
              Tab(child: Semantics(label: "Blog", excludeSemantics: true, child: const Text("Blog"))),
              Tab(child: Semantics(label: "Sunucular", excludeSemantics: true, child: const Text("Sunucular"))),
            ],
          ),
        ),
        drawer: _buildDrawer(context),
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildChatList(),
            const BlogScreen(),
            ChatServersScreen(key: ValueKey(_refreshKey)),
          ],
        ),
        floatingActionButton: _buildFAB(),
      ),
    );
  }

  Future<void> _handleBackNavigation() async {
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
      if (kIsWeb) {
        // Web'de tamamen çıkış yapmak zor, o yüzden sadece root sayfaya yönlendiriyoruz veya kapatmaya çalışıyoruz
        // Tarayıcı sekmesini kapat
        // Eğer kapatamıyorsa google'a yolla
        PocketBaseService.client.authStore.clear(); // Opsiyonel
        Navigator.pop(context); // Bu da muhtemelen hiçbir işe yaramayacak ama kIsWeb kontrolü kalması iyi
      } else {
        SystemNavigator.pop();
      }
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
        onPressed: _showCreateChatServerDialog,
        backgroundColor: Theme.of(context).colorScheme.primary,
        tooltip: "Yeni Sohbet Sunucusu Oluştur",
        child: const Icon(Icons.dns, color: Colors.black),
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
                    maxLength: 32,
                    decoration: InputDecoration(
                      labelText: 'Kullanıcı Adı',
                      hintText: 'Örn: ahmet123',
                      border: const OutlineInputBorder(),
                      errorText: errorMessage,
                      counterText: "",
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

  Future<void> _showCreateChatServerDialog() async {
    final titleController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    int capacity = 24;
    bool isSaving = false;
    final passwordController = TextEditingController();
    
    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Yeni Sohbet Sunucusu'),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: titleController,
                        autofocus: true,
                        maxLength: 32,
                        decoration: const InputDecoration(
                          labelText: 'Sunucu Adı',
                          hintText: 'Örn: Blind Social Dostlar',
                          border: OutlineInputBorder(),
                          counterText: "",
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Sunucu adı boş olamaz';
                          }
                          if (value.trim().length < 3) {
                            return 'Sunucu adı 3 karakterden kısa olamaz';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<int>(
                        value: capacity,
                        decoration: const InputDecoration(
                          labelText: 'Kişi Kapasitesi',
                          border: OutlineInputBorder(),
                        ),
                        items: [12, 24, 32, 48, 64, 128].map((int value) {
                          return DropdownMenuItem<int>(
                            value: value,
                            child: Text('$value Kişilik'),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setStateDialog(() => capacity = val);
                        },
                      ),
                      const SizedBox(height: 8),
                      Theme(
                        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          title: const Text('Güvenlik Ayarları'),
                          leading: const Icon(Icons.security, size: 20),
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              child: TextField(
                                controller: passwordController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Sunucu Şifresi (Numara)',
                                  hintText: 'Şifresiz için boş bırakın',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.lock_outline),
                                ),
                              ),
                            ),
                          ],
                        ),
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
                    
                    final name = titleController.text.trim();
                    final password = passwordController.text.trim();
                    
                    setStateDialog(() => isSaving = true);
                    
                    try {
                      final createdServer = await ChatServerService().createServer(
                        name: name,
                        description: '', // Açıklama varsayılan olarak boş
                        capacity: capacity,
                        canMembersCreateRooms: false, // Varsayılan olarak kapalı
                        password: password,
                      );
                      
                      if (context.mounted) {
                        Navigator.pop(context); // Dialogu kapat
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Sunucu başarıyla oluşturuldu!')),
                        );
                        
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => blind_social_server_rooms.ChatServerRoomsScreen(server: createdServer),
                          ),
                        ).then((_) {
                           _refresh(); 
                        });
                      }
                    } catch (e) {
                      AppLogger.instance.error('Sunucu oluşturulurken hata: $e');
                      setStateDialog(() => isSaving = false);
                      
                      String errorMsg = e.toString();
                      bool shouldCloseDialog = false;
                      
                      if (errorMsg.contains('validation_min_text_constraint')) {
                        errorMsg = 'Sunucu adı en az 3 karakter olmalıdır.';
                      } else if (errorMsg.contains('Kullanıcı en fazla 3 adet')) {
                        errorMsg = 'Kullanıcı en fazla 3 adet sunucu oluşturabilir';
                        shouldCloseDialog = true;
                      } else if (errorMsg.contains('Bir günde en fazla 2 adet')) {
                        errorMsg = 'Bir günde en fazla 2 adet sunucu oluşturabilirsiniz';
                        shouldCloseDialog = true;
                      } else if (errorMsg.contains('ClientException')) {
                        errorMsg = 'Sunucu oluşturulamadı. Lütfen tekrar deneyin.';
                      }

                      if (context.mounted) {
                        if (shouldCloseDialog) {
                           Navigator.pop(context); // Limite takıldıysa pencereyi kapat
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(errorMsg)),
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
       return _showArchived ? isArchived : !isArchived;
    }).toList();

    if (_chats.isEmpty) {
      return SafeArea(
        child: Column(
          children: [
            _buildTopActionButtons(),
            const Expanded(
              child: Center(
                child: Text(
                  'Henüz bir sohbetiniz yok.\nYeni bir sohbet başlatın.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return SafeArea(
      child: ListView.separated(
addAutomaticKeepAlives: false,
addRepaintBoundaries: true,
        controller: _chatListScrollController,
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        itemCount: filteredChats.length + 1,
        separatorBuilder: (context, index) {
          if (index == 0) return const SizedBox.shrink();
          return const Divider(height: 1, color: Colors.white10);
        },
      itemBuilder: (context, index) {
        if (index == 0) {
          return _buildTopActionButtons();
        }
        
        final chat = filteredChats[index - 1];
        final myPart = chat.data['my_participant'] as RecordModel?;
        final isArchived = myPart != null ? (myPart.data['is_archived'] ?? false) : false;
        
        String? targetUserId;
        String? lastReadId;
        String displayChatName = ProfanityFilter.filter(chat.getStringValue('name'));
        if (displayChatName.isEmpty) displayChatName = 'İsimsiz Sohbet';

        final participants = chat.expand['chat_participants_via_chat_id'] ?? [];
        final messages = chat.expand['messages_via_chat_id'] ?? [];

        if (chat.getBoolValue('is_group') == false) {
          for (var p in participants) {
            final uid = p.getStringValue('user_id');
            if (uid != currentUserId) {
              targetUserId = uid;
              if (p.expand['user_id'] != null && p.expand['user_id']!.isNotEmpty) {
                 final targetUserRec = p.expand['user_id']!.first;
                 displayChatName = targetUserRec.getStringValue('full_name');
                 if (displayChatName.isEmpty) displayChatName = targetUserRec.getStringValue('username');
              } else {
                 if (_userNameCache.containsKey(uid)) {
                   displayChatName = _userNameCache[uid]!;
                 } else {
                   _fetchUserAndCache(uid);
                 }
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
        final filteredMessages = messages.where((m) {
           final content = m.getStringValue('content');
           return !content.contains('CALL_');
        }).toList();
        final lastMessage = filteredMessages.isNotEmpty ? filteredMessages.first : null;
        
        // Calculate unread count
        int unreadCount = 0;
        final lastReadMessage = messages.firstWhere(
          (m) => m.id == lastReadId,
          orElse: () => RecordModel()
        );
        final lastReadTime = lastReadMessage.id.isNotEmpty ? DateTime.parse(lastReadMessage.created) : DateTime(0);
        
        for (var msg in messages) {
           if (msg.getStringValue('sender_id') != currentUserId) {
              final msgTime = DateTime.parse(msg.created);
              if (msgTime.isAfter(lastReadTime)) {
                unreadCount++;
              }
           }
        }
        
        String subtitleText = 'Sohbete gitmek için dokunun';
        
        if (lastMessage != null) {
           final content = ProfanityFilter.filter(lastMessage.getStringValue('content'));
           subtitleText = content.startsWith('[VOICE]') ? 'Sesli Mesaj' : content;
        }
        
        final semanticUnreadSuffix = unreadCount > 0 ? "Okunmamış $unreadCount yeni mesajınız var." : "";
        final semanticSubtitle = lastMessage != null ? "Son mesaj: $subtitleText." : "";
        
        final bool isPinned = myPart?.getBoolValue('is_pinned') == true;
        final platformActionHint = kIsWeb ? "İşlem menüsü için uzun basın." : "İşlem seçenekleri için parmağınızı yukarı ya da aşağı kaydırın.";
        
        return Semantics(
          key: ValueKey('${chat.id}_${isArchived}_$isPinned'),
          label: "$displayChatName. $semanticSubtitle $semanticUnreadSuffix $platformActionHint",
          button: true,
          excludeSemantics: true,
          onTapHint: "Sohbeti açmak için çift dokunun",
          onLongPressHint: "Seçenekleri Göster",
          onLongPress: () => _showChatOptions(chat),
          customSemanticsActions: {
            CustomSemanticsAction(label: isArchived ? 'Arşivden Çıkar' : 'Arşivle'): () {
              _toggleArchive(chat.id, isArchived);
            },
            CustomSemanticsAction(label: isPinned ? 'Sabitlemeden Çıkar' : 'Sabitle'): () {
               _togglePin(chat.id, isPinned);
            },
            CustomSemanticsAction(label: 'Sohbeti Sil'): () {
              _confirmDeleteChat(chat);
            },
          },
          child: ChatListItem(
            chat: chat,
            currentUserId: currentUserId ?? '',
            unreadCount: unreadCount,
            onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChatDetailScreen(chat: {'id': chat.id, 'name': displayChatName, 'is_group': chat.getBoolValue('is_group')}),
                  ),
                );
                _fetchChats();
            },
            onLongPress: () => _showChatOptions(chat),
            onArchive: () => _toggleArchive(chat.id, isArchived),
            onDelete: () => _confirmDeleteChat(chat),
            onPin: () => _togglePin(chat.id, myPart?.getBoolValue('is_pinned') ?? false),
          ),
        );
      },
    ),
  );
}

  Widget _buildTopActionButtons() {
    final currentUserId = PocketBaseService.client.authStore.model?.id;
    final archivedCount = _chats.where((c) {
      final myPart = c.data['my_participant'] as RecordModel?;
      return myPart != null ? (myPart.data['is_archived'] == true) : false;
    }).length;

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const ArchivedMessagesScreen()));
              },
              icon: const Icon(Icons.archive, size: 18),
              label: const FittedBox(
                fit: BoxFit.scaleDown,
                child: Text("Arşivlenmiş Sohbetler"),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const FavoriteMessagesScreen()));
              },
              icon: const Icon(Icons.star, size: 18),
              label: const FittedBox(
                fit: BoxFit.scaleDown,
                child: Text("Favori Mesajlar"),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showChatOptions(RecordModel chat) {
    final currentUserId = PocketBaseService.client.authStore.model?.id;
    final myPart = chat.data['my_participant'] as RecordModel?;
    final isArchived = myPart != null ? (myPart.data['is_archived'] ?? false) : false;
    
    // Sohbetin diğer katılımcısını bul
    String? targetUserId;
    final participants = chat.expand['chat_participants_via_chat_id'] ?? [];
    if (chat.getBoolValue('is_group') == false) {
      for (var p in participants) {
        final uid = p.getStringValue('user_id');
        if (uid != currentUserId) {
          targetUserId = uid;
          break;
        }
      }
    }

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
                  if (targetUserId != null)
                   ListTile(
                    leading: const Icon(Icons.person_outline),
                    title: const Text('Profili Görüntüle'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => UserProfileScreen(userId: targetUserId!),
                        ),
                      );
                    },
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
                    leading: Icon(myPart?.getBoolValue('is_pinned') == true ? Icons.push_pin_outlined : Icons.push_pin),
                    title: Text(myPart?.getBoolValue('is_pinned') == true ? 'Sabitlemeden Çıkar' : 'Sabitle'),
                    onTap: () {
                      Navigator.pop(context);
                      _togglePin(chat.id, myPart?.getBoolValue('is_pinned') ?? false);
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

  Widget _buildDrawerItem(BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isActive = false,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final activeBgColor = isDark ? Colors.teal.withOpacity(0.3) : const Color(0xFFBCE1C0);
    final activeFgColor = isDark ? Colors.tealAccent : const Color(0xFF1A5D1A);
    
    final inactiveBgColor = Colors.transparent;
    final inactiveFgColor = isDark ? Colors.white70 : Colors.black87;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: isActive ? activeBgColor : inactiveBgColor,
        borderRadius: BorderRadius.circular(30),
      ),
      child: ListTile(
        leading: Icon(icon, color: isActive ? activeFgColor : inactiveFgColor),
        title: Text(
           title,
           style: TextStyle(
             color: isActive ? activeFgColor : inactiveFgColor,
             fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
             fontSize: 16,
           ),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        onTap: onTap,
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    final user = PocketBaseService.client.authStore.model;
    final email = user?.getStringValue('email') ?? 'Hesap Bilgisi Yok';
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Drawer(
      backgroundColor: isDark ? const Color(0xFF1A232A) : theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 24,
              left: 24,
              right: 24,
              bottom: 24,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark 
                  ? const [Color(0xFF384A50), Color(0xFF263439)]
                  : [theme.primaryColor, theme.primaryColorDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                bottomRight: Radius.circular(32),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF81C784), width: 2),
                  ),
                  child: CircleAvatar(
                    radius: 36,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.person, color: isDark ? const Color(0xFF263439) : theme.primaryColor, size: 48),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Blind Social', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(email, style: const TextStyle(color: Colors.white70, fontSize: 14)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildDrawerItem(
                  context,
                  icon: Icons.person_outline,
                  title: 'Profilim',
                  isActive: true,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(settings: const RouteSettings(name: '/profile'), builder: (_) => const MyProfileScreen()));
                  },
                ),
                _buildDrawerItem(
                  context,
                  icon: Icons.settings_outlined,
                  title: 'Uygulama Ayarları',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(settings: const RouteSettings(name: '/settings'), builder: (_) => const AppSettingsScreen()));
                  },
                ),
                _buildDrawerItem(
                  context,
                  icon: Icons.campaign_outlined,
                  title: 'Kampanyalar',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(settings: const RouteSettings(name: '/campaigns'), builder: (_) => const CampaignsScreen()));
                  },
                ),
                _buildDrawerItem(
                  context,
                  icon: Icons.radio_outlined,
                  title: 'Canlı Radyo',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(settings: const RouteSettings(name: '/radio'), builder: (_) => const RadioListScreen()));
                  },
                ),
                _buildDrawerItem(
                  context,
                  icon: Icons.games_outlined,
                  title: 'Oyun Alanı',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(settings: const RouteSettings(name: '/games'), builder: (_) => const blind_social_games.GamesScreen()));
                  },
                ),
                _buildDrawerItem(
                  context,
                  icon: Icons.build_circle_outlined,
                  title: 'Araçlar',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(settings: const RouteSettings(name: '/tools'), builder: (_) => const blind_social_tools.ToolsScreen()));
                  },
                ),
                if (AdminService().isAdmin()) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: Divider(color: Colors.white24, indent: 32, endIndent: 32, height: 1),
                  ),
                  _buildDrawerItem(
                    context,
                    icon: Icons.admin_panel_settings_outlined,
                    title: 'Yönetici Paneli',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(settings: const RouteSettings(name: '/admin'), builder: (_) => const AdminPanelScreen()));
                    },
                  ),
                  _buildDrawerItem(
                    context,
                    icon: Icons.bug_report_outlined,
                    title: 'Geliştirici Modu / Loglar',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(settings: const RouteSettings(name: '/logs'), builder: (_) => const DeveloperLogsScreen()));
                    },
                  ),
                ],
                const SizedBox(height: 16),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Versiyon 1.0.0',
              textAlign: TextAlign.center,
              style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 13),
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
