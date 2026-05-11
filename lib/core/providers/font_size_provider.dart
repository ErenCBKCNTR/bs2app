import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/settings_service.dart';

class FontSizeNotifier extends StateNotifier<double> {
  final SettingsService _settingsService = SettingsService();

  FontSizeNotifier() : super(1.0) {
    state = _settingsService.fontSize;
  }

  Future<void> setFontSize(double size) async {
    await _settingsService.setFontSize(size);
    state = size;
  }
}

final fontSizeProvider = StateNotifierProvider<FontSizeNotifier, double>((ref) {
  return FontSizeNotifier();
});
