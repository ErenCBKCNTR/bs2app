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
