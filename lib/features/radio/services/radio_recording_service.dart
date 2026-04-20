import 'dart:async';
import 'package:record/record.dart'; // Cross-platform native recording
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../models/radio_recording.dart';
import '../data/recording_database.dart';

class RadioRecordingService {
  final _recorder = AudioRecorder(); // Native API'leri kullanan cross-platform recorder
  DateTime? _startTime;
  String? _currentFilePath;
  String? _currentStationName;

  bool get isRecording => _recorder.isRecording();

  Future<void> startRecording(String url, String stationName) async {
    if (await isRecording) return;
    
    // Permission check
    if (await _recorder.hasPermission()) {
      _startTime = DateTime.now();
      _currentStationName = stationName;

      final formattedDate = DateFormat('ddMMyyyy_HHmmss').format(_startTime!);
      final sanitizedStation = stationName
          .replaceAll(RegExp(r'[^\w\s]'), '')
          .replaceAll(' ', '_')
          .toLowerCase();
      final fileName = 'blindsocial_${sanitizedStation}_$formattedDate.m4a'; // M4A (AAC) native desteklenir
      
      final directory = await getApplicationDocumentsDirectory();
      _currentFilePath = p.join(directory.path, fileName);

      // Start recording natively
      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 128000),
        path: _currentFilePath!,
      );
    }
  }

  Future<RadioRecording?> stopRecording() async {
    if (!(await isRecording)) return null;

    final path = await _recorder.stop();
    
    final duration = DateTime.now().difference(_startTime!);

    final recording = RadioRecording(
      stationName: _currentStationName!,
      filePath: path!,
      date: _startTime!,
      duration: duration,
    );

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
