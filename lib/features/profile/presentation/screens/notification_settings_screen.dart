import 'package:flutter/material.dart';
import 'package:blind_social/core/services/settings_service.dart';
import 'package:vibration/vibration.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/localization_provider.dart';

class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  ConsumerState<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends ConsumerState<NotificationSettingsScreen> {
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
    final lang = ref.watch(localizationProvider);
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(lang.notifications)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(lang.notifications),
      ),
      body: ListView(
        children: [
          _buildSectionHeader(lang.messageNotifications),
          SwitchListTile(
            secondary: const Icon(Icons.volume_up),
            title: Text(lang.sound),
            subtitle: Text(lang.messageSoundSubtitle),
            value: _settingsService.messageSoundEnabled,
            onChanged: (val) async {
              await _settingsService.setMessageSoundEnabled(val);
              setState(() {});
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.vibration),
            title: Text(lang.vibration),
            subtitle: Text(lang.messageVibrationSubtitle),
            value: _settingsService.messageVibrationEnabled,
            onChanged: (val) async {
              await _settingsService.setMessageVibrationEnabled(val);
              if (val) _testVibration();
              setState(() {});
            },
          ),
          const Divider(),
          _buildSectionHeader(lang.callNotifications),
          SwitchListTile(
            secondary: const Icon(Icons.ring_volume),
            title: Text(lang.ringtone),
            subtitle: Text(lang.callSoundSubtitle),
            value: _settingsService.callSoundEnabled,
            onChanged: (val) async {
              await _settingsService.setCallSoundEnabled(val);
              setState(() {});
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.vibration),
            title: Text(lang.vibration),
            subtitle: Text(lang.callVibrationSubtitle),
            value: _settingsService.callVibrationEnabled,
            onChanged: (val) async {
              await _settingsService.setCallVibrationEnabled(val);
              if (val) _testVibration();
              setState(() {});
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
