import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:intl/intl.dart';
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

  /// RECORDING ENGINE (FFmpeg based)
  Future<void> startRecording(String url, String stationName) async {
    if (isRecording) return;

    _startTime = DateTime.now();
    _currentStationName = stationName;

    // 1) FORMATI .TS YAP
    final formattedDate = DateFormat('ddMMyyyy_HHmmss').format(_startTime!);
    final sanitizedStation = stationName
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .replaceAll(' ', '_')
        .toLowerCase();
    final fileName = 'blindsocial_${sanitizedStation}_$formattedDate.ts';
    
    final directory = await getApplicationDocumentsDirectory();
    _currentFilePath = p.join(directory.path, fileName);

    // 2) KESİN ÇÖZÜM: FFmpeg Optimize Command
    final String command = "-y -loglevel error -fflags nobuffer+flush_packets+discardcorrupt -flags low_delay -strict experimental -analyzeduration 0 -probesize 32 -rw_timeout 5000000 -timeout 5000000 -user_agent \"Mozilla/5.0\" -protocol_whitelist file,http,https,tcp,tls,crypto -reconnect 1 -reconnect_streamed 1 -reconnect_delay_max 2 -i \"$url\" -map 0:a:0 -vn -sn -dn -c:a copy -f mpegts \"$_currentFilePath\"";

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
        }
      }
    });
  }

  Future<RadioRecording?> stopRecording() async {
    if (!isRecording) return null;

    final session = _ffmpegSession;
    _ffmpegSession = null;

    // 5) Global cancel
    if (session != null) {
      await FFmpegKit.cancel(); 
    }

    // 6) 50ms bekleme
    await Future.delayed(const Duration(milliseconds: 50));

    final file = File(_currentFilePath!);

    if (!await file.exists() || await file.length() == 0) {
      if (await file.exists()) {
        await file.delete();
      }
      throw Exception("Kayıt başarısız veya boş dosya.");
    }

    final duration = DateTime.now().difference(_startTime!);

    final recording = RadioRecording(
      stationName: _currentStationName!,
      filePath: _currentFilePath!,
      date: _startTime!,
      duration: duration,
    );

    final id =
        await RecordingDatabase.instance.insert(recording);

    return RadioRecording(
      id: id,
      stationName: recording.stationName,
      filePath: recording.filePath,
      date: recording.date,
      duration: recording.duration,
    );
  }
}
