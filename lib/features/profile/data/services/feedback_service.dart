import 'package:blind_social/core/services/pocketbase_service.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:blind_social/core/utils/logger.dart';

class FeedbackService {
  Future<void> sendFeedback({
    required String category,
    required String subject,
    required String message,
    String? logs,
  }) async {
    final userId = PocketBaseService.client.authStore.model?.id;
    if (userId == null) throw Exception('Kullanıcı oturumu bulunamadı.');

    await PocketBaseService.client.collection('feedback').create(body: {
      'user_id': userId,
      'category': category,
      'subject': subject,
      'message': message,
      'logs': logs ?? '',
    });
  }

  Future<List<RecordModel>> getAllFeedback() async {
    return await PocketBaseService.client.collection('feedback').getFullList(
      expand: 'user_id',
      sort: '-created',
    );
  }
}
