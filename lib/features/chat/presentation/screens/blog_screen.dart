import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:blind_social/core/services/pocketbase_service.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:intl/intl.dart';
import 'package:blind_social/core/utils/logger.dart';
import 'package:blind_social/features/chat/presentation/screens/blog_comments_bottom_sheet.dart';
import 'dart:async';

class BlogScreen extends StatefulWidget {
  const BlogScreen({super.key});

  @override
  State<BlogScreen> createState() => _BlogScreenState();
}

class _BlogScreenState extends State<BlogScreen> {
  final _postController = TextEditingController();
  bool _isPosting = false;
  
  List<Map<String, dynamic>> _posts = [];
  bool _isLoading = true;
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _fetchPosts();
    _pollingTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      _fetchPosts(isBackground: true);
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _postController.dispose();
    super.dispose();
  }

  Future<void> _fetchPosts({bool isBackground = false}) async {
    try {
      final response = await PocketBaseService.client.collection('posts').getFullList(
          sort: '-created',
          expand: 'user_id,post_likes_via_post_id'
      );
          
      if (mounted) {
        setState(() {
          _posts = response.map((e) => e.toJson()).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!isBackground) {
        AppLogger.instance.error('Gönderiler yüklenemedi: $e');
      }
    }
  }

  Future<void> _createPost() async {
    final text = _postController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isPosting = true);
    
    try {
      final userId = PocketBaseService.client.authStore.model!.id;
      await PocketBaseService.client.collection('posts').create(body: {
        'user_id': userId,
        'content': text,
        'likes_count': 0
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

  Future<void> _deletePost(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Gönderiyi Sil'),
        content: const Text('Bu gönderiyi silmek istediğinize emin misiniz? Bu işlem geri alınamaz.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await PocketBaseService.client.collection('posts').delete(id);
        AppLogger.instance.info('Gönderi silindi: $id');
        _fetchPosts();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gönderi silindi.')));
        }
      } catch (e) {
        AppLogger.instance.error('Gönderi silinemedi: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
        }
      }
    }
  }

  Future<void> _toggleLike(String postId, int currentLikes) async {
    try {
      final myId = PocketBaseService.client.authStore.model!.id;
      
      // Check if user already liked
      final likes = await PocketBaseService.client.collection('post_likes').getFullList(
        filter: 'post_id = "$postId" && user_id = "$myId"'
      );
      
      if (likes.isNotEmpty) {
        // Un-like
        await PocketBaseService.client.collection('post_likes').delete(likes.first.id);
        await PocketBaseService.client.collection('posts').update(postId, body: {'likes_count': currentLikes - 1});
      } else {
        // Like
        await PocketBaseService.client.collection('post_likes').create(body: {'post_id': postId, 'user_id': myId});
        await PocketBaseService.client.collection('posts').update(postId, body: {'likes_count': currentLikes + 1});
      }
      
      _fetchPosts(isBackground: true);
    } catch (e) {
      AppLogger.instance.error('Beğeni işlemi başarısız: $e');
    }
  }

  void _showEditDialog(String id, String currentContent) {
    final editController = TextEditingController(text: currentContent);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Gönderiyi Düzenle'),
          content: TextField(
            controller: editController,
            maxLines: 4,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Gönderinizi düzenleyin...',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('İptal'),
            ),
            ElevatedButton(
              onPressed: () async {
                final newContent = editController.text.trim();
                if (newContent.isEmpty) return;
                
                Navigator.pop(context);
                try {
                  await PocketBaseService.client.collection('posts').update(id, body: {
                     'content': newContent
                  });
                  AppLogger.instance.info('Gönderi düzenlendi: $id');
                  _fetchPosts();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gönderi güncellendi.')));
                  }
                } catch (e) {
                  AppLogger.instance.error('Gönderi düzenlenemedi: $e');
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Düzenlenemedi: $e')));
                  }
                }
              },
              child: const Text('Kaydet'),
            ),
          ],
        );
      }
    );
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
          child: _isLoading 
            ? const Center(child: CircularProgressIndicator())
            : _posts.isEmpty 
              ? const Center(child: Text("Henüz hiç gönderi paylaşılmamış."))
              : ListView.separated(
                  padding: const EdgeInsets.all(8),
                  itemCount: _posts.length,
                  separatorBuilder: (context, index) => const Divider(),
                  itemBuilder: (context, index) {
                    final post = _posts[index];
                    final user = post['expand']?['user_id'];
                    final username = user != null ? (user['username'] ?? user['name'] ?? user['full_name'] ?? 'Bilinmeyen') : 'Bilinmeyen';
                    final content = post['content'] ?? '';
                    final likes = post['likes_count'] ?? 0;
                    final myId = PocketBaseService.client.authStore.model!.id;
                    // Check if current user liked
                    final likesList = post['expand']?['post_likes_via_post_id'] ?? [];
                    final isLiked = likesList.any((l) => l['user_id'] == myId);
                    
                    // TODO: We could fetch comment count independently or use a view, for now we will assume 0 or handle it later
                    final commentCount = 0;
                    final timeStr = _formatTime(post['created']);

                    return Semantics(
                      label: "$username. $timeStr. $content. $likes beğeni.",
                      button: true, // Clickable for future actions or reading context
                      onTap: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          builder: (_) => BlogCommentsBottomSheet(postId: post['id']),
                        );
                      },
                      onTapHint: "Yorumları okumak ve yazmak için çift dokunun",
                      customSemanticsActions: post['user_id'] == PocketBaseService.client.authStore.model?.id
                        ? {
                            CustomSemanticsAction(label: 'Gönderiyi Düzenle'): () {
                              _showEditDialog(post['id'], content);
                            },
                            CustomSemanticsAction(label: 'Gönderiyi Sil'): () {
                              _deletePost(post['id']);
                            },
                          }
                        : {},
                      child: ExcludeSemantics(
                        child: Card(
                          elevation: 0,
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                builder: (_) => BlogCommentsBottomSheet(postId: post['id']),
                              );
                            },
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
                                    Semantics(
                                      label: isLiked ? "Beğenildi. Şu anki beğeni sayısı $likes" : "Beğen. Şu anki beğeni sayısı $likes",
                                      button: true,
                                      onTapHint: "Gönderiyi beğenmek veya beğeniyi geri almak için çift dokunun",
                                      child: InkWell(
                                        onTap: () => _toggleLike(post['id'], likes),
                                        borderRadius: BorderRadius.circular(20),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                                          child: Row(
                                            children: [
                                              Icon(isLiked ? Icons.favorite : Icons.favorite_border, size: 20, color: Colors.red.shade400),
                                              const SizedBox(width: 4),
                                              Text(likes.toString(), style: TextStyle(color: Colors.red.shade400, fontWeight: FontWeight.bold)),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Semantics(
                                      label: "Yorumlar. $commentCount yorum var.",
                                      button: true,
                                      onTapHint: "Yorumları görmek için çift dokunun",
                                      child: InkWell(
                                        onTap: () {
                                          showModalBottomSheet(
                                            context: context,
                                            isScrollControlled: true,
                                            builder: (_) => BlogCommentsBottomSheet(postId: post['id']),
                                          );
                                        },
                                        borderRadius: BorderRadius.circular(20),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                                          child: Row(
                                            children: [
                                              Icon(Icons.chat_bubble_outline, size: 20, color: Colors.grey.shade400),
                                              const SizedBox(width: 4),
                                              Text(commentCount.toString(), style: TextStyle(color: Colors.grey.shade400)),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    ],
  );
}
}
