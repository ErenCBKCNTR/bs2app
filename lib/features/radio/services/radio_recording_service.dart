import 'dart:async';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:ffmpeg_kit_flutter_new_https/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_https/ffmpeg_session.dart';
import 'package:just_audio/just_audio.dart'; // Gerçek süreyi okumak için
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

    // Uzantıyı .aac yapıyoruz, FFmpeg bu yayını standart aac'ye çevirecek.
    final formattedDate = DateFormat('ddMMyyyy_HHmmss').format(_startTime!);
    final sanitizedStation = stationName.replaceAll(RegExp(r'[^\w\s]'), '').replaceAll(' ', '_').toLowerCase();
    final fileName = 'blindsocial_${sanitizedStation}_$formattedDate.aac';
    
    final directory = await getApplicationDocumentsDirectory();
    _currentFilePath = p.join(directory.path, fileName);

    // KATI KURALLI VE AGRESİF SENKRON FFMPEG KOMUTU:
    // fflags nobuffer, düşük prob boyutu ve low_delay ile 5 saniyelik başlama itmesini ortadan kaldırır. 
    // Tam başlatıldığı anda capture eder ve flush_packets ile durdurulduğu an yazmayı anında keser (ekstra 15 sn eklemeyi önler).
    final command = "-y -loglevel error -fflags nobuffer+flush_packets+discardcorrupt -flags low_delay -analyzeduration 500000 -probesize 500000 -user_agent \"Mozilla/5.0\" -protocol_whitelist file,http,https,tcp,tls,crypto -reconnect 1 -reconnect_streamed 1 -reconnect_delay_max 2 -i \"$url\" -map 0:a:0 -vn -sn -dn -c:a aac -b:a 128k \"$_currentFilePath\"";

    _ffmpegSession = await FFmpegKit.executeAsync(command, (session) async {
      final state = await session.getState();
      print("FFmpeg session completed with state: $state");
    });
  }

  Future<RadioRecording?> stopRecording() async {
    if (!isRecording) return null;

    final session = _ffmpegSession;
    _ffmpegSession = null;

    if (session != null) {
      await FFmpegKit.cancel(); // FFmpeg işlemini sonlandır 
    }

    // FFmpeg'in dosyayı kapatıp yazmayı bitirmesi için küçük bir güvenlik beklemesi.
    await Future.delayed(const Duration(milliseconds: 300));

    final file = File(_currentFilePath!);

    if (!await file.exists() || await file.length() == 0) {
      if (await file.exists()) await file.delete();
      throw Exception("Kayıt başarısız oldu veya 0 bayt dosya oluşturuldu.");
    }

    // Kronometre süresi yerine kaydedilen dosyanın GERÇEK süresini _player aracılığıyla buluyoruz.
    Duration finalDuration = DateTime.now().difference(_startTime!);
    try {
      final tempPlayer = AudioPlayer();
      final duration = await tempPlayer.setFilePath(_currentFilePath!);
      if (duration != null && duration.inSeconds > 0) {
        finalDuration = duration;
      }
      await tempPlayer.dispose();
    } catch (e) {
      print("Gerçek dosya süresi okunamadı, kronometre baz alınıyor: $e");
    }

    final recording = RadioRecording(
      stationName: _currentStationName!,
      filePath: _currentFilePath!,
      date: _startTime!,
      duration: finalDuration,
    );

    final id = await RecordingDatabase.instance.insert(recording);

    return recording.copyWith(id: id);
  }
}
