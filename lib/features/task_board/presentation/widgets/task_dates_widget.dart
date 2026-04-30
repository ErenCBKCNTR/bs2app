import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:blind_social/features/task_board/data/models/task_item.dart';
import 'package:blind_social/features/task_board/data/services/task_board_service.dart';

class TaskDatesWidget extends StatefulWidget {
  final TaskItem task;
  final TaskBoardService service;
  final VoidCallback onChanged;

  const TaskDatesWidget({Key? key, required this.task, required this.service, required this.onChanged}) : super(key: key);

  @override
  State<TaskDatesWidget> createState() => _TaskDatesWidgetState();
}

class _TaskDatesWidgetState extends State<TaskDatesWidget> {
  bool _isLoading = false;

  Future<void> _pickDate(bool isStart) async {
    final initialDate = isStart
        ? (widget.task.startDate ?? DateTime.now())
        : (widget.task.dueDate ?? widget.task.startDate ?? DateTime.now());
    
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked != null && mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(initialDate),
      );

      if (time != null && mounted) {
        final finalDateTime = DateTime(picked.year, picked.month, picked.day, time.hour, time.minute);
        
        setState(() => _isLoading = true);
        try {
          DateTime? newStart = widget.task.startDate;
          DateTime? newDue = widget.task.dueDate;
          
          if (isStart) newStart = finalDateTime;
          else newDue = finalDateTime;

          await widget.service.updateTaskDates(widget.task.id, newStart, newDue);
          widget.onChanged();
        } catch (e) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
        } finally {
          if (mounted) setState(() => _isLoading = false);
        }
      }
    }
  }

  String _formatTimeDiff() {
    if (widget.task.startDate == null || widget.task.dueDate == null) return "Henüz hesaplanamadı.";
    final diff = widget.task.dueDate!.difference(widget.task.startDate!);
    if (diff.isNegative) return "Bitiş tarihi başlangıçtan önce.";
    
    int days = diff.inDays;
    int hours = diff.inHours % 24;
    int mins = diff.inMinutes % 60;
    
    return "Bu görev üstünde $days gün $hours saat $mins dakika çalıştınız.";
  }
  
  String _formatDateStr(DateTime? dt) {
    if (dt == null) return "Eklenmedi";
    return "${dt.day.toString().padLeft(2,'0')}/${dt.month.toString().padLeft(2,'0')}/${dt.year} ${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}";
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Tarihler', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        if (_isLoading) const Center(child: CircularProgressIndicator())
        else ...[
          Card(
            child: ListTile(
              title: const Text('Başlangıç Tarihi'),
              subtitle: Text(_formatDateStr(widget.task.startDate)),
              trailing: const Icon(Icons.calendar_month),
              onTap: () => _pickDate(true),
            ),
          ),
          Card(
            child: ListTile(
              title: const Text('Bitiş Tarihi'),
              subtitle: Text(_formatDateStr(widget.task.dueDate)),
              trailing: const Icon(Icons.calendar_month),
              onTap: () => _pickDate(false),
            ),
          ),
          if (widget.task.startDate != null && widget.task.dueDate != null)
             Semantics(
               label: _formatTimeDiff(),
               child: Padding(
                 padding: const EdgeInsets.only(top: 8.0, left: 4.0),
                 child: Text(_formatTimeDiff(), style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.amber)),
               ),
             )
        ]
      ],
    );
  }
}
