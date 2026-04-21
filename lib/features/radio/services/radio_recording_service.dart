import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/radio_recording.dart';
import '../data/recording_database.dart';
import 'package:intl/intl.dart';

class RadioRecordingService {
  bool _isRecording = false;
  bool get isRecording => _isRecording;

  IOSink? _sink;
  Timer? _timer;
  String? _currentFilePath;
  String? _currentStationName;
  DateTime? _startTime;

  final Set<String> _downloadedSegments = {};

  Future<void> startRecording(String m3u8Url, String stationName, String filePath) async {
    if (_isRecording) return;

    _isRecording = true;
    _currentStationName = stationName;
    _currentFilePath = filePath;
    _startTime = DateTime.now();

    final file = File(filePath);
    _sink = file.openWrite(mode: FileMode.write);

    // M3U8'i her 2 saniyede bir kontrol et
    _timer = Timer.periodic(const Duration(seconds: 2), (_) async {
      if (!_isRecording) return;

      try {
        final playlist = await _fetchText(m3u8Url);
        final segments = _parseSegments(playlist, m3u8Url);

        for (final segmentUrl in segments) {
          if (!_isRecording) break;
          if (_downloadedSegments.contains(segmentUrl)) continue;

          _downloadedSegments.add(segmentUrl);

          final bytes = await _downloadSegment(segmentUrl);
          _sink?.add(bytes);
        }
      } catch (e) {
        print("Recorder error: $e");
      }
    });
  }

  Future<RadioRecording?> stopRecording() async {
    if (!_isRecording) return null;
    
    _isRecording = false;

    await _timer?.cancel();
    await _sink?.flush();
    await _sink?.close();

    final duration = DateTime.now().difference(_startTime!);

    final recording = RadioRecording(
      stationName: _currentStationName!,
      filePath: _currentFilePath!,
      date: _startTime!,
      duration: duration,
    );

    final id = await RecordingDatabase.instance.insert(recording);
    
    _downloadedSegments.clear();
    
    return recording.copyWith(id: id);
  }

  // ---------------- HELPERS ----------------

  Future<String> _fetchText(String url) async {
    final client = HttpClient();
    final request = await client.getUrl(Uri.parse(url));
    final response = await request.close();

    return await response.transform(utf8.decoder).join();
  }

  List<String> _parseSegments(String playlist, String baseUrl) {
    final lines = playlist.split('\n');
    final uri = Uri.parse(baseUrl);

    return lines
        .where((line) => line.isNotEmpty && !line.startsWith('#'))
        .map((line) => Uri.parse(line).isAbsolute
            ? line
            : uri.resolve(line).toString())
        .toList();
  }

  Future<List<int>> _downloadSegment(String url) async {
    final client = HttpClient();
    final request = await client.getUrl(Uri.parse(url));
    final response = await request.close();

    return await consolidateHttpClientResponseBytes(response);
  }
}
