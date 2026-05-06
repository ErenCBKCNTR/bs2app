import 'package:blind_social/features/chat/presentation/screens/call_screen.dart';
import 'package:blind_social/features/chat/presentation/screens/favorite_messages_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:blind_social/core/utils/json_utils.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:blind_social/core/services/pocketbase_service.dart';
import 'package:pocketbase/pocketbase.dart' hide SettingsService;
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import '../../../../core/utils/logger.dart';
import 'package:http/http.dart' as http;
import 'package:vibration/vibration.dart';
import 'package:blind_social/core/services/settings_service.dart';
import 'package:blind_social/core/utils/profanity_filter.dart';
import 'package:blind_social/core/widgets/expandable_text.dart';

import 'package:blind_social/core/widgets/chat_input_field.dart';
import 'package:blind_social/core/widgets/voice_message_widget.dart';

class ChatDetailScreen extends StatefulWidget {
  final Map<String, dynamic> chat;

  const ChatDetailScreen({super.key, required this.chat});

  static void clearCache(String chatId) {
    _ChatDetailScreenState.clearCacheForChat(chatId);
  }

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  static final Map<String, List<Map<String, dynamic>>> _messageCache = {};
  
  static void clearCacheForChat(String chatId) {
    _messageCache.remove(chatId);
  }

  final ScrollController _scrollController = ScrollController();
  final GlobalKey _unreadDividerKey = GlobalKey();
  
  late Map<String, dynamic> _chat;
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  UnsubscribeFunc? _unsub;
  late final String _myUserId;
  Map<String, dynamic>? _replyingTo;

  bool _isInitialLoad = true;
  String? _targetUserStatus;
  bool _showUserStatus = false;

