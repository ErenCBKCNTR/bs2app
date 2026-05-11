import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:blind_social/core/services/pocketbase_service.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:intl/intl.dart';
import 'package:blind_social/core/utils/logger.dart';
import 'package:blind_social/features/chat/presentation/screens/blog_comments_bottom_sheet.dart';
import 'package:blind_social/core/utils/profanity_filter.dart';
import 'package:blind_social/core/widgets/expandable_text.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:blind_social/core/providers/localization_provider.dart';

class MyBlogPostsScreen extends ConsumerStatefulWidget {
  const MyBlogPostsScreen({super.key});

  @override
  ConsumerState<MyBlogPostsScreen> createState() => _MyBlogPostsScreenState();
}

class _MyBlogPostsScreenState extends ConsumerState<MyBlogPostsScreen> {
  List<Map<String, dynamic>> _posts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchMyPosts();
  }

  Future<void> _fetchMyPosts() async {
    final lang = ref.read(localizationProvider);
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
      AppLogger.instance.error('${lang.failedToLoadDetails}: $e');
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

  Future<void> _deletePost(String postId) async {
    final lang = ref.read(localizationProvider);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(lang.deleteConfirmTitle),
        content: Text(lang.deletePostConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(lang.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(lang.delete, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await PocketBaseService.client.collection('posts').delete(postId);
      setState(() {
        _posts.removeWhere((p) => p['id'] == postId);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(lang.postDeleted)));
      }
    } catch (e) {
      AppLogger.instance.error('${lang.failedToDeletePost}: $e');
    }
  }

  Future<void> _showEditDialog(String postId, String currentContent) async {
    final lang = ref.read(localizationProvider);
    final controller = TextEditingController(text: currentContent);
    final focusNode = FocusNode();
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        Future.delayed(const Duration(milliseconds: 100), () => focusNode.requestFocus());
        return AlertDialog(
          title: Text(lang.editPostTitle),
          content: TextField(
            controller: controller,
            focusNode: focusNode,
            maxLines: 5,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(lang.cancel),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: Text(lang.save),
            ),
          ],
        );
      },
    );

    if (result != null && result.isNotEmpty && result != currentContent) {
      try {
        final res = await PocketBaseService.client.collection('posts').update(postId, body: {'content': result});
        setState(() {
          final index = _posts.indexWhere((p) => p['id'] == postId);
          if (index != -1) {
            _posts[index]['content'] = res.getStringValue('content');
          }
        });
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(lang.postUpdated)));
        }
      } catch (e) {
        AppLogger.instance.error('${lang.failedToUpdatePost}: $e');
      }
    }
  }

  Future<void> _toggleLike(String postId, int currentLikes) async {
    final lang = ref.read(localizationProvider);
    final myId = PocketBaseService.client.authStore.model!.id;
    final postIndex = _posts.indexWhere((p) => p['id'] == postId);
    if (postIndex == -1) return;

    final likesList = List.from(_posts[postIndex]['expand']?['post_likes_via_post_id'] ?? []);
    final isCurrentlyLiked = likesList.any((l) => l['user_id'] == myId);

    setState(() {
      if (isCurrentlyLiked) {
        _posts[postIndex]['likes_count'] = (currentLikes - 1).clamp(0, 999999);
        likesList.removeWhere((l) => l['user_id'] == myId);
      } else {
        _posts[postIndex]['likes_count'] = currentLikes + 1;
        likesList.add({'user_id': myId, 'id': 'temp_$myId'});
      }
      _posts[postIndex]['expand'] ??= {};
      _posts[postIndex]['expand']['post_likes_via_post_id'] = likesList;
    });

    try {
      if (isCurrentlyLiked) {
        final existingRecords = await PocketBaseService.client.collection('post_likes').getFullList(
          filter: 'post_id = "$postId" && user_id = "$myId"',
        );
        for (var rec in existingRecords) {
          await PocketBaseService.client.collection('post_likes').delete(rec.id);
        }
      } else {
        await PocketBaseService.client.collection('post_likes').create(body: {
          'post_id': postId,
          'user_id': myId,
        });
      }
    } catch (e) {
      AppLogger.instance.error('${lang.likeProcessFailed}: $e');
    }
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

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(localizationProvider);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(lang.myPosts),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: isDarkMode ? Colors.white10 : Colors.black12),
        ),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : _posts.isEmpty 
          ? Center(child: Text(lang.noPostsYet))
          : ListView.builder(
addAutomaticKeepAlives: false,
addRepaintBoundaries: true,
              padding: const EdgeInsets.all(16),
              itemCount: _posts.length,
              itemBuilder: (context, index) {
                final post = _posts[index];
                final user = post['expand']?['user_id'];
                final username = ProfanityFilter.filter(user != null ? (user['username'] ?? user['name'] ?? 'Bilinmeyen') : 'Bilinmeyen');
                final content = ProfanityFilter.filter(post['content'] ?? '');
                final likes = post['likes_count'] ?? 0;
                final timeStr = _formatTime(post['created']);
                
                final myId = PocketBaseService.client.authStore.model!.id;
                final likesList = post['expand']?['post_likes_via_post_id'] ?? [];
                final isLiked = likesList.any((l) => l['user_id'] == myId);
                final commentCount = (post['expand']?['post_comments_via_post_id'] as List?)?.length ?? 0;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Semantics(
                    label: lang.blogPostSemanticLabel(
                      username: username,
                      time: timeStr,
                      content: content,
                      likes: likes,
                      comments: commentCount,
                    ),
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
                    onTapHint: lang.readCommentsHint,
                    customSemanticsActions: {
                      CustomSemanticsAction(label: ref.read(localizationProvider).editPost): () {
                        _showEditDialog(post['id'], content);
                      },
                      CustomSemanticsAction(label: ref.read(localizationProvider).deletePost): () {
                        _deletePost(post['id']);
                      },
                      CustomSemanticsAction(label: isLiked ? ref.read(localizationProvider).unlikePost : ref.read(localizationProvider).likePost): () {
                        _toggleLike(post['id'], likes);
                      },
                      CustomSemanticsAction(label: ref.read(localizationProvider).openComments): () {
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
                                      PopupMenuButton<String>(
                                        icon: Icon(
                                          Icons.more_horiz,
                                          color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                                        ),
                                        onSelected: (val) {
                                          if (val == 'edit') _showEditDialog(post['id'], content);
                                          if (val == 'delete') _deletePost(post['id']);
                                        },
                                        itemBuilder: (context) => [
                                          PopupMenuItem(value: 'edit', child: Text(lang.edit)),
                                          PopupMenuItem(value: 'delete', child: Text(lang.delete, style: const TextStyle(color: Colors.red))),
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
    );
  }
}
