import 'package:pocketbase/pocketbase.dart';
import 'package:blind_social/core/services/pocketbase_service.dart';
import 'package:blind_social/core/utils/logger.dart';

class AdminService {
  static final AdminService _instance = AdminService._internal();
  factory AdminService() => _instance;
  AdminService._internal();

  /// Checks if the current user is an admin (Role 0)
  bool isAdmin() {
    try {
      final user = PocketBaseService.client.authStore.model;
      if (user == null) return false;
      
      final dynamic roleValue = user.data['role'];
      
      // Role 0 is Admin as per user request. STRICT role checking. No fallback.
      if (roleValue != null && roleValue.toString() == '0') return true;
    } catch (e) {
      AppLogger.instance.error('isAdmin check error: $e');
    }
    
    return false;
  }

  Future<Map<String, dynamic>> getStats() async {
    try {
      final now = DateTime.now().toUtc();
      final fifteenMinsAgo = now.subtract(const Duration(minutes: 15));
      final fifteenMinsAgoStr = fifteenMinsAgo.toIso8601String().replaceFirst('T', ' ');

      // 1. Active Users (last 15 mins)
      final activeUsersResponse = await PocketBaseService.client.collection('users').getList(
        page: 1,
        perPage: 1,
        filter: 'last_seen >= "$fifteenMinsAgoStr"',
      );
      final activeUsersCount = activeUsersResponse.totalItems;

      // 2. Total Users
      final totalUsersResponse = await PocketBaseService.client.collection('users').getList(
        page: 1,
        perPage: 1,
      );
      final totalUsersCount = totalUsersResponse.totalItems;

      // 3. Recent Blog Posts (last 15 mins)
      final postsResponse = await PocketBaseService.client.collection('posts').getList(
        page: 1,
        perPage: 1,
        filter: 'created >= "$fifteenMinsAgoStr"',
      );
      final recentPostsCount = postsResponse.totalItems;

      // 4. Total Servers
      final serversResponse = await PocketBaseService.client.collection('chat_servers').getList(
        page: 1,
        perPage: 1,
      );
      final totalServersCount = serversResponse.totalItems;

      return {
        'activeUsers': activeUsersCount,
        'totalUsers': totalUsersCount,
        'recentPosts': recentPostsCount,
        'totalServers': totalServersCount,
      };
    } catch (e) {
      AppLogger.instance.error('Admin istatistikleri alınamadı: $e');
      return {
        'activeUsers': 0,
        'totalUsers': 0,
        'recentPosts': 0,
        'totalServers': 0,
      };
    }
  }

  Future<List<RecordModel>> getAllUsers() async {
    try {
      return await PocketBaseService.client.collection('users').getFullList(
        sort: '-created',
      );
    } catch (e) {
      AppLogger.instance.error('Kullanıcı listesi alınamadı: $e');
      return [];
    }
  }

  Future<List<RecordModel>> getAllServers() async {
    try {
      return await PocketBaseService.client.collection('chat_servers').getFullList(
        sort: '-created',
      );
    } catch (e) {
      AppLogger.instance.error('Sunucu listesi alınamadı: $e');
      return [];
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
