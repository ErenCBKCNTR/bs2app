import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:blind_social/core/providers/localization_provider.dart';
import 'package:blind_social/features/task_board/data/models/task_item.dart';
import 'package:blind_social/features/task_board/data/services/task_board_service.dart';
import 'package:flutter/semantics.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'dart:async';

class TaskStopwatchWidget extends ConsumerStatefulWidget {
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
  ConsumerState<TaskStopwatchWidget> createState() => _TaskStopwatchWidgetState();
}

class _TaskStopwatchWidgetState extends ConsumerState<TaskStopwatchWidget> {
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
      SemanticsService.announce(ref.read(localizationProvider).stopwatchStarted, TextDirection.ltr);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ref.read(localizationProvider).errorLabel(e.toString()))));
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
      SemanticsService.announce(ref.read(localizationProvider).stopwatchStopped, TextDirection.ltr);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ref.read(localizationProvider).errorLabel(e.toString()))));
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
      SemanticsService.announce(ref.read(localizationProvider).removeRecording, TextDirection.ltr);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ref.read(localizationProvider).errorLabel(e.toString()))));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatTimeSpent(Duration diff) {
    final lang = ref.read(localizationProvider);
    if (diff.isNegative) return "0";
    int days = diff.inDays;
    int hours = diff.inHours % 24;
    int mins = diff.inMinutes % 60;
    
    if (days == 0 && hours == 0 && mins == 0) return lang.lessThanOneMinute;
    
    List<String> parts = [];
    if (days > 0) parts.add("$days ${lang.daysSuffix}");
    if (hours > 0) parts.add("$hours ${lang.hoursSuffix}");
    if (mins > 0) parts.add("$mins ${lang.minutesSuffix}");
    return parts.join(" ");
  }

  String _formatDate(DateTime dt) {
    return DateFormat.yMMMd(Localizations.localeOf(context).languageCode).add_Hm().format(dt.toLocal());
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
    final lang = ref.watch(localizationProvider);
    final bool active = _isTimerActive();
    final Duration totalDuration = _calculateTotalDuration();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(lang.taskStopwatch, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
            child: Text("${lang.duration}: ${_formatTimeSpent(totalDuration)}", style: const TextStyle(fontSize: 16)),
          ),
          
        if (active)
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: _isLoading ? null : _stopStopwatch,
            icon: const Icon(Icons.stop),
            label: Text(lang.stopStopwatch, style: const TextStyle(color: Colors.white)),
          )
        else
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: _isLoading ? null : _startStopwatch,
            icon: const Icon(Icons.play_arrow),
            label: Text(widget.task.timeLogs.isEmpty ? lang.startStopwatch : lang.startNewStopwatch, style: const TextStyle(color: Colors.white)),
          ),
          
        if (widget.task.timeLogs.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(lang.workHistory, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...widget.task.timeLogs.reversed.map((log) {
            final start = DateTime.parse(log['start']);
            final endStr = log['end'];
            final end = endStr != null ? DateTime.parse(endStr) : null;
            final isRunning = end == null;
            final diff = (end ?? DateTime.now().toUtc()).difference(start);
            
            final semanticsLabel = isRunning 
              ? '${lang.ongoingWork}. ${_formatDate(start)}. ${_formatTimeSpent(diff)}.'
              : '${lang.completedWork}. ${_formatDate(start)} - ${_formatDate(end!)}. ${_formatTimeSpent(diff)}.';

            return Card(
              child: Semantics(
                label: semanticsLabel,
                button: true,
                customSemanticsActions: {
                  CustomSemanticsAction(label: lang.deleteLog): () => _deleteLog(log['id']),
                },
                child: ExcludeSemantics(
                  child: ListTile(
                    leading: Icon(isRunning ? Icons.timer : Icons.timer_off, color: isRunning ? Colors.green : Colors.grey),
                    title: Text(isRunning ? lang.ongoingWork : lang.completedWork),
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
