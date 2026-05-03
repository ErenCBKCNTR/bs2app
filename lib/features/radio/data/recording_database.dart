
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/radio_recording.dart';

class RecordingDatabase {
  static final RecordingDatabase instance = RecordingDatabase._init();
  static Database? _database;

  RecordingDatabase._init();

  Future<Database> get database async {
    if (kIsWeb) {
      throw UnsupportedError('sqflite is not supported on the web');
    }
    if (_database != null) return _database!;
    _database = await _initDB('recordings.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    if (kIsWeb) throw UnsupportedError('sqflite not supported on web');
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
CREATE TABLE recordings (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  stationName TEXT NOT NULL,
  filePath TEXT NOT NULL,
  date TEXT NOT NULL,
  durationMs INTEGER NOT NULL
)
''');
  }

  Future<int> insert(RadioRecording recording) async {
    if (kIsWeb) {
      return 1; // Dummy return
    }
    final db = await instance.database;
    return await db.insert('recordings', recording.toMap());
  }

  Future<List<RadioRecording>> fetchAll() async {
    if (kIsWeb) {
      return []; // Return empty list on web
    }
    final db = await instance.database;
    final result = await db.query('recordings', orderBy: 'date DESC');
    return result.map((json) => RadioRecording.fromMap(json)).toList();
  }

  Future<int> delete(int id) async {
    if (kIsWeb) {
      return 1; // Dummy return
    }
    final db = await instance.database;
    return await db.delete('recordings', where: 'id = ?', whereArgs: [id]);
  }
}
