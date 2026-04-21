import 'package:blind_social/core/services/pocketbase_service.dart';
import 'package:blind_social/core/utils/logger.dart';

class AdminService {
  static final AdminService _instance = AdminService._internal();
  factory AdminService() => _instance;
  AdminService._internal();

  /// Checks if the current user is an admin (Role 0)
  bool isAdmin() {
    final user = PocketBaseService.client.authStore.model;
    if (user == null) return false;
    
    // Explicitly allow the owner email as admin for now if role field is missing or 0
    final email = user.email;
    final dynamic roleValue = user.data['role'];
    
    // Role 0 is Admin as per user request
    if (roleValue != null && roleValue.toString() == '0') return true;
    
    // Fallback for the creator/owner
    if (email == 'erencs87@gmail.com') return true;
    
    return false;
  }

  Future<Map<String, dynamic>> getStats() async {
    try {
      final now = DateTime.now().toUtc();
      final fifteenMinsAgo = now.subtract(const Duration(minutes: 15));
      final fifteenMinsAgoStr = fifteenMinsAgo.toIso8601String().replaceFirst('T', ' ');

      // 1. Active Users (last 15 mins)
      final usersResponse = await PocketBaseService.client.collection('users').getList(
        page: 1,
        perPage: 1,
        filter: 'last_seen >= "$fifteenMinsAgoStr"',
      );
      final activeUsersCount = usersResponse.totalItems;

      // 2. Recent Blog Posts (last 15 mins)
      final postsResponse = await PocketBaseService.client.collection('posts').getList(
        page: 1,
        perPage: 1,
        filter: 'created >= "$fifteenMinsAgoStr"',
      );
      final recentPostsCount = postsResponse.totalItems;

      // 3. Total Servers
      final serversResponse = await PocketBaseService.client.collection('chat_servers').getList(
        page: 1,
        perPage: 1,
      );
      final totalServersCount = serversResponse.totalItems;

      return {
        'activeUsers': activeUsersCount,
        'recentPosts': recentPostsCount,
        'totalServers': totalServersCount,
      };
    } catch (e) {
      AppLogger.instance.error('Admin istatistikleri alınamadı: $e');
      return {
        'activeUsers': 0,
        'recentPosts': 0,
        'totalServers': 0,
      };
    }
  }

  Future<void> deletePost(String postId) async {
    try {
      await PocketBaseService.client.collection('posts').delete(postId);
    } catch (e) {
      AppLogger.instance.error('Gönderi silinirken hata: $e');
      rethrow;
    }
  }
}