  void _toggleUserStatus() async {
    if (_showUserStatus) {
      if (mounted) setState(() => _showUserStatus = false);
      return;
    }
    
    // fetch target user id
    String? targetId;
    final participants = _chat['chat_participants'] as List<dynamic>? ?? [];
    for (var p in participants) {
      if (p['user_id'] != _myUserId) {
        targetId = p['user_id'];
        break;
      }
    }
    
    if (targetId == null) {
      // try fetching details first
      await _fetchChatDetails();
      final updatedParticipants = _chat['chat_participants'] as List<dynamic>? ?? [];
      for (var p in updatedParticipants) {
        if (p['user_id'] != _myUserId) {
          targetId = p['user_id'];
          break;
        }
      }
    }

    if (targetId != null) {
      try {
        final record = await PocketBaseService.client.collection('users').getOne(targetId);
        final isOnline = record.getBoolValue('is_online');
        final hideLastSeen = record.getBoolValue('hide_last_seen');

        String status = "Bilinmiyor";
        if (hideLastSeen) {
          status = "Son görülme gizli";
        } else if (isOnline) {
          status = "Şu an aktif";
        } else {
          final lastSeenRaw = record.getStringValue('last_seen');
          final targetRaw = lastSeenRaw.isNotEmpty ? lastSeenRaw : record.updated;
          if (targetRaw.isNotEmpty) {
            final date = DateTime.parse(targetRaw).toLocal();
            final now = DateTime.now();
            if (date.year == now.year && date.month == now.month && date.day == now.day) {
               status = "Son görülme bugün ${DateFormat('HH:mm').format(date)}";
            } else {
               status = "Son görülme ${DateFormat('dd.MM.yyyy HH:mm').format(date)}";
            }
          }
        }
        
        if (mounted) {
          setState(() {
            _targetUserStatus = status;
            _showUserStatus = true;
          });
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Durum alınamadı')));
        }
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _myUserId = PocketBaseService.client.authStore.model!.id;
    _chat = Map<String, dynamic>.from(widget.chat);
    
    final chatId = _chat['id'];
    if (_messageCache.containsKey(chatId)) {
      _messages = _messageCache[chatId]!;
      // Eğer önbellek varsa loading gösterme ama fetch yapınca veriler değişirse (silme vs) güncelleme olacak
      _isLoading = false; 
    }
    
    // Eğer katılımcılar yoksa (başka ekrandan sadece id/name ile gelindiyse) çek
    if (!_chat.containsKey('chat_participants') || (_chat['chat_participants'] as List).isEmpty) {
      _fetchChatDetails();
    }
    
    // İlk yükleme
    _fetchMessages().then((_) {
      if (mounted) {
        setState(() => _isInitialLoad = false);
      }
    });

    _setupRealtime();
  }

  void _setupRealtime() async {
    final chatId = widget.chat['id'];
    final sub = await PocketBaseService.client.collection('messages').subscribe('*', (RecordSubscriptionEvent e) {
      if (e.action == 'create') {
        if (e.record!.getStringValue('chat_id') == chatId) {
          _fetchMessages(isBackground: true);
        }
      } else if (e.action == 'update' || e.action == 'delete') {
        if (e.record!.getStringValue('chat_id') == chatId) {
          _fetchMessages(isBackground: true);
        }
      }
    });
    if (!mounted) {
      sub.call();
      return;
    }
    _unsub = sub;
  }

  @override
  void dispose() {
    _unsub?.call();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchChatDetails() async {
    try {
      final response = await PocketBaseService.client.collection('chats').getOne(
        _chat['id'],
        expand: 'chat_participants_via_chat_id'
      );
      
      if (mounted) {
        setState(() {
          _chat = response.toJson();
          _chat['chat_participants'] = response.expand['chat_participants_via_chat_id']?.map((e) => e.toJson()).toList() ?? [];
        });
      }
    } catch (e) {
      AppLogger.instance.error('Sohbet detayları yüklenemedi: $e');
    }
  }

  Future<void> _fetchMessages({bool isBackground = false}) async {
    final chatId = widget.chat['id'];
    try {
      if (!isBackground && _messages.isEmpty) {
        try {
          final prefs = await SharedPreferences.getInstance();
          final cachedMsgStr = prefs.getString('cached_messages_$chatId');
          if (cachedMsgStr != null) {
            final List<dynamic> decoded = jsonDecode(cachedMsgStr);
            if (mounted) {
              setState(() {
                final parsedMessages = <Map<String, dynamic>>[];
                for (var e in decoded) {
                  try {
                    parsedMessages.add(Map<String, dynamic>.from(e as Map));
                  } catch (itemErr) {
                    AppLogger.instance.error('Tekil mesaj çözme hatası: $itemErr');
                  }
                }
                _messages = parsedMessages;
                _isLoading = false;
              });
            }
          }
        } catch (e) {
          AppLogger.instance.error('Sohbet detayı önbellek okuma hatası: $e');
        }
      }

      // İnternet kontrolü yap (Kullanıcı talebi)
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

      if (!hasInternet && _messages.isNotEmpty) {
        AppLogger.instance.info('İnternet bağlantısı yok, var olan mesaj önbelleği kullanılacak.');
        return;
      }

      String filter = 'chat_id = "$chatId"';
      
      // PoketBase'de deleted_for alanı yoksa hata vermemesi için korumalı ekliyoruz.
      // Eğer veritabanı 400 verirse bu alanı içermeyen yedek filtreye döner.
      String currentFilter = '$filter && deleted_for !~ "$_myUserId"';

      try {
        final myPart = await PocketBaseService.client.collection('chat_participants').getFirstListItem('chat_id = "$chatId" && user_id = "$_myUserId"');
        final clearedAtStr = myPart.getStringValue('cleared_at');
        if (clearedAtStr.isNotEmpty) {
          currentFilter += ' && created > "$clearedAtStr"';
          filter += ' && created > "$clearedAtStr"';
        }
      } catch (_) {}

      List<RecordModel> response;
      try {
        response = await PocketBaseService.client.collection('messages').getFullList(
            filter: currentFilter,
            sort: 'created',
            headers: kIsWeb ? {'Cache-Control': 'no-cache', 'Pragma': 'no-cache'} : const {}
        );
      } catch (e) {
        // Eğer 400 hatası (deleted_for alanı yoksa) yedek filtre ile çek
        if (e.toString().contains('400') || e.toString().contains('deleted_for')) {
          response = await PocketBaseService.client.collection('messages').getFullList(
              filter: filter,
              sort: 'created',
              headers: kIsWeb ? {'Cache-Control': 'no-cache', 'Pragma': 'no-cache'} : const {}
          );
        } else {
          rethrow;
        }
      }

      // Katılımcıların durumlarını çek
      final participantsResponse = await PocketBaseService.client.collection('chat_participants').getFullList(
          filter: 'chat_id = "$chatId"'
      );

      _handleMessagesResponse(response, participantsResponse, isBackground);
    } catch (e) {
      if (!isBackground) {
         AppLogger.instance.error('Mesajlar yüklenirken hata: $e');
      }
    }
  }

  void _handleMessagesResponse(List<RecordModel> response, List<RecordModel> participantsResponse, bool isBackground) {
    if (!mounted) return;

    final chatId = widget.chat['id'];
    bool isNewMessageArrived = false;
    if (_messages.isNotEmpty && response.isNotEmpty) {
       if (_messages.last['id'] != response.last.id) {
         isNewMessageArrived = true;
       }
    } else if (_messages.isEmpty && response.isNotEmpty) {
       isNewMessageArrived = true;
    }

    List<Map<String, dynamic>> parsedMessages = response.map((e) => JsonUtils.deeplySerializeRecord(e)).toList();

    int firstUnreadIndex = -1;
    bool hasUnreadDivider = false;

    if (_isInitialLoad && response.isNotEmpty) {
      try {
        final myPart = participantsResponse.firstWhere((p) => p.getStringValue('user_id') == _myUserId);
        final lastReadId = myPart.getStringValue('last_read_message_id');
        int readIndex = lastReadId.isEmpty ? -1 : parsedMessages.indexWhere((m) => m['id'] == lastReadId);

        if (readIndex < parsedMessages.length - 1) { // There are unread messages
           final unreadCount = parsedMessages.length - 1 - readIndex;
           firstUnreadIndex = readIndex + 1;
           hasUnreadDivider = true;
           
           parsedMessages.insert(firstUnreadIndex, {
              'id': 'temp_divider_unread',
              'chat_id': chatId,
              'sender_id': 'system',
              'is_divider': true,
              'unread_count': unreadCount,
              'created': parsedMessages[firstUnreadIndex]['created'],
           });
        }
      } catch (_) {}
    }

    setState(() {
      _messages = parsedMessages;
      _messageCache[chatId] = _messages; // Cache güncelle
      _chat = {
        ..._chat,
        'chat_participants': participantsResponse.map((e) => e.toJson()).toList(),
      };
      _isLoading = false;
    });

    try {
      SharedPreferences.getInstance().then((prefs) {
        prefs.setString('cached_messages_$chatId', jsonEncode(_messages));
      });
    } catch(e) {}

    // Mark as read
    if (response.isNotEmpty) {
        try {
          final myPartId = participantsResponse.firstWhere((p) => p.getStringValue('user_id') == _myUserId).id;
          PocketBaseService.client.collection('chat_participants').update(myPartId, body: {
            'last_read_message_id': response.last.id
          }).catchError((e) => null);
        } catch (_) {}
    }

    // Scroll
    if (_isInitialLoad) {
      _isInitialLoad = false;
      if (hasUnreadDivider) {
        Future.delayed(const Duration(milliseconds: 300), () {
          if (_scrollController.hasClients) {
             final double estimatedOffset = firstUnreadIndex * 80.0;
             _scrollController.jumpTo(estimatedOffset.clamp(0.0, _scrollController.position.maxScrollExtent));
             
             Future.delayed(const Duration(milliseconds: 100), () {
               if (_unreadDividerKey.currentContext != null) {
                 Scrollable.ensureVisible(
                   _unreadDividerKey.currentContext!,
                   duration: const Duration(milliseconds: 300),
                   alignment: 0.1,
                   curve: Curves.easeOut,
                 );
               }
             });
          }
        });
      } else {
        Future.delayed(const Duration(milliseconds: 100), () {
          if (_scrollController.hasClients) {
             _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
          }
        });
      }
    } else if (isNewMessageArrived) {
       final lastMsg = response.last;
       if (lastMsg.getStringValue('sender_id') != _myUserId) {
          final settings = SettingsService();
          if (settings.messageVibrationEnabled) {
            Vibration.vibrate(duration: 100);
          }
          if (settings.messageSoundEnabled) {
            final player = AudioPlayer();
            player.play(AssetSource('sounds/message_received.mp3')).catchError((e) => null);
          }
       }

       Future.delayed(const Duration(milliseconds: 100), () {
         if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent + 300,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
         }
       });
    }
  }

  Future<void> _sendMessage(String text) async {
    if (text.isEmpty) return;

    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final replyData = _replyingTo;
    
    setState(() {
      _messages.add({
        'id': tempId,
        'chat_id': _chat['id'],
        'sender_id': _myUserId,
        'content': text,
        'created': DateTime.now().toIso8601String(),
        'is_pending': true,
        if (replyData != null) 'reply_to': replyData['id'],
        if (replyData != null) 'reply_content': replyData['content']?.toString() ?? '',
      });
      _replyingTo = null;
    });
    
    // Scroll down immediately
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 200,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });

    try {
      final body = {
        'chat_id': _chat['id'],
        'sender_id': _myUserId,
        'content': text,
      };

      if (replyData != null) {
        body['reply_to'] = replyData['id'];
        body['reply_content'] = replyData['content']?.toString() ?? '';
      }

      final record = await PocketBaseService.client.collection('messages').create(body: body);

      if (mounted) {
        setState(() {
          final idx = _messages.indexWhere((m) => m['id'] == tempId);
          if (idx != -1) _messages[idx] = record.toJson();
        });
      }

      // Sohbetin updated_at alanını güncelle
      await PocketBaseService.client.collection('chats').update(_chat['id'], body: {
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).catchError((_) => null);

      // Mesaj gönderildi sesi
      final settings = SettingsService();
      if (settings.messageSoundEnabled) {
        final player = AudioPlayer();
        player.play(AssetSource('sounds/message_sent.mp3')).catchError((_) => null);
      }

    } catch (e) {
      AppLogger.instance.error('Mesaj gönderilirken hata: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Bağlantı hatası: Mesaj gönderiliyor olarak işaretlendi.'),
          duration: Duration(seconds: 2),
        ));
      }
    }
  }

  Future<void> _sendAudioMessage(String path) async {
    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    
    setState(() {
      _messages.add({
        'id': tempId,
        'chat_id': widget.chat['id'],
        'sender_id': _myUserId,
        'content': '[VOICE]',
        'created': DateTime.now().toIso8601String(),
        'is_pending': true,
      });
    });
    
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 200,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });

    try {
      Uint8List fileBytes;
      if (kIsWeb) {
        final res = await http.get(Uri.parse(path));
        fileBytes = res.bodyBytes;
        AppLogger.instance.info('Web voice upload: fetched ${fileBytes.length} bytes from $path');
      } else {
        fileBytes = File(path).readAsBytesSync();
      }
      
      final record = await PocketBaseService.client.collection('messages').create(
        body: {
          'chat_id': widget.chat['id'],
          'sender_id': _myUserId,
          'content': '[VOICE]',
        },
        files: [
          http.MultipartFile.fromBytes('file', fileBytes, filename: kIsWeb ? 'ses.webm' : 'ses.m4a')
        ],
      );
      
      if (mounted) {
        setState(() {
          final idx = _messages.indexWhere((m) => m['id'] == tempId);
          if (idx != -1) _messages[idx] = record.toJson();
        });
      }

      await PocketBaseService.client.collection('chats').update(widget.chat['id'], body: {
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).catchError((_) => null);

      final settings = SettingsService();
      if (settings.messageSoundEnabled) {
        final player = AudioPlayer();
        player.play(AssetSource('sounds/message_sent.mp3')).catchError((_) => null);
      }
    } catch (e) {
      AppLogger.instance.error('Ses gönderilemedi: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Bağlantı hatası: Ses mesajı gönderiliyor olarak işaretlendi.'),
          duration: Duration(seconds: 2),
        ));
      }
    }
  }

  Future<void> _deleteMessage(String messageId) async {
    try {
      // WhatsApp mantığı: Mesajı tamamen silmek yerine sadece "benden sil" yapıyoruz.
      // Diğer tarafın sohbet geçmişini ve favorilerini etkilememesi için.
      final currentMsg = await PocketBaseService.client.collection('messages').getOne(messageId);
      final currentDeletedFor = currentMsg.getStringValue('deleted_for');
      
      String newValue = _myUserId;
      if (currentDeletedFor.isNotEmpty) {
        if (currentDeletedFor.contains(_myUserId)) return; // Zaten silinmişse
        newValue = "$currentDeletedFor,$_myUserId";
      }

      await PocketBaseService.client.collection('messages').update(messageId, body: {
        'deleted_for': newValue
      });
      _fetchMessages();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Mesaj sizden silindi.'),
          duration: Duration(seconds: 1),
        ));
      }
    } catch (e) {
      AppLogger.instance.error('Mesaj silinemedi: $e');
    }
  }

  void _toggleFavorite(String messageId, bool currentStatus) async {
    try {
      await PocketBaseService.client.collection('messages').update(messageId, body: {
        'is_favorite': !currentStatus
      });
      _fetchMessages();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(!currentStatus ? 'Mesaj favorilere eklendi.' : 'Mesaj favorilerden çıkarıldı.'),
          duration: const Duration(seconds: 1),
        ));
      }
    } catch (e) {
      AppLogger.instance.error('Favori işlemi başarısız: $e');
    }
  }

  void _addReaction(String messageId, String emoji) async {
    // Optimistic UI Update
    final messageIndex = _messages.indexWhere((m) => m['id'] == messageId);
    if (messageIndex == -1) return;

    final originalMessage = Map<String, dynamic>.from(_messages[messageIndex]);
    String currentReactions = _messages[messageIndex]['reactions'] as String? ?? '';
    
    setState(() {
      if (currentReactions.contains(emoji)) {
        // Remove emoji (handling multi-byte characters correctly)
        List<String> emojiList = currentReactions.characters.toList();
        emojiList.remove(emoji);
        _messages[messageIndex]['reactions'] = emojiList.join('');
      } else {
        // Add emoji
        _messages[messageIndex]['reactions'] = currentReactions + emoji;
      }
    });

    try {
      final msg = await PocketBaseService.client.collection('messages').getOne(messageId);
      String realCurrentReactions = msg.getStringValue('reactions');
      
      String updatedReactions;
      if (realCurrentReactions.contains(emoji)) {
        List<String> emojiList = realCurrentReactions.characters.toList();
        emojiList.remove(emoji);
        updatedReactions = emojiList.join('');
      } else {
        updatedReactions = realCurrentReactions + emoji;
      }
      
      await PocketBaseService.client.collection('messages').update(messageId, body: {
        'reactions': updatedReactions
      });
      // Silent fetch to sync with server
      _fetchMessages(isBackground: true);
    } catch (e) {
      AppLogger.instance.error('Tepki işlemi başarısız: $e');
      // Revert on error
      if (mounted) {
        setState(() {
          _messages[messageIndex] = originalMessage;
        });
      }
    }
  }

  void _showLongPressMenu(Map<String, dynamic> message, bool isMyMessage, String textContent, bool isFavorite) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isCallMessage = textContent.contains('CALL_');
        final isVoiceMessage = textContent.startsWith('[VOICE]');
        
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isCallMessage) ...[
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: ['❤️', '😂', '👍', '😢', '🙏', '🔥', '😮', '👏'].map((emoji) => InkWell(
                        onTap: () {
                          Navigator.pop(context);
                          _addReaction(message['id'], emoji);
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(emoji, style: const TextStyle(fontSize: 28)),
                        ),
                      )).toList(),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.reply),
                    title: const Text('Yanıtla'),
                    onTap: () {
                      Navigator.pop(context);
                      setState(() {
                        _replyingTo = message;
                      });
                    },
                  ),
                  ListTile(
                    leading: Icon(isFavorite ? Icons.star : Icons.star_border, color: Colors.amber),
                    title: Text(isFavorite ? 'Favorilerden Çıkar' : 'Favorilere Ekle'),
                    onTap: () {
                      Navigator.pop(context);
                      _toggleFavorite(message['id'], isFavorite);
                    },
                  ),
                ],
                if (isMyMessage && !isCallMessage && !isVoiceMessage)
                  ListTile(
                    leading: const Icon(Icons.edit_outlined),
                    title: const Text('Düzenle'),
                    onTap: () {
                      Navigator.pop(context);
                      _showEditMessageDialog(message['id'], textContent);
                    },
                  ),
                if (isMyMessage)
                  ListTile(
                    leading: const Icon(Icons.delete_outline, color: Colors.red),
                    title: const Text('Sil', style: TextStyle(color: Colors.red)),
                    onTap: () {
                      Navigator.pop(context);
                      _deleteMessage(message['id']);
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showEditMessageDialog(String messageId, String currentContent) {
    final editController = TextEditingController(text: currentContent);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Mesajı Düzenle'),
          content: TextField(
            controller: editController,
            maxLines: 3,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Mesajınızı düzenleyin...',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('İptal'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                try {
                  await PocketBaseService.client.collection('messages').update(messageId, body: {
                    'content': editController.text,
                    'is_edited': true,
                  });
                  _fetchMessages();
                } catch (e) {
                  AppLogger.instance.error('Mesaj düzenlenemedi: $e');
                }
              },
              child: const Text('Kaydet'),
            ),
          ],
        );
      }
    );
  }

  void _startCall({required bool isVideo}) {
    // Katılımcıyı bul (En güncel katılımcı listesini kontrol et)
    final participants = _chat['chat_participants'] as List<dynamic>? ?? [];
    String? targetId;
    
    // Eğer yerel state'de yoksa widget.chat'den ya da mesajlardan bulmaya çalış
    for (var p in participants) {
      if (p['user_id'] != _myUserId) {
        targetId = p['user_id'];
        break;
      }
    }

    if (targetId == null) {
       // Son çare: Mesajlardan karşı tarafı bulmaya çalış (en az bir mesaj varsa)
       for (var m in _messages) {
         if (m['sender_id'] != _myUserId) {
           targetId = m['sender_id'];
           break;
         }
       }
    }

    if (targetId == null) {
       // Hala bulunamadıysa katılımcı listesini tekrar çek ve bekle
       _fetchChatDetails().then((_) {
         final updatedParticipants = _chat['chat_participants'] as List<dynamic>? ?? [];
         for (var p in updatedParticipants) {
           if (p['user_id'] != _myUserId) {
             targetId = p['user_id'];
             break;
           }
         }
         if (targetId != null) {
            _navigateToCall(targetId!, isVideo);
         } else {
           if (mounted) {
             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
               content: Text('Hata: Katılımcı bilgisi alınamadı. Sohbet yenileniyor...'),
               behavior: SnackBarBehavior.floating,
             ));
           }
         }
       });
       return;
    }

    _navigateToCall(targetId!, isVideo);
  }

  void _navigateToCall(String targetId, bool isVideo) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CallScreen(
          chatId: _chat['id'],
          targetUserId: targetId,
          targetUsername: _chat['name'] ?? 'Kullanıcı',
          isVideo: isVideo,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chatName = ProfanityFilter.filter(widget.chat['name'] ?? 'Sohbet');
    final isSystemChat = chatName == 'Blind Social Ekibi';

    return Scaffold(
      backgroundColor: const Color(0xFF101820),
      appBar: AppBar(
        title: InkWell(
          onTap: _toggleUserStatus,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                   Text(chatName),
                   if (isSystemChat)
                     const Padding(
                       padding: EdgeInsets.only(left: 4.0),
                       child: Icon(Icons.verified, color: Colors.blue, size: 18),
                     ),
                ]
              ),
              if (_showUserStatus && _targetUserStatus != null)
                Text(_targetUserStatus!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal, color: Colors.greenAccent)),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.star_outline),
            tooltip: 'Favori Mesajlar',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => FavoriteMessagesScreen(
                    chatId: _chat['id'],
                    chatName: chatName,
                  ),
                ),
              );
            },
          ),
          if (!isSystemChat) ...[
            IconButton(
              icon: const Icon(Icons.videocam),
              tooltip: 'Görüntülü Arama',
              onPressed: () => _startCall(isVideo: true),
            ),
            IconButton(
              icon: const Icon(Icons.call),
              tooltip: 'Sesli Arama',
              onPressed: () => _startCall(isVideo: false),
            ),
          ],
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _isLoading 
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty 
                  ? const Center(child: Text('Henüz mesaj yok.'))
                  : ListView.builder(
addAutomaticKeepAlives: false,
addRepaintBoundaries: true,
                      controller: _scrollController,
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final message = _messages[index];
                      if (message['is_divider'] == true) {
                        return Container(
                          key: _unreadDividerKey,
                          margin: const EdgeInsets.symmetric(vertical: 24),
                          alignment: Alignment.center,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2C3E50),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              '${message['unread_count']} Okunmamış Mesaj',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                        );
                      }
                      final isMyMessage = isSystemChat ? false : message['sender_id'] == _myUserId;
                      final content = message['content'];
                      final createdAt = DateTime.parse(message['created'] ?? DateTime.now().toIso8601String()).toLocal();
                      final timeString = DateFormat('HH:mm').format(createdAt);
                      
                      final isCallMessage = content.toString().contains('CALL_') || content.toString().contains('[VIDEO_');
                      final isVoiceMessage = content.toString().startsWith('[VOICE]');
                      final bool isFavorite = message['is_favorite'] == true;
                      
                      // Mesaj düzenlenmiş mi kontrol et (updated ve created arasındaki fark 1 saniyeden fazlaysa)
                      final createdStr = message['created']?.toString() ?? DateTime.now().toIso8601String();
                      final updatedStr = message['updated']?.toString() ?? createdStr;
                      final created = DateTime.parse(createdStr).toUtc();
                      final updated = DateTime.parse(updatedStr).toUtc();
                      final bool isEdited = !isCallMessage && (updated.difference(created).inSeconds > 1 || message['is_edited'] == true);

                      
                      String displayContent = content.toString();
                      IconData? callIcon;
                      
                      if (isCallMessage) {
                        final rawContent = content.toString();
                        final isCallEnded = rawContent.contains('CALL_ENDED');
                        final isCallBusy = rawContent.contains('CALL_BUSY');
                        final isCallRejected = rawContent.contains('CALL_REJECTED') || rawContent.contains('VIDEO_REJECTED') || isCallBusy;
                        final isCallCancelled = rawContent.contains('CALL_CANCELLED');
                        final isCallAccepted = rawContent.contains('CALL_ACCEPTED') || rawContent.contains('VIDEO_ACCEPTED');
                        final isVideo = rawContent.contains('VIDEO');
                        final duration = rawContent.contains('(') ? rawContent.split('(').last.replaceAll(')', '') : '';
                        final isUnanswered = rawContent.contains('CEVAPLANMADI') || isCallCancelled || isCallRejected;
                        final isVideoReq = rawContent.contains('VIDEO_REQUEST');

                        if (rawContent.contains('CALL_STARTED')) {
                          displayContent = isMyMessage 
                            ? (isVideo ? "Giden Görüntülü Arama" : "Giden Sesli Arama")
                            : (isVideo ? "Gelen Görüntülü Arama" : "Gelen Sesli Arama");
                          callIcon = isVideo ? Icons.videocam : Icons.call;
                        } else if (isVideoReq) {
                          displayContent = isMyMessage ? "Görüntülü Arama İsteği Gönderildi" : "Görüntülü Arama İsteği";
                          callIcon = Icons.video_call;
                        } else if (isCallAccepted) {
                          displayContent = isMyMessage ? "Aramayı Kabul Ettiniz" : "Arama Kabul Edildi";
                          callIcon = Icons.call_made;
                        } else if (isCallEnded || isCallRejected || isCallCancelled) {
                          if (isUnanswered) {
                            displayContent = isMyMessage 
                              ? (isVideo ? "Giden Arama Cevaplanmadı" : "Giden Arama Cevaplanmadı")
                              : (isVideo ? "Cevapsız Görüntülü Arama" : "Cevapsız Gelen Arama");
                            
                            if (isCallBusy) {
                               displayContent = isMyMessage ? "Hat Meşgul" : "Arama Meşgule Alındı";
                            } else if (isCallRejected) {
                               displayContent = isMyMessage ? "Aramayı Reddetiniz" : "Arama Reddedildi";
                            } else if (isCallCancelled) {
                               displayContent = isMyMessage ? "Aramayı İptal Ettiniz" : "Arama İptal Edildi";
                            }
                            
                            callIcon = isVideo ? Icons.missed_video_call : Icons.call_missed;
                          } else {
                            displayContent = isMyMessage
                              ? (isVideo ? "Giden Görüntülü Arama" : "Giden Sesli Arama")
                              : (isVideo ? "Gelen Görüntülü Arama" : "Gelen Sesli Arama");
                            if (duration.isNotEmpty) displayContent += "\nSüre: $duration";
                            callIcon = isVideo ? Icons.videocam : Icons.call;
                          }
                        }
                      }

                      final textContent = isVoiceMessage ? '' : (isCallMessage ? displayContent : content);
                      
                      String? voiceUrl;
                      if (isVoiceMessage) {
                        final filename = message['file'];
                        if (filename != null && filename.toString().isNotEmpty) {
                          // Construct PocketBase file URL
                          final baseUrl = PocketBaseService.client.baseUrl;
                          final recordId = message['id'];
                          final collectionId = message['collectionId'];
                          final fileToken = PocketBaseService.client.authStore.token;
                          voiceUrl = '$baseUrl/api/files/$collectionId/$recordId/$filename?token=$fileToken';
                        }
                      }

                      final hasReply = message['reply_to'] != null;
                      final replyText = hasReply ? "Yanıtlanan mesaj: ${ProfanityFilter.filter(message['reply_content']?.toString() ?? '')}. " : "";

                      return Align(
                        alignment: isMyMessage ? Alignment.centerRight : Alignment.centerLeft,
                        child: Semantics(
                          label: "${isFavorite ? 'Yıldızlı. ' : ''}$replyText${isVoiceMessage 
                            ? (isMyMessage ? "Gönderdiğiniz sesli mesaj. $timeString" : "Gelen sesli mesaj. $timeString") 
                            : (isCallMessage 
                                ? "$displayContent. $timeString" 
                                : (isMyMessage ? "Gönderdiğiniz mesaj: $textContent. $timeString" : "Gelen mesaj: $textContent. $timeString"))}${isEdited ? '. Düzenlendi' : ''}",
                          customSemanticsActions: {
                            if (!isCallMessage)
                              CustomSemanticsAction(label: isFavorite ? 'Favorilerden Çıkar' : 'Favorilere Ekle'): () {
                                _toggleFavorite(message['id'], isFavorite);
                              },
                            if (isMyMessage && !isVoiceMessage && !isCallMessage)
                              CustomSemanticsAction(label: 'Mesajı Düzenle'): () {
                                _showEditMessageDialog(message['id'], textContent);
                              },
                            if (isMyMessage)
                              CustomSemanticsAction(label: 'Mesajı Sil'): () {
                                _deleteMessage(message['id']);
                              },
                          },
                          child: GestureDetector(
                            onLongPress: () => _showLongPressMenu(message, isMyMessage, textContent, isFavorite),
                            child: isVoiceMessage 
                                  ? Container(
                                      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                      decoration: BoxDecoration(
                                        color: isMyMessage ? Colors.green[700] : Colors.grey[800],
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: isMyMessage ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                        children: [
                                          _buildReplyBubbleHeader(message, isMyMessage),
                                          if (voiceUrl != null) 
                                            VoiceMessageWidget(url: voiceUrl, isMyMessage: isMyMessage),
                                          const SizedBox(height: 4),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              if (isFavorite)
                                                const Icon(Icons.star, color: Colors.amber, size: 12),
                                              if (isFavorite) const SizedBox(width: 4),
                                              Text(
                                                timeString,
                                                style: const TextStyle(fontSize: 10, color: Colors.white70),
                                              ),
                                              if (isMyMessage) ...[
                                                const SizedBox(width: 4),
                                                _buildReadStatus(message),
                                              ],
                                            ],
                                          ),
                                        ],
                                      ),
                                    )
                                  : ExcludeSemantics(
                                      child: Container(
                                        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                        decoration: BoxDecoration(
                                          color: isCallMessage 
                                            ? Colors.blueGrey[900]?.withOpacity(0.5) 
                                            : (isMyMessage ? Colors.green[700] : Colors.grey[800]),
                                          borderRadius: BorderRadius.circular(12),
                                          border: isCallMessage ? Border.all(color: Colors.white24, width: 0.5) : null,
                                        ),
                                        child: Column(
                                          crossAxisAlignment: isMyMessage ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                          children: [
                                            _buildReplyBubbleHeader(message, isMyMessage),
                                            if (isCallMessage)
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    callIcon, 
                                                    color: content.toString().contains('CEVAPLANMADI') || content.toString().contains('CANCELLED') || content.toString().contains('REJECTED')
                                                      ? Colors.redAccent 
                                                      : (isMyMessage ? Colors.white : Colors.greenAccent), 
                                                    size: 28,
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Flexible(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Text(
                                                          displayContent.split('\n').first,
                                                          style: const TextStyle(
                                                            color: Colors.white, 
                                                            fontWeight: FontWeight.bold,
                                                            fontSize: 16,
                                                          ),
                                                        ),
                                                        if (displayContent.contains('\n'))
                                                          Text(
                                                            displayContent.split('\n').last,
                                                            style: const TextStyle(
                                                              color: Colors.white70,
                                                              fontSize: 13,
                                                            ),
                                                          ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              )
                                            else
                                              ExpandableText(
                                                text: textContent,
                                                maxLines: 10,
                                                style: const TextStyle(fontSize: 16, color: Colors.white),
                                              ),
                                            const SizedBox(height: 4),
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                if (isEdited)
                                                  const Text(
                                                    'düzenlendi  ',
                                                    style: TextStyle(fontSize: 10, color: Colors.white60, fontStyle: FontStyle.italic),
                                                  ),
                                                if (isFavorite)
                                                  const Icon(Icons.star, color: Colors.amber, size: 12),
                                                if (isFavorite) const SizedBox(width: 4),
                                                Text(
                                                  timeString,
                                                  style: const TextStyle(fontSize: 10, color: Colors.white70),
                                                ),
                                                if (isMyMessage) ...[
                                                  const SizedBox(width: 4),
                                                  _buildReadStatus(message),
                                                ],
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          if (isSystemChat)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24),
              alignment: Alignment.center,
              color: const Color(0xFF1B2530),
              child: const Text('Sadece Blind Social Ekibi mesaj gönderebilir', style: TextStyle(color: Colors.grey, fontSize: 13)),
            )
          else
            _buildMessageInput(),
        ],
      ),
    ),
  );
}

  Widget _buildReadStatus(Map<String, dynamic> message) {
    if (message['sender_id'] != _myUserId) return const SizedBox.shrink();

    if (message['is_pending'] == true) {
      return const Icon(Icons.schedule, size: 14, color: Colors.white54);
    }

    final participants = _chat['chat_participants'] as List<dynamic>? ?? [];
    String? otherLastReadId;
    
    // Normal sohbetlerde diğer katılımcının son okuduğu mesajı bul
    for (var p in participants) {
      if (p['user_id'] != _myUserId) {
        otherLastReadId = p['last_read_message_id'];
        break;
      }
    }

    if (otherLastReadId == null) {
      return const Icon(Icons.done, size: 14, color: Colors.white70);
    }

    // Mesajların ID sırasına göre karşılaştırma (Serial ise)
    // UUID ise dizin karşılaştırması yapıyoruz
    bool isRead = false;
    final otherReadIndex = _messages.indexWhere((m) => m['id'] == otherLastReadId);
    final currentMsgIndex = _messages.indexOf(message);

    if (otherReadIndex != -1 && currentMsgIndex <= otherReadIndex) {
      isRead = true;
    }

    return Icon(
      isRead ? Icons.done_all : Icons.done,
      size: 14,
      color: isRead ? Colors.blueAccent : Colors.white70,
    );
  }

  Widget _buildReplyBubbleHeader(Map<String, dynamic> message, bool isMyMessage) {
    final replyContent = message['reply_content']?.toString() ?? '';
    if (replyContent.isEmpty || message['reply_to'] == null) return const SizedBox.shrink();

    String displayReply = ProfanityFilter.filter(replyContent);
    if (displayReply.startsWith('[VOICE]')) displayReply = '🎤 Sesli Mesaj';
    if (displayReply.contains('CALL_')) displayReply = '📞 Arama Kaydı';

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: isMyMessage ? Colors.white38 : Colors.blueAccent, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            isMyMessage ? 'Siz' : 'Yanıtlanan',
            style: TextStyle(
              color: isMyMessage ? Colors.white70 : Colors.blueAccent,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            displayReply,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white60, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return ChatInputField(
      onSendText: _sendMessage,
      onSendAudio: _sendAudioMessage,
      hintText: 'Mesaj yaz...',
      replyWidget: _replyingTo == null ? null : Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey[850],
          border: Border(left: BorderSide(color: Colors.blueAccent, width: 4)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Yanıtlama:',
                    style: TextStyle(
                      color: Colors.blueAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    ProfanityFilter.filter(_replyingTo!['content']?.toString() ?? ''),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 20, color: Colors.white70),
              onPressed: () => setState(() => _replyingTo = null),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }
}
