import 'package:flutter/material.dart';
import 'package:blind_social/features/task_board/data/models/task_item.dart';
import 'package:blind_social/features/task_board/data/services/task_board_service.dart';
import 'package:flutter/semantics.dart';
import 'dart:async';

class TaskStopwatchWidget extends StatefulWidget {
  final TaskItem task;
  final TaskBoardService service;
  final VoidCallback onChanged;

  const TaskStopwatchWidget({
    Key? key,
    required this.task,
    required this.service,
    required this.onChanged,
  }) : super(key: key);

  @override
  State<TaskStopwatchWidget> createState() => _TaskStopwatchWidgetState();
}

class _TaskStopwatchWidgetState extends State<TaskStopwatchWidget> {
  bool _isLoading = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (_isTimerActive()) {
      _startLocalTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  bool _isTimerActive() {
    return widget.task.timeLogs.isNotEmpty && widget.task.timeLogs.last['end'] == null;
  }

  void _startLocalTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (Timer t) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _startStopwatch() async {
    setState(() => _isLoading = true);
    try {
      List<dynamic> logs = List.from(widget.task.timeLogs);
      logs.add({
        "id": DateTime.now().millisecondsSinceEpoch.toString(),
        "start": DateTime.now().toUtc().toIso8601String(),
        "end": null
      });
      await widget.service.updateTaskTimeLogs(widget.task.id, logs);
      widget.onChanged();
      _startLocalTimer();
      SemanticsService.announce('Kronometre başlatıldı', TextDirection.ltr);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _stopStopwatch() async {
    setState(() => _isLoading = true);
    try {
      List<dynamic> logs = List.from(widget.task.timeLogs);
      if (logs.isNotEmpty && logs.last['end'] == null) {
        logs.last['end'] = DateTime.now().toUtc().toIso8601String();
        await widget.service.updateTaskTimeLogs(widget.task.id, logs);
      }
      widget.onChanged();
      _timer?.cancel();
      SemanticsService.announce('Kronometre durduruldu', TextDirection.ltr);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteLog(String id) async {
    setState(() => _isLoading = true);
    try {
      List<dynamic> logs = List.from(widget.task.timeLogs);
      logs.removeWhere((l) => l['id'] == id);
      await widget.service.updateTaskTimeLogs(widget.task.id, logs);
      widget.onChanged();
      if (!_isTimerActive()) {
        _timer?.cancel();
      }
      SemanticsService.announce('Çalışma süresi silindi', TextDirection.ltr);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatTimeSpent(Duration diff) {
    if (diff.isNegative) return "Hesaplanamıyor";
    int days = diff.inDays;
    int hours = diff.inHours % 24;
    int mins = diff.inMinutes % 60;
    
    if (days == 0 && hours == 0 && mins == 0) return "1 dakikadan az";
    
    List<String> parts = [];
    if (days > 0) parts.add("$days gün");
    if (hours > 0) parts.add("$hours saat");
    if (mins > 0) parts.add("$mins dakika");
    return parts.join(" ");
  }
  
  String _getMonthName(int month) {
    const months = ["", "Ocak", "Şubat", "Mart", "Nisan", "Mayıs", "Haziran", "Temmuz", "Ağustos", "Eylül", "Ekim", "Kasım", "Aralık"];
    return months[month];
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final dLocal = dt.toLocal();
    if (now.year == dLocal.year && now.month == dLocal.month && now.day == dLocal.day) {
      return "${dLocal.hour.toString().padLeft(2, '0')}:${dLocal.minute.toString().padLeft(2, '0')}";
    }
    if (now.year == dLocal.year) {
      return "${dLocal.day} ${_getMonthName(dLocal.month)} ${dLocal.hour.toString().padLeft(2, '0')}:${dLocal.minute.toString().padLeft(2, '0')}";
    }
    return "${dLocal.day} ${_getMonthName(dLocal.month)} ${dLocal.year}";
  }

  Duration _calculateTotalDuration() {
    Duration total = Duration.zero;
    for (var log in widget.task.timeLogs) {
      final start = DateTime.parse(log['start']);
      final end = log['end'] != null ? DateTime.parse(log['end']) : DateTime.now().toUtc();
      total += end.difference(start);
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final bool active = _isTimerActive();
    final Duration totalDuration = _calculateTotalDuration();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Görev Kronometresi', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            if (_isLoading) const SizedBox(
              width: 16, height: 16, 
              child: CircularProgressIndicator(strokeWidth: 2)
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        if (totalDuration.inSeconds > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Text("Bu görev üzerinde toplam ${_formatTimeSpent(totalDuration)} çalıştınız.", style: const TextStyle(fontSize: 16)),
          ),
          
        if (active)
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: _isLoading ? null : _stopStopwatch,
            icon: const Icon(Icons.stop),
            label: const Text('Kronometreyi Durdur', style: TextStyle(color: Colors.white)),
          )
        else
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: _isLoading ? null : _startStopwatch,
            icon: const Icon(Icons.play_arrow),
            label: Text(widget.task.timeLogs.isEmpty ? 'Kronometreyi Başlat' : 'Yeni Kronometre Başlat', style: const TextStyle(color: Colors.white)),
          ),
          
        if (widget.task.timeLogs.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text('Çalışma Geçmişi', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...widget.task.timeLogs.reversed.map((log) {
            final start = DateTime.parse(log['start']);
            final endStr = log['end'];
            final end = endStr != null ? DateTime.parse(endStr) : null;
            final isRunning = end == null;
            final diff = (end ?? DateTime.now().toUtc()).difference(start);
            
            final semanticsLabel = isRunning 
              ? 'Devam eden çalışma. Başlangıç: ${_formatDate(start)}. Geçen süre: ${_formatTimeSpent(diff)}. Kaydı silmek için eylem menüsünü kullanın.'
              : 'Tamamlanan çalışma. Başlangıç: ${_formatDate(start)}, Bitiş: ${_formatDate(end!)}. Süre: ${_formatTimeSpent(diff)}. Kaydı silmek için eylem menüsünü kullanın.';

            return Card(
              child: Semantics(
                label: semanticsLabel,
                button: true,
                customSemanticsActions: {
                  const CustomSemanticsAction(label: 'Çalışma Süresini Sil'): () => _deleteLog(log['id']),
                },
                child: ExcludeSemantics(
                  child: ListTile(
                    leading: Icon(isRunning ? Icons.timer : Icons.timer_off, color: isRunning ? Colors.green : Colors.grey),
                    title: Text(isRunning ? "Devam Ediyor..." : "Tamamlandı"),
                    subtitle: Text("${_formatDate(start)} - ${end != null ? _formatDate(end) : 'Şimdi'}\nSüre: ${_formatTimeSpent(diff)}"),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deleteLog(log['id']),
                      tooltip: 'Sil',
                    ),
                  ),
                ),
              ),
            );
          }),
        ]
      ],
    );
  }
}
