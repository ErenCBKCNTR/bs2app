
import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../models/radio_recording.dart';
import '../data/recording_database.dart';

class RadioRecordingService {
  HttpClient? _httpClient;
  HttpClientRequest? _request;
  StreamSubscription? _subscription;
  IOSink? _fileSink;
  DateTime? _startTime;
  String? _currentFilePath;
  String? _currentStationName;

  bool get isRecording => _subscription != null;

  Future<void> startRecording(String url, String stationName) async {
    if (isRecording) return;

    _startTime = DateTime.now();
    _currentStationName = stationName;
    
    final directory = await getApplicationDocumentsDirectory();
    final fileName = 'recording_${_startTime!.millisecondsSinceEpoch}.mp3';
    _currentFilePath = p.join(directory.path, fileName);
    
    final file = File(_currentFilePath!);
    _fileSink = file.openWrite();

    try {
      _httpClient = HttpClient();
      // Set reasonable timeout
      _httpClient!.connectionTimeout = const Duration(seconds: 10);
      _request = await _httpClient!.getUrl(Uri.parse(url));
      final response = await _request!.close();

      if (response.statusCode != 200) {
        throw Exception("Stream source error: ${response.statusCode}");
      }

      _subscription = response.listen(
        (data) {
          _fileSink?.add(data);
        },
        onDone: () => stopRecording(),
        onError: (e) => stopRecording(),
        cancelOnError: true,
      );
    } catch (e) {
      await _fileSink?.close();
      _httpClient?.close();
      _subscription = null;
      _fileSink = null;
      _httpClient = null;
      rethrow;
    }
  }

  Future<RadioRecording?> stopRecording() async {
    if (!isRecording) return null;

    final duration = DateTime.now().difference(_startTime!);
    
    await _subscription?.cancel();
    await _fileSink?.close();
    _httpClient?.close();

    final recording = RadioRecording(
      stationName: _currentStationName!,
      filePath: _currentFilePath!,
      date: _startTime!,
      duration: duration,
    );

    _subscription = null;
    _fileSink = null;
    _httpClient = null;

    // Save to DB
    final id = await RecordingDatabase.instance.insert(recording);
    return RadioRecording(
      id: id,
      stationName: recording.stationName,
      filePath: recording.filePath,
      date: recording.date,
      duration: recording.duration,
    );
  }
}
