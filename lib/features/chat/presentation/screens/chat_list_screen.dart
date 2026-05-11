import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:blind_social/core/services/pocketbase_service.dart';
import 'package:blind_social/core/utils/pb_cache_manager.dart';
import 'package:blind_social/core/localization/languages/language.dart';
import 'package:pocketbase/pocketbase.dart' hide SettingsService;
import 'package:blind_social/features/chat/presentation/widgets/chat_list_item.dart';
import 'package:blind_social/features/profile/presentation/screens/my_profile_screen.dart';
import 'package:blind_social/features/profile/presentation/screens/user_profile_screen.dart';
import 'package:blind_social/features/profile/presentation/screens/friend_requests_screen.dart';
import 'package:blind_social/features/profile/presentation/screens/app_settings_screen.dart';
import 'package:blind_social/features/developer/presentation/screens/developer_logs_screen.dart';
import 'package:blind_social/core/utils/json_utils.dart';
import 'package:blind_social/features/games/presentation/screens/games_screen.dart' as blind_social_games;
import 'package:blind_social/features/games/presentation/screens/quiz_game_screen.dart' as quiz_game;
import 'package:blind_social/core/providers/localization_provider.dart';
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
import 'select_contact_screen.dart';
import 'call_screen.dart';
import 'favorite_messages_screen.dart';
import 'archived_messages_screen.dart';
import 'package:blind_social/features/campaigns/presentation/screens/campaigns_screen.dart';
import '../../../radio/presentation/screens/radio_list_screen.dart';
import 'package:blind_social/features/tools/presentation/screens/tools_screen.dart' as blind_social_tools;

class ChatListScreen extends ConsumerWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(localizationProvider);
    return const _ChatListScreenContent();
  }
}

class _ChatListScreenContent extends ConsumerStatefulWidget {
  const _ChatListScreenContent();

  @override
  ConsumerState<_ChatListScreenContent> createState() => _ChatListScreenContentState();
}

