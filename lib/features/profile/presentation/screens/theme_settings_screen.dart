import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/theme_provider.dart';

class ThemeSettingsScreen extends ConsumerWidget {
  const ThemeSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tema Ayarları'),
      ),
      body: ListView(
        children: [
          RadioListTile<ThemeMode>(
            title: const Text('Sistem Teması'),
            subtitle: const Text('Cihaz ayarlarına göre değişir'),
            value: ThemeMode.system,
            groupValue: themeMode,
            onChanged: (mode) {
              if (mode != null) {
                ref.read(themeProvider.notifier).setTheme(mode);
              }
            },
          ),
          RadioListTile<ThemeMode>(
            title: const Text('Açık Tema'),
            value: ThemeMode.light,
            groupValue: themeMode,
            onChanged: (mode) {
              if (mode != null) {
                ref.read(themeProvider.notifier).setTheme(mode);
              }
            },
          ),
          RadioListTile<ThemeMode>(
            title: const Text('Koyu Tema'),
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
