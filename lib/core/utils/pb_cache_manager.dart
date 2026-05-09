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
      await prefs.setString(key, jsonEncode(jsonList));
    } catch(e) {
      AppLogger.instance.error('Cache save error ($collection): $e');
    }
  }

  static Future<List<RecordModel>?> getList(String collection, String filter) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_keyPrefix${collection}_$filter';
      final dataStr = prefs.getString(key);
      if (dataStr != null) {
        final List<dynamic> decoded = jsonDecode(dataStr);
        return decoded.map((e) => RecordModel.fromJson(e as Map<String, dynamic>)).toList();
      }
    } catch(e) {
      AppLogger.instance.error('Cache read error ($collection): $e');
    }
    return null;
  }
}
