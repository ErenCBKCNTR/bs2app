import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:async';
import '../../../../core/utils/logger.dart';

class ChatDetailScreen extends StatefulWidget {
  final Map<String, dynamic> chat;

  const ChatDetailScreen({super.key, required this.chat});

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
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
    _myUserId = Supabase.instance.client.auth.currentUser!.id;
    
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

  Future<void> _fetchMessages({bool isBackground = false}) async {
    try {
      final chatId = widget.chat['id'];
      final response = await Supabase.instance.client
          .from('messages')
          .select()
          .eq('chat_id', chatId)
          .order('created_at', ascending: true);

      if (mounted) {
        bool isNewMessageArrived = false;
        if (_messages.isNotEmpty && response.isNotEmpty) {
           if (_messages.last['id'] != response.last['id']) {
             isNewMessageArrived = true;
           }
        } else if (_messages.isEmpty && response.isNotEmpty) {
           isNewMessageArrived = true;
        }

        setState(() {
          _messages = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });

        // Yeni mesaj geldiyse aşağı kaydır
        if (isNewMessageArrived) {
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
      await Supabase.instance.client.from('messages').insert({
        'chat_id': widget.chat['id'],
        'sender_id': _myUserId,
        'content': text,
      });

      // Sohbetin updated_at alanını güncelle
      await Supabase.instance.client.from('chats').update({
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', widget.chat['id']);

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
        final file = File(path);
        final fileName = 'ses_mesaji_${widget.chat['id']}_${DateTime.now().millisecondsSinceEpoch}.m4a';
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ses mesajı gönderiliyor...')));
        }
        
        // Supabase Storage'a yükle
        final storageRes = await Supabase.instance.client.storage
            .from('chat_audio')
            .upload(fileName, file);
            
        // Dosyanın public URL'sini al
        final publicUrl = Supabase.instance.client.storage
            .from('chat_audio')
            .getPublicUrl(fileName);
            
        // Mesaj tablosuna [VOICE] prefixi ile URL'i kaydet
        await _sendMessage('[VOICE]$publicUrl');
      }
    } catch (e) {
      AppLogger.instance.error('Ses yükleme hatası: $e');
      _stopTimer();
      setState(() {
        _isRecording = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ses yüklenemedi: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatName = widget.chat['name'] ?? 'Sohbet';

    return Scaffold(
      appBar: AppBar(
        title: Text(chatName),
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
                      final createdAt = DateTime.parse(message['created_at']).toLocal();
                      final timeString = DateFormat('HH:mm').format(createdAt);
                      
                      final isVoiceMessage = content.toString().startsWith('[VOICE]');
                      final textContent = isVoiceMessage ? '' : content;
                      final voiceUrl = isVoiceMessage ? content.toString().substring(7) : null;

                      return Align(
                        alignment: isMyMessage ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                          decoration: BoxDecoration(
                            color: isMyMessage ? Colors.green[700] : Colors.grey[800],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: isMyMessage ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                            children: [
                              if (isVoiceMessage && voiceUrl != null) 
                                VoiceMessageWidget(url: voiceUrl, isMyMessage: isMyMessage)
                              else
                                Text(
                                  textContent,
                                  style: const TextStyle(fontSize: 16),
                                ),
                              const SizedBox(height: 4),
                              Text(
                                timeString,
                                style: const TextStyle(fontSize: 10, color: Colors.white70),
                              ),
                            ],
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

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(8.0),
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
              onSubmitted: (val) => _sendMessage(val.trim()),
            ),
          ),
          const SizedBox(width: 8),
          
          if (_isRecording)
            Semantics(
              label: "Mevcut ses kaydını durdur ve gönder",
              child: GestureDetector(
                onTap: _stopRecordingAndSend,
                child: const CircleAvatar(
                  radius: 24, // Yarıçapı büyüterek butonu daha belirgin yaptık
                  backgroundColor: Colors.red,
                  child: Icon(Icons.stop, color: Colors.white, size: 28),
                ),
              ),
            )
          else ...[
            Semantics(
              label: "Seslı mesaj kaydet",
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
              child: GestureDetector(
                onTap: () {
                  final text = _messageController.text.trim();
                  _sendMessage(text);
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

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      decoration: BoxDecoration(
        color: widget.isMyMessage ? Colors.green[800] : Colors.grey[700],
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            label: _isPlaying ? "Sesi duraklat" : "Sesli mesajı dinle",
            button: true,
            child: IconButton(
              icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white),
              onPressed: () async {
                if (_isPlaying) {
                  await _audioPlayer.pause();
                } else {
                  await _audioPlayer.play(UrlSource(widget.url));
                }
              },
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
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
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
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
