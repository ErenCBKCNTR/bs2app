import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
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
    
    if (langCode != null) {
      if (langCode == 'en' || langCode == 'en-US') {
        state = LanguageEn();
      } else {
        state = LanguageTr();
      }
    } else {
      // No saved language, try to detect from IP
      await _detectLanguageFromIP();
    }
  }

  Future<void> _detectLanguageFromIP() async {
    try {
      final response = await http.get(Uri.parse('https://ipapi.co/json/')).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final countryCode = data['country_code'] as String?;
        
        if (countryCode == 'TR') {
          state = LanguageTr();
          // We don't necessarily save it to prefs yet, let the user decide or save it now
          // For consistency, let's save the detected one:
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_languageKey, 'tr');
        } else {
          state = LanguageEn();
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_languageKey, 'en');
        }
      }
    } catch (e) {
      // Fallback to Turkish if detection fails (app's main target)
      state = LanguageTr();
      debugPrint("IP-based language detection failed: $e");
    }
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
  String get currentLanguageCode => state is LanguageEn ? 'en-US' : 'tr-TR';
}
