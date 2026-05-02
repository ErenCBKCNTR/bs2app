import 'package:flutter/material.dart';
import 'package:blind_social/core/services/pocketbase_service.dart';
import 'package:intl/intl.dart';
import 'package:blind_social/core/utils/logger.dart';
import 'package:blind_social/core/utils/profanity_filter.dart';

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
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return SafeArea(
      top: false, // Sheet already handles top
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        padding: EdgeInsets.fromLTRB(
          16, 
          16, 
          16, 
          MediaQuery.of(context).viewInsets.bottom > 0 ? 8 : 16
        ),
        child: Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Yorumlar', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              IconButton(
                onPressed: () => Navigator.pop(context), 
                icon: const Icon(Icons.close),
                tooltip: "Kapat",
              ),
            ],
          ),
          const Divider(),
          Flexible(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _comments.isEmpty
                    ? const Center(child: Text("Henüz yorum yapılmamış."))
                    : ListView.builder(
addAutomaticKeepAlives: false,
addRepaintBoundaries: true,
                        shrinkWrap: true,
                        itemCount: _comments.length,
                        itemBuilder: (context, index) {
                          final c = _comments[index];
                          final user = c['expand']?['user_id'];
                          final username = ProfanityFilter.filter(user != null ? (user['username'] ?? user['full_name'] ?? 'Bilinmeyen') : 'Bilinmeyen');
                          final content = ProfanityFilter.filter(c['content'] ?? '');
                          final timeStr = _formatTime(c['created'] ?? '');
                          
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Semantics(
                              excludeSemantics: true,
                              child: CircleAvatar(
                                radius: 16,
                                backgroundColor: Colors.green.shade700,
                                child: Text(
                                  username.isNotEmpty ? username[0].toUpperCase() : '?',
                                  style: const TextStyle(color: Colors.white, fontSize: 12),
                                ),
                              ),
                            ),
                            title: Text(username, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            subtitle: Text(content, style: TextStyle(color: isDarkMode ? Colors.grey[300] : Colors.black87)),
                            trailing: Text(timeStr, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                          );
                        },
                      ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _commentController,
                  decoration: const InputDecoration(
                    hintText: 'Yorum yazın...',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (_isPosting)
                const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
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
    ),
    ),
    );
  }
}
