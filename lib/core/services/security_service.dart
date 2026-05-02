import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:safe_device/safe_device.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';
import 'package:blind_social/core/utils/logger.dart';

class SecurityService {
  static final SecurityService _instance = SecurityService._internal();
  factory SecurityService() => _instance;
  SecurityService._internal();

  static const _channel = MethodChannel('com.example.blind_social/lockscreen');

  /// Uygulamanın güvenli bir cihazda çalışıp çalışmadığını kontrol eder.
  Future<bool> isDeviceSecure() async {
    try {
      bool isJailBroken = await SafeDevice.isJailBroken;
      bool isRealDevice = await SafeDevice.isRealDevice;
      bool isSafeDevice = await SafeDevice.isSafeDevice;
      
      if (isJailBroken) {
        AppLogger.instance.error('Güvenlik İhlali: Cihaz rootlu/jailbreakli tespit edildi.');
        return false;
      }

      if (!isSafeDevice && isRealDevice) {
        AppLogger.instance.error('Güvenlik İhlali: Cihaz güvenli olmayan bir ortamda çalışıyor.');
        return false;
      }

      return true;
    } catch (e) {
      AppLogger.instance.error('Güvenlik kontrolü sırasında hata: $e');
      return false;
    }
  }

  /// Ekran görüntüsü alınmasını ve ekran kaydı yapılmasını engeller (Sadece Android).
  /// iOS tarafında sistem düzeyinde kısıtlama gerektiğinden genellikle sadece bilgi verilir.
  Future<void> protectScreen() async {
    try {
      if (!kIsWeb && Platform.isAndroid) {
        await _channel.invokeMethod('toggleScreenProtection', {'enabled': true});
        AppLogger.instance.info('Ekran koruması aktif edildi (Screenshot protection).');
      }
    } catch (e) {
      AppLogger.instance.error('Ekran koruması başlatılırken hata: $e');
    }
  }

  /// Cihaz hakkında benzersiz olmayan ancak ayırt edici bilgiler döndürür.
  Future<Map<String, String>> getDeviceMetadata() async {
    final deviceInfo = DeviceInfoPlugin();
    if (kIsWeb) {
      return {
        'x-device-id': 'web',
        'x-device-model': 'web browser',
        'x-device-os': 'Web',
      };
    } else if (!kIsWeb && Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      return {
        'x-device-id': androidInfo.id,
        'x-device-model': androidInfo.model,
        'x-device-os': 'Android ${androidInfo.version.release}',
      };
    } else if (!kIsWeb && Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      return {
        'x-device-id': iosInfo.identifierForVendor ?? 'unknown',
        'x-device-model': iosInfo.utsname.machine,
        'x-device-os': 'iOS ${iosInfo.systemVersion}',
      };
    }
    return {};
  }
}
