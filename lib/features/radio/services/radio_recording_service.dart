
import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:intl/intl.dart';
import 'package:just_audio/just_audio.dart';
import 'package:ffmpeg_kit_flutter_audio/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_audio/ffmpeg_session.dart';
import '../models/radio_recording.dart';
import '../data/recording_database.dart';

class RadioRecordingService {
  FFmpegSession? _ffmpegSession;
  DateTime? _startTime;
  String? _currentFilePath;
  String? _currentStationName;

  bool get isRecording => _ffmpegSession != null;

  Future<void> startRecording(String url, String stationName) async {
    if (isRecording) return;

    _startTime = DateTime.now();
    _currentStationName = stationName;

    // Filename format: blindsocial_radyoadi_tarih.mp3
    final formattedDate = DateFormat('ddMMyyyy_HHmmss').format(_startTime!);
    final sanitizedStation = stationName
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .replaceAll(' ', '_')
        .toLowerCase();
    final fileName = 'blindsocial_${sanitizedStation}_$formattedDate.mp3';
    
    final directory = await getApplicationDocumentsDirectory();
    _currentFilePath = p.join(directory.path, fileName);

    // Using FFmpeg (Native C++) for professional recording.
    // This supports HLS (.m3u8), Shoutcast, and all common audio protocols.
    // -y: overwrite if exists
    // -i: input url
    // -c:a libmp3lame: encode to mp3
    // -q:a 2: good quality (VBR)
    // We also add reconnection flags for better stability on unstable networks
    final command = "-y -reconnect 1 -reconnect_at_eof 1 -reconnect_streamed 1 -reconnect_delay_max 2 -i \"$url\" -c:a libmp3lame -q:a 2 \"$_currentFilePath\"";

    _ffmpegSession = await FFmpegKit.executeAsync(command, (session) async {
      final state = await session.getState();
      final returnCode = await session.getReturnCode();
      if (returnCode?.isError() ?? false) {
        final logs = await session.getLogs();
        print("FFmpeg recording error: ${logs.last.getMessage()}");
      }
    });
  }

  Future<RadioRecording?> stopRecording() async {
    if (!isRecording) return null;

    final session = _ffmpegSession;
    _ffmpegSession = null; // Mark as null immediately for UI state

    // Cancel the session (FFmpeg will finish the file)
    if (session != null) {
      await FFmpegKit.cancel(session.getSessionId());
    }

    // Give FFmpeg a moment to finalize the file on disk
    await Future.delayed(const Duration(milliseconds: 1000));

    // Get real duration from the file metadata
    Duration duration;
    try {
      final probePlayer = AudioPlayer();
      final probeDuration = await probePlayer.setFilePath(_currentFilePath!);
      duration = probeDuration ?? (DateTime.now().difference(_startTime!));
      await probePlayer.dispose();
    } catch (e) {
      duration = DateTime.now().difference(_startTime!);
    }
    
    final recording = RadioRecording(
      stationName: _currentStationName!,
      filePath: _currentFilePath!,
      date: _startTime!,
      duration: duration,
    );

    // Save metadata to local database
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
