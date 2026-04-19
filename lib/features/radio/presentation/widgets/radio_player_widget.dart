
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
      setState(() {
        _isPlaying = state == PlayerState.playing;
      });
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
      await _player.play(UrlSource(widget.station.url));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(widget.station.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),
        IconButton(
          icon: Icon(_isPlaying ? Icons.stop_circle : Icons.play_circle, size: 64, color: Theme.of(context).primaryColor),
          onPressed: _togglePlayback,
          tooltip: _isPlaying ? 'Yayını Durdur' : 'Yayını Başlat',
        ),
      ],
    );
  }
}
