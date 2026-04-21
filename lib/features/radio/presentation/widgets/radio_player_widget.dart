
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:just_audio/just_audio.dart';
import 'dart:async';
import '../../data/radio_stations.dart';
import '../../services/radio_recording_service.dart';
import '../../services/favorite_stations_service.dart';
import '../../models/radio_recording.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'dart:ui' show TextDirection;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

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
  final FavoriteStationsService _favoriteService = FavoriteStationsService();
  bool _isRecording = false;
  Timer? _sleepTimer;
  int _remainingSleepSeconds = 0;
  Timer? _countdownTimer;

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
    _sleepTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _setSleepTimer(int minutes) {
    _sleepTimer?.cancel();
    _countdownTimer?.cancel();

    if (minutes == 0) {
      setState(() {
        _remainingSleepSeconds = 0;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Uyku zamanlayıcısı iptal edildi.')),
      );
      return;
    }

    setState(() {
      _remainingSleepSeconds = minutes * 60;
    });

    _sleepTimer = Timer(Duration(minutes: minutes), () async {
      if (_isPlaying) {
        await _player.pause();
      }
      if (_isRecording) {
        await _toggleRecording();
      }
      setState(() {
        _remainingSleepSeconds = 0;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Uyku zamanlayıcısı süresi doldu. Yayın durduruldu.')),
        );
      }
    });

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSleepSeconds > 0) {
        setState(() {
          _remainingSleepSeconds--;
        });
      } else {
        timer.cancel();
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Uyku zamanlayıcısı $minutes dakikaya ayarlandı.')),
    );
  }

  void _showSleepTimerDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).padding.bottom + 20,
          ),
          decoration: const BoxDecoration(
            color: Color(0xFF1A1A1A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle/indicator
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Uyku Zamanlayıcısı',
                      style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: () => Navigator.pop(context),
                      tooltip: 'Kapat',
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white12),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildTimerOption(context, 15, Icons.timer),
                      _buildTimerOption(context, 30, Icons.av_timer),
                      _buildTimerOption(context, 45, Icons.shutter_speed),
                      _buildTimerOption(context, 60, Icons.timer),
                      _buildTimerOption(context, 90, Icons.hourglass_top),
                      _buildTimerOption(context, 120, Icons.hourglass_bottom),
                      if (_remainingSleepSeconds > 0)
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.timer_off, color: Colors.redAccent),
                          ),
                          title: const Text('Zamanlayıcıyı İptal Et', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                          onTap: () { Navigator.pop(context); _setSleepTimer(0); },
                        ),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTimerOption(BuildContext context, int minutes, IconData icon) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.blueAccent.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.blueAccent, size: 24),
      ),
      title: Text('$minutes Dakika', style: const TextStyle(color: Colors.white, fontSize: 16)),
      onTap: () { Navigator.pop(context); _setSleepTimer(minutes); },
    );
  }

  String _formatTime(int seconds) {
    final m = (seconds / 60).floor();
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
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
    return SingleChildScrollView(
      child: Container(
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
          // Kanal Bilgisi, Favori ve Uyku Butonları
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.bedtime_outlined, size: 28, color: Colors.white54),
                onPressed: _showSleepTimerDialog,
                tooltip: 'Uyku Zamanlayıcısı',
              ),
              Expanded(
                child: Text(
                  widget.station.name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              FutureBuilder<void>(
                future: _favoriteService.init(),
                builder: (context, snapshot) {
                  final isFav = _favoriteService.isFavorite(widget.station.name);
                  return IconButton(
                    icon: Icon(
                      isFav ? Icons.favorite : Icons.favorite_border,
                      color: isFav ? Colors.amber : Colors.white54,
                      size: 28,
                    ),
                    onPressed: () async {
                      await _favoriteService.toggleFavorite(widget.station.name);
                      setState(() {});
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            isFav 
                              ? '${widget.station.name} favorilerden çıkarıldı.' 
                              : '${widget.station.name} favorilere eklendi.'
                          ),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    },
                    tooltip: isFav ? 'Favorilerden Çıkar' : 'Favorilere Ekle',
                  );
                },
              ),
            ],
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
          const SizedBox(height: 16),
          // Uyku Zamanlayıcısı Bilgisi
          if (_remainingSleepSeconds > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.amber.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.timer, color: Colors.amber, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    "Uyku Modu: ${_formatTime(_remainingSleepSeconds)}",
                    style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 32),
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
    ),
    );
  }
}
