
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:just_audio/just_audio.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'dart:ui' show TextDirection;
import '../../models/radio_recording.dart';
import '../../data/recording_database.dart';

class SavedRecordingsScreen extends StatefulWidget {
  const SavedRecordingsScreen({super.key});

  @override
  State<SavedRecordingsScreen> createState() => _SavedRecordingsScreenState();
}

class _SavedRecordingsScreenState extends State<SavedRecordingsScreen> {
  List<RadioRecording> _recordings = [];
  bool _isLoading = true;
  final AudioPlayer _player = AudioPlayer();
  int? _playingId;

  @override
  void initState() {
    super.initState();
    _loadRecordings();
  }

  Future<void> _loadRecordings() async {
    final list = await RecordingDatabase.instance.fetchAll();
    if (mounted) {
      setState(() {
        _recordings = list;
        _isLoading = false;
      });
    }
  }

  Future<void> _playRecording(RadioRecording recording) async {
    try {
      if (_playingId == recording.id) {
        await _player.stop();
        setState(() => _playingId = null);
        SemanticsService.announce("Kayıt durduruldu", TextDirection.ltr);
      } else {
        await _player.setFilePath(recording.filePath);
        _player.play();
        setState(() => _playingId = recording.id);
        SemanticsService.announce("${recording.stationName} kaydı oynatılıyor", TextDirection.ltr);
        
        _player.playerStateStream.listen((state) {
          if (state.processingState == ProcessingState.completed) {
            if (mounted) setState(() => _playingId = null);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        String msg = "Oynatma hatası: $e";
        if (e.toString().contains("Source error")) {
          msg = "Dosya formatı veya içeriği hatalı. Lütfen kaydı teyit edin.";
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    }
  }

  Future<void> _shareRecording(RadioRecording recording) async {
    try {
      final file = File(recording.filePath);
      if (await file.exists()) {
        await Share.shareXFiles([XFile(recording.filePath)], text: '${recording.stationName} radyo kaydı');
      } else {
        throw Exception("Dosya bulunamadı");
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Paylaşma hatası: $e")));
      }
    }
  }

  Future<void> _deleteRecording(RadioRecording recording) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kaydı Sil'),
        content: const Text('Bu kaydı telefonunuzdan kalıcı olarak silmek istediğinize emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İPTAL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('SİL', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await RecordingDatabase.instance.delete(recording.id!);
        final file = File(recording.filePath);
        if (await file.exists()) {
          await file.delete();
        }
        _loadRecordings();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Kayıt silindi")));
          SemanticsService.announce("Kayıt silindi", TextDirection.ltr);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Silme hatası: $e")));
        }
      }
    }
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(d.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(d.inSeconds.remainder(60));
    if (d.inHours > 0) {
      return "${twoDigits(d.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
    } else {
      return "$twoDigitMinutes:$twoDigitSeconds";
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kaydedilen Yayınlar')),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _recordings.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.album_outlined, size: 64, color: Colors.white24),
                        SizedBox(height: 16),
                        Text('Henüz kaydedilmiş yayın yok.', style: TextStyle(color: Colors.white54)),
                      ],
                    ),
                  )
                : ListView.separated(
addAutomaticKeepAlives: false,
addRepaintBoundaries: true,
                    padding: EdgeInsets.only(
                      top: 8,
                      bottom: MediaQuery.of(context).padding.bottom + 24,
                    ),
                    itemCount: _recordings.length,
                    separatorBuilder: (context, index) => const Divider(color: Colors.white10),
                    itemBuilder: (context, index) {
                    final rec = _recordings[index];
                    final dateStr = DateFormat('dd.MM.yyyy').format(rec.date);
                    final timeStr = DateFormat('HH:mm').format(rec.date);
                    final durationStr = _formatDuration(rec.duration);
                    final isPlaying = _playingId == rec.id;

                    return Semantics(
                      label: "${rec.stationName}. $dateStr tarihinde saat $timeStr kaydedildi. Süre $durationStr.",
                      customSemanticsActions: {
                        CustomSemanticsAction(label: 'Kaydı Oynat'): () => _playRecording(rec),
                        CustomSemanticsAction(label: 'Kaydı Paylaş'): () => _shareRecording(rec),
                        CustomSemanticsAction(label: 'Kaydı Sil'): () => _deleteRecording(rec),
                      },
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blueAccent.withOpacity(isPlaying ? 0.3 : 0.1),
                          child: Icon(
                            isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, 
                            color: Colors.blueAccent
                          ),
                        ),
                        title: Text(
                          rec.stationName, 
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('$dateStr - $timeStr', style: const TextStyle(color: Colors.white70)),
                              Text(
                                'Süre: $durationStr', 
                                style: const TextStyle(color: Colors.blueAccent, fontSize: 13, fontWeight: FontWeight.w500)
                              ),
                            ],
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(isPlaying ? Icons.stop_rounded : Icons.play_arrow_rounded),
                              onPressed: () => _playRecording(rec),
                              tooltip: 'Oynat',
                            ),
                            IconButton(
                              icon: const Icon(Icons.share_rounded, size: 20),
                              onPressed: () => _shareRecording(rec),
                              tooltip: 'Paylaş',
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 22),
                              onPressed: () => _deleteRecording(rec),
                              tooltip: 'Sil',
                            ),
                          ],
                        ),
                        onTap: () => _playRecording(rec),
                      ),
                    );
                  },
                ),
      ),
    );
  }
}
