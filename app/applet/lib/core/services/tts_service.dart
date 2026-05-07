import 'package:flutter_tts/flutter_tts.dart';
import 'package:blind_social/core/utils/logger.dart';

class TtsService {
  static final TtsService _instance = TtsService._internal();
  factory TtsService() => _instance;
  
  final FlutterTts _flutterTts = FlutterTts();
  bool _isInit = false;

  TtsService._internal() {
    _initTts();
  }

  Future<void> _initTts() async {
    if (_isInit) return;
    try {
      await _flutterTts.setLanguage("tr-TR");
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.setPitch(0.85); // Biraz daha kalın ve kibar
      _isInit = true;
    } catch (e) {
      AppLogger.instance.error("TTS başlatılamadı: $e");
    }
  }

  Future<void> setPitch(double pitch) async {
    await _flutterTts.setPitch(pitch);
  }
  
  Future<void> setSpeechRate(double rate) async {
    await _flutterTts.setSpeechRate(rate);
  }

  Future<void> speak(String text) async {
    try {
      if (!_isInit) await _initTts();
      await _flutterTts.speak(text);
    } catch (e) {
      AppLogger.instance.error("TTS Speak error: $e");
    }
  }

  Future<void> stop() async {
    try {
      await _flutterTts.stop();
    } catch (e) {
      AppLogger.instance.error("TTS Stop error: $e");
    }
  }
}
