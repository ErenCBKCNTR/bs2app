
import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:intl/intl.dart';
import '../models/radio_recording.dart';
import '../data/recording_database.dart';

class RadioRecordingService {
  HttpClient? _httpClient;
  HttpClientRequest? _request;
  StreamSubscription? _subscription;
  IOSink? _fileSink;
  DateTime? _startTime;
  DateTime? _actualDataStartTime;
  String? _currentFilePath;
  String? _currentStationName;

  bool get isRecording => _subscription != null;

  Future<void> startRecording(String url, String stationName) async {
    if (isRecording) return;

    _startTime = DateTime.now();
    _currentStationName = stationName;
    _actualDataStartTime = null;

    // Filename format: blindsocial_radyoadi_tarih.mp3
    final formattedDate = DateFormat('ddMMyyyy_HHmmss').format(_startTime!);
    final sanitizedStation = stationName
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .replaceAll(' ', '_')
        .toLowerCase();
    final fileName = 'blindsocial_${sanitizedStation}_$formattedDate.mp3';
    
    final directory = await getApplicationDocumentsDirectory();
    _currentFilePath = p.join(directory.path, fileName);
    
    final file = File(_currentFilePath!);
    _fileSink = file.openWrite();

    try {
      _httpClient = HttpClient();
      _httpClient!.connectionTimeout = const Duration(seconds: 10);
      _request = await _httpClient!.getUrl(Uri.parse(url));
      final response = await _request!.close();

      if (response.statusCode != 200) {
        throw Exception("Yayın kaynağı hatası: ${response.statusCode}");
      }

      _subscription = response.listen(
        (data) {
          if (_actualDataStartTime == null) {
            _actualDataStartTime = DateTime.now();
          }
          _fileSink?.add(data);
        },
        onDone: () => stopRecording(),
        onError: (e) => stopRecording(),
        cancelOnError: true,
      );
    } catch (e) {
      await _fileSink?.close();
      _httpClient?.close(force: true);
      _subscription = null;
      _fileSink = null;
      _httpClient = null;
      rethrow;
    }
  }

  Future<RadioRecording?> stopRecording() async {
    if (!isRecording) return null;

    // Use actual data start time for duration to avoid connection delay bias
    final durationStartTime = _actualDataStartTime ?? _startTime!;
    final duration = DateTime.now().difference(durationStartTime);
    
    // Stop subscription immediately
    final sub = _subscription;
    _subscription = null;
    await sub?.cancel();
    
    // Close sink and client
    await _fileSink?.close();
    _fileSink = null;
    _httpClient?.close(force: true);
    _httpClient = null;

    final recording = RadioRecording(
      stationName: _currentStationName!,
      filePath: _currentFilePath!,
      date: _startTime!,
      duration: duration,
    );

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
