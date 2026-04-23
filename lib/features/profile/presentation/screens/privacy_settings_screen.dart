import 'package:flutter/material.dart';
import '../../../../core/services/settings_service.dart';

class PrivacySettingsScreen extends StatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  State<PrivacySettingsScreen> createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends State<PrivacySettingsScreen> {
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
        title: const Text('Gizlilik Ayarları'),
      ),
      body: ListView(
        children: [
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
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Gizlilik ayarları uygulama güvenliğinizi ve kişisel verilerinizin korunmasını sağlar.',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
