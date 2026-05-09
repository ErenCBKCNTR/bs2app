import 'package:blind_social/core/services/notification_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:blind_social/core/utils/performance_monitor.dart';
import '../../../../core/utils/logger.dart';

class DeveloperLogsScreen extends StatefulWidget {
  const DeveloperLogsScreen({super.key});

  @override
  State<DeveloperLogsScreen> createState() => _DeveloperLogsScreenState();
}

class _DeveloperLogsScreenState extends State<DeveloperLogsScreen> {
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    // Ekranda açıkken değerlerin güncellenmesi için saniyede bir ekranı yeniler.
    _refreshTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Geliştirici Günlükleri'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_active_outlined),
            tooltip: 'Test Bildirimi Gönder',
            onPressed: () async {
              try {
                // Yerel bildirim testi
                await NotificationService().showCallNotification(
                  "Test Çağrısı", 
                  "Bu bir geliştirici test bildirimidir.", 
                  "test_id"
                );
                
                final token = await FirebaseMessaging.instance.getToken();
                AppLogger.instance.info("FCM Token: $token");
                
                if (context.mounted) {
                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                     content: Text("Test bildirimi gönderildi ve FCM Token loglara kaydedildi."),
                   ));
                }
              } catch (e) {
                AppLogger.instance.error("Test bildirimi hatası: $e");
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            tooltip: 'Logları Temizle',
            onPressed: () {
              AppLogger.instance.clear();
            },
          )
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Theme.of(context).colorScheme.surfaceVariant,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Performans Göstergesi',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  'En Yüksek RAM Kullanımı: ${PerformanceMonitor.maxRamUsedMB.toStringAsFixed(1)} MB',
                  style: const TextStyle(fontSize: 13),
                ),
                Text(
                  'Toplam İşlemci (CPU) Takılma (Jank) Oranı: ${PerformanceMonitor.cpuJankCount}',
                  style: const TextStyle(fontSize: 13),
                ),
                if (PerformanceMonitor.janksPerRoute.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Text('Sayfa Bazlı Jank Detayı:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ...PerformanceMonitor.janksPerRoute.entries.map(
                    (e) => Text('- ${e.key}: ${e.value} kez', style: const TextStyle(fontSize: 12))
                  ).toList(),
                ],
              ],
            ),
          ),
          Expanded(
            child: ListenableBuilder(
              listenable: AppLogger.instance,
              builder: (context, child) {
                final logs = AppLogger.instance.logs.reversed.toList(); // En yeniler en üstte

                if (logs.isEmpty) {
                   return const Center(child: Text("Günlük boş."));
                }

                return ListView.builder(
                  addAutomaticKeepAlives: false,
                  addRepaintBoundaries: true,
                  itemCount: logs.length,
                  itemBuilder: (context, index) {
                    final log = logs[index];
                    final timeStr = DateFormat('HH:mm:ss').format(log.timestamp);
                    
                    Color textColor = Colors.white;
                    IconData iconData = Icons.info_outline;
                    
                    if (log.level == LogLevel.error) {
                      textColor = Colors.redAccent;
                      iconData = Icons.error_outline;
                    } else if (log.level == LogLevel.warning) {
                      textColor = Colors.orangeAccent;
                      iconData = Icons.warning_amber_outlined;
                    }

                    return InkWell(
                      onLongPress: () {
                        Clipboard.setData(ClipboardData(text: log.message));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Hata kaydı panoya kopyalandı')),
                        );
                      },
                      onTap: log.details != null ? () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Günlük Detayı', style: TextStyle(fontSize: 16)),
                            content: SingleChildScrollView(
                               child: SelectableText(log.details!, style: const TextStyle(fontSize: 13, fontFamily: 'monospace')),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Kapat'),
                              ),
                              TextButton(
                                onPressed: () {
                                   Clipboard.setData(ClipboardData(text: "${log.message}\n\n${log.details}"));
                                   ScaffoldMessenger.of(context).showSnackBar(
                                     const SnackBar(content: Text('Detaylar panoya kopyalandı')),
                                   );
                                   Navigator.pop(context);
                                },
                                child: const Text('Kopyala'),
                              )
                            ],
                          ),
                        );
                      } : null,
                      child: ListTile(
                        leading: Icon(iconData, color: textColor, size: 20),
                        title: Text(log.message, style: TextStyle(color: textColor, fontSize: 13)),
                        subtitle: Text(timeStr, style: const TextStyle(color: Colors.grey, fontSize: 10)),
                        trailing: log.details != null ? const Icon(Icons.info_outline, size: 16, color: Colors.blueAccent) : null,
                        dense: true,
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
