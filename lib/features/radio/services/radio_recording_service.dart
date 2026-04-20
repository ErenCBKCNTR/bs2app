import 'dart:async';
import 'dart:html' as html;
import 'package:just_audio/just_audio.dart';
import 'package:intl/intl.dart';
import '../models/radio_recording.dart';
import '../data/recording_database.dart';

class RadioRecordingService {
  html.MediaRecorder? _mediaRecorder;
  List<html.Blob> _chunks = [];
  DateTime? _startTime;
  String? _currentStationName;
  Completer<RadioRecording>? _recordingCompleter;

  bool get isRecording => _mediaRecorder != null && _mediaRecorder!.state == 'recording';

  Future<void> startRecording(String url, String stationName) async {
    if (isRecording) return;
    
    _startTime = DateTime.now();
    _currentStationName = stationName;
    _chunks.clear();

    // Browser Web Audio API'den stream yakala
    final audioContext = html.AudioContext();
    final destination = audioContext.createMediaStreamDestination();
    
    // MediaRecorder ile stream'i kaydet
    final options = {'mimeType': 'audio/webm'};
    _mediaRecorder = html.MediaRecorder(destination.stream, options);
    
    _mediaRecorder!.addEventListener('dataavailable', (html.Event event) {
      final blobEvent = event as html.BlobEvent;
      _chunks.add(blobEvent.data!);
    });

    _mediaRecorder!.addEventListener('stop', (html.Event event) async {
      final blob = html.Blob(_chunks, 'audio/webm');
      final url = html.Url.createObjectUrlFromBlob(blob);
      
      final duration = DateTime.now().difference(_startTime!);
      final recording = RadioRecording(
        stationName: _currentStationName!,
        filePath: url, // Web object URL olarak saklıyoruz
        date: _startTime!,
        duration: duration,
      );
      
      final id = await RecordingDatabase.instance.insert(recording);
      _recordingCompleter?.complete(RadioRecording(
        id: id,
        stationName: recording.stationName,
        filePath: recording.filePath,
        date: recording.date,
        duration: recording.duration,
      ));
    });

    _mediaRecorder!.start();
  }

  Future<RadioRecording?> stopRecording() async {
    if (!isRecording) return null;
    _recordingCompleter = Completer<RadioRecording>();
    _mediaRecorder!.stop();
    return _recordingCompleter!.future;
  }
}
