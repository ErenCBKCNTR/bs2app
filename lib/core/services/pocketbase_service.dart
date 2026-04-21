import 'package:pocketbase/pocketbase.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PocketBaseService {
  static PocketBase client = PocketBase('https://api.cabukcan.com');

  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final authStore = AsyncAuthStore(
        save: (String data) async => prefs.setString('pb_auth', data),
        initial: prefs.getString('pb_auth'),
        clear: () async => prefs.remove('pb_auth'),
      );

      client = PocketBase('https://api.cabukcan.com', authStore: authStore);
    } catch (e) {
      debugPrint("PocketBase initialization failed, using default client: $e");
      // client default zaten başlatıldı yukarıda
    }
  }
}
