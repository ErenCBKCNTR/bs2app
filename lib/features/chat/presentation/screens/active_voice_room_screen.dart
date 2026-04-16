import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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

  @override
  void initState() {
    super.initState();
    _connectToRoom();
  }

  Future<void> _connectToRoom() async {
    // Simüle eilen bağlanma süreci. 
    // Gerçek LiveKit entegrasyonu sunucu tarafında token üretmeyi gerektirir.
    AppLogger.instance.info('Odaya bağlanılıyor: ${widget.roomName} (${widget.roomId})');
    
    await Future.delayed(const Duration(seconds: 1));
    if (mounted) {
      setState(() {
        _isConnected = true;
      });
      AppLogger.instance.info('Odaya başarıyla bağlanıldı: ${widget.roomName}');
    }
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
              const Text(
                "Şu anda odadasınız. Canlı sesli sohbet özellikleri (LiveKit) yapılandırılınca aktif olacaktır.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
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
                  onPressed: _isConnected ? () {
                    setState(() {
                      _isMuted = !_isMuted;
                    });
                    AppLogger.instance.info(_isMuted ? 'Mikrofon kapatıldı' : 'Mikrofon açıldı');
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
