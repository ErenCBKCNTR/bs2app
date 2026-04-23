import 'package:flutter/foundation.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:blind_social/core/services/security_service.dart';

class PocketBaseService {
  static PocketBase client = PocketBase('https://api.cabukcan.com');
  static const _secureStorage = FlutterSecureStorage();
  static const _authKey = 'pb_auth_secure';

  static Future<void> init() async {
    try {
      // 1. Cihaz güvenliği kontrolü
      final isSecure = await SecurityService().isDeviceSecure();
      if (!isSecure) {
        // Güvenli olmayan cihazlarda oturumu temizleyebilir veya kritik verileri silebiliriz.
        // Şimdilik sadece uyarı veriyoruz, ancak üretimde uygulamayı durdurmak daha iyidir.
        debugPrint("UYARI: Cihaz güvenliği düşük tespit edildi.");
      }

      // 2. Güvenli AuthStore başlatma
      final authStore = AsyncAuthStore(
        save: (String data) async => await _secureStorage.write(key: _authKey, value: data),
        initial: await _secureStorage.read(key: _authKey),
        clear: () async => await _secureStorage.delete(key: _authKey),
      );

      client = PocketBase('https://api.cabukcan.com', authStore: authStore);
    } catch (e) {
      debugPrint("PocketBase initialization failed: $e");
    }
  }
}
