import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:blind_social/core/services/pocketbase_service.dart';
import 'package:blind_social/features/task_board/data/models/task_comment.dart';
import 'package:blind_social/features/task_board/data/services/task_board_service.dart';
import 'package:blind_social/core/widgets/chat_input_field.dart';
import 'dart:async';
import 'package:just_audio/just_audio.dart';

class TaskCommentsWidget extends StatefulWidget {
  final String taskId;
  const TaskCommentsWidget({super.key, required this.taskId});

  @override
  State<TaskCommentsWidget> createState() => _TaskCommentsWidgetState();
}

class _TaskCommentsWidgetState extends State<TaskCommentsWidget> {
  final TaskBoardService _service = TaskBoardService();
  List<TaskComment> _comments = [];
  bool _isLoading = true;
  String? _currentUserId;
  final ScrollController _scrollController = ScrollController();
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  String? _playingCommentId;

  @override
  void initState() {
    super.initState();
    _currentUserId = PocketBaseService.client.authStore.model?.id;
    _fetchComments();
    _audioPlayer.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        if (mounted) setState(() => _playingCommentId = null);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _fetchComments() async {
    try {
      final list = await _service.getComments(widget.taskId);
      if (mounted) {
        setState(() {
          _comments = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteComment(TaskComment comment) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mesajı Sil'),
        content: const Text('Bu mesajı silmek istediğinize emin misiniz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('İptal')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sil', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _service.deleteComment(comment.id);
        setState(() {
          _comments.removeWhere((c) => c.id == comment.id);
        });
        SemanticsService.announce('Mesaj silindi', TextDirection.ltr);
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Silinirken hata oluştu: $e')));
      }
    }
  }

  Future<void> _sendText(String text) async {
    try {
      final cnd = await _service.createComment(widget.taskId, text);
      setState(() {
        _comments.insert(0, cnd);
      });
      SemanticsService.announce("Mesaj gönderildi", TextDirection.ltr);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
    }
  }

  Future<void> _sendVoice(String path) async {
    try {
      SemanticsService.announce("Ses mesajı gönderiliyor, lütfen bekleyin", TextDirection.ltr);
      final cnd = await _service.createVoiceComment(widget.taskId, path);
      setState(() {
        _comments.insert(0, cnd);
      });
      SemanticsService.announce("Sesli mesaj başarıyla gönderildi", TextDirection.ltr);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
    }
  }

  void _playVoice(TaskComment comment) async {
    if (comment.voiceNote.isEmpty) return;
    try {
      if (_playingCommentId == comment.id) {
         await _audioPlayer.stop();
         setState(() => _playingCommentId = null);
         return;
      }
      await _audioPlayer.stop();
      final url = '${PocketBaseService.client.baseUrl}/api/files/task_comments/${comment.id}/${comment.voiceNote}';
      setState(() => _playingCommentId = comment.id);
      await _audioPlayer.setUrl(url);
      await _audioPlayer.play();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return Column(
        children: [
          Expanded(
            child: _comments.isEmpty
              ? const Center(child: Text('Henüz mesaj yok. İlk mesajı siz gönderin.', style: TextStyle(color: Colors.grey)))
              : ListView.builder(
addAutomaticKeepAlives: false,
addRepaintBoundaries: true,
                  controller: _scrollController,
                  reverse: true,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: _comments.length,
                  itemBuilder: (context, index) {
                    final c = _comments[index];
                    final isMe = c.userId == _currentUserId;
                    final hasVoice = c.voiceNote.isNotEmpty;
                    final isPlaying = _playingCommentId == c.id;

                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Semantics(
                        customSemanticsActions: {
                           if (isMe)
                             const CustomSemanticsAction(label: 'Sil'): () => _deleteComment(c),
                        },
                        child: GestureDetector(
                          onLongPress: isMe ? () => _deleteComment(c) : null,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(12),
                            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                            decoration: BoxDecoration(
                              color: isMe ? Colors.blue.shade800 : Colors.grey.shade800,
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(16),
                                topRight: const Radius.circular(16),
                                bottomLeft: Radius.circular(isMe ? 16 : 0),
                                bottomRight: Radius.circular(isMe ? 0 : 16),
                              )
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (!isMe) ...[
                                  Text(c.userName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blueGrey)),
                                  const SizedBox(height: 4),
                                ],
                                if (hasVoice)
                                  Semantics(
                                    label: "Sesli Mesaj. ${isPlaying ? 'Durdurmak için dokunun' : 'Oynatmak için dokunun'}",
                                    button: true,
                                    child: InkWell(
                                      onTap: () => _playVoice(c),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(isPlaying ? Icons.stop : Icons.play_arrow, color: Colors.white),
                                          const SizedBox(width: 8),
                                          const Text('Sesli Mesaj', style: TextStyle(color: Colors.white)),
                                        ],
                                      ),
                                    ),
                                  )
                                else
                                  Text(c.content, style: const TextStyle(color: Colors.white)),
                                const SizedBox(height: 4),
                                Text(
                                  "${c.created.hour.toString().padLeft(2, '0')}:${c.created.minute.toString().padLeft(2, '0')}",
                                  style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.6)),
                                )
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
          ),
          ChatInputField(
            onSendText: _sendText,
            onSendAudio: _sendVoice,
          ),
        ],
      );
  }
}