class _ChatListScreenContentState extends ConsumerState<_ChatListScreenContent> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _refreshKey = 0;
  
  List<RecordModel> _chats = [];
  bool _isLoadingChats = true;
  bool _isDeleting = false;
  bool _showArchived = false;
  final Set<String> _pendingOperations = {}; 
  final Map<String, String> _userNameCache = {};
  Timer? _pollingTimer;
  Timer? _fetchDebounceTimer;

  void _debouncedFetchChats() {
    if (!mounted) return;
    _fetchDebounceTimer?.cancel();
    _fetchDebounceTimer = Timer(const Duration(milliseconds: 2500), () {
      if (mounted) _fetchChats(isBackground: true);
    });
  }

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
    _pollingTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      _fetchChats(isBackground: true);
    });
    
    _chatListScrollController.addListener(_scrollListener);
  }

  Future<void> _checkPendingGameInvites() async {
    try {
      final myId = PocketBaseService.client.authStore.model?.id;
      if (myId == null) return;
      final lang = ref.read(localizationProvider);

      final pendingGames = await PocketBaseService.client.collection('quiz_games').getList(
        filter: 'player2_id = "$myId" && status = "waiting"',
      );
      for (var game in pendingGames.items) {
        String inviterName = lang.unnamed;
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
                String senderName = 'Bir Kullanıcı';
                if (_userNameCache.containsKey(senderId)) {
                   senderName = _userNameCache[senderId]!;
                } else {
                   final senderRecord = await PocketBaseService.client.collection('users').getOne(senderId);
                   senderName = senderRecord.getStringValue('username');
                   if (mounted) {
                     setState(() {
                       _userNameCache[senderId] = senderName;
                     });
                   }
                }
                
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
       _debouncedFetchChats();
    });

    // Sohbet eklendiğinde
    _realtimeChatsUnsub = await PocketBaseService.client.collection('chats').subscribe('*', (e) {
       _debouncedFetchChats();
    });

    // Katılımcı eklendiğinde
    _realtimeParticipantsUnsub = await PocketBaseService.client.collection('chat_participants').subscribe('*', (e) {
       _debouncedFetchChats();
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
    final lang = ref.read(localizationProvider);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(lang.gameInviteTitle),
          content: Text('$inviterName ${lang.gameInviteDesc}'),
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
              child: Text(lang.reject),
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
              child: Text(lang.accept),
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
    _fetchDebounceTimer?.cancel();
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
      List<RecordModel> myParticipants = [];
      final cacheStr = 'user_id_participants';
      
      final cachedParticipants = await PbCacheManager.getList('chat_participants', cacheStr, maxAge: const Duration(seconds: 15));
      
      if (cachedParticipants != null && cachedParticipants.isNotEmpty) {
          myParticipants = cachedParticipants;
      } else {
        try {
          myParticipants = await PocketBaseService.client.collection('chat_participants').getFullList(
             filter: 'user_id = "$userId"',
             expand: 'chat_id,chat_id.chat_participants_via_chat_id,chat_id.chat_participants_via_chat_id.user_id,chat_id.messages_via_chat_id',
             headers: kIsWeb ? {'Cache-Control': 'no-cache', 'Pragma': 'no-cache'} : const {},
          ).timeout(const Duration(seconds: 15));
          await PbCacheManager.saveList('chat_participants', cacheStr, myParticipants);
        } catch (e) {
          if (!hasInternet || loadedFromCache) {
            final fallback = await PbCacheManager.getList('chat_participants', cacheStr);
            if (fallback != null && fallback.isNotEmpty) {
               myParticipants = fallback;
            } else {
               rethrow;
            }
          } else {
            rethrow;
          }
        }
      }
      
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

      // Toplu olarak eksik katılımcıları çek (N+1 sorgu problemini çözer)
      List<String> missingChatIds = [];
      for (var chat in chatRecords) {
        if (chat.getBoolValue('is_group') == false) {
           final participants = (chat.expand['chat_participants_via_chat_id'] as List<dynamic>?)?.cast<RecordModel>() ?? [];
           bool hasOther = participants.any((p) => p.getStringValue('user_id') != userId);
           if (!hasOther) {
              missingChatIds.add(chat.id);
           }
        }
      }

      if (missingChatIds.isNotEmpty) {
          try {
             // Maksimum 30 adetlik gruplar halinde tek bir seferde (batch) çekeriz.
             const int chunkSize = 30;
             for (int i = 0; i < missingChatIds.length; i += chunkSize) {
                 final end = (i + chunkSize > missingChatIds.length) ? missingChatIds.length : (i + chunkSize);
                 final chunk = missingChatIds.sublist(i, end);
                 final chunkConds = chunk.map((id) => 'chat_id = "$id"').join(' || ');
                 final filterStr = "($chunkConds) && user_id != \"$userId\"";
                 
                 final batchParts = await PocketBaseService.client.collection('chat_participants').getFullList(
                    filter: filterStr,
                    expand: 'user_id'
                 );
                 
                 for (var chat in chatRecords) {
                    final chatParts = batchParts.where((p) => p.getStringValue('chat_id') == chat.id).toList();
                    if (chatParts.isNotEmpty) {
                        List<RecordModel> participants = [];
                        if (chat.expand['chat_participants_via_chat_id'] != null) {
                           participants = List<RecordModel>.from(chat.expand['chat_participants_via_chat_id'] as List<dynamic>);
                        }
                        participants.addAll(chatParts);
                        chat.expand['chat_participants_via_chat_id'] = participants;
                    }
                 }
             }
          } catch(e) {
              AppLogger.instance.error('Diğer katılımcıları toplu çekerken hata: $e');
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
    final lang = ref.read(localizationProvider);
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
            content: Text(!currentStatus ? lang.chatPinnedStatus : lang.chatUnpinnedStatus),
            duration: const Duration(seconds: 2),
          )
        );
      }
    } catch (e) {
      AppLogger.instance.error('Sabitleme hatası: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${lang.error}: $e')));
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
    final lang = ref.read(localizationProvider);
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
            content: Text(!currentStatus ? lang.chatArchivedStatus : lang.chatUnarchivedStatus),
            duration: const Duration(seconds: 2),
          )
        );
      }
    } catch (e) {
      AppLogger.instance.error('Arşivleme hatası: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${lang.error}: $e')));
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
      final finalName = username.isNotEmpty ? username : fullName;
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
    final lang = ref.watch(localizationProvider);
    return PopScope(
      canPop: false,
            onPopInvoked: (didPop) {
              if (didPop) return;
              _handleBackNavigation();
            },
      child: Scaffold(
        appBar: AppBar(
          title: Semantics(
            label: "Blind Social ${lang.overview}",
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
              Tab(child: Semantics(label: lang.chats, excludeSemantics: true, child: Text(lang.chats))),
              Tab(child: Semantics(label: lang.blog, excludeSemantics: true, child: Text(lang.blog))),
              Tab(child: Semantics(label: lang.servers, excludeSemantics: true, child: Text(lang.servers))),
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
        floatingActionButton: _buildFAB(lang),
      ),
    );
  }

  Future<void> _handleBackNavigation() async {
    final lang = ref.read(localizationProvider);
    if (_tabController.index != 0) {
      _tabController.animateTo(0);
      return;
    }

    final exitConfirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(lang.exitAppTitle),
        content: Text(lang.exitAppConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(lang.cancelUppercase),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(lang.exit, style: const TextStyle(color: Colors.red)),
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

  Widget? _buildFAB(BaseLanguage lang) {
    if (_tabController.index == 0) {
      return FloatingActionButton(
        onPressed: () async {
          final targetUser = await Navigator.push<RecordModel>(
            context,
            MaterialPageRoute(builder: (_) => const SelectContactScreen()),
          );
          if (targetUser != null && mounted) {
            _createOrOpenChat(targetUser);
          }
        },
        backgroundColor: Theme.of(context).colorScheme.primary,
        tooltip: lang.newChatTooltip,
        child: const Icon(Icons.message, color: Colors.black),
      );
    } else if (_tabController.index == 2) {
      return FloatingActionButton(
        onPressed: () => _showCreateChatServerDialog(lang),
        backgroundColor: Theme.of(context).colorScheme.primary,
        tooltip: lang.newServerTooltip,
        child: const Icon(Icons.dns, color: Colors.black),
      );
    }
    return null;
  }

  Future<void> _showCreateChatServerDialog(BaseLanguage lang) async {
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
              title: Text(lang.createServerTitle),
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
                        decoration: InputDecoration(
                          labelText: lang.serverNameLabel,
                          hintText: lang.serverNameHint,
                          border: const OutlineInputBorder(),
                          counterText: "",
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return lang.serverNameRequired;
                          }
                          if (value.trim().length < 3) {
                            return lang.serverNameTooShort;
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      Semantics(
                        hint: lang.dropdownHint,
                        child: DropdownButtonFormField<int>(
                          value: capacity,
                          decoration: InputDecoration(
                            labelText: lang.capacityLabel,
                            border: const OutlineInputBorder(),
                          ),
                          items: [12, 24, 32, 48, 64, 128].map((int value) {
                            return DropdownMenuItem<int>(
                              value: value,
                              child: Text(lang.voiceRoomCapacity(value.toString())),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setStateDialog(() => capacity = val);
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      Theme(
                        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          title: Text(lang.securitySettings),
                          leading: const Icon(Icons.security, size: 20),
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              child: TextField(
                                controller: passwordController,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: lang.serverPasswordLabel,
                                  hintText: lang.serverPasswordHint,
                                  border: const OutlineInputBorder(),
                                  prefixIcon: const Icon(Icons.lock_outline),
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
                  child: Text(lang.cancel),
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
                           SnackBar(content: Text(lang.serverCreatedSuccess)),
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
                        errorMsg = lang.serverNameMinLength;
                      } else if (errorMsg.contains('Kullanıcı en fazla 3 adet')) {
                        errorMsg = lang.serverLimitReached;
                        shouldCloseDialog = true;
                      } else if (errorMsg.contains('Bir günde en fazla 2 adet')) {
                        errorMsg = lang.serverLimitDaily;
                        shouldCloseDialog = true;
                      } else if (errorMsg.contains('ClientException')) {
                        errorMsg = lang.serverCreateGenericError;
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
                      : Text(lang.create),
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
        final lang = ref.read(localizationProvider);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(lang.operationFailed))); // actually localized error handling is better
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
      final lang = ref.read(localizationProvider);
      return SafeArea(
        child: Column(
          children: [
            _buildTopActionButtons(),
            Expanded(
              child: Center(
                child: Text(
                  lang.emptyChatList,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
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
        final lang = ref.read(localizationProvider);
        String displayChatName = ProfanityFilter.filter(chat.getStringValue('name'));
        if (displayChatName.isEmpty) displayChatName = lang.unnamedChat;

        final participants = chat.expand['chat_participants_via_chat_id'] ?? [];
        final messages = chat.expand['messages_via_chat_id'] ?? [];

        if (chat.getBoolValue('is_group') == false) {
          for (var p in participants) {
            final uid = p.getStringValue('user_id');
            if (uid != currentUserId) {
              targetUserId = uid;
              if (p.expand['user_id'] != null && p.expand['user_id']!.isNotEmpty) {
                 final targetUserRec = p.expand['user_id']!.first;
                 displayChatName = targetUserRec.getStringValue('username');
                 if (displayChatName.isEmpty) displayChatName = targetUserRec.getStringValue('full_name');
                 if (displayChatName.isEmpty) displayChatName = lang.unnamed;
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
        
        String subtitleText = lang.tapToGoToChat;
        
        if (lastMessage != null) {
           final content = ProfanityFilter.filter(lastMessage.getStringValue('content'));
           subtitleText = content.startsWith('[VOICE]') ? lang.voiceMessage : content;
        }
        
        final semanticUnreadSuffix = unreadCount > 0 ? lang.unreadMessagesSuffix(unreadCount) : "";
        final semanticSubtitle = lastMessage != null ? lang.lastMessagePrefix(subtitleText) : "";
        
        final bool isPinned = myPart?.getBoolValue('is_pinned') == true;
        final platformActionHint = kIsWeb ? lang.platformActionHintWeb : lang.platformActionHintMobile;
        
        return Semantics(
          key: ValueKey('${chat.id}_${isArchived}_$isPinned'),
          label: "$displayChatName. $semanticSubtitle $semanticUnreadSuffix $platformActionHint",
          button: true,
          excludeSemantics: true,
          onTapHint: lang.doubleTapToOpenChat,
          onLongPressHint: lang.showOptions,
          onLongPress: () => _showChatOptions(chat),
          customSemanticsActions: {
            CustomSemanticsAction(label: isArchived ? lang.unarchiveChat : lang.archiveChat): () {
              _toggleArchive(chat.id, isArchived);
            },
            CustomSemanticsAction(label: isPinned ? lang.unpinChat : lang.pinChat): () {
               _togglePin(chat.id, isPinned);
            },
            CustomSemanticsAction(label: lang.deleteChat): () {
              _confirmDeleteChat(chat);
            },
          },
          child: ChatListItem(
            chat: chat,
            displayChatName: displayChatName,
            currentUserId: currentUserId ?? '',
            unreadCount: unreadCount,
            onTap: () async {
                if (targetUserId != null) {
                  final blocks = await PocketBaseService.client.collection('user_blocks').getFullList(
                    filter: '(blocker = "$currentUserId" && blocked = "$targetUserId") || (blocker = "$targetUserId" && blocked = "$currentUserId")',
                  );
                  if (blocks.isNotEmpty) {
                     if (context.mounted) {
                       ScaffoldMessenger.of(context).showSnackBar(
                         const SnackBar(content: Text('Aradığınız kişi bulunamadı.')), // Fakely say not found
                       );
                     }
                     return;
                  }
                }
                
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
    final lang = ref.watch(localizationProvider);
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
              label: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(lang.archivedChats),
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
              label: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(lang.favoriteMessages),
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
    final lang = ref.read(localizationProvider);
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
                    title: Text(lang.viewProfile),
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
                    title: Text(isArchived ? lang.unarchiveChat : lang.archiveChat),
                    onTap: () {
                      Navigator.pop(context);
                      _toggleArchive(chat.id, isArchived);
                    },
                  ),
                  ListTile(
                    leading: Icon(myPart?.getBoolValue('is_pinned') == true ? Icons.push_pin_outlined : Icons.push_pin),
                    title: Text(myPart?.getBoolValue('is_pinned') == true ? lang.unpinChat : lang.pinChat),
                    onTap: () {
                      Navigator.pop(context);
                      _togglePin(chat.id, myPart?.getBoolValue('is_pinned') ?? false);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.delete_outline, color: Colors.red),
                    title: Text(lang.deleteChat, style: const TextStyle(color: Colors.red)),
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

  Widget _buildDrawerSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 24, top: 16, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.grey,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    final lang = ref.read(localizationProvider);
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
          const SizedBox(height: 8),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildDrawerSectionHeader(lang.socialSection),
                _buildDrawerItem(
                  context,
                  icon: Icons.person_outline,
                  title: lang.myProfile,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(settings: const RouteSettings(name: '/profile'), builder: (_) => const MyProfileScreen()));
                  },
                ),
                _buildDrawerItem(
                  context,
                  icon: Icons.group_add_outlined,
                  title: lang.friendAndBlockedList,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(settings: const RouteSettings(name: '/friend_requests'), builder: (_) => const FriendRequestsScreen()));
                  },
                ),
                _buildDrawerItem(
                  context,
                  icon: Icons.games_outlined,
                  title: lang.gamesArea,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(settings: const RouteSettings(name: '/games'), builder: (_) => const blind_social_games.GamesScreen()));
                  },
                ),
                
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: Divider(height: 32),
                ),
                _buildDrawerSectionHeader(lang.contentAndToolsSection),
                _buildDrawerItem(
                  context,
                  icon: Icons.campaign_outlined,
                  title: lang.campaigns,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(settings: const RouteSettings(name: '/campaigns'), builder: (_) => const CampaignsScreen()));
                  },
                ),
                _buildDrawerItem(
                  context,
                  icon: Icons.radio_outlined,
                  title: lang.liveRadio,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(settings: const RouteSettings(name: '/radio'), builder: (_) => const RadioListScreen()));
                  },
                ),
                _buildDrawerItem(
                  context,
                  icon: Icons.build_circle_outlined,
                  title: lang.tools,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(settings: const RouteSettings(name: '/tools'), builder: (_) => const blind_social_tools.ToolsScreen()));
                  },
                ),

                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: Divider(height: 32),
                ),
                _buildDrawerSectionHeader(lang.systemSection),
                _buildDrawerItem(
                  context,
                  icon: Icons.settings_outlined,
                  title: lang.appSettings,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(settings: const RouteSettings(name: '/settings'), builder: (_) => const AppSettingsScreen()));
                  },
                ),
                
                if (AdminService().isAdmin()) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    child: Divider(height: 32),
                  ),
                  _buildDrawerSectionHeader(lang.administrationSection),
                  _buildDrawerItem(
                    context,
                    icon: Icons.admin_panel_settings_outlined,
                    title: lang.adminPanel,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(settings: const RouteSettings(name: '/admin'), builder: (_) => const AdminPanelScreen()));
                    },
                  ),
                  _buildDrawerItem(
                    context,
                    icon: Icons.bug_report_outlined,
                    title: lang.developerModeLogs,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(settings: const RouteSettings(name: '/logs'), builder: (_) => const DeveloperLogsScreen()));
                    },
                  ),
                ],
                const SizedBox(height: 24),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: Text(
              lang.version('1.0.0'),
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
    final lang = ref.read(localizationProvider);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(lang.deleteChatTitle),
        content: Text(lang.deleteChatConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(lang.cancelUppercase),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteChat(chat.id);
            },
            child: Text(lang.deleteUppercase, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteChat(String chatId) async {
    final lang = ref.read(localizationProvider);
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(lang.chatDeletedStatus)));
      }
    } catch (e) {
      AppLogger.instance.error('Sohbet silme hatası: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(lang.chatDeleteError(e.toString()))));
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
