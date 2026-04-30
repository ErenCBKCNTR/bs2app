import 'package:flutter/material.dart';
import '../../../../core/services/settings_service.dart';
import 'theme_settings_screen.dart';
import 'notification_settings_screen.dart';
import 'accessibility_settings_screen.dart';
import 'privacy_settings_screen.dart';
import 'changelog_screen.dart';
import 'feedback_screen.dart';
import '../../../../features/admin/data/services/admin_service.dart';

class AppSettingsScreen extends StatefulWidget {
  const AppSettingsScreen({super.key});

  @override
  State<AppSettingsScreen> createState() => _AppSettingsScreenState();
}

class _AppSettingsScreenState extends State<AppSettingsScreen> {
  final SettingsService _settingsService = SettingsService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Uygulama Ayarları'),
      ),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.brightness_6),
            title: const Text('Tema Ayarları'),
            subtitle: const Text('Açık, koyu veya sistem teması seçin'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ThemeSettingsScreen()),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.notifications_active),
            title: const Text('Bildirim Ayarları'),
            subtitle: const Text('Ses ve titreşim ayarlarını yönetin'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificationSettingsScreen()),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.accessibility),
            title: const Text('Erişilebilirlik Ayarları'),
            subtitle: const Text('Ekran okuyucu ve yardım özellikleri'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AccessibilitySettingsScreen()),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.security),
            title: const Text('Gizlilik Ayarları'),
            subtitle: const Text('Ekran koruma ve kilit ekranı seçenekleri'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PrivacySettingsScreen()),
              );
            },
          ),
          if (AdminService().isAdmin()) ...[
            const Divider(),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('Sürüm Bilgisi'),
              subtitle: const Text('v1.7.5 - Neler yeni?'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ChangelogScreen()),
                );
              },
            ),
          ],
          const Divider(),
          ListTile(
            leading: const Icon(Icons.feedback_outlined),
            title: const Text('İstek, Öneri ve Şikayet Bildirimi'),
            subtitle: const Text('Görüşlerinizi bizimle paylaşın'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FeedbackScreen()),
              );
            },
          ),
          const SizedBox(height: 16),
          const Center(
            child: Text(
              'Blind Social © 2026',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
