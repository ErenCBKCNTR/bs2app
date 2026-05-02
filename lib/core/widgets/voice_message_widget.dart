import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:audioplayers/audioplayers.dart';

class VoiceMessageWidget extends StatefulWidget {
  final String url;
  final bool isMyMessage;

  const VoiceMessageWidget({super.key, required this.url, required this.isMyMessage});

  @override
  State<VoiceMessageWidget> createState() => _VoiceMessageWidgetState();
}

class _VoiceMessageWidgetState extends State<VoiceMessageWidget> {
  late AudioPlayer _audioPlayer;
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();

    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
        });
      }
    });

    _audioPlayer.onDurationChanged.listen((newDuration) {
      if (mounted) {
        setState(() {
          _duration = newDuration;
        });
      }
    });

    _audioPlayer.onPositionChanged.listen((newPosition) {
      if (mounted) {
        setState(() {
          _position = newPosition;
        });
      }
    });
    
    _audioPlayer.onPlayerComplete.listen((event) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _position = Duration.zero;
        });
      }
    });

    // Ses kaynağını önceden yükle, böylece süre (duration) 00:00 yerine hemen güncellenir
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await _audioPlayer.setSource(UrlSource(widget.url));
      } catch (e) {
        debugPrint('Ses metaverisi yüklenemedi: $e');
      }
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void _seekRelative(int seconds) {
    final newPosition = _position + Duration(seconds: seconds);
    if (newPosition < Duration.zero) {
      _audioPlayer.seek(Duration.zero);
    } else if (newPosition > _duration && _duration != Duration.zero) {
      _audioPlayer.seek(_duration);
    } else {
      _audioPlayer.seek(newPosition);
    }
  }

  @override
  Widget build(BuildContext context) {
    final playPauseLabel = _isPlaying ? "Sesi duraklat" : "Sesli mesajı oynat";
    
    return Container(
      width: 260, 
      decoration: BoxDecoration(
        color: widget.isMyMessage ? Colors.green[800] : Colors.grey[700],
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Play/Pause Button
          Semantics(
            label: playPauseLabel,
            button: true,
            excludeSemantics: true,
            child: IconButton(
              constraints: const BoxConstraints(),
              padding: const EdgeInsets.all(4),
              icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white, size: 32),
              onPressed: () async {
                if (_isPlaying) {
                  await _audioPlayer.pause();
                } else {
                  if (_audioPlayer.source == null) {
                    await _audioPlayer.play(UrlSource(widget.url));
                  } else {
                    await _audioPlayer.resume();
                  }
                }
              },
            ),
          ),
          
          // Rewind 5s
          Semantics(
            label: "5 saniye geri sar",
            button: true,
            excludeSemantics: true,
            child: IconButton(
              constraints: const BoxConstraints(),
              padding: const EdgeInsets.all(4),
              icon: const Icon(Icons.replay_5, color: Colors.white, size: 24),
              onPressed: () => _seekRelative(-5),
            ),
          ),

          // Forward 5s
          Semantics(
            label: "5 saniye ileri sar",
            button: true,
            excludeSemantics: true,
            child: IconButton(
              constraints: const BoxConstraints(),
              padding: const EdgeInsets.all(4),
              icon: const Icon(Icons.forward_5, color: Colors.white, size: 24),
              onPressed: () => _seekRelative(5),
            ),
          ),

          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Semantics(
                  label: "Ses ilerlemesi: ${_formatDuration(_position)} / ${_formatDuration(_duration)}",
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                      trackHeight: 2,
                    ),
                    child: Slider(
                      min: 0,
                      max: _duration.inSeconds > 0 ? _duration.inSeconds.toDouble() : 1.0,
                      value: _position.inSeconds.toDouble().clamp(0.0, _duration.inSeconds > 0 ? _duration.inSeconds.toDouble() : 1.0),
                      onChanged: (val) {
                        _audioPlayer.seek(Duration(seconds: val.toInt()));
                      },
                      activeColor: Colors.white,
                      inactiveColor: Colors.white30,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: Text(
                    '${_formatDuration(_position)} / ${_formatDuration(_duration)}',
                    style: const TextStyle(fontSize: 10, color: Colors.white70),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
