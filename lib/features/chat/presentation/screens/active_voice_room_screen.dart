import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:livekit_client/livekit_client.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:blind_social/core/services/pocketbase_service.dart';
import 'package:blind_social/core/utils/logger.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as webrtc;

import 'package:permission_handler/permission_handler.dart';
import '../../../../core/services/settings_service.dart';

class ActiveVoiceRoomScreen extends StatefulWidget {
  final String roomId;
  final String roomName;

  const ActiveVoiceRoomScreen({
    super.key,
    required this.roomId,
    required this.roomName,
  });

  @override
  State<ActiveVoiceRoomScreen> createState() => _ActiveVoiceRoomScreenState();
}

class _ActiveVoiceRoomScreenState extends State<ActiveVoiceRoomScreen> {
  bool _isMuted = false;
  bool _isConnected = false;
  String? _errorMessage;
  Room? _room;
  EventsListener<RoomEvent>? _listener;
  List<Participant> _participants = [];
  final SettingsService _settingsService = SettingsService();

  bool _isLoadingParticipants = true;
  List<Map<String, dynamic>> _previewParticipants = [];

  Future<void> _playSystemBeep({required bool isJoin}) async {
    if (!kIsWeb) {
      try {
        await const MethodChannel('com.example.blind_social/lockscreen')
            .invokeMethod('playTone', {'type': isJoin ? 'start' : 'end', 'duration': 150});
      } catch (e) {
        AppLogger.instance.warning('Sistem biplenirken hata: $e');
      }
    }
  }

  @override
  void initState() {
    super.initState();
    // Do not connect automatically, wait for user interaction to avoid minified DOMException on Web
    _fetchParticipants();
  }

