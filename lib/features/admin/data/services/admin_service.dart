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
      
      // Get role from expanded data or direct data
      final roleValue = user.data['role'];
      
      // PocketBase may return id as double or int depending on JSON parser. 
      // Safe check for both '0' string and 0 number.
      if (roleValue != null && (roleValue.toString() == '0' || roleValue.toString() == '0.0')) {
        return true;
      }
    } catch (e) {
      AppLogger.instance.error('isAdmin check error: $e');
    }
    
    return false;
  }
  
  /// Auto-promote developer to Admin and refresh token if needed
  Future<void> checkAndFixAdminRole() async {
    try {
      final user = PocketBaseService.client.authStore.model;
      if (user == null) return;
      
      final email = user.getStringValue('email');
      if (email.isEmpty) return;
      
      final String userEmail = email.toLowerCase();
      final bool isDeveloper = userEmail == 'erencs87@gmail.com';
      final dynamic roleValue = user.data['role'];
      
      // If developer but not marked as Admin in data, or just to be safe, update it.
      if (isDeveloper && (roleValue == null || roleValue.toString() != '0')) {
        AppLogger.instance.info('Yetki onarılıyor: $userEmail admin yapılıyor...');
        
        await PocketBaseService.client.collection('users').update(
          user.id,
          body: {'role': 0},
        );
        
        // Refresh token to apply new role to future API requests
        await PocketBaseService.client.collection('users').authRefresh();
        AppLogger.instance.info('Yetki onarıldı ve oturum tazelendi.');
      }
    } catch (e) {
      AppLogger.instance.error('Yetki onarma hatası: $e');
    }
  }

  Future<Map<String, dynamic>> getStats() async {
    try {
      final now = DateTime.now().toUtc();
      final fifteenMinsAgo = now.subtract(const Duration(minutes: 15));
      final fifteenMinsAgoStr = fifteenMinsAgo.toIso8601String().replaceFirst('T', ' ');

      final otherStatsFutures = Future.wait([
        // 1. Recent Blog Posts (last 15 mins)
        PocketBaseService.client.collection('posts').getList(
          page: 1,
          perPage: 1,
          filter: 'created >= "$fifteenMinsAgoStr"',
        ),
        // 2. Total Servers
        PocketBaseService.client.collection('chat_servers').getList(
          page: 1,
          perPage: 1,
        ),
        // 3. Total Feedback
        PocketBaseService.client.collection('feedback').getList(
          page: 1,
          perPage: 1,
        ),
        // 4. Total Sources
        PocketBaseService.client.collection('campaign_sources').getList(
          page: 1,
          perPage: 1,
        ),
      ]);

      // Wait for both independent batches
      final totalUsersResponse = await PocketBaseService.client.collection('users').getList(
        page: 1,
        perPage: 1,
      );
      
      final results = await otherStatsFutures;

      return {
        'totalUsers': totalUsersResponse.totalItems,
        'recentPosts': results[0].totalItems,
        'totalServers': results[1].totalItems,
        'feedbackCount': results[2].totalItems,
        'totalSources': results[3].totalItems,
      };
    } catch (e) {
      AppLogger.instance.error('Admin istatistikleri alınamadı: $e');
      return {
        'totalUsers': 0,
        'recentPosts': 0,
        'totalServers': 0,
        'feedbackCount': 0,
        'totalSources': 0,
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

  Future<void> deleteUserCascade(String userId) async {
    try {
      await PocketBaseService.client.collection('users').delete(userId);
      AppLogger.instance.info('Kullanıcı [$userId] başarıyla silindi.');
    } catch (e) {
      AppLogger.instance.error('Kullanıcı silinemedi: $e');
      rethrow;
    }
  }
}
