import 'package:flutter/material.dart';
import '../../../../core/services/settings_service.dart';
import 'theme_settings_screen.dart';
import 'notification_settings_screen.dart';
import 'accessibility_settings_screen.dart';

class AppSettingsScreen extends StatefulWidget {
  const AppSettingsScreen({super.key});

  @override
  State<AppSettingsScreen> createState() => _AppSettingsScreenState();
}

class _AppSettingsScreenState extends State<AppSettingsScreen> {
  final SettingsService _settingsService = SettingsService();
  bool _showOnLockScreen = false;

  @override
  void initState() {
    super.initState();
    _showOnLockScreen = _settingsService.showOnLockScreenEnabled;
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
        ],
      ),
    );
  }
}