  Future<void> _fetchParticipants() async {
    try {
      String livekitUrl = dotenv.env['LIVEKIT_URL'] ?? '';
      final String apiKey = dotenv.env['LIVEKIT_API_KEY'] ?? '';
      final String apiSecret = dotenv.env['LIVEKIT_API_SECRET'] ?? '';

      if (livekitUrl.isEmpty || apiKey.isEmpty || apiSecret.isEmpty) {
        if (mounted) setState(() => _isLoadingParticipants = false);
        return;
      }

      final jwt = JWT({
        'iss': apiKey,
        'nbf': 0,
        'exp': (DateTime.now().millisecondsSinceEpoch / 1000).round() + 60,
        'video': {
          'roomAdmin': true,
          'room': widget.roomId,
        }
      });
      final token = jwt.sign(SecretKey(apiSecret));

      final httpUrl = livekitUrl.replaceFirst('wss://', 'https://').replaceFirst('ws://', 'http://');

      final response = await http.post(
        Uri.parse('$httpUrl/twirp/livekit.RoomService/ListParticipants'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({"room": widget.roomId}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final list = data['participants'] as List? ?? [];
        if (mounted) {
          setState(() {
            _previewParticipants = list.map((e) => e as Map<String, dynamic>).toList();
            _isLoadingParticipants = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoadingParticipants = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingParticipants = false;
        });
      }
    }
  }

  void _onRoomDidUpdate() {
    if (_room == null) return;
    setState(() {
      _participants = [
        if (_room!.localParticipant != null) _room!.localParticipant!,
        ..._room!.remoteParticipants.values,
      ];
    });
  }

  String _generateToken(String apiKey, String apiSecret, String roomName, String participantIdentity, String participantName) {
    final jwt = JWT({
      'exp': (DateTime.now().millisecondsSinceEpoch / 1000).round() + (60 * 60 * 24), // 24 hours valid
      'iss': apiKey,
      'sub': participantIdentity,
      'name': participantName,
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

  Future<void> _connectToRoom() async {
    try {
      if (!kIsWeb) {
        final status = await Permission.microphone.request();
        if (status != PermissionStatus.granted) {
          if (mounted) {
            setState(() {
              _errorMessage = 'Sohbete katılmak için mikrofon izni gereklidir.';
            });
          }
          return;
        }
      }

      AppLogger.instance.info('Odaya bağlanılıyor: ${widget.roomName} (${widget.roomId})');
      
      String livekitUrl = dotenv.env['LIVEKIT_URL'] ?? '';
      final String apiKey = dotenv.env['LIVEKIT_API_KEY'] ?? '';
      final String apiSecret = dotenv.env['LIVEKIT_API_SECRET'] ?? '';

      // Web platform needs https instead of wss
      if (kIsWeb && livekitUrl.startsWith('wss://')) {
        livekitUrl = livekitUrl.replaceFirst('wss://', 'https://');
      }
      if (kIsWeb && livekitUrl.startsWith('ws://')) {
        livekitUrl = livekitUrl.replaceFirst('ws://', 'http://');
      }

      if (livekitUrl.isEmpty || apiKey.isEmpty || apiSecret.isEmpty) {
        AppLogger.instance.warning('LiveKit URL, Key veya Secret bulunamadı.');
        if (mounted) {
          setState(() {
            _errorMessage = 'LiveKit sunucu ayarları yapılandırılmadığı için sohbet odasına bağlanılamıyor.';
            _isConnected = false;
          });
        }
        return;
      }

      String userId = 'anonymous_${DateTime.now().millisecondsSinceEpoch}';
      String userName = 'Misafir';
      
      try {
        final user = PocketBaseService.client.authStore.model;
        if (user != null) {
          userId = user.id ?? userId;
          
          bool hasUsername = false;
          try {
            hasUsername = user.getStringValue('username').isNotEmpty;
            if (hasUsername) {
              userName = '@${user.getStringValue('username')}';
            }
          } catch (_) {
            if (user is Map) {
              userName = user['username'] != null && user['username'].toString().isNotEmpty 
                  ? '@${user['username']}' 
                  : 'Misafir';
            }
          }
        }
      } catch (e) {
        AppLogger.instance.warning('User bilgisi alınırken hata: $e');
      }
      
      AppLogger.instance.info('User bilgisi tamam.');
      AppLogger.instance.info('Token oluşturuluyor...');
      String livekitToken = '';
      try {
        livekitToken = _generateToken(apiKey, apiSecret, widget.roomId, userId, userName);
        AppLogger.instance.info('Token oluşturuldu.');
      } catch (e, st) {
        AppLogger.instance.error('Token oluşturma hatası: $e\n$st');
        throw Exception('Token Error: $e');
      }

      if (!kIsWeb) {
        try {
          await Hardware.instance.setSpeakerphoneOn(true);
        } catch (_) {}
      }

      try {
        _room = Room();
        _listener = _room!.createListener();

        AppLogger.instance.info('Room connect çağrılıyor...');
        await _room!.connect(
          livekitUrl, 
          livekitToken,
          connectOptions: const ConnectOptions(
            autoSubscribe: true,
          ),
        );
        AppLogger.instance.info('Room connect bitti.');
      } catch (e, st) {
        String deepError = e.toString();
        if (kIsWeb) {
            try {
               final jsObj = e as dynamic;
               final name = jsObj.name != null ? 'Name: ${jsObj.name}' : '';
               final message = jsObj.message != null ? 'Msg: ${jsObj.message}' : '';
               deepError += ' | JS Data: $name $message';
            } catch (_) {}
        }
        AppLogger.instance.error('Room.connect sırasında hata: $deepError\n$st');
        throw Exception('Connect Error: $deepError');
      }
      
      _listener
      //...
        ?..on<ParticipantConnectedEvent>((event) {
          _onRoomDidUpdate();
          _notifyParticipantStatus(event.participant, true);
        })
        ..on<ParticipantDisconnectedEvent>((event) {
          _onRoomDidUpdate();
          _notifyParticipantStatus(event.participant, false);
        })
        ..on<RoomDisconnectedEvent>((_) {
           if (mounted) Navigator.of(context).pop();
        })
        ..on<TrackSubscribedEvent>((_) => _onRoomDidUpdate())
        ..on<TrackUnsubscribedEvent>((_) => _onRoomDidUpdate())
        ..on<ActiveSpeakersChangedEvent>((_) => _onRoomDidUpdate())
        ..on<ParticipantMetadataUpdatedEvent>((_) => _onRoomDidUpdate());

      if (mounted) {
        setState(() {
          _isConnected = true;
          _onRoomDidUpdate();
        });
      }

      try {
        await _room!.localParticipant?.setMicrophoneEnabled(true);
        if (mounted) {
          setState(() {
            _isMuted = false;
          });
        }
      } catch (micError) {
        String cause = micError.toString();
        try {
          final jsObj = micError as dynamic;
          if (jsObj.name != null) cause = '${jsObj.name}: ${jsObj.message}';
        } catch (_) {}
        AppLogger.instance.warning('Bağlantı sonrası mikrofon açılamadı (\'$cause\'). Sadece dinleyici modundasınız.');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Mikrofona erişilemedi, sadece dinleyici olarak katıldınız.')),
          );
          setState(() {
            _isMuted = true;
          });
        }
      }
      
      AppLogger.instance.info('LiveKit odaya başarıyla bağlanıldı: ${widget.roomName}');
      _playSystemBeep(isJoin: true);

    } catch (e, st) {
      String finalErrorOut = e.toString();
      try {
        final jsObj = e as dynamic;
        if (jsObj.name != null) finalErrorOut = '${jsObj.name}: ${jsObj.message}';
      } catch (_) {}
      
      AppLogger.instance.error('LiveKit bağlantı hatası: $finalErrorOut\n$st');
      
      if (mounted) {
        setState(() {
          _errorMessage = finalErrorOut;
          _isConnected = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Bağlantı hatası: $finalErrorOut')),
        );
      }
    }
  }

  void _notifyParticipantStatus(Participant? participant, bool isJoined) {
    if (participant == null || !_settingsService.voiceRoomNotificationsEnabled) return;
    
    final name = participant.name.isNotEmpty ? participant.name : 'Bir kullanıcı';
    final message = isJoined ? "$name odaya girdi" : "$name odadan ayrıldı";
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  void dispose() {
    if (_isConnected) {
      _playSystemBeep(isJoin: false);
    }
    try {
      _listener?.dispose();
    } catch (_) {}
    try {
      _room?.disconnect();
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF101820), // Koyu arka plan
      appBar: AppBar(
        title: Semantics(
          label: "${widget.roomName} isimli sesli odadasınız",
          header: true,
          child: ExcludeSemantics(child: Text(widget.roomName)),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _errorMessage != null 
        ? Center(child: Padding(padding: const EdgeInsets.all(16.0), child: Text('Bağlantı hatası: $_errorMessage\nLütfen sayfayı yenileyip tekrar deneyin.', textAlign: TextAlign.center, style: const TextStyle(color: Colors.red))))
        : !_isConnected && _room == null
            ? Column(
                children: [
                  const SizedBox(height: 32),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      setState(() {
                        _errorMessage = null;
                      });
                      _connectToRoom();
                    },
                    child: Semantics(
                      label: "Sohbete Katıl",
                      child: const Text("Sohbete Katıl", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 32),
                  if (_isLoadingParticipants)
                    const Center(child: CircularProgressIndicator())
                  else
                    Expanded(
                      child: _previewParticipants.isEmpty
                          ? const Center(
                              child: Text(
                                "Oda şu an boş.\nİlk katılan siz olun!",
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.white54, fontSize: 16),
                              ),
                            )
                          : _buildPreviewParticipantsTable(),
                    ),
                ],
              )
            : _isConnected 
              ? _buildParticipantGrid()
              : const Center(child: CircularProgressIndicator()),
      bottomNavigationBar: _isConnected ? _buildBottomControls() : null,
    );
  }

  Widget _buildPreviewParticipantsTable() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12.0),
            child: Semantics(
              header: true,
              child: Text(
                "Odada ${_previewParticipants.length} aktif kişi var",
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1B2838),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12),
              ),
              child: ListView.separated(
                itemCount: _previewParticipants.length,
                separatorBuilder: (context, index) => const Divider(color: Colors.white12, height: 1),
                itemBuilder: (context, index) {
                  final p = _previewParticipants[index];
                  final String identity = p['identity']?.toString() ?? 'Bilinmeyen';
                  final String rawName = p['name']?.toString() ?? identity;
                  final String displayName = rawName.isNotEmpty ? rawName : identity;
                  final String name = displayName.startsWith('anonymous_') ? 'Misafir' : displayName;

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.blueGrey,
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    title: Text(
                      name,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                    ),
                    trailing: const Icon(Icons.record_voice_over, color: Colors.green, size: 20),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildParticipantGrid() {
    // Katılımcı sayısına göre kolon sayısı
    int crossAxisCount = 1;
    if (_participants.length > 1) {
      crossAxisCount = 2;
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Adaptif yükseklik hesaplama (Ekrana sığması için)
          final double totalHeight = constraints.maxHeight;
          final int rowCount = (_participants.length / crossAxisCount).ceil();
          final double itemHeight = (totalHeight / (rowCount > 0 ? rowCount : 1)) - (16 * (rowCount - 1) / (rowCount > 0 ? rowCount : 1));
          final double childAspectRatio = (constraints.maxWidth / crossAxisCount) / (itemHeight > 0 ? itemHeight : 100);

          return GridView.builder(
            itemCount: _participants.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: childAspectRatio,
            ),
            itemBuilder: (context, index) {
              final p = _participants[index];
              return _ParticipantTile(participant: p);
            },
          );
        }
      ),
    );
  }

  Widget _buildBottomControls() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 30),
        color: const Color(0xFF101820),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            // Ayarlar butonu
            _ControlButton(
              icon: Icons.settings_outlined,
              label: "Mikrofon Ayarları",
              hint: "Mikrofon giriş ve çıkış ayarlarını düzenle",
              onPressed: () {
                // Gelecekte eklenecek
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Ayarlar yakında eklenecek')),
                );
              },
              backgroundColor: Colors.grey.withOpacity(0.2),
            ),
            // Odadan Ayrıl (Kırmızı)
            _ControlButton(
              icon: Icons.call_end,
              label: "Görüşmeyi Kapat",
              hint: "Sesli sohbetten ayrıl",
              onPressed: () {
                AppLogger.instance.info('Odadan ayrılındı: ${widget.roomName}');
                Navigator.of(context).pop();
              },
              backgroundColor: Colors.red,
              size: 70,
              iconSize: 32,
            ),
            // Mikrofon Aç/Kapat (Yeşil/Kırmızı)
            _ControlButton(
              icon: _isMuted ? Icons.mic_off : Icons.mic,
              label: _isMuted ? "Mikrofonu Aç" : "Mikrofonu Kapat",
              hint: _isMuted ? "Sesini sohbete gönder" : "Sesini sessize al",
              onPressed: () async {
                try {
                  final targetState = !_isMuted;
                  if (_room != null) {
                    await _room!.localParticipant?.setMicrophoneEnabled(!targetState);
                  }
                  setState(() {
                    _isMuted = targetState;
                  });
                } catch (e) {
                  AppLogger.instance.error('Mikrofon kontrol hatası: $e');
                }
              },
              backgroundColor: _isMuted ? Colors.red.withOpacity(0.5) : Colors.green[700],
            ),
          ],
        ),
      ),
    );
  }
}

