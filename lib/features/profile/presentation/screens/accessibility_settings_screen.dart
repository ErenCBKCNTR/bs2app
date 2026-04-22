import 'package:flutter/material.dart';
import '../../../../core/services/settings_service.dart';

class AccessibilitySettingsScreen extends StatefulWidget {
  const AccessibilitySettingsScreen({super.key});

  @override
  State<AccessibilitySettingsScreen> createState() => _AccessibilitySettingsScreenState();
}

class _AccessibilitySettingsScreenState extends State<AccessibilitySettingsScreen> {
  final SettingsService _settingsService = SettingsService();
  bool _voiceRoomNotifications = true;

  @override
  void initState() {
    super.initState();
    _voiceRoomNotifications = _settingsService.voiceRoomNotificationsEnabled;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Erişilebilirlik Ayarları'),
      ),
      body: ListView(
        children: [
          SwitchListTile(
            secondary: const Icon(Icons.record_voice_over),
            title: const Text('Sesli Oda Bildirimleri'),
            subtitle: const Text('Odadaki giriş çıkış yapan kullanıcıları sesli bildir'),
            value: _voiceRoomNotifications,
            onChanged: (bool value) async {
              await _settingsService.setVoiceRoomNotificationsEnabled(value);
              setState(() {
                _voiceRoomNotifications = value;
              });
            },
          ),
          const Divider(),
        ],
      ),
    );
  }
}
