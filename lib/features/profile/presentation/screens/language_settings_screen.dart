import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/localization_provider.dart';

class LanguageSettingsScreen extends ConsumerWidget {
  const LanguageSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(localizationProvider);
    final notifier = ref.read(localizationProvider.notifier);
    final currentCode = notifier.currentLanguageCode;

    return Scaffold(
      appBar: AppBar(
        title: Text(lang.language),
      ),
      body: ListView(
        children: [
          _buildLanguageItem(
            context,
            ref,
            'Türkçe',
            'tr',
            '🇹🇷',
            currentCode == 'tr',
          ),
          const Divider(),
          _buildLanguageItem(
            context,
            ref,
            'English',
            'en',
            '🇺🇸',
            currentCode == 'en',
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageItem(
    BuildContext context,
    WidgetRef ref,
    String name,
    String code,
    String flag,
    bool isSelected,
  ) {
    return ListTile(
      leading: Text(flag, style: const TextStyle(fontSize: 24)),
      title: Text(name),
      trailing: isSelected ? Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary) : null,
      onTap: () {
        ref.read(localizationProvider.notifier).setLanguage(code);
      },
    );
  }
}
