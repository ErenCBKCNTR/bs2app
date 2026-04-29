import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:blind_social/features/task_board/data/models/task_board.dart';
import 'package:blind_social/features/task_board/data/models/task_list_model.dart';
import 'package:blind_social/features/task_board/data/models/task_item.dart';
import 'package:blind_social/features/task_board/data/services/task_board_service.dart';

class TaskBoardDetailScreen extends StatefulWidget {
  final TaskBoard board;
  const TaskBoardDetailScreen({super.key, required this.board});

  @override
  State<TaskBoardDetailScreen> createState() => _TaskBoardDetailScreenState();
}

class _TaskBoardDetailScreenState extends State<TaskBoardDetailScreen> {
  final TaskBoardService _service = TaskBoardService();
  bool _isLoading = true;
  List<TaskListM> _lists = [];
  Map<String, List<TaskItem>> _tasksByList = {};

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final lists = await _service.getLists(widget.board.id);
      final Map<String, List<TaskItem>> tasksTemp = {};
      
      for (var list in lists) {
        tasksTemp[list.id] = await _service.getTasks(list.id);
      }

      if (mounted) {
        setState(() {
          _lists = lists;
          _tasksByList = tasksTemp;
        });
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _createListDialog() async {
    final nameCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      useSafeArea: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Yeni Liste Ekle'),
              content: Form(
                key: formKey,
                child: TextFormField(
                  controller: nameCtrl,
                  maxLength: 100,
                  enabled: !isSaving,
                  decoration: const InputDecoration(labelText: 'Liste Adı', hintText: 'Örn: Yapılacaklar, Tamamlananlar'),
                  validator: (v) => v != null && v.trim().isEmpty ? 'Lütfen liste adı giriniz' : null,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(context),
                  child: const Text('İptal'),
                ),
                ElevatedButton(
                  onPressed: isSaving ? null : () async {
                    if (!formKey.currentState!.validate()) return;
                    setStateDialog(() => isSaving = true);
                    try {
                      final order = _lists.length + 1;
                      await _service.createList(widget.board.id, nameCtrl.text.trim(), order);
                      SemanticsService.announce("Liste eklendi", TextDirection.ltr);
                      if (context.mounted) {
                        Navigator.pop(context);
                        _fetchData();
                      }
                    } catch (e) {
                      setStateDialog(() => isSaving = false);
                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
                    }
                  },
                  child: isSaving ? const CircularProgressIndicator() : const Text('Ekle'),
                ),
              ],
            );
          }
        );
      }
    );
  }

  Future<void> _createTaskDialog(String listId) async {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      useSafeArea: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Yeni Görev Ekle'),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: titleCtrl,
                        maxLength: 100,
                        enabled: !isSaving,
                        decoration: const InputDecoration(labelText: 'Görev Adı'),
                        validator: (v) => v != null && v.trim().isEmpty ? 'Boş bırakılamaz' : null,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: descCtrl,
                        maxLength: 500,
                        enabled: !isSaving,
                        maxLines: 3,
                        decoration: const InputDecoration(labelText: 'Geniş Açıklama'),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(context),
                  child: const Text('İptal'),
                ),
                ElevatedButton(
                  onPressed: isSaving ? null : () async {
                    if (!formKey.currentState!.validate()) return;
                    setStateDialog(() => isSaving = true);
                    try {
                      final currentTasksCount = _tasksByList[listId]?.length ?? 0;
                      await _service.createTask(listId, titleCtrl.text.trim(), descCtrl.text.trim(), currentTasksCount + 1);
                      SemanticsService.announce("Görev eklendi", TextDirection.ltr);
                      if (context.mounted) {
                        Navigator.pop(context);
                        _fetchData();
                      }
                    } catch (e) {
                      setStateDialog(() => isSaving = false);
                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
                    }
                  },
                  child: isSaving ? const CircularProgressIndicator() : const Text('Ekle'),
                ),
              ],
            );
          }
        );
      }
    );
  }

  Future<void> _toggleTaskState(TaskItem task) async {
    try {
      await _service.updateTaskState(task.id, !task.isCompleted);
      _fetchData();
      SemanticsService.announce(!task.isCompleted ? "Görev tamamlandı olarak işaretlendi" : "Görev tamamlanmadı olarak işaretlendi", TextDirection.ltr);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.board.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_card),
            tooltip: 'Yeni Liste Ekle',
            onPressed: _createListDialog,
          )
        ],
      ),
      body: SafeArea(
        child: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : _lists.isEmpty
            ? const Center(child: Text('Bu panoda henüz bir liste yok.\nSağ üst köşeden liste ekleyebilirsiniz.', textAlign: TextAlign.center))
            : ListView.builder(
                padding: const EdgeInsets.all(16.0),
                itemCount: _lists.length,
                itemBuilder: (context, index) {
                  final list = _lists[index];
                  final tasks = _tasksByList[list.id] ?? [];
                  
                  return Card(
                    margin: const EdgeInsets.only(bottom: 24),
                    elevation: 4,
                    color: Theme.of(context).colorScheme.surfaceVariant,
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    list.name,
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add),
                                  tooltip: '${list.name} içerisine görev ekle',
                                  onPressed: () => _createTaskDialog(list.id),
                                )
                              ],
                            ),
                          ),
                          const Divider(),
                          if (tasks.isEmpty)
                            const Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Text('Bu listede henüz görev yok.'),
                            ),
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: tasks.length,
                            itemBuilder: (context, tIndex) {
                              final task = tasks[tIndex];
                              return Card(
                                child: CheckboxListTile(
                                  value: task.isCompleted,
                                  title: Text(task.title, style: TextStyle(
                                    decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                                  )),
                                  subtitle: task.description.isNotEmpty ? Text(task.description) : null,
                                  onChanged: (val) {
                                    if (val != null) _toggleTaskState(task);
                                  },
                                ),
                              );
                            },
                          )
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
