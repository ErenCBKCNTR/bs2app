import 'package:flutter/material.dart';
import 'package:blind_social/core/services/pocketbase_service.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:intl/intl.dart';
import 'package:blind_social/core/utils/logger.dart';
import 'package:blind_social/features/chat/presentation/screens/blog_comments_bottom_sheet.dart';
import 'package:blind_social/core/utils/profanity_filter.dart';
import 'package:blind_social/core/widgets/expandable_text.dart';

class MyBlogPostsScreen extends StatefulWidget {
  const MyBlogPostsScreen({super.key});

  @override
  State<MyBlogPostsScreen> createState() => _MyBlogPostsScreenState();
}

class _MyBlogPostsScreenState extends State<MyBlogPostsScreen> {
  List<Map<String, dynamic>> _posts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchMyPosts();
  }

  Future<void> _fetchMyPosts() async {
    try {
      final userId = PocketBaseService.client.authStore.model!.id;
      final response = await PocketBaseService.client.collection('posts').getFullList(
          filter: 'user_id = "$userId"',
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
      AppLogger.instance.error('Kendi gönderilerim yüklenemedi: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatTime(String? isoString) {
    if (isoString == null) return '';
    try {
      final date = DateTime.parse(isoString).toLocal();
      return DateFormat('dd.MM.yyyy HH:mm').format(date);
    } catch (e) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gönderilerim'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: isDarkMode ? Colors.white10 : Colors.black12),
        ),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : _posts.isEmpty 
          ? const Center(child: Text("Henüz hiç gönderi paylaşmadınız."))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _posts.length,
              itemBuilder: (context, index) {
                final post = _posts[index];
                final user = post['expand']?['user_id'];
                final username = ProfanityFilter.filter(user != null ? (user['username'] ?? user['name'] ?? 'Bilinmeyen') : 'Bilinmeyen');
                final content = ProfanityFilter.filter(post['content'] ?? '');
                final likes = post['likes_count'] ?? 0;
                final timeStr = _formatTime(post['created']);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDarkMode ? const Color(0xFF232B2B) : Colors.grey[200],
                      borderRadius: BorderRadius.circular(20),
                    ),
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
                                  username[0].toUpperCase(),
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  username,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                              ),
                              Text(
                                timeStr,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                                ),
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
                              Icon(Icons.favorite, size: 20, color: Colors.green),
                              const SizedBox(width: 8),
                              Text(likes.toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
                              const Spacer(),
                              TextButton.icon(
                                onPressed: () {
                                  showModalBottomSheet(
                                    context: context,
                                    isScrollControlled: true,
                                    builder: (_) => BlogCommentsBottomSheet(postId: post['id']),
                                  );
                                },
                                icon: const Icon(Icons.chat_bubble_outline, size: 20),
                                label: const Text('Yorumlar'),
                                style: TextButton.styleFrom(foregroundColor: Colors.green),
                              ),
                            ],
                          )
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
