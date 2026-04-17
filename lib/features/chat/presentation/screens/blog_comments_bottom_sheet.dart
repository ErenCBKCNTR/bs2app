import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
      final response = await Supabase.instance.client
          .from('post_comments')
          .select('*, users!inner(username)')
          .eq('post_id', widget.postId)
          .order('created_at', ascending: true);

      if (mounted) {
        setState(() {
          _comments = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      AppLogger.instance.error('Yorumlar getirilirken hata (Belki tablo henüz yok): $e');
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
      await Supabase.instance.client.from('post_comments').insert({
        'post_id': widget.postId,
        'user_id': Supabase.instance.client.auth.currentUser!.id,
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
                          final username = c['users']?['username'] ?? 'Bilinmeyen';
                          final content = c['content'];
                          final timeStr = _formatTime(c['created_at']);
                          
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
