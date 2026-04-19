
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../data/radio_stations.dart';

class RadioPlayerWidget extends StatefulWidget {
  final RadioStation station;
  const RadioPlayerWidget({super.key, required this.station});

  @override
  State<RadioPlayerWidget> createState() => _RadioPlayerWidgetState();
}

class _RadioPlayerWidgetState extends State<RadioPlayerWidget> {
  late AudioPlayer _player;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _player.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
        });
      }
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  void _togglePlayback() async {
    if (_isPlaying) {
      await _player.stop();
    } else {
      try {
        await _player.play(UrlSource(widget.station.url));
      } catch (e) {
        debugPrint("Playback error: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Yayın şu an dinlenemiyor.')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Radyo Görseli (Şablon Tasarım)
        Container(
          width: 250,
          height: 250,
          decoration: BoxDecoration(
            color: Colors.grey[800],
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))],
          ),
          child: const Icon(Icons.radio, size: 100, color: Colors.white70),
        ),
        const SizedBox(height: 16),
        // CANLI Etiketi
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.circle, color: Colors.red, size: 12),
            SizedBox(width: 8),
            Text("CANLI", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
          ],
        ),
        const SizedBox(height: 8),
        // Kanal İsmi
        Text(widget.station.name, 
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
          semanticsLabel: "Şu an oynatılan: ${widget.station.name}",
        ),
        const SizedBox(height: 32),
        // Oynatıcı Kontrolleri
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.skip_previous, size: 48, color: Colors.white),
              onPressed: () {}, // Gelecekteki özellik
              tooltip: 'Önceki Kanal',
            ),
            const SizedBox(width: 24),
            Semantics(
              label: _isPlaying ? 'Yayını durdur' : 'Yayını başlat',
              button: true,
              child: IconButton(
                icon: Icon(_isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled, size: 80, color: Colors.white),
                onPressed: _togglePlayback,
                tooltip: _isPlaying ? 'Yayını Durdur' : 'Yayını Başlat',
              ),
            ),
            const SizedBox(width: 24),
            IconButton(
              icon: const Icon(Icons.skip_next, size: 48, color: Colors.white),
              onPressed: () {}, // Gelecekteki özellik
              tooltip: 'Sonraki Kanal',
            ),
          ],
        ),
        const SizedBox(height: 32),
        // Ses Dalgası Görseli (Temsili)
        Container(
          width: double.infinity,
          height: 60,
          color: Colors.transparent,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(20, (index) => Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              width: 4,
              height: _isPlaying ? (20 + (index % 10) * 4).toDouble() : 10,
              color: Colors.white.withOpacity(0.5),
            )),
          ),
        ),
      ],
    );
  }
}
