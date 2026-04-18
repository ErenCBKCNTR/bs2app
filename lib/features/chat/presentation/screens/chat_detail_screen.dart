import 'package:blind_social/features/chat/presentation/screens/call_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:blind_social/core/services/pocketbase_service.dart';
import 'package:pocketbase/pocketbase.dart' hide SettingsService;
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:async';
import '../../../../core/utils/logger.dart';
import 'package:http/http.dart' as http;
import 'package:vibration/vibration.dart';
import 'package:blind_social/core/services/settings_service.dart';

class ChatDetailScreen extends StatefulWidget {
  final Map<String, dynamic> chat;

  const ChatDetailScreen({super.key, required this.chat});

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  late Map<String, dynamic> _chat;
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  Timer? _pollingTimer;
  late final String _myUserId;

  // Ses kaydı için değişkenler
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  String? _recordingPath;
  
  Timer? _recordTimer;
  int _recordDuration = 0;

  void _startTimer() {
    _recordTimer?.cancel();
    _recordDuration = 0;
    _recordTimer = Timer.periodic(const Duration(seconds: 1), (Timer t) {
      if (mounted) {
        setState(() => _recordDuration++);
      }
    });
  }

  void _stopTimer() {
    _recordTimer?.cancel();
  }

  String _formatRecordDuration(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$secs';
  }

  @override
  void initState() {
    super.initState();
    _myUserId = PocketBaseService.client.authStore.model!.id;
    _chat = Map<String, dynamic>.from(widget.chat);
    
    // Eğer katılımcılar yoksa (başka ekrandan sadece id/name ile gelindiyse) çek
    if (!_chat.containsKey('chat_participants') || (_chat['chat_participants'] as List).isEmpty) {
      _fetchChatDetails();
    }
    
    // İlk yükleme
    _fetchMessages();
    
    // 2 saniyede bir gizlice yenileme (Polling / WebSockets alternatifi)
    _pollingTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _fetchMessages(isBackground: true);
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _recordTimer?.cancel();
    _audioRecorder.dispose();
    _messageController.dispose();
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
    try {
      final chatId = widget.chat['id'];
      final response = await PocketBaseService.client.collection('messages').getFullList(
          filter: 'chat_id = "$chatId"',
          sort: 'created'
      );

      // Katılımcıların durumlarını (okunma bilgisi için) her seferinde çekelim
      final participantsResponse = await PocketBaseService.client.collection('chat_participants').getFullList(
          filter: 'chat_id = "$chatId"'
      );

      if (mounted) {
        bool isNewMessageArrived = false;
        if (_messages.isNotEmpty && response.isNotEmpty) {
           if (_messages.last['id'] != response.last.id) {
             isNewMessageArrived = true;
           }
        } else if (_messages.isEmpty && response.isNotEmpty) {
           isNewMessageArrived = true;
        }

        setState(() {
          _messages = response.map((e) => e.toJson()).toList();
          _chat = {
            ..._chat,
            'chat_participants': participantsResponse.map((e) => e.toJson()).toList(),
          };
          _isLoading = false;
        });

        // Mark as read in participants table if we have messages
        if (response.isNotEmpty) {
            try {
              final myPartId = participantsResponse.firstWhere((p) => p.getStringValue('user_id') == _myUserId).id;
              PocketBaseService.client.collection('chat_participants').update(myPartId, body: {
                'last_read_message_id': response.last.id
              }).catchError((e) {
                AppLogger.instance.error('Okunma durumu güncellenemedi: $e');
              });
            } catch (_) {}
        }

        // Yeni mesaj geldiyse aşağı kaydır
        if (isNewMessageArrived) {
           final lastMsg = response.last;
           if (lastMsg.getStringValue('sender_id') != _myUserId) {
              final settings = SettingsService();
              if (settings.messageVibrationEnabled) {
                Vibration.vibrate(duration: 100);
              }
              if (settings.messageSoundEnabled) {
                // Try to play a short notification sound
                final player = AudioPlayer();
                player.play(AssetSource('sounds/new_message.mp3')).catchError((e) => null);
              }
           }

           Future.delayed(const Duration(milliseconds: 100), () {
             if (_scrollController.hasClients) {
                _scrollController.animateTo(
                  _scrollController.position.maxScrollExtent + 200,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                );
             }
           });
        }
      }
    } catch (e) {
      if (!isBackground) {
         AppLogger.instance.error('Mesajlar yüklenirken hata: $e');
      }
    }
  }

