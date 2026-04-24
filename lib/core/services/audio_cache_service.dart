import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class AudioCacheService {
  static const String _outgoingCallUrl =
      'https://api.cabukcan.com/sounds/outgoing_call.mp3';
  static bool _isInitialized = false;

  static Future<void> initializeCache() async {
    _isInitialized = true;
    try {
      if (!kIsWeb) {
        final directory = await getApplicationDocumentsDirectory();
        final File cachedFile = File('${directory.path}/outgoing_call_cached.mp3');
        if (await cachedFile.exists()) {
          await cachedFile.delete(); // Clear corrupted cache
        }
      }
    } catch (_) {}
  }

  static Future<String?> getCachedOutgoingCallPath() async {
    return null; // Always return null to force UrlSource usage
  }
}

