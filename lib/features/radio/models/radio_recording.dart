
class RadioRecording {
  final int? id;
  final String stationName;
  final String filePath;
  final DateTime date;
  final Duration duration;

  RadioRecording({
    this.id,
    required this.stationName,
    required this.filePath,
    required this.date,
    required this.duration,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'stationName': stationName,
      'filePath': filePath,
      'date': date.toIso8601String(),
      'durationMs': duration.inMilliseconds,
    };
  }

  factory RadioRecording.fromMap(Map<String, dynamic> map) {
    return RadioRecording(
      id: map['id'],
      stationName: map['stationName'],
      filePath: map['filePath'],
      date: DateTime.parse(map['date']),
      duration: Duration(milliseconds: map['durationMs']),
    );
  }
}
