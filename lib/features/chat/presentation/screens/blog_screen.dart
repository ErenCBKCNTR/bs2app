import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/semantics.dart';
import 'package:blind_social/core/services/pocketbase_service.dart';
import 'package:blind_social/core/utils/json_utils.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:intl/intl.dart';
import 'package:blind_social/core/utils/logger.dart';
import 'package:blind_social/features/chat/presentation/screens/blog_comments_bottom_sheet.dart';
import 'package:blind_social/features/chat/presentation/screens/my_blog_posts_screen.dart';
import 'package:blind_social/core/widgets/expandable_text.dart';
import 'package:blind_social/features/admin/data/services/admin_service.dart';
import 'package:blind_social/core/utils/profanity_filter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:io';

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
    _loadCachedPosts();
    _fetchPosts();
    _pollingTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      _fetchPosts(isBackground: true);
    });
  }

  Future<void> _loadCachedPosts() async {
    if (_posts.isNotEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedStr = prefs.getString('cached_blog_posts');
      if (cachedStr != null) {
        final List<dynamic> decoded = jsonDecode(cachedStr);
        if (mounted) {
          setState(() {
            final parsedPosts = <Map<String, dynamic>>[];
            for (var e in decoded) {
              try {
                parsedPosts.add(Map<String, dynamic>.from(e as Map));
              } catch (err) {
                AppLogger.instance.error('Tekil post çözme hatası: $err');
              }
            }
            _posts = parsedPosts;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      AppLogger.instance.error('Önbellek okuma hatası: $e');
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _postController.dispose();
    super.dispose();
  }

  Future<void> _fetchPosts({bool isBackground = false}) async {
    // İnternet kontrolü (önbellek varsa boşa ağ isteği atma)
    if (_posts.isNotEmpty) {
      bool hasInternet = true;
      if (!kIsWeb) {
        try {
          final result = await InternetAddress.lookup('api.cabukcan.com').timeout(const Duration(seconds: 3));
          if (result.isEmpty || result[0].rawAddress.isEmpty) {
            hasInternet = false;
          }
        } catch (_) {
          hasInternet = false;
        }
      }
      
      if (!hasInternet) {
        AppLogger.instance.info('İnternet bağlantısı yok, var olan post önbelleği kullanılacak.');
        return;
      }
    }

    try {
      final response = await PocketBaseService.client.collection('posts').getFullList(
          sort: '-created',
          expand: 'user_id,post_likes_via_post_id,post_comments_via_post_id',
          headers: kIsWeb ? {'Cache-Control': 'no-cache', 'Pragma': 'no-cache'} : const {},
      ).timeout(const Duration(seconds: 15));
          
      if (mounted) {
        setState(() {
          final newPosts = response.map((e) => JsonUtils.deeplySerializeRecord(e)).toList();
          // If we have processing likes, we don't want to override those posts with stale data from server
          if (_processingLikes.isNotEmpty) {
            for (var i = 0; i < newPosts.length; i++) {
              if (_processingLikes.contains(newPosts[i]['id'])) {
                // Keep the local optimistic state
                final localIndex = _posts.indexWhere((p) => p['id'] == newPosts[i]['id']);
                if (localIndex != -1) {
                  newPosts[i] = _posts[localIndex];
                }
              }
            }
          }
          _posts = newPosts;
          _cachedPosts = _posts;
          _isLoading = false;
        });
        
        try {
          SharedPreferences.getInstance().then((prefs) {
            prefs.setString('cached_blog_posts', jsonEncode(_posts));
          });
        } catch(e) {}
      }
    } catch (e) {
      if (!isBackground) {
        AppLogger.instance.error('Gönderiler yüklenemedi: $e');
        if (mounted) {
          setState(() => _isLoading = false);
        }
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gönderilemedi. Lütfen internet bağlantınızı kontrol edin.')));
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
            maxLength: 1000,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Gönderinizi düzenleyin...',
              border: OutlineInputBorder(),
              counterText: "", // Hide counter but keep limit
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
            maxLength: 1000,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Ne düşünüyorsunuz?',
              border: OutlineInputBorder(),
              counterText: "",
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
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Semantics(
                button: true,
                label: "Gönderilerim sayfası",
                onTapHint: "Paylaştığınız tüm gönderileri görmek için çift dokunun",
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const MyBlogPostsScreen()),
                    );
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.history, color: Colors.green, size: 22),
                        const SizedBox(width: 12),
                        const Text(
                          "Blog Gönderilerim",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                        const Spacer(),
                        Icon(Icons.chevron_right, color: Colors.green.withOpacity(0.5)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Semantics(
                button: true,
                label: "Yeni gönderi paylaş",
                excludeSemantics: true,
                onTapHint: "Yeni bir blog içeriği oluşturmak için çift dokunun",
                child: OutlinedButton.icon(
                  onPressed: _showCreatePostDialog,
                  icon: const Icon(Icons.edit, size: 20),
                  label: const Text(
                    "Yeni Gönderi Paylaş",
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 54),
                    foregroundColor: Colors.green,
                    side: const BorderSide(color: Colors.green, width: 2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Divider(color: isDarkMode ? Colors.white10 : Colors.black12),
            ),
            const SizedBox(height: 8),
            if (_isPosting)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: LinearProgressIndicator(color: Colors.green),
              ),
            Expanded(
              child: _isLoading 
                ? const Center(child: CircularProgressIndicator())
                : _posts.isEmpty 
                  ? const Center(child: Text("Henüz hiç gönderi paylaşılmamış."))
                  : ListView.builder(
addAutomaticKeepAlives: false,
addRepaintBoundaries: true,
                      padding: const EdgeInsets.all(16),
                      itemCount: _posts.length,
                      itemBuilder: (context, index) {
                        final post = _posts[index];
                        final user = post['expand']?['user_id'];
                        final username = ProfanityFilter.filter(user != null ? (user['username'] ?? user['name'] ?? user['full_name'] ?? 'Bilinmeyen') : 'Bilinmeyen');
                        final content = ProfanityFilter.filter(post['content'] ?? '');
                        final likes = post['likes_count'] ?? 0;
                        final myId = PocketBaseService.client.authStore.model!.id;
                        final likesList = post['expand']?['post_likes_via_post_id'] ?? [];
                        final isLiked = likesList.any((l) => l['user_id'] == myId);
                        
                        final commentCount = (post['expand']?['post_comments_via_post_id'] as List?)?.length ?? 0;
                        final timeStr = _formatTime(post['created']);
    
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Semantics(
                            label: "$username. $timeStr. $content. $likes beğeni, $commentCount yorum.",
                            button: true,
                            excludeSemantics: true,
                            onTap: () {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                useSafeArea: true,
                                builder: (_) => BlogCommentsBottomSheet(postId: post['id']),
                              );
                            },
                            onTapHint: "Yorumları okumak ve yazmak için çift dokunun",
                            customSemanticsActions: {
                              ...post['user_id'] == PocketBaseService.client.authStore.model?.id
                              ? {
                                  CustomSemanticsAction(label: 'Gönderiyi Düzenle'): () {
                                    _showEditDialog(post['id'], content);
                                  },
                                  CustomSemanticsAction(label: 'Gönderiyi Sil'): () {
                                    _deletePost(post['id']);
                                  },
                                }
                              : {},
                              CustomSemanticsAction(label: isLiked ? 'Beğeniyi Kaldır' : 'Beğen'): () {
                                _toggleLike(post['id'], likes);
                              },
                              CustomSemanticsAction(label: 'Yorumları Aç'): () {
                                showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  useSafeArea: true,
                                  builder: (_) => BlogCommentsBottomSheet(postId: post['id']),
                                );
                              },
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: isDarkMode ? const Color(0xFF232B2B) : Colors.grey[200],
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: ExcludeSemantics(
                                  child: InkWell(
                                    onTap: () {
                                      showModalBottomSheet(
                                        context: context,
                                        isScrollControlled: true,
                                        useSafeArea: true,
                                        builder: (_) => BlogCommentsBottomSheet(postId: post['id']),
                                      );
                                    },
                                    borderRadius: BorderRadius.circular(20),
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              CircleAvatar(
                                                radius: 20,
                                                backgroundColor: Colors.green.shade700,
                                                child: Text(
                                                  username.isNotEmpty ? username[0].toUpperCase() : '?',
                                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      username,
                                                      style: const TextStyle(
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 16,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Text(
                                                timeStr,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                                                ),
                                              ),
                                              if (post['user_id'] == PocketBaseService.client.authStore.model?.id || AdminService().isAdmin())
                                                PopupMenuButton<String>(
                                                  icon: Icon(
                                                    Icons.more_horiz,
                                                    color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                                                  ),
                                                  onSelected: (val) {
                                                    if (val == 'edit') {
                                                      if (post['user_id'] == PocketBaseService.client.authStore.model?.id) {
                                                        _showEditDialog(post['id'], content);
                                                      } else {
                                                        ScaffoldMessenger.of(context).showSnackBar(
                                                          const SnackBar(content: Text('Sadece kendi gönderilerinizi düzenleyebilirsiniz.'))
                                                        );
                                                      }
                                                    }
                                                    if (val == 'delete') _deletePost(post['id']);
                                                  },
                                                  itemBuilder: (context) => [
                                                    if (post['user_id'] == PocketBaseService.client.authStore.model?.id)
                                                      const PopupMenuItem(value: 'edit', child: Text('Düzenle')),
                                                    const PopupMenuItem(value: 'delete', child: Text('Sil', style: TextStyle(color: Colors.red))),
                                                  ],
                                                ),
                                            ],
                                          ),
                                          const SizedBox(height: 16),
                                          ExpandableText(
                                            text: content,
                                            maxLines: 4,
                                            style: TextStyle(
                                              fontSize: 15,
                                              height: 1.4,
                                              color: isDarkMode ? Colors.grey[200] : Colors.black87,
                                            ),
                                          ),
                                          const SizedBox(height: 16),
                                          Row(
                                            children: [
                                              _buildInteractionButton(
                                                icon: isLiked ? Icons.favorite : Icons.favorite_border,
                                                count: likes,
                                                isActive: isLiked,
                                                activeColor: Colors.green,
                                                onTap: () => _toggleLike(post['id'], likes),
                                              ),
                                              const SizedBox(width: 16),
                                              _buildInteractionButton(
                                                icon: Icons.chat_bubble_outline,
                                                count: commentCount,
                                                isActive: false,
                                                activeColor: Colors.green,
                                                onTap: () {
                                                  showModalBottomSheet(
                                                    context: context,
                                                    isScrollControlled: true,
                                                    useSafeArea: true,
                                                    builder: (_) => BlogCommentsBottomSheet(postId: post['id']),
                                                  );
                                                },
                                              ),
                                            ],
                                          )
                                        ],
                                      ),
                                    ),
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

  Widget _buildInteractionButton({
    required IconData icon,
    required int count,
    required bool isActive,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    final color = isActive ? activeColor : (Theme.of(context).brightness == Brightness.dark ? Colors.grey[400] : Colors.grey[600]);
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        child: Row(
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(width: 8),
            Text(
              count.toString(),
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
