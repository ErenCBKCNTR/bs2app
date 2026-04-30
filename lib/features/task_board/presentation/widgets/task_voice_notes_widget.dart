import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:async';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:just_audio/just_audio.dart';
import 'package:blind_social/features/task_board/data/models/task_item.dart';
import 'package:blind_social/features/task_board/data/services/task_board_service.dart';
import 'package:blind_social/core/services/pocketbase_service.dart';
import 'package:flutter/semantics.dart';

class TaskVoiceNotesWidget extends StatefulWidget {
  final TaskItem task;
  final TaskBoardService service;
  final VoidCallback onChanged;

  const TaskVoiceNotesWidget({Key? key, required this.task, required this.service, required this.onChanged}) : super(key: key);

  @override
  State<TaskVoiceNotesWidget> createState() => _TaskVoiceNotesWidgetState();
}

class _TaskVoiceNotesWidgetState extends State<TaskVoiceNotesWidget> {
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  bool _isRecording = false;
  bool _isLoading = false;
  int _recordDuration = 0;
  Timer? _timer;
  
  String? _playingFile;
  bool _isPlaying = false;

  bool _isPaused = false;

  final FocusNode _startBtnFocusNode = FocusNode();
  final FocusNode _stopBtnFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _audioPlayer.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        if (mounted) {
          setState(() {
            _isPlaying = false;
            _playingFile = null;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    _startBtnFocusNode.dispose();
    _stopBtnFocusNode.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (Timer t) {
      if (_isPaused) return;
      if (_recordDuration >= 300) { // 5 minutes = 300 seconds limit
        _stopRecording();
      } else {
        setState(() => _recordDuration++);
      }
    });
  }

  String _formatDuration(int seconds) {
    String format(int n) => n.toString().padLeft(2, "0");
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return "${format(mins)}:${format(secs)}";
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final dir = await getApplicationDocumentsDirectory();
        final path = '${dir.path}/task_voice_note_${DateTime.now().millisecondsSinceEpoch}.m4a';
        
        await _audioRecorder.start(const RecordConfig(), path: path);
        setState(() {
          _isRecording = true;
          _isPaused = false;
          _recordDuration = 0;
        });
        _startTimer();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _stopBtnFocusNode.requestFocus();
          SemanticsService.announce('Kayıt başladı', TextDirection.ltr);
        });
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ses kaydedici başlatılamadı: $e')));
    }
  }

  Future<void> _pauseRecording() async {
    await _audioRecorder.pause();
    setState(() => _isPaused = true);
    SemanticsService.announce('Kayıt duraklatıldı', TextDirection.ltr);
  }

  Future<void> _resumeRecording() async {
    await _audioRecorder.resume();
    setState(() => _isPaused = false);
    SemanticsService.announce('Kayda devam ediliyor', TextDirection.ltr);
  }

  Future<void> _cancelRecording() async {
    _timer?.cancel();
    final path = await _audioRecorder.stop();
    setState(() {
      _isRecording = false;
      _isPaused = false;
    });

    if (path != null) {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    }
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startBtnFocusNode.requestFocus();
      SemanticsService.announce('Kayıt iptal edildi', TextDirection.ltr);
    });
  }

  Future<void> _stopRecording() async {
    _timer?.cancel();
    final path = await _audioRecorder.stop();
    setState(() {
      _isRecording = false;
    });
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startBtnFocusNode.requestFocus();
      SemanticsService.announce('Kayıt durduruldu', TextDirection.ltr);
    });

    if (path != null) {
      _uploadVoiceNote(path);
    }
  }

  Future<void> _uploadVoiceNote(String path) async {
    setState(() => _isLoading = true);
    try {
      await widget.service.uploadVoiceNote(widget.task.id, path);
      widget.onChanged();
      SemanticsService.announce('Sesli not başarıyla kaydedildi.', TextDirection.ltr);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ses notu yüklenemedi: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteVoiceNote(String fileName) async {
    setState(() => _isLoading = true);
    try {
      await widget.service.deleteVoiceNote(widget.task.id, fileName);
      widget.onChanged();
      SemanticsService.announce('Sesli not silindi.', TextDirection.ltr);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ses notu silinemedi: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _togglePlay(String fileName) async {
    if (_playingFile == fileName && _isPlaying) {
      await _audioPlayer.pause();
      setState(() {
        _isPlaying = false;
      });
      return;
    }

    try {
      // Constructing URL manually since we need record id and collection id
      final baseUrl = PocketBaseService.client.baseUrl;
      final fileUrl = "$baseUrl/api/files/task_items/${widget.task.id}/$fileName";
      
      await _audioPlayer.setUrl(fileUrl);
      _audioPlayer.play();
      setState(() {
        _playingFile = fileName;
        _isPlaying = true;
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ses notu oynatılamadı: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    // 3 limits
    bool canRecord = widget.task.voiceNotes.length < 3;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Sesli Notlar', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            if (_isLoading) const SizedBox(
              width: 16, height: 16, 
              child: CircularProgressIndicator(strokeWidth: 2)
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (widget.task.voiceNotes.isEmpty)
           const Text('Sesli not eklenmemiş.'),
           
        ...widget.task.voiceNotes.map((fileName) {
            final isCurrentPlaying = _playingFile == fileName && _isPlaying;
            return Card(
              child: Semantics(
                label: 'Sesli Not. Durum: ${isCurrentPlaying ? "Oynatılıyor" : "Durduruldu"}. Oynatmak veya durdurmak için çift tıklayın. İşlem seçenekleri için parmağınızı yukarı veya aşağı kaydırın.',
                button: true,
                onTapHint: isCurrentPlaying ? 'Durdur' : 'Dinle',
                customSemanticsActions: {
                  const CustomSemanticsAction(label: 'Kaydı Sil'): () => _deleteVoiceNote(fileName),
                },
                child: ExcludeSemantics(
                  child: ListTile(
                    leading: IconButton(
                      icon: Icon(isCurrentPlaying ? Icons.pause : Icons.play_arrow),
                      onPressed: () => _togglePlay(fileName),
                      tooltip: isCurrentPlaying ? 'Durdur' : 'Dinle',
                    ),
                    title: const Text('Sesli Not'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deleteVoiceNote(fileName),
                      tooltip: 'Bu sesli notu sil',
                    ),
                    onTap: () => _togglePlay(fileName),
                  ),
                ),
              ),
            );
          }).toList(),

          const SizedBox(height: 16),
          
          if (canRecord && !_isRecording)
            ElevatedButton.icon(
              focusNode: _startBtnFocusNode,
              onPressed: _startRecording,
              icon: const Icon(Icons.mic),
              label: const Text('Yeni Sesli Not Kaydet (Max 5 dk)'),
            )
          else if (_isRecording)
            Card(
              color: Colors.red.withOpacity(0.1),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.fiber_manual_record, color: _isPaused ? Colors.grey : Colors.red),
                        const SizedBox(width: 8),
                        Text(_isPaused ? 'Duraklatıldı: ${_formatDuration(_recordDuration)} / 05:00' : 'Kaydediliyor: ${_formatDuration(_recordDuration)} / 05:00', style: TextStyle(fontWeight: FontWeight.bold, color: _isPaused ? Colors.grey : Colors.red)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.spaceBetween,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _isLoading ? null : _cancelRecording,
                          icon: const Icon(Icons.delete_forever),
                          label: const Text('İptal Et'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _isLoading ? null : (_isPaused ? _resumeRecording : _pauseRecording),
                          icon: Icon(_isPaused ? Icons.play_arrow : Icons.pause),
                          label: Text(_isPaused ? 'Devam Et' : 'Duraklat'),
                        ),
                        ElevatedButton.icon(
                          focusNode: _stopBtnFocusNode,
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                          onPressed: _isLoading ? null : _stopRecording,
                          icon: const Icon(Icons.stop),
                          label: const Text('Bitir', style: TextStyle(color: Colors.white)),
                        )
                      ],
                    )
                  ],
                ),
              )
            )
      ],
    );
  }
}
