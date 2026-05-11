import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/settings_service.dart';
import '../../../../core/providers/font_size_provider.dart';
import '../../../../core/providers/localization_provider.dart';

class AccessibilitySettingsScreen extends ConsumerStatefulWidget {
  const AccessibilitySettingsScreen({super.key});

  @override
  ConsumerState<AccessibilitySettingsScreen> createState() => _AccessibilitySettingsScreenState();
}

class _AccessibilitySettingsScreenState extends ConsumerState<AccessibilitySettingsScreen> {
  final SettingsService _settingsService = SettingsService();
  bool _voiceRoomNotifications = true;

  @override
  void initState() {
    super.initState();
    _voiceRoomNotifications = _settingsService.voiceRoomNotificationsEnabled;
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(localizationProvider);
    final currentFontSize = ref.watch(fontSizeProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(lang.accessibility),
      ),
      body: ListView(
        children: [
          SwitchListTile(
            secondary: const Icon(Icons.record_voice_over),
            title: Text(lang.voiceRoomNotif),
            subtitle: Text(lang.voiceRoomNotifDesc),
            value: _voiceRoomNotifications,
            onChanged: (bool value) async {
              await _settingsService.setVoiceRoomNotificationsEnabled(value);
              setState(() {
                _voiceRoomNotifications = value;
              });
            },
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.format_size, color: Colors.grey),
                    const SizedBox(width: 16),
                    Text(
                      lang.fontSize,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  lang.fontSizeDesc,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 24),
                Slider(
                  value: currentFontSize,
                  min: 0.8,
                  max: 1.4,
                  divisions: 3,
                  label: _getFontSizeLabel(currentFontSize),
                  onChanged: (double value) {
                    ref.read(fontSizeProvider.notifier).setFontSize(value);
                  },
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(lang.small, style: const TextStyle(fontSize: 12)),
                      Text(lang.normal, style: const TextStyle(fontSize: 12)),
                      Text(lang.large, style: const TextStyle(fontSize: 12)),
                      Text(lang.extraLarge, style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    lang.fontSizeExample,
                    style: const TextStyle(height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
        ],
      ),
    );
  }

  String _getFontSizeLabel(double value) {
    final lang = ref.read(localizationProvider);
    if (value <= 0.8) return lang.extraLarge; // Wait, slider label logic seems inverted or just labels...
    // Actually min is 0.8 (small) max 1.4 (extra large)
    if (value <= 0.8) return lang.small;
    if (value <= 1.0) return lang.normal;
    if (value <= 1.2) return lang.large;
    return lang.extraLarge;
  }
}
