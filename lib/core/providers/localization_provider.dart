import 'dart:convert';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../localization/languages/language.dart';
import '../localization/languages/en_us.dart';
import '../localization/languages/tr_tr.dart';

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
    
    if (langCode != null && langCode.isNotEmpty) {
      if (langCode.startsWith('en')) {
        state = LanguageEn();
      } else {
        state = LanguageTr();
      }
    } else {
      // No saved language, detect from system locale
      _detectLanguageFromSystem();
    }
  }

  void _detectLanguageFromSystem() {
    final locales = PlatformDispatcher.instance.locales;
    bool isTurkish = false;
    
    for (var loc in locales) {
      final code = loc.languageCode.toLowerCase();
      if (code == 'tr' || code.startsWith('tr') || code.startsWith('tur')) {
        isTurkish = true;
        break;
      }
    }
    
    if (isTurkish) {
      state = LanguageTr();
    } else {
      state = LanguageEn();
    }
    
    // Save the detected language for future sessions
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString(_languageKey, state is LanguageEn ? 'en' : 'tr');
    });
  }

  Future<void> setLanguage(String langCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, langCode);
    if (langCode.startsWith('en')) {
      state = LanguageEn();
    } else {
      state = LanguageTr();
    }
  }

  String get languageCode => state is LanguageEn ? 'en' : 'tr';
  String get currentLanguageCode => state is LanguageEn ? 'en' : 'tr';
}
