import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/settings_service.dart';
import '../../../../core/services/pocketbase_service.dart';
import '../../../../core/providers/localization_provider.dart';

class PrivacySettingsScreen extends ConsumerStatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  ConsumerState<PrivacySettingsScreen> createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends ConsumerState<PrivacySettingsScreen> {
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
    final lang = ref.watch(localizationProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(lang.privacy),
      ),
      body: _isLoadingPbSettings 
        ? const Center(child: CircularProgressIndicator()) 
        : ListView(
        children: [
          SwitchListTile(
            secondary: const Icon(Icons.security),
            title: Text(lang.screenProtection),
            subtitle: Text(lang.screenProtectionSubtitle),
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
            title: Text(lang.showOnLockScreen),
            subtitle: Text(lang.showOnLockScreenSubtitle),
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
            title: Text(lang.fullnamePrivacy),
            subtitle: Text(lang.whoCanSeeThis),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Semantics(
              label: lang.fullnamePrivacySemantics,
              child: SegmentedButton<String>(
                segments: [
                  ButtonSegment(value: 'everyone', label: Text(lang.everyone), icon: const Icon(Icons.public)),
                  ButtonSegment(value: 'friends', label: Text(lang.friends), icon: const Icon(Icons.people)),
                  ButtonSegment(value: 'none', label: Text(lang.nobody), icon: const Icon(Icons.lock)),
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
            title: Text(lang.lastSeen),
            subtitle: Text(lang.lastSeenSubtitle),
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
            title: Text(lang.birthday),
            subtitle: Text(lang.whoCanSeeThis),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Semantics(
              label: lang.birthdayPrivacySemantics,
              child: SegmentedButton<String>(
                segments: [
                  ButtonSegment(value: 'everyone', label: Text(lang.everyone), icon: const Icon(Icons.public)),
                  ButtonSegment(value: 'friends', label: Text(lang.friends), icon: const Icon(Icons.people)),
                  ButtonSegment(value: 'none', label: Text(lang.nobody), icon: const Icon(Icons.lock)),
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
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              lang.privacyFooter,
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
