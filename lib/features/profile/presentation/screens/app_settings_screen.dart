import 'package:flutter/material.dart';
import '../../../../core/services/settings_service.dart';
import 'theme_settings_screen.dart';
import 'notification_settings_screen.dart';
import 'accessibility_settings_screen.dart';
import 'changelog_screen.dart';

class AppSettingsScreen extends StatefulWidget {
  const AppSettingsScreen({super.key});

  @override
  State<AppSettingsScreen> createState() => _AppSettingsScreenState();
}

class _AppSettingsScreenState extends State<AppSettingsScreen> {
  final SettingsService _settingsService = SettingsService();
  bool _showOnLockScreen = false;
  bool _screenProtection = true;

  @override
  void initState() {
    super.initState();
    _showOnLockScreen = _settingsService.showOnLockScreenEnabled;
    _screenProtection = _settingsService.screenProtectionEnabled;
  }

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
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Text(
              'Gizlilik',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.security),
            title: const Text('Ekran Kaydı Koruması'),
            subtitle: const Text('Uygulama içinde ekran görüntüsü alınmasını ve kaydedilmesini engeller'),
            value: _screenProtection,
            onChanged: (bool value) async {
              await _settingsService.setScreenProtectionEnabled(value);
              setState(() {
                _screenProtection = value;
              });
            },
          ),
          const Divider(),
          SwitchListTile(
            secondary: const Icon(Icons.screen_lock_portrait),
            title: const Text('Kilit Ekranında Göster'),
            subtitle: const Text('Ekran kilitliyken bile uygulama görünür kalır'),
            value: _showOnLockScreen,
            onChanged: (bool value) async {
              await _settingsService.setShowOnLockScreenEnabled(value);
              setState(() {
                _showOnLockScreen = value;
              });
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Sürüm Bilgisi'),
            subtitle: const Text('v1.2.3 - Neler yeni?'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ChangelogScreen()),
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
