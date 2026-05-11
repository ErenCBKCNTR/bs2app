import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'languages/language.dart';
import 'languages/en_us.dart';
import 'languages/tr_tr.dart';

final localizationProvider = StateNotifierProvider<LocalizationNotifier, BaseLanguage>((ref) {
  return LocalizationNotifier();
});

class LocalizationNotifier extends StateNotifier<BaseLanguage> {
  LocalizationNotifier() : super(LanguageTr()) {
    _loadLanguage();
  }

  static const String _languageKey = 'selected_language';

  Future<void> _loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final langCode = prefs.getString(_languageKey);
    if (langCode == 'en') {
      state = LanguageEn();
    } else {
      state = LanguageTr();
    }
  }

  Future<void> setLanguage(String langCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, langCode);
    if (langCode == 'en') {
      state = LanguageEn();
    } else {
      state = LanguageTr();
    }
  }

  String get languageCode => state is LanguageEn ? 'en' : 'tr';
}
