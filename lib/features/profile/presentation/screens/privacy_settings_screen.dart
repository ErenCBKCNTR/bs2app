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
  String _birthdayPrivacy = 'everyone';
  String _fullnamePrivacy = 'everyone';
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
            
            // Handle legacy bool or new select values
            if (record.data.containsKey('birthday_privacy')) {
              _birthdayPrivacy = record.getStringValue('birthday_privacy');
              if (_birthdayPrivacy.isEmpty) _birthdayPrivacy = 'everyone';
            } else {
              _birthdayPrivacy = record.getBoolValue('hide_birthday') ? 'none' : 'everyone';
            }

            if (record.data.containsKey('fullname_privacy')) {
              _fullnamePrivacy = record.getStringValue('fullname_privacy');
              if (_fullnamePrivacy.isEmpty) _fullnamePrivacy = 'everyone';
            } else {
              _fullnamePrivacy = record.getBoolValue('hide_full_name') ? 'none' : 'everyone';
            }
            
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

  Future<void> _updatePocketBaseSetting(String key, dynamic value) async {
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
          ListTile(
            leading: const Icon(Icons.badge),
            title: const Text('İsim Soyisim Bilgisi'),
            subtitle: const Text('Bu bilgiyi kimlerin görebileceğini seçin'),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Semantics(
              label: 'İsim soyisim gizlilik ayarı',
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'everyone', label: Text('Herkes'), icon: Icon(Icons.public)),
                  ButtonSegment(value: 'friends', label: Text('Arkadaşlar'), icon: Icon(Icons.people)),
                  ButtonSegment(value: 'none', label: Text('Hiç Kimse'), icon: Icon(Icons.lock)),
                ],
                selected: {_fullnamePrivacy},
                onSelectionChanged: (Set<String> newSelection) {
                  final value = newSelection.first;
                  setState(() {
                    _fullnamePrivacy = value;
                  });
                  _updatePocketBaseSetting('fullname_privacy', value);
                },
              ),
            ),
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
            subtitle: const Text('Bu bilgiyi kimlerin görebileceğini seçin'),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Semantics(
              label: 'Doğum tarihi gizlilik ayarı',
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'everyone', label: Text('Herkes'), icon: Icon(Icons.public)),
                  ButtonSegment(value: 'friends', label: Text('Arkadaşlar'), icon: Icon(Icons.people)),
                  ButtonSegment(value: 'none', label: Text('Hiç Kimse'), icon: Icon(Icons.lock)),
                ],
                selected: {_birthdayPrivacy},
                onSelectionChanged: (Set<String> newSelection) {
                  final value = newSelection.first;
                  setState(() {
                    _birthdayPrivacy = value;
                  });
                  _updatePocketBaseSetting('birthday_privacy', value);
                },
              ),
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
