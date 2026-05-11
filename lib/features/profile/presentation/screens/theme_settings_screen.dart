import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/theme_provider.dart';
import '../../../../core/providers/localization_provider.dart';

class ThemeSettingsScreen extends ConsumerWidget {
  const ThemeSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);
    final lang = ref.watch(localizationProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(lang.theme),
      ),
      body: ListView(
        children: [
          RadioListTile<ThemeMode>(
            title: Text(lang.systemTheme),
            subtitle: Text(lang.themeDesc),
            value: ThemeMode.system,
            groupValue: themeMode,
            onChanged: (mode) {
              if (mode != null) {
                ref.read(themeProvider.notifier).setTheme(mode);
              }
            },
          ),
          RadioListTile<ThemeMode>(
            title: Text(lang.lightTheme),
            value: ThemeMode.light,
            groupValue: themeMode,
            onChanged: (mode) {
              if (mode != null) {
                ref.read(themeProvider.notifier).setTheme(mode);
              }
            },
          ),
          RadioListTile<ThemeMode>(
            title: Text(lang.darkTheme),
            value: ThemeMode.dark,
            groupValue: themeMode,
            onChanged: (mode) {
              if (mode != null) {
                ref.read(themeProvider.notifier).setTheme(mode);
              }
            },
          ),
        ],
      ),
    );
  }
}
