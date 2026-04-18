import 'package:flutter/material.dart';
import 'package:blind_social/core/services/pocketbase_service.dart';
import 'package:intl/intl.dart';
import 'package:blind_social/core/utils/logger.dart';

class BlogCommentsBottomSheet extends StatefulWidget {
  final String postId;

  const BlogCommentsBottomSheet({super.key, required this.postId});

  @override
  State<BlogCommentsBottomSheet> createState() => _BlogCommentsBottomSheetState();
}

class _BlogCommentsBottomSheetState extends State<BlogCommentsBottomSheet> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _comments = [];
  final _commentController = TextEditingController();
  bool _isPosting = false;

  @override
  void initState() {
    super.initState();
    _fetchComments();
  }

  Future<void> _fetchComments() async {
    try {
      final response = await PocketBaseService.client.collection('post_comments').getFullList(
          filter: 'post_id = "${widget.postId}"',
          expand: 'user_id',
          sort: 'created'
      );

      if (mounted) {
        setState(() {
          _comments = response.map((e) => e.toJson()).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      AppLogger.instance.error('Yorumlar getirilirken hata: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _postComment() async {
    if (_commentController.text.trim().isEmpty) return;

    setState(() {
      _isPosting = true;
    });

    try {
      await PocketBaseService.client.collection('post_comments').create(body: {
        'post_id': widget.postId,
        'user_id': PocketBaseService.client.authStore.model!.id,
        'content': _commentController.text.trim(),
      });
      _commentController.clear();
      _fetchComments();
    } catch (e) {
      AppLogger.instance.error('Yorum gönderilirken hata: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Yorum gönderilemedi: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPosting = false;
        });
      }
    }
  }

  String _formatTime(String isoString) {
    if (isoString.isEmpty) return '';
    try {
      final date = DateTime.parse(isoString).toLocal();
      return DateFormat('HH:mm').format(date);
    } catch (e) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Yorumlar', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
            ],
          ),
          const Divider(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _comments.isEmpty
                    ? const Center(child: Text("Henüz yorum yapılmamış."))
                    : ListView.builder(
                        itemCount: _comments.length,
                        itemBuilder: (context, index) {
                          final c = _comments[index];
                          final user = c['expand']?['user_id'];
                          final username = user != null ? (user['name'] ?? user['full_name'] ?? 'Bilinmeyen') : 'Bilinmeyen';
                          final content = c['content'];
                          final timeStr = _formatTime(c['created'] ?? '');
                          
                          return ListTile(
                            leading: const Icon(Icons.person),
                            title: Text(username),
                            subtitle: Text(content),
                            trailing: Text(timeStr, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          );
                        },
                      ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _commentController,
                  decoration: const InputDecoration(
                    hintText: 'Yorum yazın...',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (_isPosting)
                const CircularProgressIndicator()
              else
                IconButton(
                  onPressed: _postComment,
                  icon: const Icon(Icons.send),
                  color: Colors.green,
                  tooltip: 'Yorumu Gönder',
                ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
