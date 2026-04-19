
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:just_audio/just_audio.dart';
import '../../data/radio_stations.dart';
import '../../services/radio_recording_service.dart';
import '../../models/radio_recording.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'dart:ui' show TextDirection;

class RadioPlayerWidget extends StatefulWidget {
  final RadioStation station;
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  
  const RadioPlayerWidget({
    super.key, 
    required this.station,
    required this.onNext,
    required this.onPrevious,
  });

  @override
  State<RadioPlayerWidget> createState() => _RadioPlayerWidgetState();
}

class _RadioPlayerWidgetState extends State<RadioPlayerWidget> {
  late AudioPlayer _player;
  bool _isPlaying = false;
  double _volume = 0.8;
  bool _isBuffering = false;
  final RadioRecordingService _recordingService = RadioRecordingService();
  bool _isRecording = false;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _player.setVolume(_volume);
    
    // Status stream
    _player.playerStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state.playing;
          _isBuffering = state.processingState == ProcessingState.buffering || 
                         state.processingState == ProcessingState.loading;
        });
      }
    });

    _startPlayback();
  }

  @override
  void didUpdateWidget(RadioPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.station.url != widget.station.url) {
      _startPlayback();
    }
  }

  Future<void> _startPlayback() async {
    if (mounted) setState(() => _isBuffering = true);
    try {
      // just_audio is better for m3u8 and shoutcast
      await _player.stop();
      await _player.setUrl(widget.station.url);
      _player.play(); // No need to await play() for streams as it returns when done playing
      if (mounted) setState(() => _isBuffering = false);
    } catch (e) {
      debugPrint("Playback error: $e");
      if (mounted) {
        setState(() => _isBuffering = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${widget.station.name} oynatılamadı. Bağlantı hatası.'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  void _togglePlayback() async {
    if (_isPlaying) {
      await _player.pause();
    } else {
      if (_player.processingState == ProcessingState.idle) {
        _startPlayback();
      } else {
        _player.play();
      }
    }
  }

  Future<void> _toggleRecording() async {
    try {
      if (_isRecording) {
        final recording = await _recordingService.stopRecording();
        setState(() => _isRecording = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Kayıt tamamlandı: ${recording?.stationName}'),
              behavior: SnackBarBehavior.floating,
            ),
          );
          // Announce to screen reader
          SemanticsService.announce("Kayıt durduruldu ve kaydedildi", TextDirection.ltr);
        }
      } else {
        setState(() => _isRecording = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kayıt başlatıldı...'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        // Announce to screen reader
        SemanticsService.announce("Canlı yayın kaydı başlatıldı", TextDirection.ltr);
        
        await _recordingService.startRecording(widget.station.url, widget.station.name);
      }
    } catch (e) {
      setState(() => _isRecording = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Kayıt hatası: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Radyo Görseli / Logo Alanı
          Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blueGrey[900]!, Colors.black],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: Colors.blueAccent.withOpacity(0.2),
                  blurRadius: 20,
                  spreadRadius: 5,
                )
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Icon(Icons.radio, size: 100, color: Colors.blueAccent),
                if (_isBuffering)
                  const SizedBox(
                    width: 140,
                    height: 140,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.blueAccent),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 30),
          // Kanal Bilgisi
          Text(
            widget.station.name,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: _isPlaying ? Colors.red.withOpacity(0.1) : Colors.white10,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _isPlaying ? Colors.red : Colors.white24,
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.circle, color: _isPlaying ? Colors.red : Colors.white24, size: 10),
                const SizedBox(width: 6),
                Text(
                  _isPlaying ? "YAYINDA" : "DURDURULDU",
                  style: TextStyle(
                    color: _isPlaying ? Colors.red : Colors.white38,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 48),
          // Ana Kontroller
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.skip_previous_rounded, size: 44, color: Colors.white),
                onPressed: widget.onPrevious,
                tooltip: 'Önceki Kanal',
              ),
              const SizedBox(width: 32),
              // Erişilebilirlik etiketi IconButton tooltip ile sağlanır.
              IconButton(
                onPressed: _togglePlayback,
                tooltip: _isPlaying ? 'Yayını Durdur' : 'Yayını Başlat',
                iconSize: 84,
                padding: EdgeInsets.zero,
                icon: Container(
                  width: 84,
                  height: 84,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    size: 56,
                    color: Colors.black,
                  ),
                ),
              ),
              const SizedBox(width: 32),
              IconButton(
                icon: const Icon(Icons.skip_next_rounded, size: 44, color: Colors.white),
                onPressed: widget.onNext,
                tooltip: 'Sonraki Kanal',
              ),
            ],
          ),
          const SizedBox(height: 32),
          // Kayıt Butonu
          Semantics(
            label: _isRecording ? "Kaydı Durdur" : "Kaydı Başlat",
            button: true,
            hint: _isRecording ? "Kaydı bitirmek için çift dokunun" : "Canlı yayını kaydetmek için çift dokunun",
            child: InkWell(
              onTap: _toggleRecording,
              borderRadius: BorderRadius.circular(30),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: _isRecording ? Colors.red : Colors.blueAccent,
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (_isRecording ? Colors.red : Colors.blueAccent).withOpacity(0.3),
                      blurRadius: 10,
                      spreadRadius: 1,
                    )
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isRecording ? Icons.stop_circle : Icons.fiber_manual_record,
                      color: Colors.red,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _isRecording ? "Kaydı Durdur" : "Kaydı Başlat",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
          // Ses Kontrol Ünitesi
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.volume_mute, color: Colors.white54, size: 20),
                    Expanded(
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 4,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                          overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                        ),
                        child: Slider(
                          value: _volume,
                          onChanged: (v) {
                            setState(() => _volume = v);
                            _player.setVolume(v);
                          },
                        ),
                      ),
                    ),
                    const Icon(Icons.volume_up, color: Colors.white54, size: 20),
                  ],
                ),
                Text(
                  "Ses Seviyesi: %${(_volume * 100).toInt()}",
                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
