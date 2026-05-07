import 'package:flutter/material.dart';
import 'package:blind_social/features/admin/data/services/admin_service.dart';
import 'package:blind_social/core/utils/logger.dart';
import 'package:blind_social/core/utils/snackbar_utils.dart';

class ErrorHandler {
  /// Standart hata gösterici ve kaydedici servis.
  /// 
  /// 1. Hatayı uygulamanın AppLogger sistemine kaydeder (böylece Geri Bildirim sayfasında detaylı log gider).
  /// 2. Yönetici (Admin) kullanıcılara hatanın detaylarını ekranda panoya kopyalanabilir şekilde gösterir.
  /// 3. Standart kullanıcılara sadece "Lütfen tekrar deneyiniz" uyarısı gösterir.
  static void handleError(BuildContext context, dynamic error, [StackTrace? stackTrace]) {
    final String errorMsg = error.toString();
    
    // 1. Hatayı arka planda günlüklere (Logs) kaydet, böylelikle feedback atarken bunlar da gider.
    AppLogger.instance.error(errorMsg);

    if (!context.mounted) return;

    // 2. Kullanıcı yetki kontrolü
    final isAdmin = AdminService().isAdmin();

    // 3. Ekranda gösterilecek mesaj
    final displayMessage = isAdmin ? errorMsg : 'Lütfen tekrar deneyiniz.';

    // 4. SnackBar ile göster (Yöneticiler veya normal kullanıcılar, fakat panoya her zaman detaylı hata kopyalanabilir)
    SnackbarUtils.showCopyableSnackbar(
      context, 
      displayMessage, 
      fullMessage: errorMsg,
      isError: true,
    );
  }
}
