import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart' as lk;
import 'package:blind_social/core/services/pocketbase_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import '../../../../core/utils/logger.dart';
import '../../../../core/services/settings_service.dart';

class CallScreen extends StatefulWidget {
  final String chatId;
  final String targetUserId;
  final String targetUsername;
  final bool isVideo;
  final bool isIncoming;

  const CallScreen({
    super.key,
    required this.chatId,
    required this.targetUserId,
    required this.targetUsername,
    this.isVideo = false,
    this.isIncoming = false,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  lk.Room? _room;
  bool _isMuted = false;
  bool _isCamOff = false;
  bool _isJoined = false;
  bool _isAccepted = false; // Arama cevaplandı mı?
  String _connectionStatus = 'Başlatılıyor...';
  
  // Timer for call duration
  Timer? _durationTimer;
  int _secondsElapsed = 0;
  
  late final String _myId;
  final AudioPlayer _ringtonePlayer = AudioPlayer();
  VoidCallback? _messagesUnsub;
  
  @override
  void initState() {
    super.initState();
    _myId = PocketBaseService.client.authStore.model!.id;
    _initCall();
    _playRingtone();
    _listenToCallEndEvents();
  }

  void _listenToCallEndEvents() async {
    _messagesUnsub = await PocketBaseService.client.collection('messages').subscribe('*', (e) {
      if (e.action == 'create') {
        final msg = e.record;
        if (msg != null && msg.getStringValue('chat_id') == widget.chatId && msg.getStringValue('sender_id') != _myId) {
          final content = msg.getStringValue('content');
          
          if (content.contains('CALL_ENDED')) {
            if (mounted) {
              Navigator.pop(context);
            }
          } else if (content == '[CALL_ACCEPTED]') {
            // Arayan taraf için: Karşı taraf aramayı kabul etti
            if (!widget.isIncoming && !_isAccepted) {
               _stopRingtone();
               if (mounted) {
                 setState(() {
                   _isAccepted = true;
                 });
                 _startTimer();
                 _connectToLiveKitRoom();
               }
            }
          }
        }
      }
    });
  }

  Future<void> _playRingtone() async {
    final settings = SettingsService();
    
    // Gelen aramada titreşim çal
    if (widget.isIncoming && settings.callVibrationEnabled) {
      Vibration.vibrate(pattern: [500, 1000, 500, 1000], repeat: 0);
    }

    if (!settings.callSoundEnabled) return;

    try {
      await _ringtonePlayer.setReleaseMode(ReleaseMode.loop);
      await _ringtonePlayer.play(AssetSource('sounds/outgoing_call.mp3'));
    } catch (e) {
      AppLogger.instance.warning('Zil sesi çalınamadı: $e');
    }
  }

  Future<void> _stopRingtone() async {
    Vibration.cancel();
    await _ringtonePlayer.stop();
  }

  Future<void> _initCall() async {
    // Permission checks
    final permissions = [
      Permission.microphone,
      if (widget.isVideo) Permission.camera,
    ];
    
    Map<Permission, PermissionStatus> statuses = await permissions.request();
    
    bool allGranted = true;
    statuses.forEach((permission, status) {
      if (!status.isGranted) allGranted = false;
    });

    if (!allGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kilit özellikler için kamera ve mikrofon izni gereklidir.')),
        );
        Navigator.pop(context);
      }
      return;
    }

    try {
      if (!widget.isIncoming) {
        // Arama başlatılıyorsa karşı tarafa bildirim gönder (signaling)
        await PocketBaseService.client.collection('messages').create(body: {
          'chat_id': widget.chatId,
          'sender_id': _myId,
          'content': widget.isVideo ? '[VIDEO_CALL_STARTED]' : '[VOICE_CALL_STARTED]',
        });
      }
    } catch (e) {
      AppLogger.instance.error('Arama başlatma hatası: $e');
      if (mounted) Navigator.pop(context);
    }
  }

