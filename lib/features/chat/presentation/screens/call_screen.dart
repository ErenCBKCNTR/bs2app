import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart'; // SemanticsService için eklendi
import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart' as lk;
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:blind_social/core/services/pocketbase_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import '../../../../core/utils/logger.dart';
import '../../../../core/services/settings_service.dart';
import '../../../../core/services/audio_cache_service.dart';

class CallScreen extends StatefulWidget {
  final String chatId;
  final String targetUserId;
  final String targetUsername;
  final bool isVideo;
  final bool isIncoming;
  final String? messageId;

  static bool isInCall = false;

  const CallScreen({
    super.key,
    required this.chatId,
    required this.targetUserId,
    required this.targetUsername,
    this.isVideo = false,
    this.isIncoming = false,
    this.messageId,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  lk.Room? _room;
  bool _isMuted = false;
  bool _isCamOff = false;
  bool _isLocalVideoFullscreen = false;
  bool _isScreenSharing = false;
  bool _isJoined = false;
  bool _isAccepted = false; // Arama cevaplandı mı?
  bool _isSpeakerOn = false;
  bool _isVideoCall = false;
  bool _showVideoRequest = false;
  String _videoRequesterName = '';
  String _connectionStatus = 'Başlatılıyor...';
  String? _callMessageId;

  // Video tracks
  lk.VideoTrack? _localVideoTrack;
  lk.VideoTrack? _remoteVideoTrack;
  
  // Timer for call duration
  Timer? _durationTimer;
  Timer? _reconnectTimer;
  Timer? _reconnectBeepTimer;
  Timer? _callTimeoutTimer; // 45s without answer
  
  int _secondsElapsed = 0;
  
  late final String _myId;
  final AudioPlayer _ringtonePlayer = AudioPlayer();
  VoidCallback? _messagesUnsub;
  
  @override
  void initState() {
    super.initState();
    CallScreen.isInCall = true;
    _myId = PocketBaseService.client.authStore.model!.id;
    _isVideoCall = widget.isVideo;
    _callMessageId = widget.messageId;
    
    // Sesli görüşmedeyse varsayılan ahize (speaker off)
    // Görüntülü görüşmedeyse varsayılan hoparlör (isteğe bağlı ama kullanıcı "varsayılan ahize" dedi)
    _isSpeakerOn = false; 
    lk.Hardware.instance.setSpeakerphoneOn(_isSpeakerOn);

    _initCall();
    _playRingtone();
    _listenToCallEndEvents();
    _startCallTimeout();
  }

  void _startCallTimeout() {
    _callTimeoutTimer?.cancel();
    _callTimeoutTimer = Timer(const Duration(seconds: 45), () {
      if (!_isAccepted) {
        if (!widget.isIncoming) {
           _cancelCall();
        } else {
           // Gelen arama da cevapsız kaldığı için kapansın
           _hangUp();
        }
      }
    });
  }

  void _listenToCallEndEvents() async {
    _messagesUnsub = await PocketBaseService.client.collection('messages').subscribe('*', (e) async {
      if (e.action == 'create' || e.action == 'update') {
        final msg = e.record;
        if (msg != null && msg.getStringValue('chat_id') == widget.chatId && msg.getStringValue('sender_id') != _myId) {
          final content = msg.getStringValue('content');
          
          if (content.contains('CALL_ENDED') || content.contains('CALL_REJECTED') || content.contains('CALL_CANCELLED')) {
            _stopRingtone();
            await _playEndSound();
            if (mounted) {
              Navigator.pop(context);
            }
          } else if (content.contains('CALL_BUSY')) {
            // Karşı taraf başka bir görüşmede
            _stopRingtone();
            _callTimeoutTimer?.cancel();
            if (mounted) {
              setState(() {
                _connectionStatus = "Meşgul";
              });
              try {
                // Meşgul sesi çal (ton generatör ile)
                if (!kIsWeb) {
                  final channel = const MethodChannel('com.example.blind_social/lockscreen');
                  channel.invokeMethod('playTone', {'type': 'end', 'duration': 400});
                  await Future.delayed(const Duration(milliseconds: 600));
                  channel.invokeMethod('playTone', {'type': 'end', 'duration': 400});
                  await Future.delayed(const Duration(milliseconds: 600));
                  channel.invokeMethod('playTone', {'type': 'end', 'duration': 400});
                  await Future.delayed(const Duration(milliseconds: 800));
                }
              } catch (_) {}
              if (mounted) Navigator.pop(context);
            }
          } else if (content == '[CALL_ACCEPTED]') {
            // Arayan taraf için: Karşı taraf aramayı kabul etti
            if (!widget.isIncoming && !_isAccepted) {
               _stopRingtone();
               _callTimeoutTimer?.cancel();
               if (mounted) {
                 setState(() {
                   _isAccepted = true;
                 });
                 _startTimer();
                 _connectToLiveKitRoom();
               }
            }
          } else if (content == '[VIDEO_REQUEST]') {
             if (mounted && _isAccepted && !_isVideoCall) {
               setState(() {
                 _videoRequesterName = widget.targetUsername;
                 _showVideoRequest = true;
               });
               SemanticsService.announce("$_videoRequesterName görüntülü görüşmeye geçmek istiyor", TextDirection.ltr);
             }
          } else if (content == '[VIDEO_ACCEPTED]') {
             if (mounted && _isAccepted && !_isVideoCall) {
               _enableVideo(true);
             }
          } else if (content == '[VIDEO_REJECTED]') {
             if (mounted) {
               ScaffoldMessenger.of(context).showSnackBar(
                 const SnackBar(content: Text('Görüntülü görüşme isteği reddedildi.')),
               );
             }
          }
        }
      }
    });
  }

  Future<void> _playSystemBeep({required bool isEnd}) async {
    if (!kIsWeb) {
      try {
        await const MethodChannel('com.example.blind_social/lockscreen')
            .invokeMethod('playTone', {'type': isEnd ? 'end' : 'start', 'duration': isEnd ? 200 : 150});
      } catch (e) {
        AppLogger.instance.warning('Sistem biplenirken hata: $e');
      }
    }
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
      if (!widget.isIncoming) {
        // Giden aramada çalmadan önce kısa "bip" sesi çal
        await _playSystemBeep(isEnd: false);
        await Future.delayed(const Duration(milliseconds: 300));
        
        try {
          await _ringtonePlayer.play(UrlSource('https://api.cabukcan.com/sounds/outgoing_call.mp3'));
          return;
        } catch(e) {
          AppLogger.instance.warning('URL Source başlatılamadı, varsayılan sese dönülüyor.');
        }
      } else {
        try {
          // Play system ringtone
          FlutterRingtonePlayer().playRingtone();
          return;
        } catch(e) {
          AppLogger.instance.warning('Sistem zil sesi çalınamadı, varsayılan sese dönülüyor.');
        }
      }
      final soundPath = widget.isIncoming ? 'sounds/incoming_call.mp3' : 'sounds/outgoing_call.mp3';
      await _ringtonePlayer.play(AssetSource(soundPath));
    } catch (e) {
      AppLogger.instance.warning('Zil sesi çalınamadı: $e');
    }
  }

  Future<void> _playEndSound() async {
    await _playSystemBeep(isEnd: true);
    await Future.delayed(const Duration(milliseconds: 300));
  }

  Future<void> _stopRingtone() async {
    Vibration.cancel();
    try {
      FlutterRingtonePlayer().stop();
    } catch(_) {}
    await _ringtonePlayer.stop();
  }

  Future<void> _initCall() async {
    // Permission checks
    if (!kIsWeb) {
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
    }

    try {
      if (!widget.isIncoming) {
        // Arama başlatılıyorsa karşı tarafa bildirim gönder (signaling)
        await _updateOrCreateCallMessage(widget.isVideo ? '[VIDEO_CALL_STARTED]' : '[VOICE_CALL_STARTED]');
      }
    } catch (e) {
      AppLogger.instance.error('Arama başlatma hatası: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Arama yapılamadı. Lütfen internet bağlantınızı kontrol edin.'),
        ));
        Navigator.pop(context);
      }
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
    String livekitUrl = dotenv.env['LIVEKIT_URL'] ?? 'wss://live.cabukcan.com';
    final String apiKey = dotenv.env['LIVEKIT_API_KEY'] ?? '';
    final String apiSecret = dotenv.env['LIVEKIT_API_SECRET'] ?? '';

