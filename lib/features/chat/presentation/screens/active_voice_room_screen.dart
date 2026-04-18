import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:blind_social/core/services/pocketbase_service.dart';
import 'package:blind_social/core/utils/logger.dart';

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
  Room? _room;

  @override
  void initState() {
    super.initState();
    _connectToRoom();
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

  Future<void> _connectToRoom() async {
    AppLogger.instance.info('Odaya bağlanılıyor: ${widget.roomName} (${widget.roomId})');
    
    // .env dosyasından okuyoruz. GitHub Actions .env oluşturuyor.
    final String livekitUrl = dotenv.env['LIVEKIT_URL'] ?? '';
    final String apiKey = dotenv.env['LIVEKIT_API_KEY'] ?? '';
    final String apiSecret = dotenv.env['LIVEKIT_API_SECRET'] ?? '';

    if (livekitUrl.isEmpty || apiKey.isEmpty || apiSecret.isEmpty) {
      AppLogger.instance.warning('LiveKit URL, Key veya Secret bulunamadı. Simülasyon modunda açılıyor.');
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        setState(() {
          _isConnected = true;
        });
        AppLogger.instance.info('Odaya simülasyon modunda başarıyla bağlanıldı: ${widget.roomName}');
      }
      return;
    }

    try {
      final user = PocketBaseService.client.authStore.model;
      final userId = user?.id ?? 'anonymous_${DateTime.now().millisecondsSinceEpoch}';
      
      // Tokeni lokal imzalayarak oluşturuyoruz
      final String livekitToken = _generateToken(apiKey, apiSecret, widget.roomName, userId);

      _room = Room();
      
      const roomOptions = RoomOptions(
        adaptiveStream: true,
        dynacast: true,
      );

      await _room!.connect(livekitUrl, livekitToken, roomOptions: roomOptions);
      
      if (mounted) {
        setState(() {
          _isConnected = true;
        });
      }

      await _room!.localParticipant?.setMicrophoneEnabled(true);
      AppLogger.instance.info('LiveKit odaya başarıyla bağlanıldı: ${widget.roomName}');

    } catch (e) {
      AppLogger.instance.error('LiveKit bağlantı hatası: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Bağlantı hatası: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _room?.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.roomName),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.graphic_eq,
              size: 100,
              color: Colors.green,
            ),
            const SizedBox(height: 20),
            Text(
              _isConnected ? "Odaya Bağlanıldı" : "Bağlanılıyor...",
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            if (_isConnected)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24.0),
                child: Text(
                  "Şu anda odadasınız. (Eğer ses gitmiyorsa LiveKit backend token entegrasyonu tamamlanmamış olabilir).",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 40.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Semantics(
                label: _isMuted ? "Mikrofonu Aç" : "Mikrofonu Kapat",
                button: true,
                child: FloatingActionButton(
                  heroTag: "muteBtn",
                  onPressed: _isConnected ? () async {
                    try {
                      final targetState = !_isMuted;
                      if (_room != null) {
                         await _room!.localParticipant?.setMicrophoneEnabled(!targetState);
                      }
                      setState(() {
                        _isMuted = targetState;
                      });
                      AppLogger.instance.info(_isMuted ? 'Mikrofon kapatıldı' : 'Mikrofon açıldı');
                    } catch (e) {
                       AppLogger.instance.error('Mikrofon kontrol hatası: $e');
                    }
                  } : null,
                  backgroundColor: _isMuted ? Colors.red : Colors.green[700],
                  child: Icon(
                    _isMuted ? Icons.mic_off : Icons.mic,
                    color: Colors.white,
                  ),
                ),
              ),
              Semantics(
                label: "Odadan Ayrıl",
                button: true,
                child: FloatingActionButton(
                  heroTag: "leaveBtn",
                  onPressed: () {
                    AppLogger.instance.info('Odadan ayrılındı: ${widget.roomName}');
                    Navigator.of(context).pop();
                  },
                  backgroundColor: Colors.red[900],
                  child: const Icon(Icons.call_end, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
