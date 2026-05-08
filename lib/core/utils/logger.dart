import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

enum LogLevel { info, warning, error }

class LogEntry {
  final DateTime timestamp;
  final String message;
  final LogLevel level;
  final String? details; // Extended information, e.g. endpoint request counts

  LogEntry({required this.timestamp, required this.message, required this.level, this.details});

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'message': message,
    'level': level.index,
    'details': details, // Can be null
  };

  factory LogEntry.fromJson(Map<String, dynamic> json) => LogEntry(
    timestamp: DateTime.parse(json['timestamp']),
    message: json['message'] ?? '',
    level: LogLevel.values[json['level'] ?? 0],
    details: json['details'], // Will be null for older entries
  );
}

class AppLogger extends ChangeNotifier {
  static final AppLogger instance = AppLogger._internal();
  bool _isLoaded = false;
  final List<LogEntry> _pendingLogs = [];

  AppLogger._internal() {
    _loadLogs();
  }

  final List<LogEntry> _logs = [];

  List<LogEntry> get logs => List.unmodifiable(_logs);

  Future<void> _loadLogs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final logsString = prefs.getString('developer_logs_v2');
      if (logsString != null) {
        final List<dynamic> jsonList = jsonDecode(logsString);
        _logs.addAll(jsonList.map((e) => LogEntry.fromJson(e)).toList());
      }
      
      if (_pendingLogs.isNotEmpty) {
        _logs.addAll(_pendingLogs);
        _pendingLogs.clear();
      }

      if (_logs.length > 500) {
        _logs.removeRange(0, _logs.length - 500);
      }

      _isLoaded = true;
      _saveLogs();
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('Log yüklenirken hata: ${e}');
      }
      _isLoaded = true;
    }
  }

  Future<void> _saveLogs() async {
    if (!_isLoaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = _logs.map((e) => e.toJson()).toList();
      await prefs.setString('developer_logs_v2', jsonEncode(jsonList));
    } catch (e) {
      if (kDebugMode) {
        print('Log kaydedilirken hata: ${e}');
      }
    }
  }

  void log(String message, {LogLevel level = LogLevel.info, String? details}) {
    final entry = LogEntry(
      timestamp: DateTime.now(),
      message: message,
      level: level,
      details: details,
    );

    if (!_isLoaded) {
      _pendingLogs.add(entry);
    } else {
      _logs.add(entry);
      if (_logs.length > 500) {
        _logs.removeAt(0); 
      }
      _saveLogs();
      notifyListeners();
    }
    
    if (kDebugMode) {
      if (details != null) {
         print('[${level.name.toUpperCase()}] $message\nDetails: $details');
      } else {
         print('[${level.name.toUpperCase()}] $message');
      }
    }
  }

  void info(String message, {String? details}) => log(message, level: LogLevel.info, details: details);
  void warning(String message, {String? details}) => log(message, level: LogLevel.warning, details: details);
  void error(String message, {String? details}) => log(message, level: LogLevel.error, details: details);

  void clear() async {
    _logs.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('developer_logs_v2');
    notifyListeners();
  }
}