class _ParticipantTile extends StatelessWidget {
  final Participant participant;

  const _ParticipantTile({required this.participant});

  @override
  Widget build(BuildContext context) {
    final identity = participant.identity;
    // LiveKit name alanını kontrol et, boşsa identity (ID) kullan.
    final displayName = participant.name.isNotEmpty ? participant.name : identity;
    final name = displayName.startsWith('anonymous_') ? 'Misafir' : displayName;
    final isMuted = !participant.isMicrophoneEnabled();
    final isSpeaking = participant.isSpeaking;

    return Semantics(
      label: "$name. ${isMuted ? 'Mikrofonu kapalı' : 'Mikrofonu açık'}${isSpeaking ? '. Şu anda konuşuyor' : ''}",
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1B2838),
          borderRadius: BorderRadius.circular(20),
          border: isSpeaking ? Border.all(color: Colors.green, width: 2) : Border.all(color: Colors.white12),
        ),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.blueGrey,
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: const TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    name,
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (isSpeaking)
                   const Padding(
                     padding: EdgeInsets.only(top: 4.0),
                     child: Text(
                       "Şu anda konuşuyor",
                       style: TextStyle(color: Colors.green, fontSize: 12),
                     ),
                   ),
                  if (isSpeaking)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _VoiceWaveBar(height: 10, active: true),
                          SizedBox(width: 2),
                          _VoiceWaveBar(height: 20, active: true),
                          SizedBox(width: 2),
                          _VoiceWaveBar(height: 15, active: true),
                          SizedBox(width: 2),
                          _VoiceWaveBar(height: 25, active: true),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: Icon(
                isMuted ? Icons.mic_off : Icons.mic,
                size: 18,
                color: isMuted ? Colors.red : Colors.white60,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VoiceWaveBar extends StatelessWidget {
  final double height;
  final bool active;

  const _VoiceWaveBar({required this.height, required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 3,
      height: height,
      decoration: BoxDecoration(
        color: active ? Colors.green : Colors.grey,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final Color? backgroundColor;
  final double size;
  final double iconSize;
  final String label;
  final String hint;

  const _ControlButton({
    required this.icon,
    required this.onPressed,
    required this.label,
    required this.hint,
    this.backgroundColor,
    this.size = 56,
    this.iconSize = 24,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      hint: hint,
      button: true,
      excludeSemantics: true,
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: backgroundColor ?? Colors.grey.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Icon(icon, color: Colors.white, size: iconSize),
          ),
        ),
      ),
    );
  }
}