  Future<void> _sendMessage(String text) async {
    if (text.isEmpty) return;

    _messageController.clear();

    try {
      await PocketBaseService.client.collection('messages').create(body: {
        'chat_id': _chat['id'],
        'sender_id': _myUserId,
        'content': text,
      });

      // Sohbetin updated_at alanını güncelle
      await PocketBaseService.client.collection('chats').update(_chat['id'], body: {
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });

      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 100,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      AppLogger.instance.error('Mesaj gönderilirken hata: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
      }
    }
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final dir = await getApplicationDocumentsDirectory();
        final path = '${dir.path}/ses_mesaji_${DateTime.now().millisecondsSinceEpoch}.m4a';
        
        await _audioRecorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc),
          path: path,
        );
        
        _startTimer();
        AppLogger.instance.info('Kayıt başlatıldı: $path');
        setState(() {
          _isRecording = true;
          _recordingPath = path;
        });
      } else {
        AppLogger.instance.warning('Kayıt için izin reddedildi.');
      }
    } catch (e) {
      AppLogger.instance.error('Kayıt başlatılamadı: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Kayıt başlatılamadı: $e')));
      }
    }
  }

  Future<void> _stopRecordingAndSend() async {
    try {
      final path = await _audioRecorder.stop();
      _stopTimer();
      setState(() {
        _isRecording = false;
      });

      if (path != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ses mesajı gönderiliyor...')));
        }
        
        final fileBytes = File(path).readAsBytesSync();
        
        // PocketBase messages tablosunda 'file' isminde bir File alanı olması gerekiyor.
        await PocketBaseService.client.collection('messages').create(
          body: {
            'chat_id': widget.chat['id'],
            'sender_id': _myUserId,
            'content': '[VOICE]',
          },
          files: [
            http.MultipartFile.fromBytes('file', fileBytes, filename: 'ses.m4a')
          ],
        );
      }
    } catch (e) {
      AppLogger.instance.error('Ses kaydı durdurulamadı: $e');
      _stopTimer();
      setState(() {
        _isRecording = false;
      });
    }
  }

  Future<void> _deleteMessage(String messageId) async {
    try {
      await PocketBaseService.client.collection('messages').delete(messageId);
      _fetchMessages();
    } catch (e) {
      AppLogger.instance.error('Mesaj silinemedi: $e');
    }
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
                    'content': editController.text
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
    final chatName = widget.chat['name'] ?? 'Sohbet';

    return Scaffold(
      appBar: AppBar(
        title: Text(chatName),
        actions: [
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
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : _messages.isEmpty 
                ? const Center(child: Text('Henüz mesaj yok.'))
                : ListView.builder(
                    controller: _scrollController,
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      final isMyMessage = message['sender_id'] == _myUserId;
                      final content = message['content'];
                      final createdAt = DateTime.parse(message['created'] ?? DateTime.now().toIso8601String()).toLocal();
                      final timeString = DateFormat('HH:mm').format(createdAt);
                      
                      final isCallMessage = content.toString().contains('_CALL_');
                      final isVoiceMessage = content.toString().startsWith('[VOICE]');
                      
                      String displayContent = content.toString();
                      IconData? callIcon;
                      
                      if (isCallMessage) {
                        if (content.toString().contains('VOICE_CALL_STARTED')) {
                          displayContent = "Sesli görüşme başlatıldı";
                          callIcon = Icons.call_made;
                        } else if (content.toString().contains('VOICE_CALL_ENDED')) {
                          final duration = content.toString().contains('(') ? content.toString().split('(').last.replaceAll(')', '') : '';
                          displayContent = content.toString().contains('CEVAPLANMADI') ? "Cevaplanmayan sesli görüşme" : "Sesli görüşme bitti: $duration";
                          callIcon = content.toString().contains('CEVAPLANMADI') ? Icons.call_missed : Icons.call_end;
                        } else if (content.toString().contains('VIDEO_CALL_STARTED')) {
                          displayContent = "Görüntülü görüşme başlatıldı";
                          callIcon = Icons.videocam;
                        } else if (content.toString().contains('VIDEO_CALL_ENDED')) {
                          final duration = content.toString().contains('(') ? content.toString().split('(').last.replaceAll(')', '') : '';
                          displayContent = content.toString().contains('CEVAPLANMADI') ? "Cevaplanmayan görüntülü görüşme" : "Görüntülü görüşme bitti: $duration";
                          callIcon = content.toString().contains('CEVAPLANMADI') ? Icons.missed_video_call : Icons.videocam_off;
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
                          voiceUrl = '$baseUrl/api/files/$collectionId/$recordId/$filename';
                        }
                      }

                      return Align(
                        alignment: isMyMessage ? Alignment.centerRight : Alignment.centerLeft,
                        child: Semantics(
                          label: isVoiceMessage 
                            ? (isMyMessage ? "Gönderdiğiniz sesli mesaj. $timeString" : "Gelen sesli mesaj. $timeString") 
                            : (isCallMessage 
                                ? "$displayContent. $timeString" 
                                : (isMyMessage ? "Gönderdiğiniz mesaj: $textContent. $timeString" : "Gelen mesaj: $textContent. $timeString")),
                          customSemanticsActions: isMyMessage && !isVoiceMessage && !isCallMessage
                            ? {
                                CustomSemanticsAction(label: 'Mesajı Düzenle'): () {
                                  _showEditMessageDialog(message['id'], textContent);
                                },
                                CustomSemanticsAction(label: 'Mesajı Sil'): () {
                                  _deleteMessage(message['id']);
                                },
                              }
                            : ((isMyMessage && (isVoiceMessage || isCallMessage)) ? {
                                CustomSemanticsAction(label: 'Mesajı Sil'): () {
                                  _deleteMessage(message['id']);
                                },
                              } : {}),
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
                                        if (voiceUrl != null) 
                                          VoiceMessageWidget(url: voiceUrl, isMyMessage: isMyMessage),
                                        const SizedBox(height: 4),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
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
                                          if (isCallMessage)
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                if (callIcon != null) Icon(callIcon, color: Colors.white70, size: 16),
                                                if (callIcon != null) const SizedBox(width: 8),
                                                Text(
                                                  displayContent,
                                                  style: const TextStyle(fontSize: 14, fontStyle: FontStyle.italic, color: Colors.white),
                                                ),
                                              ],
                                            )
                                          else
                                            Text(
                                              textContent,
                                              style: const TextStyle(fontSize: 16),
                                            ),
                                          const SizedBox(height: 4),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
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
                      );
                    },
                  ),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildReadStatus(Map<String, dynamic> message) {
    if (message['sender_id'] != _myUserId) return const SizedBox.shrink();

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

  Widget _buildMessageInput() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        color: Colors.grey[900],
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                decoration: InputDecoration(
                  hintText: _isRecording ? 'Kayıt: ${_formatRecordDuration(_recordDuration)}' : 'Mesaj yaz...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: _isRecording ? Colors.red.withOpacity(0.2) : Colors.grey[800],
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                enabled: !_isRecording,
                onSubmitted: (val) {
                  final text = val.trim();
                  if (text.isNotEmpty) _sendMessage(text);
                },
              ),
            ),
            const SizedBox(width: 8),
            
            if (_isRecording)
              Semantics(
                label: "Ses kaydını durdur ve gönder",
                button: true,
                child: GestureDetector(
                  onTap: _stopRecordingAndSend,
                  child: const CircleAvatar(
                    radius: 22,
                    backgroundColor: Colors.red,
                    child: Icon(Icons.stop, color: Colors.white, size: 28),
                  ),
                ),
              )
            else ...[
              Semantics(
                label: "Sesli mesaj kaydet",
                button: true,
                child: GestureDetector(
                  onTap: _startRecording,
                  child: const CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.blueAccent,
                    child: Icon(Icons.mic, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Semantics(
                label: "Mesaj gönder",
                button: true,
                child: GestureDetector(
                  onTap: () {
                    final text = _messageController.text.trim();
                    if (text.isNotEmpty) _sendMessage(text);
                  },
                  child: const CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.green,
                    child: Icon(Icons.send, color: Colors.white),
                  ),
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }
}

class VoiceMessageWidget extends StatefulWidget {
  final String url;
  final bool isMyMessage;

  const VoiceMessageWidget({super.key, required this.url, required this.isMyMessage});

  @override
  State<VoiceMessageWidget> createState() => _VoiceMessageWidgetState();
}

class _VoiceMessageWidgetState extends State<VoiceMessageWidget> {
  late AudioPlayer _audioPlayer;
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();

    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
        });
      }
    });

    _audioPlayer.onDurationChanged.listen((newDuration) {
      if (mounted) {
        setState(() {
          _duration = newDuration;
        });
      }
    });

    _audioPlayer.onPositionChanged.listen((newPosition) {
      if (mounted) {
        setState(() {
          _position = newPosition;
        });
      }
    });
    
    _audioPlayer.onPlayerComplete.listen((event) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _position = Duration.zero;
        });
      }
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void _seekRelative(int seconds) {
    final newPosition = _position + Duration(seconds: seconds);
    if (newPosition < Duration.zero) {
      _audioPlayer.seek(Duration.zero);
    } else if (newPosition > _duration && _duration != Duration.zero) {
      _audioPlayer.seek(_duration);
    } else {
      _audioPlayer.seek(newPosition);
    }
  }

  @override
  Widget build(BuildContext context) {
    final playPauseLabel = _isPlaying ? "Sesi duraklat" : "Sesli mesajı oynat";
    
    return Container(
      width: 260, 
      decoration: BoxDecoration(
        color: widget.isMyMessage ? Colors.green[800] : Colors.grey[700],
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Play/Pause Button
          Semantics(
            label: playPauseLabel,
            button: true,
            excludeSemantics: true,
            child: IconButton(
              constraints: const BoxConstraints(),
              padding: const EdgeInsets.all(4),
              icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white, size: 32),
              onPressed: () async {
                if (_isPlaying) {
                  await _audioPlayer.pause();
                } else {
                  await _audioPlayer.play(UrlSource(widget.url));
                }
              },
            ),
          ),
          
          // Rewind 5s
          Semantics(
            label: "5 saniye geri sar",
            button: true,
            excludeSemantics: true,
            child: IconButton(
              constraints: const BoxConstraints(),
              padding: const EdgeInsets.all(4),
              icon: const Icon(Icons.replay_5, color: Colors.white, size: 24),
              onPressed: () => _seekRelative(-5),
            ),
          ),

          // Forward 5s
          Semantics(
            label: "5 saniye ileri sar",
            button: true,
            excludeSemantics: true,
            child: IconButton(
              constraints: const BoxConstraints(),
              padding: const EdgeInsets.all(4),
              icon: const Icon(Icons.forward_5, color: Colors.white, size: 24),
              onPressed: () => _seekRelative(5),
            ),
          ),

          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Semantics(
                  label: "Ses ilerlemesi: ${_formatDuration(_position)} / ${_formatDuration(_duration)}",
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                      trackHeight: 2,
                    ),
                    child: Slider(
                      min: 0,
                      max: _duration.inSeconds > 0 ? _duration.inSeconds.toDouble() : 1.0,
                      value: _position.inSeconds.toDouble().clamp(0.0, _duration.inSeconds > 0 ? _duration.inSeconds.toDouble() : 1.0),
                      onChanged: (val) {
                        _audioPlayer.seek(Duration(seconds: val.toInt()));
                      },
                      activeColor: Colors.white,
                      inactiveColor: Colors.white30,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: Text(
                    '${_formatDuration(_position)} / ${_formatDuration(_duration)}',
                    style: const TextStyle(fontSize: 10, color: Colors.white70),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
