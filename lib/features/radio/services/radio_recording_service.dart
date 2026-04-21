import 'dart:async';
import 'dart:io';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:intl/intl.dart';
import '../models/radio_recording.dart';
import '../data/recording_database.dart';

class RadioRecordingService {
  final AudioPlayer _player = AudioPlayer();
  StreamSubscription<List<int>>? _streamSub;
  IOSink? _fileSink;
  DateTime? _startTime;
  String? _currentFilePath;
  String? _currentStationName;

  bool get isRecording => _streamSub != null;

  Future<void> startRecording(String url, String stationName) async {
    if (isRecording) return;
    
    _startTime = DateTime.now();
    _currentStationName = stationName;

    final formattedDate = DateFormat('ddMMyyyy_HHmmss').format(_startTime!);
    final sanitizedStation = stationName.replaceAll(RegExp(r'[^\w\s]'), '').replaceAll(' ', '_').toLowerCase();
    final fileName = 'blindsocial_${sanitizedStation}_$formattedDate.aac';
    
    final directory = await getApplicationDocumentsDirectory();
    _currentFilePath = p.join(directory.path, fileName);
    _fileSink = File(_currentFilePath!).openWrite();

    // Yayını çek
    final client = HttpClient();
    final request = await client.getUrl(Uri.parse(url));
    final response = await request.close();

    // Stream'i böl
    final controller = StreamController<List<int>>();
    _streamSub = response.listen(
      (chunk) {
        controller.add(chunk);
        _fileSink?.add(chunk);
      },
      onDone: () => controller.close(),
      cancelOnError: true,
    );

    // Player'ı başlat ve sync et
    await _player.setAudioSource(StreamAudioSourceWrapper(controller.stream));
    _player.play();
  }

  Future<RadioRecording?> stopRecording() async {
    if (!isRecording) return null;

    await _streamSub?.cancel();
    _streamSub = null;
    await _player.stop();
    await _fileSink?.flush();
    await _fileSink?.close();

    final duration = DateTime.now().difference(_startTime!);
    final recording = RadioRecording(
      stationName: _currentStationName!,
      filePath: _currentFilePath!,
      date: _startTime!,
      duration: duration,
    );
    
    final id = await RecordingDatabase.instance.insert(recording);
    return recording.copyWith(id: id);
  }
}

class StreamAudioSourceWrapper extends StreamAudioSource {
  final Stream<List<int>> _stream;
  StreamAudioSourceWrapper(this._stream);
  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    return StreamAudioResponse(sourceLength: null, contentLength: null, offset: 0, stream: _stream, contentType: 'audio/aac');
  }
}
