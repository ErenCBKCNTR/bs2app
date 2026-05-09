import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:blind_social/core/utils/logger.dart';

class PbCacheManager {
  static const String _keyPrefix = 'pb_cache_';
  
  static Future<void> saveList(String collection, String filter, List<RecordModel> items) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_keyPrefix${collection}_$filter';
      final jsonList = items.map((e) => e.toJson()).toList();
      
      final cacheData = {
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'data': jsonList,
      };
      await prefs.setString(key, jsonEncode(cacheData));
    } catch(e) {
      AppLogger.instance.error('Cache save error ($collection): $e');
    }
  }

  static Future<List<RecordModel>?> getList(String collection, String filter, {Duration? maxAge}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_keyPrefix${collection}_$filter';
      final dataStr = prefs.getString(key);
      if (dataStr != null) {
        final Map<String, dynamic> decoded = jsonDecode(dataStr);
        final int timestamp = decoded['timestamp'] ?? 0;
        final List<dynamic> recordsRaw = decoded['data'] ?? [];
        
        if (maxAge != null) {
          final age = DateTime.now().millisecondsSinceEpoch - timestamp;
          if (age > maxAge.inMilliseconds) {
            return null; // Cache expired
          }
        }
        return recordsRaw.map((e) => RecordModel.fromJson(e as Map<String, dynamic>)).toList();
      }
    } catch(e) {
      AppLogger.instance.error('Cache read error ($collection): $e');
    }
    return null;
  }
}

