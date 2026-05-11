import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:share_plus/share_plus.dart';
import 'package:blind_social/core/services/pocketbase_service.dart';
import 'package:blind_social/features/task_board/data/models/task_item.dart';
import 'package:blind_social/features/task_board/data/models/task_checklist.dart';
import 'package:blind_social/features/task_board/data/models/task_list_model.dart';
import 'package:blind_social/features/task_board/data/services/task_board_service.dart';
import 'package:blind_social/features/task_board/presentation/widgets/task_stopwatch_widget.dart';
import 'package:blind_social/features/task_board/presentation/widgets/task_voice_notes_widget.dart';
import 'package:blind_social/features/task_board/presentation/widgets/task_comments_widget.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:blind_social/core/providers/localization_provider.dart';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

class TaskDetailScreen extends ConsumerStatefulWidget {
  final TaskItem task;
  final List<TaskListM> allLists;

  const TaskDetailScreen({
    Key? key,
    required this.task,
    required this.allLists,
  }) : super(key: key);

  @override
  ConsumerState<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends ConsumerState<TaskDetailScreen> {
  final TaskBoardService _service = TaskBoardService();
  late TaskItem _task;
  List<TaskChecklist> _checklists = [];
  bool _isLoading = true;
  List<Map<String, dynamic>> _assigneesData = [];

  final FocusNode _addLabelBtnFocusNode = FocusNode();
  final FocusNode _addChecklistBtnFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _task = widget.task;
    _fetchDataCombined();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _announceRemainingDays();
    });
  }

  void _announceRemainingDays() {
    final lang = ref.read(localizationProvider);
    if (_task.dueDate != null) {
      final diff = _task.dueDate!.difference(DateTime.now());
      final d = diff.inDays;
      if (d > 0) {
        SemanticsService.announce(lang.remainingDays.replaceAll('{days}', d.toString()), TextDirection.ltr);
      } else if (d == 0) {
        SemanticsService.announce(lang.todayIsLastDay, TextDirection.ltr);
      } else {
        SemanticsService.announce(lang.overdueDays.replaceAll('{days}', d.abs().toString()), TextDirection.ltr);
      }
    }
  }

  Future<void> _selectDueDate() async {
    final lang = ref.read(localizationProvider);
    final ctrl = TextEditingController();
    
    if (_task.dueDate != null) {
      final dt = _task.dueDate!.toLocal();
      final day = dt.day.toString().padLeft(2, '0');
      final month = dt.month.toString().padLeft(2, '0');
      ctrl.text = '$day/$month/${dt.year}';
    }

    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(lang.setDueDateTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(
                label: lang.dueDateHint,
                child: TextField(
                  controller: ctrl,
                  keyboardType: TextInputType.datetime,
                  decoration: InputDecoration(
                    labelText: lang.dueDateLabel,
                    hintText: lang.dueDateExample,
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.calendar_today),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(lang.dueDateDeleteHint, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context), 
              child: Text(lang.no)
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, ctrl.text.trim());
              }, 
              child: Text(lang.save)
            ),
          ],
        );
      }
    );

    if (result != null) {
      DateTime? selectedDate;
      String dob = result;
      if (dob.isNotEmpty) {
        if (dob.length == 8 && !dob.contains('/')) {
          dob = '${dob.substring(0, 2)}/${dob.substring(2, 4)}/${dob.substring(4, 8)}';
        }
        final dateRegExp = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$');
        final match = dateRegExp.firstMatch(dob);
        if (match != null) {
          final int? day = int.tryParse(match.group(1)!);
          final int? month = int.tryParse(match.group(2)!);
          final int? year = int.tryParse(match.group(3)!);
          if (day != null && month != null && year != null) {
            try {
              selectedDate = DateTime(year, month, day);
            } catch (_) {}
          }
        }
        
        if (selectedDate == null) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(lang.invalidDateFormat)));
          return;
        }
      }

      setState(() => _isLoading = true);
      try {
        final updated = await _service.updateTaskDates(_task.id, _task.startDate, selectedDate);
        setState(() => _task = updated);
        if (selectedDate != null) {
          SemanticsService.announce(lang.dueDateSuccess, TextDirection.ltr);
          _announceRemainingDays();
        } else {
          SemanticsService.announce(lang.dueDateDeleted, TextDirection.ltr);
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${lang.error}: $e')));
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _addLabelBtnFocusNode.dispose();
    _addChecklistBtnFocusNode.dispose();
    super.dispose();
  }

  Future<void> _fetchDataCombined() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _fetchChecklists(),
      _fetchAssignees(),
    ]);
    if (mounted) setState(() => _isLoading = false);
  }
  
  Future<void> _fetchAssignees() async {
    List<Map<String, dynamic>> users = [];
    for (String id in _task.assignees) {
      try {
        final rec = await PocketBaseService.client.collection('_pb_users_auth_').getOne(id);
        users.add(rec.toJson());
      } catch (e) {
        // ignore
      }
    }
    if (mounted) {
      setState(() {
        _assigneesData = users;
      });
    }
  }

  Future<void> _fetchChecklists() async {
    final lang = ref.read(localizationProvider);
    try {
      final items = await _service.getChecklist(_task.id);
      setState(() {
        _checklists = items;
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${lang.error}: $e')));
    }
  }

  Future<void> _refreshTask() async {
    final lang = ref.read(localizationProvider);
    try {
      final updatedTaskRecord = await PocketBaseService.client.collection('task_items').getOne(_task.id);
      setState(() {
        _task = TaskItem.fromRecord(updatedTaskRecord);
      });
      await _fetchAssignees();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${lang.error}: $e')));
    }
  }

  Future<void> _editDescription() async {
    final lang = ref.read(localizationProvider);
    final ctrl = TextEditingController(text: _task.description);
    final isSaved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(lang.editDescription),
          content: TextField(
            controller: ctrl,
            maxLines: 5,
            decoration: InputDecoration(border: const OutlineInputBorder(), hintText: lang.descriptionHint),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(lang.no),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(lang.save),
            ),
          ],
        );
      },
    );

    if (isSaved == true) {
      try {
        final updated = await _service.updateTaskDetails(_task.id, description: ctrl.text);
        setState(() {
          _task = updated;
        });
        SemanticsService.announce(lang.descriptionSuccess, TextDirection.ltr);
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${lang.error}: $e')));
      }
    }
  }

  Future<void> _addLabel() async {
    final lang = ref.read(localizationProvider);
    final ctrl = TextEditingController();
    String? selectedColor = 'blue';
    final colors = ['blue', 'red', 'green', 'purple', 'orange'];

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(lang.addLabelTitle),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: ctrl,
                    decoration: InputDecoration(labelText: lang.labelNameLabel),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    children: colors.map((c) {
                      final colorObj = _getColor(c);
                      final cTr = _getColorNameTr(c);
                      return Semantics(
                        label: '$cTr ${lang.colorSelection}',
                        selected: selectedColor == c,
                        child: ExcludeSemantics(
                          child: ChoiceChip(
                            label: const Text(' '),
                            selected: selectedColor == c,
                            selectedColor: colorObj.withOpacity(0.5),
                            backgroundColor: colorObj,
                            onSelected: (val) {
                              setDialogState(() => selectedColor = c);
                            },
                          ),
                        ),
                      );
                    }).toList(),
                  )
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, null),
                  child: Text(lang.no),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (ctrl.text.isEmpty) return;
                    Navigator.pop(context, {'text': ctrl.text, 'color': selectedColor!});
                  },
                  child: Text(lang.add),
                ),
              ],
            );
          }
        );
      },
    );

    if (result != null) {
      try {
        final newLabels = List.from(_task.labels)..add(result);
        final updated = await _service.updateTaskLabels(_task.id, newLabels);
        setState(() {
          _task = updated;
        });
        SemanticsService.announce(lang.labelAdded, TextDirection.ltr);
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${lang.error}: $e')));
      }
    }
  }

  Future<void> _removeLabel(dynamic label) async {
    final lang = ref.read(localizationProvider);
    try {
      final newLabels = List.from(_task.labels)..remove(label);
      final updated = await _service.updateTaskLabels(_task.id, newLabels);
      setState(() {
        _task = updated;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _addLabelBtnFocusNode.requestFocus();
        SemanticsService.announce(lang.labelDeleted, TextDirection.ltr);
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${lang.error}: $e')));
    }
  }

  void _shareTaskInformation() {
    final lang = ref.read(localizationProvider);
    final buffer = StringBuffer();
    buffer.writeln('${lang.shareTaskTitle}: ${_task.title}');
    buffer.writeln('${lang.shareTaskStatus}: ${_task.isCompleted ? lang.completed : lang.incomplete}');
    
    buffer.writeln('${lang.shareTaskCreated}: ${_formatDt(_task.created)}');
    if (_task.dueDate != null) {
      buffer.writeln('${lang.shareTaskDue}: ${_formatDt(_task.dueDate!)}');
      final diff = _task.dueDate!.difference(DateTime.now());
      final d = diff.inDays;
      if (d > 0) {
        buffer.writeln('${lang.shareTaskRemaining}: $d ${lang.days}.');
      } else if (d == 0) {
        buffer.writeln('${lang.shareTaskRemaining}: ${lang.todayIsLastDay}');
      } else {
        buffer.writeln('${lang.shareTaskRemaining}: ${lang.overdueDays.replaceAll('{days}', d.abs().toString())}');
      }
    }
    buffer.writeln();

    if (_task.description.isNotEmpty) {
      buffer.writeln('${lang.shareTaskDescription}:');
      buffer.writeln(_task.description);
      buffer.writeln();
    }

    if (_task.labels.isNotEmpty) {
      buffer.writeln('${lang.shareTaskLabels}:');
      for (var lbl in _task.labels) {
        buffer.writeln('- ${lbl['text']}');
      }
      buffer.writeln();
    }

    if (_assigneesData.isNotEmpty) {
      buffer.writeln('${lang.shareTaskAssignees}:');
      final assigneesStr = _assigneesData.map((u) => (u['full_name'] as String? ?? '').isNotEmpty == true ? u['full_name'] : u['username']).join(', ');
      buffer.writeln(assigneesStr);
      buffer.writeln();
    }

    if (_checklists.isNotEmpty) {
      buffer.writeln('${lang.shareTaskChecklist}:');
      for (var c in _checklists) {
        buffer.writeln('- ${c.title} (${c.isCompleted ? lang.completed : lang.incomplete})');
      }
      buffer.writeln();
    }

    if (_task.resources.isNotEmpty) {
      buffer.writeln('${lang.shareTaskResources}:');
      for (var res in _task.resources) {
        final urlString = res is Map ? (res['url']?.toString() ?? '') : res.toString();
        final titleString = res is Map ? (res['title']?.toString() ?? urlString) : urlString;
        
        if (titleString != urlString) {
          buffer.writeln('- $titleString: $urlString');
        } else {
          buffer.writeln('- $urlString');
        }
      }
      buffer.writeln();
    }

    if (_task.voiceNotes.isNotEmpty) {
      buffer.writeln('${lang.shareTaskVoiceNotes}: ${_task.voiceNotes.length} ${lang.shareTaskVoiceNotesCount}');
      buffer.writeln();
    }

    if (_task.timeLogs.isNotEmpty) {
      Duration total = Duration.zero;
      for (var log in _task.timeLogs) {
        final start = DateTime.parse(log['start']);
        final end = log['end'] != null ? DateTime.parse(log['end']) : DateTime.now().toUtc();
        total += end.difference(start);
      }
      if (total.inSeconds > 0) {
        int days = total.inDays;
        int hours = total.inHours % 24;
        int mins = total.inMinutes % 60;
        List<String> p = [];
        if(days > 0) p.add("$days ${lang.days}");
        if(hours > 0) p.add("$hours ${lang.hours}");
        if(mins > 0) p.add("$mins ${lang.minutes}");
        if(p.isEmpty) p.add(lang.lessThanAMinute);
        buffer.writeln("${lang.shareTaskStopwatch}: ${lang.shareTaskTimeSpent.replaceAll('{time}', p.join(" "))}");
        buffer.writeln();
      }
    }

    buffer.writeln('--------------------');
    buffer.writeln(lang.shareTaskFooter);

    Share.share(buffer.toString());
  }

  Future<void> _moveList() async {
    final lang = ref.read(localizationProvider);
    final newListId = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(lang.moveTaskTitle),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              addAutomaticKeepAlives: false,
              addRepaintBoundaries: true,
              shrinkWrap: true,
              itemCount: widget.allLists.length,
              itemBuilder: (context, index) {
                final list = widget.allLists[index];
                if (list.id == _task.listId) return const SizedBox.shrink();
                return ListTile(
                  title: Text(list.name),
                  onTap: () => Navigator.pop(context, list.id),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: Text(lang.no),
            ),
          ],
        );
      },
    );

    if (newListId != null) {
      try {
        final updated = await _service.updateTaskDetails(_task.id, listId: newListId);
        setState(() {
          _task = updated;
        });
        SemanticsService.announce(lang.moveTaskSuccess, TextDirection.ltr);
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${lang.error}: $e')));
      }
    }
  }

  Color _getColor(String c) {
    switch (c) {
      case 'red': return Colors.red;
      case 'green': return Colors.green;
      case 'purple': return Colors.purple;
      case 'orange': return Colors.orange;
      case 'blue':
      default: return Colors.blue;
    }
  }

  String _getColorNameTr(String c) {
    final lang = ref.read(localizationProvider);
    switch (c) {
      case 'red': return lang.colorRed;
      case 'green': return lang.colorGreen;
      case 'purple': return lang.colorPurple;
      case 'orange': return lang.colorOrange;
      case 'blue': return lang.colorBlue;
      default: return lang.colorBlue;
    }
  }

  void _announceChecklistProgress() {
    final lang = ref.read(localizationProvider);
    if (_checklists.isEmpty) return;
    int completedCount = _checklists.where((c) => c.isCompleted).length;
    int total = _checklists.length;
    int percentage = ((completedCount / total) * 100).round();
    SemanticsService.announce(
      lang.checklistProgress
        .replaceAll('{total}', total.toString())
        .replaceAll('{completed}', completedCount.toString())
        .replaceAll('{percentage}', percentage.toString()), 
      TextDirection.ltr
    );
  }

  Future<void> _addChecklistItem() async {
    final lang = ref.read(localizationProvider);
    final ctrl = TextEditingController();
    final isSaved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(lang.newChecklistItemTitle),
        content: TextField(controller: ctrl, decoration: InputDecoration(labelText: lang.newChecklistItemLabel)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(lang.no)),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: Text(lang.add)),
        ],
      )
    );

    if (isSaved == true && ctrl.text.isNotEmpty) {
      try {
        final order = _checklists.isEmpty ? 1 : _checklists.last.order + 1;
        final newItem = await _service.createChecklistItem(_task.id, ctrl.text, order);
        setState(() {
          _checklists.add(newItem);
        });
        _announceChecklistProgress();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${lang.error}: $e')));
      }
    }
  }

  Future<void> _toggleChecklist(TaskChecklist item) async {
    final lang = ref.read(localizationProvider);
    try {
      final updated = await _service.updateChecklistState(item.id, !item.isCompleted);
      setState(() {
        final idx = _checklists.indexWhere((c) => c.id == item.id);
        if (idx != -1) _checklists[idx] = updated;
      });
      _announceChecklistProgress();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${lang.error}: $e')));
    }
  }

  Future<void> _deleteChecklistItem(TaskChecklist item) async {
    final lang = ref.read(localizationProvider);
    try {
      await _service.deleteChecklistItem(item.id);
      setState(() {
        _checklists.removeWhere((c) => c.id == item.id);
      });
      _announceChecklistProgress();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _addChecklistBtnFocusNode.requestFocus();
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${lang.error}: $e')));
    }
  }

  Future<void> _deleteTask() async {
    final lang = ref.read(localizationProvider);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(lang.deleteTaskTitle),
        content: Text(lang.deleteTaskConfirmDetail),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(lang.no)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: Text(lang.delete, style: const TextStyle(color: Colors.white)),
          ),
        ],
      )
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        await _service.deleteTask(_task.id);
        SemanticsService.announce(lang.deleteTaskSuccess, TextDirection.ltr);
        if (mounted) Navigator.pop(context, true);
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${lang.error}: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  Future<String?> _fetchPageTitle(String url) async {
    try {
      final uri = Uri.tryParse(url);
      if (uri == null || !uri.isAbsolute) return null;
      
      final response = await http.get(uri).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final match = RegExp(r'<title[^>]*>([^<]+)</title>', caseSensitive: false).firstMatch(response.body);
        if (match != null && match.groupCount > 0) {
          final title = match.group(1)?.trim();
          if (title != null && title.isNotEmpty) {
            return title.replaceAll('&nbsp;', ' ')
                        .replaceAll('&amp;', '&')
                        .replaceAll('&lt;', '<')
                        .replaceAll('&gt;', '>')
                        .replaceAll('&quot;', '"')
                        .replaceAll('&#39;', "'")
                        .replaceAll('\n', '')
                        .replaceAll('\r', '');
          }
        }
      }
    } catch (_) {}
    return null;
  }

  Future<void> _addResource() async {
    final lang = ref.read(localizationProvider);
    final ctrl = TextEditingController();
    final isSaved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(lang.addResourceTitle),
        content: Row(
          children: [
            Expanded(
              child: TextField(
                controller: ctrl,
                decoration: InputDecoration(labelText: lang.addResourceLabel, hintText: lang.addResourceHint),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.paste),
              tooltip: lang.pasteFromClipboard,
              onPressed: () async {
                final data = await Clipboard.getData(Clipboard.kTextPlain);
                if (data != null && data.text != null) {
                  ctrl.text = data.text!;
                }
              },
            )
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(lang.no)),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: Text(lang.add)),
        ],
      )
    );

    if (isSaved == true && ctrl.text.isNotEmpty) {
      setState(() => _isLoading = true);
      try {
        final url = ctrl.text.trim();
        final title = await _fetchPageTitle(url);
        final resObj = {
          'url': url,
          'title': title
        };
        final newResources = List.from(_task.resources)..add(resObj);
        final updated = await _service.updateTaskResources(_task.id, newResources);
        setState(() {
          _task = updated;
        });
        SemanticsService.announce(lang.addResourceSuccess, TextDirection.ltr);
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${lang.error}: $e')));
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _removeResource(dynamic res) async {
    final lang = ref.read(localizationProvider);
    try {
      final newResources = List.from(_task.resources)..remove(res);
      final updated = await _service.updateTaskResources(_task.id, newResources);
      setState(() {
        _task = updated;
      });
      SemanticsService.announce(lang.deleteResourceSuccess, TextDirection.ltr);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${lang.error}: $e')));
    }
  }

  Future<void> _copyResource(String url) async {
    final lang = ref.read(localizationProvider);
    await Clipboard.setData(ClipboardData(text: url));
    SemanticsService.announce(lang.copyUrlSemantics, TextDirection.ltr);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(lang.copyUrlSuccess)));
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(localizationProvider);
    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, true); // Her zaman değişiklik var kabul edip sayfayı yenilemek için true dönüyoruz
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Focus(
            autofocus: true,
            child: Text('${_task.title} ${lang.taskDetails}'),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.share),
              tooltip: lang.shareTask,
              onPressed: _shareTaskInformation,
            ),
            IconButton(
              icon: const Icon(Icons.drive_file_move),
              tooltip: lang.changeList,
              onPressed: _moveList,
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              tooltip: lang.deleteTaskTitle,
              onPressed: _deleteTask,
            )
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_task.title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('${lang.createdDate}: ${_formatDt(_task.created)}', style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(_task.dueDate != null ? '${lang.dueDateTarget}: ${_formatDt(_task.dueDate!)}' : lang.noDueDate, style: const TextStyle(color: Colors.grey)),
                    IconButton(
                      icon: const Icon(Icons.edit_calendar),
                      tooltip: lang.setDueDate,
                      onPressed: _selectDueDate,
                    )
                  ]
                ),
                const SizedBox(height: 16),
                
                // Etiketler
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ..._task.labels.map((lbl) {
                        final colorName = lbl['color'] ?? 'blue';
                        final cTr = _getColorNameTr(colorName);
                        return Semantics(
                          label: '${lbl['text']} ${lang.label}. $cTr. ${lang.taskOptionsHint}',
                          button: true,
                          customSemanticsActions: {
                            CustomSemanticsAction(label: lang.labelDeleted): () => _removeLabel(lbl),
                          },
                          child: ExcludeSemantics(
                            child: Chip(
                              label: Text(lbl['text'] ?? '', style: const TextStyle(color: Colors.white)),
                              backgroundColor: _getColor(colorName),
                              onDeleted: () => _removeLabel(lbl),
                              deleteIconColor: Colors.white,
                            ),
                          ),
                        );
                    }).toList(),
                    ActionChip(
                      focusNode: _addLabelBtnFocusNode,
                      label: Text(lang.addLabelTitle),
                      avatar: const Icon(Icons.add, size: 16),
                      onPressed: _addLabel,
                    )
                  ],
                ),
                const SizedBox(height: 24),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(lang.assignees, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ActionChip(
                      label: Text(_task.assignees.contains(PocketBaseService.client.authStore.model?.id) ? lang.leaveResponsibility : lang.makeMeResponsible),
                      onPressed: () async {
                        final uId = PocketBaseService.client.authStore.model?.id;
                        if (uId == null) return;
                        try {
                          final updated = await _service.toggleAssignee(_task.id, uId);
                          setState(() {
                            _task = updated;
                          });
                          await _fetchAssignees();
                          SemanticsService.announce(lang.statusUpdated, TextDirection.ltr);
                        } catch (e) {
                          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${lang.error}: $e')));
                        }
                      },
                    )
                  ],
                ),
                if (_assigneesData.isEmpty)
                  Text(lang.noAssignees)
                else
                  Text('${_assigneesData.map((u) => (u['full_name'] as String? ?? '').isNotEmpty == true ? u['full_name'] : u['username']).join(', ')} ${lang.assigneesAssigned}'),
                const SizedBox(height: 24),

                // Açıklama
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(lang.description, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: const Icon(Icons.edit),
                      tooltip: lang.editDescription,
                      onPressed: _editDescription,
                    )
                  ],
                ),
                Text(
                  _task.description.isEmpty ? lang.noDescription : _task.description,
                ),
                const SizedBox(height: 24),
                const Divider(),

                // Kaynaklar (Resources)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(lang.resources, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: const Icon(Icons.add),
                      tooltip: lang.addResource,
                      onPressed: _addResource,
                    )
                  ],
                ),
                if (_task.resources.isEmpty)
                  Text(lang.noResources)
                else
                  ..._task.resources.map((res) {
                    final String urlString = res is Map ? (res['url']?.toString() ?? '') : res.toString();
                    final String titleString = res is Map ? (res['title']?.toString() ?? urlString) : urlString;
                    
                    return Card(
                      child: Semantics(
                        label: titleString != urlString ? '${lang.checklistTitle}: $titleString' : 'URL: $urlString',
                        button: true,
                        customSemanticsActions: {
                          CustomSemanticsAction(label: lang.copyUrlSuccess): () => _copyResource(urlString),
                          CustomSemanticsAction(label: lang.delete): () => _removeResource(res),
                        },
                        child: ExcludeSemantics(
                          child: ListTile(
                            leading: const Icon(Icons.link),
                            title: Text(titleString, maxLines: 2, overflow: TextOverflow.ellipsis),
                            subtitle: titleString != urlString ? Text(urlString, maxLines: 1, overflow: TextOverflow.ellipsis) : null,
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.copy),
                                  tooltip: lang.copy,
                                  onPressed: () => _copyResource(urlString),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  tooltip: lang.delete,
                                  onPressed: () => _removeResource(res),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),

                const SizedBox(height: 24),
                const Divider(),

                // Kontrol Listesi
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(lang.checklist, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        if (_checklists.isNotEmpty)
                          Builder(
                            builder: (context) {
                              int completedCount = _checklists.where((c) => c.isCompleted).length;
                              int total = _checklists.length;
                              int percentage = ((completedCount / total) * 100).round();
                              return Padding(
                                padding: const EdgeInsets.all(0),
                                child: Text(lang.checklistProgress.replaceAll('{total}', total.toString()).replaceAll('{completed}', completedCount.toString()).replaceAll('{percentage}', percentage.toString()), style: const TextStyle(fontSize: 14, color: Colors.white70)),
                              );
                            }
                          ),
                      ],
                    ),
                    IconButton(
                      focusNode: _addChecklistBtnFocusNode,
                      icon: const Icon(Icons.add),
                      tooltip: lang.addChecklistItem,
                      onPressed: _addChecklistItem,
                    )
                  ],
                ),
                if (_isLoading) const Center(child: CircularProgressIndicator())
                else if (_checklists.isEmpty) Text(lang.checklistEmpty)
                else ..._checklists.map((c) {
                  return Card(
                    child: Semantics(
                      label: '${c.title}. ${c.isCompleted ? lang.completed : lang.incomplete}. ${lang.taskOptionsHint}',
                      button: true,
                      customSemanticsActions: {
                        CustomSemanticsAction(label: c.isCompleted ? lang.markAsIncomplete : lang.markAsCompleted): () => _toggleChecklist(c),
                        CustomSemanticsAction(label: lang.delete): () => _deleteChecklistItem(c),
                      },
                      child: ExcludeSemantics(
                        child: ListTile(
                          leading: Checkbox(
                            value: c.isCompleted,
                            onChanged: (v) => _toggleChecklist(c),
                          ),
                          title: Text(
                            c.title,
                            style: TextStyle(
                              decoration: c.isCompleted ? TextDecoration.lineThrough : null,
                            ),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            tooltip: lang.delete,
                            onPressed: () => _deleteChecklistItem(c),
                          ),
                          onTap: () => _toggleChecklist(c),
                        ),
                      ),
                    ),
                  );
                }).toList(),
                
                const SizedBox(height: 24),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.chat),
                  title: Text(lang.comments, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(lang.taskMessagesSubtitle),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (c) => Scaffold(
                          appBar: AppBar(
                            title: Semantics(
                              label: '${lang.taskMessagesSemantics} ${_task.title}',
                              child: Text(
                                '${_task.title} - ${lang.comments}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          body: SafeArea(
                            child: TaskCommentsWidget(taskId: _task.id),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                
                const SizedBox(height: 24),
                const Divider(),
                TaskVoiceNotesWidget(
                  task: _task,
                  service: _service,
                  onChanged: () => _refreshTask(),
                ),
                
                const SizedBox(height: 24),
                const Divider(),
                TaskStopwatchWidget(
                  task: _task,
                  service: _service,
                  onChanged: () => _refreshTask(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDt(DateTime dt) {
    final lang = ref.read(localizationProvider);
    final now = DateTime.now();
    final dLocal = dt.toLocal();
    final months = lang.months;
    if (now.year == dLocal.year) return "${dLocal.day} ${months[dLocal.month]}";
    return "${dLocal.day} ${months[dLocal.month]} ${dLocal.year}";
  }
}
