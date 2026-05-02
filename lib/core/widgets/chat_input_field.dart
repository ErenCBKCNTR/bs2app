import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:vibration/vibration.dart';
import 'package:blind_social/core/utils/profanity_filter.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/foundation.dart' as foundation;

class ChatInputField extends StatefulWidget {
  final Function(String) onSendText;
  final Function(String) onSendAudio;
  final String hintText;
  final Widget? replyWidget;
  final bool canRecord;

  const ChatInputField({
    super.key,
    required this.onSendText,
    required this.onSendAudio,
    this.hintText = 'Mesaj yaz...',
    this.replyWidget,
    this.canRecord = true,
  });

  @override
  State<ChatInputField> createState() => _ChatInputFieldState();
}

class _ChatInputFieldState extends State<ChatInputField> {
  final TextEditingController _controller = TextEditingController();
  final AudioRecorder _audioRecorder = AudioRecorder();
  final FocusNode _focusNode = FocusNode();
  bool _isRecording = false;
  int _recordDuration = 0;
  Timer? _recordTimer;
  bool _showEmojiPicker = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      if (mounted) setState(() {});
    });
    _focusNode.addListener(() {
      if (_focusNode.hasFocus && _showEmojiPicker) {
        setState(() {
          _showEmojiPicker = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _audioRecorder.dispose();
    _focusNode.dispose();
    _recordTimer?.cancel();
    super.dispose();
  }

  bool _isPaused = false;

  void _startTimer() {
    _recordTimer?.cancel();
    _recordTimer = Timer.periodic(const Duration(seconds: 1), (Timer t) {
      if (mounted && !_isPaused) {
        setState(() => _recordDuration++);
      }
    });
  }

  void _stopTimer() {
    _recordTimer?.cancel();
  }

  String _formatRecordDuration(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$secs';
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        String? path;
        if (!foundation.kIsWeb) {
          final directory = await getApplicationDocumentsDirectory();
          path = '${directory.path}/recording_${DateTime.now().millisecondsSinceEpoch}.m4a';
        }

        final config = RecordConfig(encoder: foundation.kIsWeb ? AudioEncoder.opus : AudioEncoder.aacLc);
        await _audioRecorder.start(config, path: path ?? '');

        if (!foundation.kIsWeb) {
          try { Vibration.vibrate(duration: 50); } catch (_) {}
        }
        setState(() {
          _isRecording = true;
          _isPaused = false;
          _recordDuration = 0;
        });
        _startTimer();
      } else {
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mikrofon izni verilmedi.')));
        }
      }
    } catch (e) {
      debugPrint('Recording error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ses kaydetme hatası: $e')));
      }
    }
  }

  Future<void> _pauseOrResumeRecording() async {
    try {
      if (_isPaused) {
        await _audioRecorder.resume();
        setState(() => _isPaused = false);
      } else {
        await _audioRecorder.pause();
        setState(() => _isPaused = true);
      }
    } catch (e) {
      debugPrint('Pause/Resume error: $e');
    }
  }

  Future<void> _cancelRecording() async {
    try {
      _stopTimer();
      await _audioRecorder.stop(); // Ignore the path, we cancel
      setState(() {
        _isRecording = false;
        _isPaused = false;
        _recordDuration = 0;
      });
      if (!foundation.kIsWeb) {
        try { Vibration.vibrate(duration: 50); } catch (_) {}
      }
    } catch(e) {
      debugPrint('Cancel recording error: $e');
    }
  }

  Future<void> _stopRecordingAndSend() async {
    _stopTimer();
    final path = await _audioRecorder.stop();
    setState(() {
      _isRecording = false;
      _isPaused = false;
    });

    if (path != null && _recordDuration >= 1) {
      widget.onSendAudio(path);
      if (!foundation.kIsWeb) {
        try { Vibration.vibrate(duration: 100); } catch (_) {}
      }
    }
  }

  void _handleSendText() {
    final text = _controller.text.trim();
    if (text.isNotEmpty) {
      widget.onSendText(text);
      _controller.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.replyWidget != null) widget.replyWidget!,
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                if (_isRecording) ...[
                  IconButton(
                    tooltip: "Kaydı iptal et",
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: _cancelRecording,
                  ),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Text(
                        _isPaused 
                          ? 'Durduruldu: ${_formatRecordDuration(_recordDuration)}'
                          : 'Kayıt: ${_formatRecordDuration(_recordDuration)}',
                        style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: _isPaused ? "Kayda devam et" : "Kaydı duraklat",
                    icon: Icon(_isPaused ? Icons.mic : Icons.pause, color: Colors.orange),
                    onPressed: _pauseOrResumeRecording,
                  ),
                ] else ...[
                  Expanded(
                    child: TextField(
                      focusNode: _focusNode,
                      controller: _controller,
                      maxLength: 4000,
                      style: const TextStyle(fontSize: 14),
                      decoration: InputDecoration(
                        prefixIcon: foundation.kIsWeb ? null : IconButton(
                          tooltip: "Emoji klavyesini aç veya kapat",
                          icon: Icon(
                            _showEmojiPicker ? Icons.keyboard : Icons.emoji_emotions_outlined,
                            color: isDarkMode ? Colors.white70 : Colors.black54,
                          ),
                          onPressed: () {
                            setState(() {
                              _showEmojiPicker = !_showEmojiPicker;
                            });
                            if (_showEmojiPicker) {
                              FocusScope.of(context).unfocus();
                            } else {
                              FocusScope.of(context).requestFocus(_focusNode);
                            }
                          },
                        ),
                        hintText: widget.hintText,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: isDarkMode ? Colors.grey[800] : Colors.grey[200],
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        counterText: "",
                      ),
                      maxLines: null,
                      onSubmitted: (_) => _handleSendText(),
                    ),
                  ),
                ],
                const SizedBox(width: 8),
                if (_isRecording)
                  Semantics(
                    label: "Ses kaydını tamamla ve gönder",
                    button: true,
                    child: GestureDetector(
                      onTap: _stopRecordingAndSend,
                      child: const CircleAvatar(
                        radius: 22,
                        backgroundColor: Colors.green,
                        child: Icon(Icons.send, color: Colors.white, size: 20),
                      ),
                    ),
                  )
                else if (widget.canRecord && _controller.text.isEmpty)
                  Semantics(
                    label: "Sesli mesaj kaydet",
                    button: true,
                    child: GestureDetector(
                      onTap: _startRecording,
                      child: CircleAvatar(
                        radius: 22,
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        child: const Icon(Icons.mic, color: Colors.black, size: 24),
                      ),
                    ),
                  )
                else
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    child: IconButton(
                      tooltip: "Mesajı gönder",
                      icon: const Icon(Icons.send, color: Colors.black, size: 20),
                      onPressed: _handleSendText,
                    ),
                  ),
              ],
            ),
          ),
          if (_showEmojiPicker && !foundation.kIsWeb)
            SizedBox(
              height: 250,
              child: EmojiPicker(
                      textEditingController: _controller,
                      config: Config(
                        emojiViewConfig: EmojiViewConfig(
                          columns: 7,
                          emojiSizeMax: 32,
                          backgroundColor: Theme.of(context).colorScheme.surface,
                        ),
                        categoryViewConfig: CategoryViewConfig(
                          backgroundColor: Theme.of(context).colorScheme.surface,
                          indicatorColor: Theme.of(context).colorScheme.primary,
                          iconColorSelected: Theme.of(context).colorScheme.primary,
                          iconColor: Colors.grey,
                        ),
                        bottomActionBarConfig: const BottomActionBarConfig(
                          enabled: false,
                        ),
                      ),
                    ),
            ),
        ],
      ),
    );
  }
}
