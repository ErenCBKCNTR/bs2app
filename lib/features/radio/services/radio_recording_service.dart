
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
      _httpClient!.connectionTimeout = const Duration(seconds: 15);
      
      final uri = Uri.parse(url);
      _request = await _httpClient!.getUrl(uri);
      
      // Set common User-Agent and headers
      _request!.headers.set(HttpHeaders.userAgentHeader, 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36');
      _request!.headers.set(HttpHeaders.acceptHeader, '*/*');
      _request!.followRedirects = true;
      _request!.maxRedirects = 5;

      final response = await _request!.close();

      if (response.statusCode != 200 && response.statusCode != 206) {
        throw Exception("Yayın kaynağı hatası: ${response.statusCode}");
      }

      // Check if it's potentially an HLS playlist (m3u8)
      final contentType = response.headers.contentType?.toString().toLowerCase() ?? '';
      if (url.toLowerCase().contains('.m3u8') || contentType.contains('application/x-mpegurl') || contentType.contains('application/vnd.apple.mpegurl')) {
        // HLS is not directly recordable as a raw stream by HttpClient
        throw Exception("Bu radyo kanalı (HLS) şu anki sürümde doğrudan kaydedilemiyor. Lütfen başka bir kanal deneyin.");
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
        cancelOnError: false,
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

    // Stop subscription immediately
    final sub = _subscription;
    _subscription = null;
    await sub?.cancel();
    
    // Abort request and close client to stop receiving data immediately
    try {
      _request?.abort();
    } catch (_) {}
    
    _httpClient?.close(force: true);
    _httpClient = null;
    _request = null;

    // Ensure all data is written to disk
    await _fileSink?.flush();
    await _fileSink?.close();
    _fileSink = null;

    // Small delay to ensure file is closed by the OS
    await Future.delayed(const Duration(milliseconds: 500));

    // Try to get real duration from the file
    Duration duration;
    try {
      // We use a temporary player to probe the file duration
      final probePlayer = AudioPlayer();
      final probeDuration = await probePlayer.setFilePath(_currentFilePath!);
      duration = probeDuration ?? (DateTime.now().difference(_actualDataStartTime ?? _startTime!));
      await probePlayer.dispose();
    } catch (e) {
      // Fallback to time-based duration
      duration = DateTime.now().difference(_actualDataStartTime ?? _startTime!);
    }
    
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
