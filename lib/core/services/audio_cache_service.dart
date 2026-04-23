import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class AudioCacheService {
  static const String _outgoingCallUrl =
      'https://drive.google.com/uc?export=download&id=1bUmwgR4fdbPhDkUlCSrSUYPuLOcEf3-h';
  static bool _isInitialized = false;

  static Future<void> initializeCache() async {
    if (_isInitialized) return;
    try {
      final directory = await getApplicationDocumentsDirectory();
      final File cachedFile = File('${directory.path}/outgoing_call_cached.mp3');

      if (!await cachedFile.exists()) {
        debugPrint('Downloading outgoing call ringtone...');
        final client = HttpClient();
        final request = await client.getUrl(Uri.parse(_outgoingCallUrl));
        final response = await request.close();
        if (response.statusCode == 200) {
          await response.pipe(cachedFile.openWrite());
          debugPrint('Outgoing call audio cached successfully.');
        } else {
          debugPrint('Failed to cache outgoing call audio: ${response.statusCode}');
        }
      } else {
        debugPrint('Outgoing call audio already cached.');
      }
      _isInitialized = true;
    } catch (e) {
      debugPrint('Error caching audio: $e');
    }
  }

  static Future<String?> getCachedOutgoingCallPath() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final File cachedFile = File('${directory.path}/outgoing_call_cached.mp3');
      if (await cachedFile.exists()) {
        return cachedFile.path;
      }
    } catch (e) {
      debugPrint('Error getting cached audio: $e');
    }
    return null;
  }
}
