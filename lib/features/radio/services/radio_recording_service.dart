
import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:intl/intl.dart';
import 'package:just_audio/just_audio.dart';
import 'package:ffmpeg_kit_flutter_new_https/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_https/ffmpeg_session.dart';
import 'package:ffmpeg_kit_flutter_new_https/return_code.dart';
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
    final fileName = 'blindsocial_${sanitizedStation}_$formattedDate.m4a';
    
    final directory = await getApplicationDocumentsDirectory();
    _currentFilePath = p.join(directory.path, fileName);

    // Using FFmpeg (Native C++) for professional recording.
    final isM3u8 = url.toLowerCase().contains('.m3u8');
    late String command;
    
    if (isM3u8) {
      // PERMANENT SOLUTION: Optimized for HLS (M3U8) sync like A Haber.
      // -c:a copy: Zero latency, zero CPU usage, exact data from server.
      // -use_wallclock_as_timestamps 1: Forces output to sync with real world time.
      // -live_start_index -1: Always grabs the very latest segment being played.
      // -fflags +nobuffer+genpts+discardcorrupt: Essential for gapless HLS capture.
      command = "-y -user_agent \"Mozilla/5.0\" -protocol_whitelist file,http,https,tcp,tls,crypto -reconnect 1 -reconnect_streamed 1 -reconnect_delay_max 2 -use_wallclock_as_timestamps 1 -fflags +nobuffer+genpts+discardcorrupt -analyzeduration 1000 -probesize 1000 -live_start_index -1 -i \"$url\" -vn -sn -c:a copy -movflags frag_keyframe+empty_moov+default_base_moof \"$_currentFilePath\"";
    } else {
      // Standard stream optimization
      command = "-y -user_agent \"Mozilla/5.0\" -reconnect 1 -reconnect_at_eof 1 -reconnect_streamed 1 -reconnect_delay_max 2 -fflags +nobuffer+genpts -i \"$url\" -vn -sn -c:a aac -b:a 128k \"$_currentFilePath\"";
    }

    _ffmpegSession = await FFmpegKit.executeAsync(command, (session) async {
      final returnCode = await session.getReturnCode();
      if (ReturnCode.isCancel(returnCode)) {
        print("FFmpeg recording cancelled by user.");
      } else if (ReturnCode.isSuccess(returnCode)) {
        print("FFmpeg recording completed successfully.");
      } else {
        final logs = await session.getLogs();
        if (logs.isNotEmpty) {
          print("FFmpeg recording error: ${logs.last.getMessage()}");
        } else {
          print("FFmpeg recording failed with return code: ${returnCode?.getValue()}");
        }
      }
    });
  }

  Future<RadioRecording?> stopRecording() async {
    if (!isRecording) return null;

    final session = _ffmpegSession;
    _ffmpegSession = null; // Mark as null immediately for UI state

    // Cancel the session (FFmpeg will finish the file)
    if (session != null) {
      // Use peaceful finish instead of hard kill for stream copy to flush metadata
      await FFmpegKit.cancel(session.getSessionId());
    }

    // Give FFmpeg enough time to flush the fragmented MOOV atom to disk
    // For stream copy, this is critical to have a valid duration.
    await Future.delayed(const Duration(milliseconds: 1500));

    final file = File(_currentFilePath!);
    if (!await file.exists() || await file.length() == 0) {
      if (await file.exists()) {
        await file.delete();
      }
      
      String errorDetails = 'Yayın kaynak bağlantısı reddedildi veya kayıt için yeterli veri alınamadı.';
      if (session != null) {
        final logs = await session.getLogs();
        if (logs.isNotEmpty) {
          final recentLogs = logs.reversed.take(4).map((l) => l.getMessage()).join(' | ');
          errorDetails = 'Kayıt başarısız. FFmpeg Log: $recentLogs';
        }
      }
      
      throw Exception(errorDetails);
    }

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
