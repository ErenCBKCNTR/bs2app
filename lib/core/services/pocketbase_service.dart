import 'package:flutter/foundation.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:blind_social/core/services/security_service.dart';
import 'package:blind_social/core/network/custom_http_client.dart';

class PocketBaseService {
  static PocketBase client = PocketBase('https://api.cabukcan.com', httpClientFactory: () => CustomHttpClient());
  static const _secureStorage = FlutterSecureStorage();
  static const _authKey = 'pb_auth_secure';

  static Future<void> init() async {
    const androidOptions = AndroidOptions();
    try {
      // 1. Cihaz güvenliği kontrolü
      final isSecure = await SecurityService().isDeviceSecure();
      if (!isSecure) {
        debugPrint("UYARI: Cihaz güvenliği düşük tespit edildi.");
      }

      String? initialAuth;
      try {
        initialAuth = await _secureStorage.read(key: _authKey, aOptions: androidOptions);
      } catch (e) {
        debugPrint("Secure storage okuma hatasi, sifirlaniyor: $e");
        await _secureStorage.delete(key: _authKey, aOptions: androidOptions);
      }

      // 2. Güvenli AuthStore başlatma
      final authStore = AsyncAuthStore(
        save: (String data) async {
          try {
            await _secureStorage.write(key: _authKey, value: data, aOptions: androidOptions);
          } catch (e) {
            debugPrint("Secure storage yazma hatasi: $e");
          }
        },
        initial: initialAuth,
        clear: () async {
          try {
            await _secureStorage.delete(key: _authKey, aOptions: androidOptions);
          } catch (e) {
            debugPrint("Secure storage silme hatasi: $e");
          }
        },
      );

      client = PocketBase(
        'https://api.cabukcan.com', 
        authStore: authStore,
        httpClientFactory: () => CustomHttpClient(),
      );
    } catch (e) {
      debugPrint("PocketBase initialization failed: $e");
    }
  }
}
