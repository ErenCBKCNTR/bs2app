import 'package:flutter/foundation.dart';
import 'package:safe_device/safe_device.dart';
import 'package:flutter_windowmanager/flutter_windowmanager.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';
import 'package:blind_social/core/utils/logger.dart';

class SecurityService {
  static final SecurityService _instance = SecurityService._internal();
  factory SecurityService() => _instance;
  SecurityService._internal();

  /// Uygulamanın güvenli bir cihazda çalışıp çalışmadığını kontrol eder.
  Future<bool> isDeviceSecure() async {
    try {
      bool isJailBroken = await SafeDevice.isJailBroken;
      bool isRealDevice = await SafeDevice.isRealDevice;
      bool isSafeDevice = await SafeDevice.isSafeDevice;
      bool isDevelopmentMode = await SafeDevice.isDevelopmentMode;
      bool isDebuggerAttached = await SafeDevice.isDebuggerAttached;
      
      if (isJailBroken) {
        AppLogger.instance.error('Güvenlik İhlali: Cihaz rootlu/jailbreakli tespit edildi.');
        return false;
      }

      if (isDebuggerAttached && !kDebugMode) {
        AppLogger.instance.error('Güvenlik İhlali: Hata ayıklayıcı (Debugger) tespit edildi.');
        return false;
      }

      if (!isSafeDevice && !isDevelopmentMode) {
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
    if (Platform.isAndroid) {
      await FlutterWindowManager.addFlags(FlutterWindowManager.FLAG_SECURE);
      AppLogger.instance.info('Ekran koruması aktif edildi (Screenshot protection).');
    }
  }

  /// Cihaz hakkında benzersiz olmayan ancak ayırt edici bilgiler döndürür.
  Future<Map<String, String>> getDeviceMetadata() async {
    final deviceInfo = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      return {
        'x-device-id': androidInfo.id,
        'x-device-model': androidInfo.model,
        'x-device-os': 'Android ${androidInfo.version.release}',
      };
    } else if (Platform.isIOS) {
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
