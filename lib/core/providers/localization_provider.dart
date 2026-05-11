import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../localization/languages/language.dart';
import '../localization/languages/tr_tr.dart';
import '../localization/languages/en_us.dart';
import '../services/settings_service.dart';

class LocalizationNotifier extends StateNotifier<BaseLanguage> {
  final SettingsService _settingsService = SettingsService();

  LocalizationNotifier() : super(LanguageTr()) {
    _init();
  }

  void _init() {
    final langCode = _settingsService.language;
    state = _getLanguageFromCode(langCode);
  }

  BaseLanguage _getLanguageFromCode(String code) {
    switch (code) {
      case 'en-US':
        return LanguageEn();
      case 'tr-TR':
      default:
        return LanguageTr();
    }
  }

  Future<void> setLanguage(String code) async {
    await _settingsService.setLanguage(code);
    state = _getLanguageFromCode(code);
  }

  String get currentLanguageCode => _settingsService.language;
}

final localizationProvider = StateNotifierProvider<LocalizationNotifier, BaseLanguage>((ref) {
  return LocalizationNotifier();
});

// Extension to easily access translations from context if using ConsumerWidget/StatefulWidget
// But since we use Riverpod, we can just ref.watch(localizationProvider)