  String _generateToken(String apiKey, String apiSecret, String roomName, String participantIdentity) {
    final jwt = JWT({
      'exp': (DateTime.now().millisecondsSinceEpoch / 1000).round() + (60 * 60 * 24), // 24 hours valid
      'iss': apiKey,
      'sub': participantIdentity,
      'nbf': 0,
      'video': {
        'room': roomName,
        'roomJoin': true,
        'canPublish': true,
        'canSubscribe': true,
      }
    });

    return jwt.sign(SecretKey(apiSecret));
  }

  Future<void> _connectToLiveKitRoom() async {
    final String livekitUrl = dotenv.env['LIVEKIT_URL'] ?? 'wss://live.cabukcan.com';
    final String apiKey = dotenv.env['LIVEKIT_API_KEY'] ?? '';
    final String apiSecret = dotenv.env['LIVEKIT_API_SECRET'] ?? '';

    if (apiKey.isEmpty || apiSecret.isEmpty) {
      AppLogger.instance.warning('LiveKit API key/secret eksik. Medya bağlantısı kurulamayabilir.');
      return;
    }

    try {
      final String roomName = widget.chatId; // Odanın adı chatId olsun (benzersiz)
      final String token = _generateToken(apiKey, apiSecret, roomName, _myId);

      _room = lk.Room();
      
      // Olay dinleyicileri
      _room!.createListener()
        ..on<lk.RoomDisconnectedEvent>((event) {
          AppLogger.instance.info('LiveKit bağlantısı kesildi.');
          if (mounted) {
            setState(() => _connectionStatus = 'Bağlantı Kesildi');
            Future.delayed(const Duration(seconds: 2), () {
              if (mounted) Navigator.pop(context);
            });
          }
        });

      // Bağlantı durumunu dinle (addListener kullanarak daha güvenli)
      _room!.addListener(_onRoomStateChanged);

      const roomOptions = lk.RoomOptions(
        adaptiveStream: true,
        dynacast: true,
      );

      await _room!.connect(livekitUrl, token, roomOptions: roomOptions);
      
      if (mounted) {
        setState(() {
          _isJoined = true;
        });
        
        // Mikrofonu ve varsa kamerayı aç
        await _room!.localParticipant?.setMicrophoneEnabled(true);
        if (widget.isVideo) {
          await _room!.localParticipant?.setCameraEnabled(true);
        }
      }
      AppLogger.instance.info('LiveKit odasına bağlanıldı: $roomName');
    } catch (e) {
      AppLogger.instance.error('LiveKit bağlantı hatası: $e');
    }
  }

  void _onRoomStateChanged() {
    if (!mounted || _room == null) return;
    
    setState(() {
      switch (_room!.connectionState) {
        case lk.ConnectionState.connecting:
          _connectionStatus = 'Bağlanıyor...';
          break;
        case lk.ConnectionState.connected:
          _connectionStatus = 'Bağlandı';
          break;
        case lk.ConnectionState.reconnecting:
          _connectionStatus = 'Yeniden Bağlanıyor...';
          break;
        case lk.ConnectionState.disconnected:
          _connectionStatus = 'Bağlantı Kesildi';
          break;
      }
    });
    
    AppLogger.instance.info('Oda durumu güncellendi: ${_room!.connectionState}');
  }

  void _handleAccept() async {
    _stopRingtone();
    setState(() {
      _isAccepted = true;
    });
    
    // Kabul edildi mesajı gönder (Arayanı uyarmak için)
    try {
      await PocketBaseService.client.collection('messages').create(body: {
        'chat_id': widget.chatId,
        'sender_id': _myId,
        'content': '[CALL_ACCEPTED]',
      });
    } catch (e) {
      AppLogger.instance.error('Arama kabul mesajı gönderilemedi: $e');
    }

    _startTimer();
    _connectToLiveKitRoom();
  }

