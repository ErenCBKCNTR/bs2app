import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const String _keyMessageSound = 'message_sound_enabled';
  static const String _keyMessageVibration = 'message_vibration_enabled';
  static const String _keyCallSound = 'call_sound_enabled';
  static const String _keyCallVibration = 'call_vibration_enabled';

  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();

  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // Getters
  bool get messageSoundEnabled => _prefs.getBool(_keyMessageSound) ?? true;
  bool get messageVibrationEnabled => _prefs.getBool(_keyMessageVibration) ?? true;
  bool get callSoundEnabled => _prefs.getBool(_keyCallSound) ?? true;
  bool get callVibrationEnabled => _prefs.getBool(_keyCallVibration) ?? true;

  // Setters
  Future<void> setMessageSoundEnabled(bool value) async => await _prefs.setBool(_keyMessageSound, value);
  Future<void> setMessageVibrationEnabled(bool value) async => await _prefs.setBool(_keyMessageVibration, value);
  Future<void> setCallSoundEnabled(bool value) async => await _prefs.setBool(_keyCallSound, value);
  Future<void> setCallVibrationEnabled(bool value) async => await _prefs.setBool(_keyCallVibration, value);
}
