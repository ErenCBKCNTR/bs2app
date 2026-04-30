import 'package:flutter/material.dart';
import 'package:blind_social/features/task_board/data/models/task_item.dart';
import 'package:blind_social/features/task_board/data/services/task_board_service.dart';
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
    return widget.task.startDate != null && widget.task.dueDate == null;
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
      await widget.service.updateTaskDates(
        widget.task.id,
        DateTime.now().toUtc(),
        null,
      );
      widget.onChanged();
      _startLocalTimer();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _stopStopwatch() async {
    setState(() => _isLoading = true);
    try {
      await widget.service.updateTaskDates(
        widget.task.id,
        widget.task.startDate,
        DateTime.now().toUtc(),
      );
      widget.onChanged();
      _timer?.cancel();
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
    if (now.year == dt.year) {
      return "${dt.day} ${_getMonthName(dt.month)}";
    }
    return "${dt.day} ${_getMonthName(dt.month)} ${dt.year}";
  }

  @override
  Widget build(BuildContext context) {
    final bool active = _isTimerActive();
    Duration currentDiff = Duration.zero;

    if (active) {
      currentDiff = DateTime.now().difference(widget.task.startDate!);
    } else if (widget.task.startDate != null && widget.task.dueDate != null) {
      currentDiff = widget.task.dueDate!.difference(widget.task.startDate!);
    }

    String timeSpentText = "";
    if (widget.task.startDate != null && widget.task.dueDate != null) {
       timeSpentText = "Bu görev üzerinde ${_formatTimeSpent(currentDiff)} çalıştınız.\n"
                       "${_formatDate(widget.task.startDate!)} tarihinde başladınız, "
                       "${_formatDate(widget.task.dueDate!)} tarihinde bitirdiniz.";
    } else if (active) {
       timeSpentText = "Görev üzerinde şu ana kadar ${_formatTimeSpent(currentDiff)} çalıştınız.";
    }

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
        
        if (timeSpentText.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Text(timeSpentText, style: const TextStyle(fontSize: 16)),
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
            label: Text(widget.task.startDate == null ? 'Kronometreyi Başlat' : 'Yeni Kronometre Başlat', style: const TextStyle(color: Colors.white)),
          ),
      ],
    );
  }
}
