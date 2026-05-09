import 'package:flutter/scheduler.dart';
import 'package:blind_social/core/utils/logger.dart';
import 'package:blind_social/core/utils/route_observer.dart';
import 'dart:io';
import 'dart:async';

class PerformanceMonitor {
  static bool _initialized = false;
  static int _droppedFrames = 0;
  static int _lastWarningMs = DateTime.now().millisecondsSinceEpoch;
  
  static double maxRamUsedMB = 0.0;
  static int cpuJankCount = 0; // CPU performans göstergesi olarak jank (dropped frames) kullanılıyor
  static Timer? _resourceTimer;

  static void init() {
    if (_initialized) return;
    _initialized = true;

    // RAM takibi (10 saniyede bir ölçülerek, en yüksek değeri kaydeder)
    _resourceTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      try {
        final rssBytes = ProcessInfo.currentRss;
        final ramMB = rssBytes / (1024 * 1024);
        if (ramMB > maxRamUsedMB) {
          maxRamUsedMB = ramMB;
        }
      } catch (_) {}
    });

    SchedulerBinding.instance.addTimingsCallback((List<FrameTiming> timings) {
      for (final timing in timings) {
        // Normalde 16ms'de bir kare çizilmesi gerekir (60 FPS için).
        // 50ms ve üzeri süreler, fark edilebilir takılmalar (jank) yaratır.
        if (timing.totalSpan.inMilliseconds > 50) {
          _droppedFrames++;
          cpuJankCount++;
        }
      }
      
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - _lastWarningMs > 10000) {
        if (_droppedFrames > 10) {
          final String currentRoute = GlobalRouteObserver.currentRoute;
          AppLogger.instance.warning(
             'Arayüz Takılma Uyarısı (UI Jank) [$currentRoute]', 
             details: 'Sayfa: $currentRoute\nSon 10 saniyede $_droppedFrames kez ekran çiziminde gecikme (50ms+) yaşandı. Uygulamayı yoran iç içe ListView, ağır animasyonlar veya gereksiz Widget yeniden oluşturulmaları (rebuilds) olabilir.'
          );
        }
        _droppedFrames = 0;
        _lastWarningMs = now;
      }
    });
  }
}
