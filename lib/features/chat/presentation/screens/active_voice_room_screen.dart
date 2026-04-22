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
  late final EventsListener<RoomEvent> _listener;
  List<Participant> _participants = [];

  @override
  void initState() {
    super.initState();
    _connectToRoom();
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
    
    final String livekitUrl = dotenv.env['LIVEKIT_URL'] ?? '';
    final String apiKey = dotenv.env['LIVEKIT_API_KEY'] ?? '';
    final String apiSecret = dotenv.env['LIVEKIT_API_SECRET'] ?? '';

    if (livekitUrl.isEmpty || apiKey.isEmpty || apiSecret.isEmpty) {
      AppLogger.instance.warning('LiveKit URL, Key veya Secret bulunamadı. Simülasyon modunda açılıyor.');
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        setState(() {
          _isConnected = true;
          // Simülasyon için sahte katılımcılar (test amaçlı)
          // Gerçek LiveKit bağlı olmadığında Participant oluşturmak zor olabilir çünkü abstract sınıflardır.
        });
        AppLogger.instance.info('Odaya simülasyon modunda başarıyla bağlanıldı: ${widget.roomName}');
      }
      return;
    }

    try {
      final user = PocketBaseService.client.authStore.model;
      final userId = user?.id ?? 'anonymous_${DateTime.now().millisecondsSinceEpoch}';
      
      final String livekitToken = _generateToken(apiKey, apiSecret, widget.roomName, userId);

      _room = Room();
      _listener = _room!.createListener();

      const roomOptions = RoomOptions(
        adaptiveStream: true,
        dynacast: true,
      );

      await _room!.connect(livekitUrl, livekitToken, roomOptions: roomOptions);
      
      _listener
        ..on<ParticipantConnectedEvent>((_) => _onRoomDidUpdate())
        ..on<ParticipantDisconnectedEvent>((_) => _onRoomDidUpdate())
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
      backgroundColor: const Color(0xFF101820), // Koyu arka plan
      appBar: AppBar(
        title: Text(widget.roomName),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isConnected 
        ? _buildParticipantGrid()
        : const Center(child: CircularProgressIndicator()),
      bottomNavigationBar: _isConnected ? _buildBottomControls() : null,
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
            Semantics(
              label: "Mikrofon Ayarları",
              button: true,
              child: _ControlButton(
                icon: Icons.settings_outlined,
                onPressed: () {
                  // Gelecekte eklenecek
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Ayarlar yakında eklenecek')),
                  );
                },
                backgroundColor: Colors.grey.withOpacity(0.2),
              ),
            ),
            // Odadan Ayrıl (Kırmızı)
            Semantics(
              label: "Odadan Ayrıl",
              button: true,
              child: _ControlButton(
                icon: Icons.call_end,
                onPressed: () {
                  AppLogger.instance.info('Odadan ayrılındı: ${widget.roomName}');
                  Navigator.of(context).pop();
                },
                backgroundColor: Colors.red,
                size: 70,
                iconSize: 32,
              ),
            ),
            // Mikrofon Aç/Kapat (Yeşil/Kırmızı)
            Semantics(
              label: _isMuted ? "Mikrofonu Aç" : "Mikrofonu Kapat",
              button: true,
              child: _ControlButton(
                icon: _isMuted ? Icons.mic_off : Icons.mic,
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
    // PocketBase modelinden isim çekmek daha iyi olur ama LiveKit contextinde identity genelde username olur.
    final name = identity.startsWith('anonymous_') ? 'Misafir' : identity;
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

  const _ControlButton({
    required this.icon,
    required this.onPressed,
    this.backgroundColor,
    this.size = 56,
    this.iconSize = 24,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: FloatingActionButton(
        onPressed: onPressed,
        backgroundColor: backgroundColor,
        elevation: 0,
        highlightElevation: 0,
        shape: const CircleBorder(),
        child: Icon(icon, color: Colors.white, size: iconSize),
      ),
    );
  }
}
