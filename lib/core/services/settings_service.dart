import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const String _keyMessageSound = 'message_sound_enabled';
  static const String _keyMessageVibration = 'message_vibration_enabled';
  static const String _keyCallSound = 'call_sound_enabled';
  static const String _keyCallVibration = 'call_vibration_enabled';
  static const String _keyShowOnLockScreen = 'show_on_lock_screen_enabled';
  static const String _keyVoiceRoomNotifications = 'voice_room_notifications_enabled';
  static const String _keyScreenProtection = 'screen_protection_enabled';

  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();

  late SharedPreferences _prefs;
  static const platform = MethodChannel('com.example.blind_social/lockscreen');

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    // Apply lock screen setting on init
    _applyLockScreenSetting(showOnLockScreenEnabled);
    // Apply screen protection setting on init
    _applyScreenProtectionSetting(screenProtectionEnabled);
  }

  // Getters
  bool get messageSoundEnabled => _prefs.getBool(_keyMessageSound) ?? true;
  bool get messageVibrationEnabled => _prefs.getBool(_keyMessageVibration) ?? true;
  bool get callSoundEnabled => _prefs.getBool(_keyCallSound) ?? true;
  bool get callVibrationEnabled => _prefs.getBool(_keyCallVibration) ?? true;
  bool get showOnLockScreenEnabled => _prefs.getBool(_keyShowOnLockScreen) ?? false; // Varsayılan olarak kapalı
  bool get voiceRoomNotificationsEnabled => _prefs.getBool(_keyVoiceRoomNotifications) ?? true; // Varsayılan olarak açık
  bool get screenProtectionEnabled => _prefs.getBool(_keyScreenProtection) ?? false; // Varsayılan olarak kapalı (Kullanıcı isteği)

  // Setters
  Future<void> setMessageSoundEnabled(bool value) async => await _prefs.setBool(_keyMessageSound, value);
  Future<void> setMessageVibrationEnabled(bool value) async => await _prefs.setBool(_keyMessageVibration, value);
  Future<void> setCallSoundEnabled(bool value) async => await _prefs.setBool(_keyCallSound, value);
  Future<void> setCallVibrationEnabled(bool value) async => await _prefs.setBool(_keyCallVibration, value);
  Future<void> setShowOnLockScreenEnabled(bool value) async {
    await _prefs.setBool(_keyShowOnLockScreen, value);
    _applyLockScreenSetting(value);
  }
  Future<void> setVoiceRoomNotificationsEnabled(bool value) async => await _prefs.setBool(_keyVoiceRoomNotifications, value);

  Future<void> setScreenProtectionEnabled(bool value) async {
    await _prefs.setBool(_keyScreenProtection, value);
    _applyScreenProtectionSetting(value);
  }

  Future<void> _applyScreenProtectionSetting(bool enabled) async {
    try {
      await platform.invokeMethod('toggleScreenProtection', {'enabled': enabled});
    } on PlatformException catch (e) {
      print("Failed to set screen protection: '${e.message}'.");
    }
  }

  Future<void> _applyLockScreenSetting(bool isVisible) async {
    try {
      await platform.invokeMethod('setLockScreenVisibility', {'isVisible': isVisible});
    } on PlatformException catch (e) {
      print("Failed to set lock screen visibility: '${e.message}'.");
    }
  }
}
