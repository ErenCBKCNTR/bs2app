import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:blind_social/core/utils/logger.dart';

class BlogScreen extends StatefulWidget {
  const BlogScreen({super.key});

  @override
  State<BlogScreen> createState() => _BlogScreenState();
}

class _BlogScreenState extends State<BlogScreen> {
  final _postController = TextEditingController();
  bool _isPosting = false;

  Future<void> _createPost() async {
    final text = _postController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isPosting = true);
    
    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      await Supabase.instance.client.from('posts').insert({
        'user_id': userId,
        'content': text,
      });
      _postController.clear();
      AppLogger.instance.info('Yeni blog postu oluşturuldu');
      // Tablodaki değişiklik Realtime ile veya FutureBuilder yenilenerek ekrana yansır.
      setState(() {}); 
    } catch (e) {
      AppLogger.instance.error('Post oluştururken hata: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gönderilemedi: $e')));
      }
    } finally {
      if (mounted) setState(() => _isPosting = false);
    }
  }

  String _formatTime(String? isoString) {
    if (isoString == null) return '';
    try {
      final date = DateTime.parse(isoString).toLocal();
      final now = DateTime.now();
      final diff = now.difference(date);
      if (diff.inMinutes < 60) {
        return '${diff.inMinutes} dk önce';
      } else if (diff.inHours < 24) {
        return '${diff.inHours} saat önce';
      } else {
        return DateFormat('dd.MM.yyyy HH:mm').format(date);
      }
    } catch (e) {
      return '';
    }
  }

  void _showCreatePostDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Yeni Gönderi'),
          content: TextField(
            controller: _postController,
            maxLines: 4,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Ne düşünüyorsunuz?',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('İptal'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _createPost();
              },
              child: const Text('Paylaş'),
            ),
          ],
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: ElevatedButton.icon(
            onPressed: _showCreatePostDialog,
            icon: const Icon(Icons.edit),
            label: const Text("Yeni Gönderi Paylaş"),
            style: ElevatedButton.styleFrom(
               minimumSize: const Size(double.infinity, 50),
            ),
          ),
        ),
        if (_isPosting)
          const LinearProgressIndicator(),
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            // Tabloyu ve ilişkili kullanıcı bilgisini çekiyor
            future: Supabase.instance.client
                .from('posts')
                .select('*, users!inner(username)')
                .order('created_at', ascending: false),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Gönderiler yüklenemedi: ${snapshot.error}'));
              }
              
              final posts = snapshot.data ?? [];
              
              if (posts.isEmpty) {
                return const Center(child: Text("Henüz hiç gönderi paylaşılmamış."));
              }

              return ListView.separated(
                padding: const EdgeInsets.all(8),
                itemCount: posts.length,
                separatorBuilder: (context, index) => const Divider(),
                itemBuilder: (context, index) {
                  final post = posts[index];
                  final user = post['users'] as Map<String, dynamic>?;
                  final username = user?['username'] ?? 'Bilinmeyen';
                  final content = post['content'] ?? '';
                  final likes = post['likes_count'] ?? 0;
                  final timeStr = _formatTime(post['created_at']);

                  return Card(
                    elevation: 0,
                    color: Colors.transparent,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: Colors.green.shade800,
                                child: Text(
                                  username.isNotEmpty ? username[0].toUpperCase() : '?',
                                  style: const TextStyle(color: Colors.white, fontSize: 14),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                username,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              const Spacer(),
                              Text(
                                timeStr,
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            content,
                            style: const TextStyle(fontSize: 15),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Icon(Icons.favorite_border, size: 20, color: Colors.grey.shade400),
                              const SizedBox(width: 4),
                              Text(likes.toString(), style: TextStyle(color: Colors.grey.shade400)),
                              const SizedBox(width: 16),
                              Icon(Icons.chat_bubble_outline, size: 20, color: Colors.grey.shade400),
                              const SizedBox(width: 4),
                              Text("0", style: TextStyle(color: Colors.grey.shade400)),
                            ],
                          )
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
