import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:vibration/vibration.dart';
import 'package:blind_social/core/utils/profanity_filter.dart';

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
  bool _isRecording = false;
  int _recordDuration = 0;
  Timer? _recordTimer;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _audioRecorder.dispose();
    _recordTimer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _recordTimer?.cancel();
    _recordDuration = 0;
    _recordTimer = Timer.periodic(const Duration(seconds: 1), (Timer t) {
      if (mounted) {
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
        final directory = await getApplicationDocumentsDirectory();
        final path = '${directory.path}/recording_${DateTime.now().millisecondsSinceEpoch}.m4a';

        await _audioRecorder.start(const RecordConfig(), path: path);

        Vibration.vibrate(duration: 50);
        setState(() {
          _isRecording = true;
        });
        _startTimer();
      }
    } catch (e) {
      debugPrint('Recording error: $e');
    }
  }

  Future<void> _stopRecordingAndSend() async {
    _stopTimer();
    final path = await _audioRecorder.stop();
    setState(() {
      _isRecording = false;
    });

    if (path != null && _recordDuration >= 1) {
      widget.onSendAudio(path);
      Vibration.vibrate(duration: 100);
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
                Expanded(
                  child: TextField(
                    controller: _controller,
                    maxLength: 4000,
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: _isRecording 
                        ? 'Kayıt: ${_formatRecordDuration(_recordDuration)}' 
                        : widget.hintText,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: _isRecording 
                        ? Colors.red.withOpacity(0.2) 
                        : (isDarkMode ? Colors.grey[800] : Colors.grey[200]),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      counterText: "",
                    ),
                    enabled: !_isRecording,
                    maxLines: null,
                    onSubmitted: (_) => _handleSendText(),
                  ),
                ),
                const SizedBox(width: 8),
                if (_isRecording)
                  Semantics(
                    label: "Ses kaydını durdur ve gönder",
                    button: true,
                    child: GestureDetector(
                      onTap: _stopRecordingAndSend,
                      child: const CircleAvatar(
                        radius: 22,
                        backgroundColor: Colors.red,
                        child: Icon(Icons.stop, color: Colors.white, size: 24),
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
                  Semantics(
                    label: "Mesajı gönder",
                    button: true,
                    child: IconButton(
                      icon: const Icon(Icons.send),
                      onPressed: _handleSendText,
                      color: Theme.of(context).colorScheme.primary,
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
