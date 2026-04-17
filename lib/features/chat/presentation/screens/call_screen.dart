import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import '../../../../core/utils/logger.dart';

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
  Room? _room;
  bool _isMuted = false;
  bool _isCamOff = false;
  bool _isJoined = false;
  
  // Timer for call duration
  Timer? _durationTimer;
  int _secondsElapsed = 0;
  
  late final String _myId;
  
  @override
  void initState() {
    super.initState();
    _myId = Supabase.instance.client.auth.currentUser!.id;
    _initCall();
  }

  Future<void> _initCall() async {
    // Permission checks
    await [
      Permission.microphone,
      if (widget.isVideo) Permission.camera,
    ].request();

    final micStatus = await Permission.microphone.status;
    final camStatus = widget.isVideo ? await Permission.camera.status : PermissionStatus.granted;

    if (!micStatus.isGranted || !camStatus.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kamera veya mikrofon izni verilmedi.')),
        );
        Navigator.pop(context);
      }
      return;
    }

    // Note: Proje kapsamında LiveKit server ve token generator gereklidir.
    // Şimdilik WhatsApp arayüzünü ve LiveKit altyapı hazırlığını sunuyoruz.
    try {
      if (!widget.isIncoming) {
        // Arama başlatılıyorsa karşı tarafa bildirim gönder (signaling)
        await Supabase.instance.client.from('messages').insert({
          'chat_id': widget.chatId,
          'sender_id': _myId,
          'content': widget.isVideo ? '[VIDEO_CALL_STARTED]' : '[VOICE_CALL_STARTED]',
        });
      }
      
      // Mock Room init for UI demo
      // Room options
      final roomOptions = RoomOptions(
        adaptiveStream: true,
        dynacast: true,
      );
      
      _room = Room();
      
      // Listen for events
      final listener = _room!.createListener();
      listener.on<RoomDisconnectedEvent>((event) {
        if (mounted) Navigator.pop(context);
      });

      setState(() {
        _isJoined = true;
      });
      _startTimer();
      
    } catch (e) {
      AppLogger.instance.error('Arama başlatma hatası: $e');
      if (mounted) Navigator.pop(context);
    }
  }

  void _startTimer() {
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && _isJoined) {
        setState(() {
          _secondsElapsed++;
        });
      }
    });
  }

  String _formatDuration(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return "$minutes:$secs";
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    _room?.disconnect();
    super.dispose();
  }

  void _hangUp() async {
    if (!widget.isIncoming) {
       await Supabase.instance.client.from('messages').insert({
          'chat_id': widget.chatId,
          'sender_id': _myId,
          'content': widget.isVideo ? '[VIDEO_CALL_ENDED]' : '[VOICE_CALL_ENDED]',
        });
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
                Text(
                  _isJoined 
                    ? _formatDuration(_secondsElapsed)
                    : (widget.isIncoming ? "Gelen Arama" : "Aranıyor..."),
                  style: const TextStyle(fontSize: 16, color: Colors.white70),
                ),
                const Spacer(),
                
                // Control ButtonsBar
                Container(
                  margin: const EdgeInsets.all(24),
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                  decoration: BoxDecoration(
                    color: Colors.white10,
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
          
          if (widget.isIncoming)
             Positioned(
               bottom: 120,
               left: 0,
               right: 0,
               child: Row(
                 mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                 children: [
                   FloatingActionButton(
                     heroTag: "accept",
                     onPressed: () {
                       setState(() {
                         _isJoined = true;
                       });
                       _startTimer();
                     },
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
    return Column(
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
    );
  }
}
