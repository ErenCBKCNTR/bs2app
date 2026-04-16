import 'package:flutter/foundation.dart';

enum LogLevel { info, warning, error }

class LogEntry {
  final DateTime timestamp;
  final String message;
  final LogLevel level;

  LogEntry({required this.timestamp, required this.message, required this.level});
}

class AppLogger extends ChangeNotifier {
  static final AppLogger instance = AppLogger._internal();
  AppLogger._internal();

  final List<LogEntry> _logs = [];

  List<LogEntry> get logs => List.unmodifiable(_logs);

  void log(String message, {LogLevel level = LogLevel.info}) {
    _logs.add(LogEntry(
      timestamp: DateTime.now(),
      message: message,
      level: level,
    ));
    
    // Yüksek bellek kullanımını önlemek için son 500 kaydı tut
    if (_logs.length > 500) {
      _logs.removeAt(0); 
    }
    
    if (kDebugMode) {
      print('[${level.name.toUpperCase()}] $message');
    }
    
    notifyListeners();
  }

  void info(String message) => log(message, level: LogLevel.info);
  void warning(String message) => log(message, level: LogLevel.warning);
  void error(String message) => log(message, level: LogLevel.error);

  void clear() {
    _logs.clear();
    notifyListeners();
  }
}
