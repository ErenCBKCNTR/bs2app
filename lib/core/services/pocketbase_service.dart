import 'package:pocketbase/pocketbase.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PocketBaseService {
  static late final PocketBase client;

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    
    final authStore = AsyncAuthStore(
      save: (String data) async => prefs.setString('pb_auth', data),
      initial: prefs.getString('pb_auth'),
      clear: () async => prefs.remove('pb_auth'),
    );

    client = PocketBase('https://api.cabukcan.com', authStore: authStore);
  }
}
