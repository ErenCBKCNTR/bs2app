import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:share_plus/share_plus.dart';
import 'package:blind_social/core/services/pocketbase_service.dart';
import 'package:blind_social/features/task_board/data/models/task_item.dart';
import 'package:blind_social/features/task_board/data/models/task_checklist.dart';
import 'package:blind_social/features/task_board/data/models/task_list_model.dart';
import 'package:blind_social/features/task_board/data/services/task_board_service.dart';

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

  @override
  void initState() {
    super.initState();
    _task = widget.task;
    _fetchChecklists();
  }

  Future<void> _fetchChecklists() async {
    try {
      final items = await _service.getChecklist(_task.id);
      setState(() {
        _checklists = items;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
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
      SemanticsService.announce('Etiket silindi', TextDirection.ltr);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
    }
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
              onPressed: () {
                Share.share('Görev: ${_task.title}\nAçıklama: ${_task.description}\nDurum: ${_task.isCompleted ? "Tamamlandı" : "Devam Ediyor"}\nLink: https://api.cabukcan.com/task/${_task.id}');
              },
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
                          SemanticsService.announce("Sorumluluk durumu güncellendi", TextDirection.ltr);
                        } catch (e) {
                          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
                        }
                      },
                    )
                  ],
                ),
                Text('Toplam ${_task.assignees.length} kişi bu görevden sorumlu.'),
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
                    const Text('Kontrol Listesi', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    IconButton(
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
                  );
                }).toList(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
