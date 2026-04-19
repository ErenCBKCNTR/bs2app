import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:blind_social/core/services/pocketbase_service.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:intl/intl.dart';
import 'package:blind_social/core/utils/logger.dart';
import 'package:blind_social/features/chat/presentation/screens/blog_comments_bottom_sheet.dart';
import 'package:blind_social/core/utils/profanity_filter.dart';
import 'dart:async';

class BlogScreen extends StatefulWidget {
  const BlogScreen({super.key});

  @override
  State<BlogScreen> createState() => _BlogScreenState();
}

class _BlogScreenState extends State<BlogScreen> {
  static List<Map<String, dynamic>>? _cachedPosts;
  
  final _postController = TextEditingController();
  bool _isPosting = false;
  
  List<Map<String, dynamic>> _posts = _cachedPosts ?? [];
  bool _isLoading = _cachedPosts == null;
  Timer? _pollingTimer;
  final Set<String> _processingLikes = {};
  final Map<String, Timer> _likeDebouncers = {};

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
          // If we have processing likes, we don't want to override those posts with stale data from server
          if (_processingLikes.isEmpty) {
            _posts = response.map((e) => e.toJson()).toList();
          } else {
            final newPosts = response.map((e) => e.toJson()).toList();
            for (var i = 0; i < newPosts.length; i++) {
              if (_processingLikes.contains(newPosts[i]['id'])) {
                // Keep the local optimistic state
                final localIndex = _posts.indexWhere((p) => p['id'] == newPosts[i]['id']);
                if (localIndex != -1) {
                  newPosts[i] = _posts[localIndex];
                }
              }
            }
            _posts = newPosts;
          }
          _cachedPosts = _posts;
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
    final myId = PocketBaseService.client.authStore.model!.id;
    final postIndex = _posts.indexWhere((p) => p['id'] == postId);
    if (postIndex == -1) return;

    final likesList = List.from(_posts[postIndex]['expand']?['post_likes_via_post_id'] ?? []);
    final isCurrentlyLiked = likesList.any((l) => l['user_id'] == myId);

    // Optimistic UI Update - Instant feedback
    setState(() {
      _processingLikes.add(postId);
      if (isCurrentlyLiked) {
        _posts[postIndex]['likes_count'] = (currentLikes - 1).clamp(0, 999999);
        likesList.removeWhere((l) => l['user_id'] == myId);
      } else {
        _posts[postIndex]['likes_count'] = currentLikes + 1;
        likesList.add({'user_id': myId, 'id': 'temp_$myId'}); // Temp ID for list management
      }
      _posts[postIndex]['expand'] ??= {};
      _posts[postIndex]['expand']['post_likes_via_post_id'] = likesList;
      _cachedPosts = _posts;
    });

    // Debounce the actual API call to sector standards
    _likeDebouncers[postId]?.cancel();
    _likeDebouncers[postId] = Timer(const Duration(milliseconds: 500), () async {
      try {
        // Double check likes collection first
        final realLikes = await PocketBaseService.client.collection('post_likes').getFullList(
          filter: 'post_id = "$postId" && user_id = "$myId"',
        );
        
        // Final check on server to sync the count accurately
        final updatedPostRecord = await PocketBaseService.client.collection('posts').getOne(postId);
        int freshCount = updatedPostRecord.getIntValue('likes_count');

        if (realLikes.isNotEmpty) {
          if (!isCurrentlyLiked) {
             // We un-liked, but it was already liked in DB, good
             await PocketBaseService.client.collection('post_likes').delete(realLikes.first.id);
             await PocketBaseService.client.collection('posts').update(postId, body: {'likes_count': (freshCount - 1).clamp(0, 999999)});
          }
        } else {
          if (isCurrentlyLiked == false) {
             // We liked, it's NOT in DB, good
             await PocketBaseService.client.collection('post_likes').create(body: {'post_id': postId, 'user_id': myId});
             await PocketBaseService.client.collection('posts').update(postId, body: {'likes_count': freshCount + 1});
          }
        }
      } catch (e) {
        AppLogger.instance.error('Beğeni işlemi başarısız: $e');
        // On error, let the next background fetch fix it
      } finally {
        if (mounted) {
          setState(() {
            _processingLikes.remove(postId);
          });
          _likeDebouncers.remove(postId);
        }
      }
    });
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
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Blog'),
      ),
      body: SafeArea(
        child: Column(
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
                      final username = ProfanityFilter.filter(user != null ? (user['username'] ?? user['name'] ?? user['full_name'] ?? 'Bilinmeyen') : 'Bilinmeyen');
                      final content = ProfanityFilter.filter(post['content'] ?? '');
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
      ),
    ),
  );
}
}
