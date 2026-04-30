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

class TaskDetailScreen extends StatefulWidget {
  final TaskItem task;
  final List<TaskListM> allLists;

  const TaskDetailScreen({
    Key? key,
    required this.task,
    required this.allLists,
  }) : super(key: key);

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
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
    try {
      final items = await _service.getChecklist(_task.id);
      setState(() {
        _checklists = items;
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
    }
  }

  Future<void> _refreshTask() async {
    try {
      final updatedTaskRecord = await PocketBaseService.client.collection('task_items').getOne(_task.id);
      setState(() {
        _task = TaskItem.fromRecord(updatedTaskRecord);
      });
      await _fetchAssignees();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Görev yenilenemedi: $e')));
    }
  }

  Future<void> _editDescription() async {
    final ctrl = TextEditingController(text: _task.description);
    final isSaved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Açıklama Düzenle'),
          content: TextField(
            controller: ctrl,
            maxLines: 5,
            decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Açıklama giriniz...'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('İptal'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Kaydet'),
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
        SemanticsService.announce('Açıklama güncellendi', TextDirection.ltr);
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
      }
    }
  }

  Future<void> _addLabel() async {
    final ctrl = TextEditingController();
    String? selectedColor = 'blue';
    final colors = ['blue', 'red', 'green', 'purple', 'orange'];

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Etiket Ekle'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: ctrl,
                    decoration: const InputDecoration(labelText: 'Etiket Adı'),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    children: colors.map((c) {
                      final colorObj = _getColor(c);
                      final cTr = _getColorNameTr(c);
                      return Semantics(
                        label: '$cTr renk seçimi',
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
                  child: const Text('İptal'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (ctrl.text.isEmpty) return;
                    Navigator.pop(context, {'text': ctrl.text, 'color': selectedColor!});
                  },
                  child: const Text('Ekle'),
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
        SemanticsService.announce('Etiket eklendi', TextDirection.ltr);
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
      }
    }
  }

  Future<void> _removeLabel(dynamic label) async {
    try {
      final newLabels = List.from(_task.labels)..remove(label);
      final updated = await _service.updateTaskLabels(_task.id, newLabels);
      setState(() {
        _task = updated;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _addLabelBtnFocusNode.requestFocus();
        SemanticsService.announce('Etiket silindi', TextDirection.ltr);
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
    }
  }

  void _shareTaskInformation() {
    final buffer = StringBuffer();
    buffer.writeln('Görev Adı: ${_task.title}');
    buffer.writeln('Durum: ${_task.isCompleted ? "Tamamlandı" : "Devam Ediyor"}');
    buffer.writeln();

    if (_task.description.isNotEmpty) {
      buffer.writeln('Açıklama:');
      buffer.writeln(_task.description);
      buffer.writeln();
    }

    if (_task.labels.isNotEmpty) {
      buffer.writeln('Etiketler:');
      for (var lbl in _task.labels) {
        buffer.writeln('- ${lbl['text']}');
      }
      buffer.writeln();
    }

    if (_assigneesData.isNotEmpty) {
      buffer.writeln('Sorumlular (Atananlar):');
      final assigneesStr = _assigneesData.map((u) => (u['full_name'] as String? ?? '').isNotEmpty == true ? u['full_name'] : u['username']).join(', ');
      buffer.writeln(assigneesStr);
      buffer.writeln();
    }

    if (_checklists.isNotEmpty) {
      buffer.writeln('Kontrol Listesi:');
      for (var c in _checklists) {
        buffer.writeln('- ${c.title} (${c.isCompleted ? "Tamamlandı" : "Tamamlanmadı"})');
      }
      buffer.writeln();
    }

    if (_task.voiceNotes.isNotEmpty) {
      buffer.writeln('Sesli Notlar: ${_task.voiceNotes.length} adet sesli not mevcut.');
      buffer.writeln();
    }

    if (_task.startDate != null) {
      final now = DateTime.now();
      final dtStart = _task.startDate!;
      final dtEnd = _task.dueDate;

      String formatDt(DateTime dt) {
        const months = ["", "Ocak", "Şubat", "Mart", "Nisan", "Mayıs", "Haziran", "Temmuz", "Ağustos", "Eylül", "Ekim", "Kasım", "Aralık"];
        if (now.year == dt.year) return "${dt.day} ${months[dt.month]}";
        return "${dt.day} ${months[dt.month]} ${dt.year}";
      }

      if (dtEnd != null) {
        final diff = dtEnd.difference(dtStart);
        if (!diff.isNegative) {
          int days = diff.inDays;
          int hours = diff.inHours % 24;
          int mins = diff.inMinutes % 60;
          List<String> p = [];
          if(days > 0) p.add("$days gün");
          if(hours > 0) p.add("$hours saat");
          if(mins > 0) p.add("$mins dakika");
          if(p.isEmpty) p.add("1 dakikadan az");
          buffer.writeln("Görev Kronometresi: Bu görev üzerinde ${p.join(" ")} çalışıldı. ${formatDt(dtStart)} tarihinde başlandı, ${formatDt(dtEnd)} tarihinde bitirildi.");
        }
      } else {
        final diff = now.difference(dtStart);
        if (!diff.isNegative) {
          int days = diff.inDays;
          int hours = diff.inHours % 24;
          int mins = diff.inMinutes % 60;
          List<String> p = [];
          if(days > 0) p.add("$days gün");
          if(hours > 0) p.add("$hours saat");
          if(mins > 0) p.add("$mins dakika");
          if(p.isEmpty) p.add("1 dakikadan az");
          buffer.writeln("Görev Kronometresi: Görev üzerinde şu ana kadar ${p.join(" ")} çalışıldı. Başlama tarihi: ${formatDt(dtStart)}.");
        }
      }
      buffer.writeln();
    }

    buffer.writeln('--------------------');
    buffer.writeln('Blind Social - Görev Planlayıcısı ile oluşturulmuştur.');

    Share.share(buffer.toString());
  }

  Future<void> _moveList() async {
    final newListId = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Listeyi Değiştir'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
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
              child: const Text('İptal'),
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
        SemanticsService.announce('Görev başka listeye taşındı', TextDirection.ltr);
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
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
    switch (c) {
      case 'red': return 'Kırmızı';
      case 'green': return 'Yeşil';
      case 'purple': return 'Mor';
      case 'orange': return 'Turuncu';
      case 'blue': return 'Mavi';
      default: return 'Mavi';
    }
  }

  void _announceChecklistProgress() {
    if (_checklists.isEmpty) return;
    int completedCount = _checklists.where((c) => c.isCompleted).length;
    int total = _checklists.length;
    int percentage = ((completedCount / total) * 100).round();
    SemanticsService.announce('$total işten $completedCount bitti, yüzde $percentage tamamlandı', TextDirection.ltr);
  }

  Future<void> _addChecklistItem() async {
    final ctrl = TextEditingController();
    final isSaved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Yeni Kontrol Maddesi'),
        content: TextField(controller: ctrl, decoration: const InputDecoration(labelText: 'Başlık')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('İptal')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Ekle')),
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
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
      }
    }
  }

  Future<void> _toggleChecklist(TaskChecklist item) async {
    try {
      final updated = await _service.updateChecklistState(item.id, !item.isCompleted);
      setState(() {
        final idx = _checklists.indexWhere((c) => c.id == item.id);
        if (idx != -1) _checklists[idx] = updated;
      });
      _announceChecklistProgress();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
    }
  }

  Future<void> _deleteChecklistItem(TaskChecklist item) async {
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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, true); // Her zaman değişiklik var kabul edip sayfayı yenilemek için true dönüyoruz
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Focus(
            autofocus: true,
            child: Text('${_task.title} isimli görevin detayları'),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.share),
              tooltip: 'Kartı Paylaş',
              onPressed: _shareTaskInformation,
            ),
            IconButton(
              icon: const Icon(Icons.drive_file_move),
              tooltip: 'Listeyi Değiştir',
              onPressed: _moveList,
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
                          label: '${lbl['text']} isimli $cTr renkli etiket. Etiketi silmek için işlemler menüsünü açın ve özellikleri kullanın.',
                          button: true,
                          customSemanticsActions: {
                            const CustomSemanticsAction(label: 'Etiketi Sil'): () => _removeLabel(lbl),
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
                      label: const Text('Etiket Ekle'),
                      avatar: const Icon(Icons.add, size: 16),
                      onPressed: _addLabel,
                    )
                  ],
                ),
                const SizedBox(height: 24),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Sorumlular (Atananlar)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ActionChip(
                      label: Text(_task.assignees.contains(PocketBaseService.client.authStore.model?.id) ? 'Sorumluluğu Bırak' : 'Beni Sorumlu Yap'),
                      onPressed: () async {
                        final uId = PocketBaseService.client.authStore.model?.id;
                        if (uId == null) return;
                        try {
                          final updated = await _service.toggleAssignee(_task.id, uId);
                          setState(() {
                            _task = updated;
                          });
                          await _fetchAssignees();
                          SemanticsService.announce("Sorumluluk durumu güncellendi", TextDirection.ltr);
                        } catch (e) {
                          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
                        }
                      },
                    )
                  ],
                ),
                if (_assigneesData.isEmpty)
                  const Text('Bu göreve henüz kimse atanmadı.')
                else
                  Text('${_assigneesData.map((u) => (u['full_name'] as String? ?? '').isNotEmpty == true ? u['full_name'] : u['username']).join(', ')} isimli kullanıcılar bu görev için atandı.'),
                const SizedBox(height: 24),

                // Açıklama
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Açıklama', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: const Icon(Icons.edit),
                      tooltip: 'Açıklamayı Düzenle',
                      onPressed: _editDescription,
                    )
                  ],
                ),
                Text(
                  _task.description.isEmpty ? 'Açıklama eklenmemiş.' : _task.description,
                ),
                const SizedBox(height: 24),
                const Divider(),

                // Kontrol Listesi
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Kontrol Listesi', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        if (_checklists.isNotEmpty)
                          Builder(
                            builder: (context) {
                              int completedCount = _checklists.where((c) => c.isCompleted).length;
                              int total = _checklists.length;
                              int percentage = ((completedCount / total) * 100).round();
                              return Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Text('Yüzde $percentage Tamamlandı ($completedCount/$total)', style: const TextStyle(fontSize: 14, color: Colors.white70)),
                              );
                            }
                          ),
                      ],
                    ),
                    IconButton(
                      focusNode: _addChecklistBtnFocusNode,
                      icon: const Icon(Icons.add),
                      tooltip: 'Madde Ekle',
                      onPressed: _addChecklistItem,
                    )
                  ],
                ),
                if (_isLoading) const Center(child: CircularProgressIndicator())
                else if (_checklists.isEmpty) const Text('Kontrol listesi boş.')
                else ..._checklists.map((c) {
                  return Card(
                    child: Semantics(
                      label: '${c.title}. ${c.isCompleted ? "Tamamlandı" : "Tamamlanmadı"}.',
                      button: true,
                      customSemanticsActions: {
                        CustomSemanticsAction(label: c.isCompleted ? 'Tamamlanmadı Olarak İşaretle' : 'Tamamlandı Olarak İşaretle'): () => _toggleChecklist(c),
                        const CustomSemanticsAction(label: 'Maddeyi Sil'): () => _deleteChecklistItem(c),
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
                            tooltip: 'Sil',
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
}
