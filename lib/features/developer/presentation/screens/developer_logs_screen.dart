import 'package:blind_social/core/services/notification_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/utils/logger.dart';

class DeveloperLogsScreen extends StatelessWidget {
  const DeveloperLogsScreen({super.key});

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
      body: ListenableBuilder(
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

              return ListTile(
                leading: Icon(iconData, color: textColor, size: 20),
                title: Text(log.message, style: TextStyle(color: textColor, fontSize: 13)),
                subtitle: Text(timeStr, style: const TextStyle(color: Colors.grey, fontSize: 10)),
                dense: true,
              );
            },
          );
        },
      ),
    );
  }
}