  void _startTimer() {
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && _isAccepted) {
        setState(() {
          _secondsElapsed++;
        });
      }
    });
  }

  String _formatDuration(int seconds) {
    if (seconds == 0 && !_isAccepted) return "";
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return "$minutes:$secs";
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    _ringtonePlayer.dispose();
    _room?.removeListener(_onRoomStateChanged);
    _room?.disconnect();
    _messagesUnsub?.call();
    super.dispose();
  }

  void _hangUp() async {
    _stopRingtone();
    final durationText = _secondsElapsed > 0 ? " (${_formatDuration(_secondsElapsed)})" : "";
    final status = _secondsElapsed > 0 ? "TAMAMLANDI" : "CEVAPLANMADI";
       
    try {
      await PocketBaseService.client.collection('messages').create(body: {
         'chat_id': widget.chatId,
         'sender_id': _myId,
         'content': widget.isVideo ? '[VIDEO_CALL_ENDED]$status$durationText' : '[VOICE_CALL_ENDED]$status$durationText',
      });
    } catch (e) {
      AppLogger.instance.error('Arama kapanış mesajı hatası: $e');
    }
    
    await _room?.disconnect();
    if (mounted) Navigator.pop(context);
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
    });
    _room?.localParticipant?.setMicrophoneEnabled(!_isMuted);
  }

  void _toggleCam() {
    setState(() {
      _isCamOff = !_isCamOff;
    });
    _room?.localParticipant?.setCameraEnabled(!_isCamOff);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Video background (if video enabled)
          if (widget.isVideo && _isJoined)
             const Center(
               child: Icon(Icons.videocam_off, color: Colors.white24, size: 80),
             ),
             
          // WhatsApp Style Overlay
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 60),
                CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.grey[800],
                  child: Text(
                    widget.targetUsername[0].toUpperCase(),
                    style: const TextStyle(fontSize: 40, color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  widget.targetUsername,
                  style: const TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      widget.isVideo ? Icons.videocam : Icons.call,
                      size: 16,
                      color: Colors.white70,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isAccepted 
                        ? (widget.isVideo ? "Görüntülü Görüşme (" + _connectionStatus + ")" : "Sesli Görüşme (" + _connectionStatus + ")")
                        : (widget.isIncoming ? "Gelen Arama" : "Çalıyor..."),
                      style: const TextStyle(fontSize: 16, color: Colors.white70),
                    ),
                  ],
                ),
                if (_isAccepted) ...[
                  const SizedBox(height: 4),
                  Text(
                    _formatDuration(_secondsElapsed),
                    style: const TextStyle(fontSize: 14, color: Colors.greenAccent, fontWeight: FontWeight.bold),
                  ),
                ],
                const Spacer(),
                
                // Control ButtonsBar
                Container(
                  margin: const EdgeInsets.all(24),
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(40),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildControlButton(
                        icon: _isMuted ? Icons.mic_off : Icons.mic,
                        color: _isMuted ? Colors.white : Colors.white24,
                        iconColor: _isMuted ? Colors.black : Colors.white,
                        onPressed: _toggleMute,
                        label: "Sessiz",
                      ),
                      if (widget.isVideo)
                        _buildControlButton(
                          icon: _isCamOff ? Icons.videocam_off : Icons.videocam,
                          color: _isCamOff ? Colors.white : Colors.white24,
                          iconColor: _isCamOff ? Colors.black : Colors.white,
                          onPressed: _toggleCam,
                          label: "Kamera",
                        ),
                      _buildControlButton(
                        icon: Icons.call_end,
                        color: Colors.red,
                        iconColor: Colors.white,
                        onPressed: _hangUp,
                        label: "Kapat",
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
          
          if (widget.isIncoming && !_isAccepted)
             Positioned(
               bottom: 120,
               left: 0,
               right: 0,
               child: Row(
                 mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                 children: [
                   FloatingActionButton(
                     heroTag: "accept",
                     onPressed: _handleAccept,
                     backgroundColor: Colors.green,
                     child: const Icon(Icons.call),
                   ),
                   FloatingActionButton(
                     heroTag: "decline",
                     onPressed: _hangUp,
                     backgroundColor: Colors.red,
                     child: const Icon(Icons.call_end),
                   ),
                 ],
               ),
             ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required Color color,
    required Color iconColor,
    required VoidCallback onPressed,
    required String label,
  }) {
    return Semantics(
      label: label,
      button: true,
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: onPressed,
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 28),
            ),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }
}