    // Web platformunda LiveKit için wss yerine https kullanılması önerilir.
    if (kIsWeb && livekitUrl.startsWith('wss://')) {
      livekitUrl = livekitUrl.replaceFirst('wss://', 'https://');
    }
    if (kIsWeb && livekitUrl.startsWith('ws://')) {
      livekitUrl = livekitUrl.replaceFirst('ws://', 'http://');
    }

    if (apiKey.isEmpty || apiSecret.isEmpty) {
      AppLogger.instance.warning('LiveKit API key/secret eksik. Medya bağlantısı kurulamayabilir.');
      return;
    }

    try {
      final String roomName = widget.chatId; // Odanın adı chatId olsun (benzersiz)
      final String token = _generateToken(apiKey, apiSecret, roomName, _myId);

      _room = lk.Room();
      
      // Ses çıkışını ayarla
      lk.Hardware.instance.setSpeakerphoneOn(_isSpeakerOn);
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
        })
        ..on<lk.ParticipantDisconnectedEvent>((event) {
          AppLogger.instance.info('Karşı taraf ayrıldı: ${event.participant.identity}');
          if (mounted) {
            setState(() {
              _connectionStatus = 'Karşı taraf bağlantıyı kesti'; // Status update immediately
            });
          }
          // Arama ekranında isek eğer karşı taraf gittiyse birkaç saniye sonra doğrudan aramayı bitirelim.
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted && _room != null) {
               _hangUp(); 
            }
          });
        })
        ..on<lk.ParticipantConnectedEvent>((event) {
           AppLogger.instance.info('Biri katıldı: ${event.participant.identity}');
           _remoteHasJoined = true;
           if (mounted) {
             setState(() {}); // Trigger refresh
           }
        })
        ..on<lk.TrackSubscribedEvent>((event) {
          if (event.track.kind == lk.TrackType.VIDEO) {
            if (mounted) {
              setState(() {
                _remoteVideoTrack = event.track as lk.VideoTrack;
              });
            }
          }
        })
        ..on<lk.TrackUnsubscribedEvent>((event) {
          if (event.track.kind == lk.TrackType.VIDEO) {
            if (mounted) {
              setState(() {
                _remoteVideoTrack = null;
              });
            }
          }
        })
        ..on<lk.LocalTrackPublishedEvent>((event) {
          if (event.publication.track?.kind == lk.TrackType.VIDEO) {
            if (mounted) {
              setState(() {
                _localVideoTrack = event.publication.track as lk.VideoTrack;
              });
            }
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
        if (_isVideoCall) {
          await _room!.localParticipant?.setCameraEnabled(true);
        }
      }
      AppLogger.instance.info('LiveKit odasına bağlanıldı: $roomName');
    } catch (e) {
      AppLogger.instance.error('LiveKit bağlantı hatası: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Bağlantı kurulamadı. Lütfen internet bağlantınızı kontrol edin.'),
          duration: Duration(seconds: 3),
        ));
        Navigator.pop(context);
      }
    }
  }

  bool _remoteHasJoined = false;
  
  void _onRoomStateChanged() {
    if (!mounted || _room == null) return;
    
    // Yalnızca karşı taraf bağlandıysa takip et
    if (_room!.remoteParticipants.isNotEmpty) {
      _remoteHasJoined = true;
    }
    
    setState(() {
      switch (_room!.connectionState) {
        case lk.ConnectionState.connecting:
          _connectionStatus = 'Bağlanıyor...';
          break;
        case lk.ConnectionState.connected:
          // Karşı taraf çıkmışsa da bağlantı kesildi say
          if (_remoteHasJoined && _room!.remoteParticipants.isEmpty) {
            _connectionStatus = 'Karşı taraf bağlantısını kaybetti...';
            if (_reconnectTimer == null || !_reconnectTimer!.isActive) {
              _startReconnectionProcess();
            }
          } else {
            _connectionStatus = 'Bağlandı';
            _reconnectTimer?.cancel();
            _reconnectBeepTimer?.cancel();
          }
          break;
        case lk.ConnectionState.reconnecting:
          _connectionStatus = 'Yeniden Bağlanıyor...';
          if (_reconnectTimer == null || !_reconnectTimer!.isActive) {
            _startReconnectionProcess();
          }
          break;
        case lk.ConnectionState.disconnected:
          _connectionStatus = 'Bağlantı Kesildi';
          _reconnectTimer?.cancel();
          _reconnectBeepTimer?.cancel();
          break;
      }
    });
    
    AppLogger.instance.info('Oda durumu güncellendi: ${_room!.connectionState}');
  }

  void _startReconnectionProcess() {
    _reconnectTimer?.cancel();
    _reconnectBeepTimer?.cancel();

    // 10 saniye süre tanı, bağlanmazsa kapat
    _reconnectTimer = Timer(const Duration(seconds: 10), () {
      if (mounted && _room != null) {
        bool stillDisconnected = _room!.connectionState != lk.ConnectionState.connected || 
                                 (_remoteHasJoined && _room!.remoteParticipants.isEmpty);
        if (stillDisconnected) {
          AppLogger.instance.warning('Yeniden bağlanma zaman aşımına uğradı, çağrı sonlandırılıyor.');
          _hangUp();
        }
      }
    });

    // Yeniden bağlanırken 'dıt dıt' sesi çal (1 saniyede bir)
    _reconnectBeepTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
       _playSystemBeep(isEnd: true); 
    });
  }

  Future<void> _updateOrCreateCallMessage(String content) async {
    try {
      if (_callMessageId != null) {
        await PocketBaseService.client.collection('messages').update(_callMessageId!, body: {
          'content': content,
        });
      } else {
        final record = await PocketBaseService.client.collection('messages').create(body: {
          'chat_id': widget.chatId,
          'sender_id': _myId,
          'content': content,
        });
        _callMessageId = record.id;
      }
    } catch (e) {
      AppLogger.instance.error('Arama mesajı güncelleme hatası: $e');
    }
  }

  void _handleAccept() async {
    _stopRingtone();
    _callTimeoutTimer?.cancel();
    setState(() {
      _isAccepted = true;
    });
    
    // Kabul edildi mesajı gönder (Arayanı uyarmak için)
    try {
      await _updateOrCreateCallMessage('[CALL_ACCEPTED]');
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
    CallScreen.isInCall = false;
    _stopRingtone();
    _callTimeoutTimer?.cancel();
    _reconnectTimer?.cancel();
    _reconnectBeepTimer?.cancel();
    _durationTimer?.cancel();
    _ringtonePlayer.dispose();
    _room?.removeListener(_onRoomStateChanged);
    _room?.disconnect();
    _messagesUnsub?.call();
    _room = null; // Bellek yönetimi için null yap
    super.dispose();
  }

  void _hangUp() async {
    if (!mounted) return;
    _stopRingtone();
    final durationText = _secondsElapsed > 0 ? " (${_formatDuration(_secondsElapsed)})" : "";
    final status = _secondsElapsed > 0 ? "TAMAMLANDI" : "CEVAPLANMADI";
       
    try {
      await _updateOrCreateCallMessage(_isVideoCall ? '[VIDEO_CALL_ENDED]$status$durationText' : '[VOICE_CALL_ENDED]$status$durationText');
    } catch (e) {
      AppLogger.instance.error('Arama kapanış mesajı hatası: $e');
    }
    
    // Odayı kapatmadan önce dinleyiciyi kaldır
    _room?.removeListener(_onRoomStateChanged);
    await _room?.disconnect();
    _room = null;
    
    _playEndSound();
    
    if (mounted) Navigator.pop(context);
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
    });
    _room?.localParticipant?.setMicrophoneEnabled(!_isMuted);
    
    // Sesli okuma uyarısı
    SemanticsService.announce(
      _isMuted ? "Mikrofon şu anda kapalı" : "Mikrofon şu anda açık",
      TextDirection.ltr,
    );
  }

  void _toggleCam() {
    setState(() {
      _isCamOff = !_isCamOff;
    });
    _room?.localParticipant?.setCameraEnabled(!_isCamOff);
    
    // Sesli okuma uyarısı
    SemanticsService.announce(
      _isCamOff ? "Kamera şu anda kapalı" : "Kamera şu anda açık",
      TextDirection.ltr,
    );
  }

  bool _isFrontCamera = true;

  void _switchCamera() async {
    try {
      final localPart = _room?.localParticipant;
      if (localPart != null) {
        final videoTrack = localPart.videoTrackPublications.firstOrNull?.track as lk.LocalVideoTrack?;
        if (videoTrack != null) {
          // LiveKit Flutter SDK switchCamera() signature might vary by version.
          // Using restartTrack with toggled position for better compatibility.
          _isFrontCamera = !_isFrontCamera;
          await videoTrack.restartTrack(lk.CameraCaptureOptions(
            cameraPosition: _isFrontCamera ? lk.CameraPosition.front : lk.CameraPosition.back,
          ));
          SemanticsService.announce("Kamera değiştirildi", TextDirection.ltr);
        }
      }
    } catch (e) {
      AppLogger.instance.error('Kamera değiştirme hatası: $e');
    }
  }

  void _showShareMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[600],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Icon(
                  _isScreenSharing ? Icons.stop_screen_share : Icons.screen_share,
                  color: Colors.white,
                ),
                title: Text(
                  _isScreenSharing ? "Ekran Paylaşımını Durdur" : "Ekranı Paylaş",
                  style: const TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(context); // Menüyü kapat
                  _toggleScreenShare();
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _toggleScreenShare() async {
    if (_isScreenSharing) {
      try {
        await _room?.localParticipant?.setScreenShareEnabled(false);
        setState(() {
          _isScreenSharing = false;
        });
        SemanticsService.announce("Ekran paylaşımı durduruldu", TextDirection.ltr);
      } catch (e) {
        AppLogger.instance.error('Ekran paylaşımı durdurulamadı: $e');
      }
    } else {
      // Prompt user confirm
      bool? confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text("Ekranı Paylaş", style: TextStyle(color: Colors.white)),
          content: const Text(
            "Görüntülü görüşmede ekranda yer alan içerikleri karşı taraf görecek. Görüntünüz kapatılacaktır. Onaylıyor musunuz?",
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("İptal", style: TextStyle(color: Colors.white54)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Paylaş", style: TextStyle(color: Colors.blue)),
            ),
          ],
        ),
      );

      if (confirm == true) {
        if (_isVideoCall && !_isCamOff) {
          _toggleCam(); // Kamerayı kapat
        }
        try {
          await _room?.localParticipant?.setScreenShareEnabled(true);
          setState(() {
            _isScreenSharing = true;
          });
          SemanticsService.announce("Ekran paylaşımı başlatıldı", TextDirection.ltr);
        } catch (e) {
          AppLogger.instance.error('Ekran paylaşımı başlatılamadı: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Ekran paylaşımı başlatılamadı veya desteklenmiyor.')),
            );
          }
        }
      }
    }
  }

  void _toggleSpeaker() {
    setState(() {
      _isSpeakerOn = !_isSpeakerOn;
    });
    lk.Hardware.instance.setSpeakerphoneOn(_isSpeakerOn);
    
    SemanticsService.announce(
      _isSpeakerOn ? "Hoparlör açıldı" : "Hoparlör kapatıldı (Ahizeye geçildi)",
      TextDirection.ltr,
    );
  }

  void _requestVideoTransition() async {
    try {
      await _updateOrCreateCallMessage('[VIDEO_REQUEST]');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Görüntülü görüşme isteği gönderildi...')),
      );
    } catch (e) {
      AppLogger.instance.error('Video isteği hatası: $e');
    }
  }

  void _acceptVideoRequest() async {
    setState(() {
      _showVideoRequest = false;
    });
    try {
      await _updateOrCreateCallMessage('[VIDEO_ACCEPTED]');
      _enableVideo(true);
    } catch (e) {
      AppLogger.instance.error('Video kabul hatası: $e');
    }
  }

  void _rejectVideoRequest() async {
    setState(() {
      _showVideoRequest = false;
    });
    try {
      await _updateOrCreateCallMessage('[VIDEO_REJECTED]');
    } catch (e) {
      AppLogger.instance.error('Video reddetme hatası: $e');
    }
  }

  void _enableVideo(bool enable) async {
    if (_room == null) return;
    
    // Kamera izni kontrol et
    if (enable && !kIsWeb) {
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kamera izni verilmedi.')),
        );
        return;
      }
    }

    setState(() {
      _isVideoCall = enable;
    });
    await _room!.localParticipant?.setCameraEnabled(enable);
    
    // Görüntü geldikten sonra hoparlörü açmak mantıklı olabilir ama kullanıcı "varsayılan ahize" dediği için dokunmuyorum
    // lk.Hardware.instance.setSpeakerphoneOn(enable); 
    
    SemanticsService.announce(
      enable ? "Görüntülü görüşmeye geçildi" : "Sesli görüşmeye dönüldü",
      TextDirection.ltr,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Fullscreen Video
          if (_isVideoCall && _isJoined)
            Positioned.fill(
              child: GestureDetector(
                onTap: () {
                  if (_localVideoTrack != null && _remoteVideoTrack != null) {
                    setState(() => _isLocalVideoFullscreen = !_isLocalVideoFullscreen);
                  }
                },
                child: _isLocalVideoFullscreen
                    ? (_localVideoTrack != null && !_isCamOff
                        ? lk.VideoTrackRenderer(_localVideoTrack!)
                        : const Center(child: Icon(Icons.videocam_off, color: Colors.white24, size: 80)))
                    : (_remoteVideoTrack != null
                        ? lk.VideoTrackRenderer(_remoteVideoTrack!)
                        : const Center(child: Icon(Icons.videocam_off, color: Colors.white24, size: 80))),
              ),
            ),
          
          // PiP Video
          if (_isVideoCall && _isJoined)
            Positioned(
              top: MediaQuery.of(context).padding.top + 20,
              right: 20,
              child: GestureDetector(
                onTap: () {
                  if (_localVideoTrack != null && _remoteVideoTrack != null) {
                    setState(() => _isLocalVideoFullscreen = !_isLocalVideoFullscreen);
                  }
                },
                child: Container(
                  width: 100,
                  height: 150,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: _isLocalVideoFullscreen
                        ? (_remoteVideoTrack != null
                            ? lk.VideoTrackRenderer(_remoteVideoTrack!)
                            : const Center(child: Icon(Icons.videocam_off, color: Colors.white24)))
                        : (_localVideoTrack != null && !_isCamOff
                            ? lk.VideoTrackRenderer(_localVideoTrack!)
                            : const Center(child: Icon(Icons.videocam_off, color: Colors.white24))),
                  ),
                ),
              ),
            ),
             
          // WhatsApp Style Overlay
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 60),
                if (_remoteVideoTrack == null || !_isVideoCall) ...[
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
                ],
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _isVideoCall ? Icons.videocam : Icons.call,
                      size: 16,
                      color: Colors.white70,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isAccepted 
                        ? (_isVideoCall ? "Görüntülü Görüşme (" + _connectionStatus + ")" : "Sesli Görüşme (" + _connectionStatus + ")")
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
                
                // Control ButtonsBar - Sadece arama kabul edildiyse göster
                if (_isAccepted)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.grey[900]?.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildControlButton(
                              icon: _isSpeakerOn ? Icons.volume_up : Icons.volume_down,
                              color: _isSpeakerOn ? Colors.white : Colors.white10,
                              iconColor: _isSpeakerOn ? Colors.black : Colors.white,
                              onPressed: _toggleSpeaker,
                              label: "Hoparlör",
                            ),
                            _buildControlButton(
                              icon: _isVideoCall ? Icons.videocam : Icons.videocam_off,
                              color: _isVideoCall ? Colors.white : Colors.white10,
                              iconColor: _isVideoCall ? Colors.black : Colors.white,
                              onPressed: _isVideoCall ? _toggleCam : _requestVideoTransition,
                              label: "Video",
                            ),
                            _buildControlButton(
                              icon: _isMuted ? Icons.mic_off : Icons.mic,
                              color: _isMuted ? Colors.white : Colors.white10,
                              iconColor: _isMuted ? Colors.black : Colors.white,
                              onPressed: _toggleMute,
                              label: "Sessize al",
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildControlButton(
                              icon: Icons.ios_share,
                              color: _isScreenSharing ? Colors.blue : Colors.white10,
                              iconColor: Colors.white,
                              onPressed: () => _showShareMenu(context),
                              label: "Paylaş",
                            ),
                            if (_isVideoCall)
                              _buildControlButton(
                                icon: Icons.flip_camera_ios,
                                color: Colors.white10,
                                iconColor: Colors.white,
                                onPressed: _switchCamera,
                                label: "Kamera Değiştir",
                              )
                            else
                              const SizedBox(width: 56),
                            _buildControlButton(
                              icon: Icons.call_end,
                              color: Colors.red,
                              iconColor: Colors.white,
                              onPressed: _hangUp,
                              label: "Bitir",
                            ),
                          ],
                        ),
                      ],
                    ),
                  )
                else if (!widget.isIncoming)
                  // Arayan taraf için vazgeç butonu
                  Padding(
                    padding: const EdgeInsets.only(bottom: 60),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FloatingActionButton(
                          heroTag: "cancel",
                          onPressed: _cancelCall,
                          backgroundColor: Colors.red,
                          tooltip: "Vazgeç",
                          child: const Icon(Icons.call_end, color: Colors.white, size: 30),
                        ),
                        const SizedBox(height: 12),
                        const ExcludeSemantics(child: Text("Vazgeç", style: TextStyle(color: Colors.white))),
                      ],
                    ),
                  ),
                const SizedBox(height: 48),
              ],
            ),
          ),
          
          // Gelen arama butonları - Sadece arama henüz kabul edilmediyse ve gelense göster
          if (widget.isIncoming && !_isAccepted)
             Align(
               alignment: Alignment.bottomCenter,
               child: Padding(
                 padding: const EdgeInsets.only(bottom: 60),
                 child: Row(
                   mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                   children: [
                     Column(
                       mainAxisSize: MainAxisSize.min,
                       children: [
                         Semantics(
                           label: "Cevapla",
                           button: true,
                           child: FloatingActionButton(
                             heroTag: "accept",
                             onPressed: _handleAccept,
                             backgroundColor: Colors.green,
                             tooltip: "Cevapla",
                             child: const Icon(Icons.call, color: Colors.white, size: 30),
                           ),
                         ),
                         const SizedBox(height: 12),
                         const Text("Cevapla", style: TextStyle(color: Colors.white)),
                       ],
                     ),
                     Column(
                       mainAxisSize: MainAxisSize.min,
                       children: [
                         Semantics(
                           label: "Reddet",
                           button: true,
                           child: FloatingActionButton(
                             heroTag: "decline",
                             onPressed: _hangUpRejected,
                             backgroundColor: Colors.red,
                             tooltip: "Reddet",
                             child: const Icon(Icons.call_end, color: Colors.white, size: 30),
                           ),
                         ),
                         const SizedBox(height: 12),
                         const Text("Reddet", style: TextStyle(color: Colors.white)),
                       ],
                     ),
                   ],
                 ),
               ),
             ),
          
          // Görüntülü Görüşme İsteği Overly/Dialog
          if (_showVideoRequest)
             Positioned.fill(
               child: Container(
                 color: Colors.black87,
                 child: Center(
                   child: Container(
                     margin: const EdgeInsets.symmetric(horizontal: 32),
                     padding: const EdgeInsets.all(24),
                     decoration: BoxDecoration(
                       color: Colors.grey[900],
                       borderRadius: BorderRadius.circular(24),
                       border: Border.all(color: Colors.white12),
                     ),
                     child: Column(
                       mainAxisSize: MainAxisSize.min,
                       children: [
                         const Icon(Icons.videocam, color: Colors.greenAccent, size: 48),
                         const SizedBox(height: 16),
                         Text(
                           "$_videoRequesterName görüntülü görüşmeye geçmek istiyor",
                           textAlign: TextAlign.center,
                           style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                         ),
                         const SizedBox(height: 24),
                         Row(
                           children: [
                             Expanded(
                               child: ElevatedButton(
                                 onPressed: _rejectVideoRequest,
                                 style: ElevatedButton.styleFrom(
                                   backgroundColor: Colors.red[800],
                                   foregroundColor: Colors.white,
                                   padding: const EdgeInsets.symmetric(vertical: 12),
                                 ),
                                 child: const Text("İptal"),
                               ),
                             ),
                             const SizedBox(width: 16),
                             Expanded(
                               child: ElevatedButton(
                                 onPressed: _acceptVideoRequest,
                                 style: ElevatedButton.styleFrom(
                                   backgroundColor: Colors.green[800],
                                   foregroundColor: Colors.white,
                                   padding: const EdgeInsets.symmetric(vertical: 12),
                                 ),
                                 child: const Text("Geç"),
                               ),
                             ),
                           ],
                         ),
                       ],
                     ),
                   ),
                 ),
               ),
             ),
        ],
      ),
    );
  }

  void _cancelCall() async {
    _stopRingtone();
    _playEndSound();
    try {
      await _updateOrCreateCallMessage('[CALL_CANCELLED]');
    } catch (e) {
      AppLogger.instance.error('Arama iptal mesajı hatası: $e');
    }
    if (mounted) Navigator.pop(context);
  }

  void _hangUpRejected() async {
    _stopRingtone();
    _playEndSound();
    try {
      await _updateOrCreateCallMessage('[CALL_REJECTED]');
    } catch (e) {
      AppLogger.instance.error('Arama reddetme mesajı hatası: $e');
    }
    if (mounted) Navigator.pop(context);
  }

  Widget _buildControlButton({
    required IconData icon,
    required Color color,
    required Color iconColor,
    required VoidCallback onPressed,
    required String label,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: Icon(icon),
            color: iconColor,
            iconSize: 28,
            onPressed: onPressed,
            tooltip: label,
          ),
        ),
        const SizedBox(height: 8),
        ExcludeSemantics(
          child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ),
      ],
    );
  }
}
