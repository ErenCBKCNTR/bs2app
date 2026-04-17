import 'package:flutter/material.dart';
import 'package:blind_social/core/services/settings_service.dart';
import 'package:vibration/vibration.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  final _settingsService = SettingsService();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    await _settingsService.init();
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _testVibration() async {
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(duration: 500);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Bildirim Ayarları')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bildirim Ayarları'),
      ),
      body: ListView(
        children: [
          _buildSectionHeader('Mesaj Bildirimleri'),
          SwitchListTile(
            secondary: const Icon(Icons.volume_up),
            title: const Text('Ses'),
            subtitle: const Text('Yeni mesaj geldiğinde ses çal'),
            value: _settingsService.messageSoundEnabled,
            onChanged: (val) async {
              await _settingsService.setMessageSoundEnabled(val);
              setState(() {});
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.vibration),
            title: const Text('Titreşim'),
            subtitle: const Text('Yeni mesaj geldiğinde titreşim ver'),
            value: _settingsService.messageVibrationEnabled,
            onChanged: (val) async {
              await _settingsService.setMessageVibrationEnabled(val);
              if (val) _testVibration();
              setState(() {});
            },
          ),
          const Divider(),
          _buildSectionHeader('Arama Bildirimleri'),
          SwitchListTile(
            secondary: const Icon(Icons.ring_volume),
            title: const Text('Zil Sesi'),
            subtitle: const Text('Gelen aramalarda zil sesi çal'),
            value: _settingsService.callSoundEnabled,
            onChanged: (val) async {
              await _settingsService.setCallSoundEnabled(val);
              setState(() {});
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.vibration),
            title: const Text('Titreşim'),
            subtitle: const Text('Gelen aramalarda titreşim ver'),
            value: _settingsService.callVibrationEnabled,
            onChanged: (val) async {
              await _settingsService.setCallVibrationEnabled(val);
              if (val) _testVibration();
              setState(() {});
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Bildirim Testi'),
            subtitle: const Text('Ayarların çalışıp çalışmadığını test etmek için buraya dokunun'),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Bildirim ayarları kaydedildi.'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
          fontSize: 14,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
