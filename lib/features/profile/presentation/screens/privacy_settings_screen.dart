import 'package:flutter/material.dart';
import '../../../../core/services/settings_service.dart';
import '../../../../core/services/pocketbase_service.dart';

class PrivacySettingsScreen extends StatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  State<PrivacySettingsScreen> createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends State<PrivacySettingsScreen> {
  final SettingsService _settingsService = SettingsService();
  bool _showOnLockScreen = false;
  bool _screenProtection = true;
  bool _hideLastSeen = false;
  bool _hideBirthday = false;
  bool _isLoadingPbSettings = true;

  @override
  void initState() {
    super.initState();
    _showOnLockScreen = _settingsService.showOnLockScreenEnabled;
    _screenProtection = _settingsService.screenProtectionEnabled;
    _fetchPocketBaseSettings();
  }

  Future<void> _fetchPocketBaseSettings() async {
    try {
      final userId = PocketBaseService.client.authStore.model?.id;
      if (userId != null) {
        final record = await PocketBaseService.client.collection('users').getOne(userId);
        if (mounted) {
          setState(() {
            _hideLastSeen = record.getBoolValue('hide_last_seen');
            _hideBirthday = record.getBoolValue('hide_birthday');
            _isLoadingPbSettings = false;
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingPbSettings = false;
        });
      }
    }
  }

  Future<void> _updatePocketBaseSetting(String key, bool value) async {
    try {
      final userId = PocketBaseService.client.authStore.model?.id;
      if (userId != null) {
        await PocketBaseService.client.collection('users').update(userId, body: {
          key: value,
        });
      }
    } catch (_) {
      // Revert if error? We are updating Optimistically
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gizlilik Ayarları'),
      ),
      body: _isLoadingPbSettings 
        ? const Center(child: CircularProgressIndicator()) 
        : ListView(
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
          SwitchListTile(
            secondary: const Icon(Icons.visibility),
            title: const Text('Son Görülme Bilgisi'),
            subtitle: const Text('Diğer kullanıcıların son görülme zamanınızı görmesine izin verin'),
            value: !_hideLastSeen,
            onChanged: (bool value) {
              setState(() {
                _hideLastSeen = !value;
              });
              _updatePocketBaseSetting('hide_last_seen', !value);
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.cake),
            title: const Text('Doğum Tarihi'),
            subtitle: const Text('Doğum tarihinizin kimler tarafından görünebileceğini seçin'),
            trailing: DropdownButton<bool>(
              value: !_hideBirthday,
              underline: const SizedBox(),
              items: const [
                DropdownMenuItem(
                  value: true,
                  child: Text('Herkes'),
                ),
                DropdownMenuItem(
                  value: false,
                  child: Text('Hiç Kimse'),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _hideBirthday = !value;
                  });
                  _updatePocketBaseSetting('hide_birthday', !value);
                }
              },
            ),
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
