import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:blind_social/core/services/pocketbase_service.dart';
import 'package:blind_social/features/task_board/data/models/task_board.dart';
import 'package:blind_social/features/task_board/data/models/task_list_model.dart';
import 'package:blind_social/features/task_board/data/models/task_item.dart';
import 'package:blind_social/features/task_board/data/services/task_board_service.dart';
import 'package:blind_social/features/task_board/presentation/screens/task_detail_screen.dart';

class TaskBoardDetailScreen extends StatefulWidget {
  final TaskBoard board;
  const TaskBoardDetailScreen({super.key, required this.board});

  @override
  State<TaskBoardDetailScreen> createState() => _TaskBoardDetailScreenState();
}

class _TaskBoardDetailScreenState extends State<TaskBoardDetailScreen> {
  final TaskBoardService _service = TaskBoardService();
  String? _currentUserId;
  bool _isLoading = true;
  bool _isSearching = false;
  String _searchQuery = '';
  List<TaskListM> _lists = [];
  Map<String, List<TaskItem>> _tasksByList = {};

  @override
  void initState() {
    super.initState();
    _currentUserId = PocketBaseService.client.authStore.model?.id;
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
        _sortLists();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _sortLists() {
    _lists.sort((a, b) {
      final aPinned = _currentUserId != null && a.pinnedBy.contains(_currentUserId);
      final bPinned = _currentUserId != null && b.pinnedBy.contains(_currentUserId);
      if (aPinned && !bPinned) return -1;
      if (!aPinned && bPinned) return 1;
      return a.order.compareTo(b.order);
    });
  }

  Future<void> _togglePin(TaskListM listM) async {
    try {
      final updated = await _service.toggleListPinned(listM);
      setState(() {
        final index = _lists.indexWhere((l) => l.id == listM.id);
        if (index != -1) _lists[index] = updated;
        _sortLists();
      });
      final isPinned = _currentUserId != null && updated.pinnedBy.contains(_currentUserId);
      SemanticsService.announce(isPinned ? "Liste başa tutturuldu" : "Listenin başa tutturulması kaldırıldı", TextDirection.ltr);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
    }
  }

  Future<void> _toggleCollapse(TaskListM listM) async {
    try {
      final updated = await _service.toggleListCollapsed(listM);
      setState(() {
        final index = _lists.indexWhere((l) => l.id == listM.id);
        if (index != -1) _lists[index] = updated;
      });
      final isCollapsed = _currentUserId != null && updated.collapsedBy.contains(_currentUserId);
      SemanticsService.announce(isCollapsed ? "Liste daraltıldı" : "Liste genişletildi", TextDirection.ltr);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
    }
  }

  Future<void> _moveList(TaskListM listM, bool moveUp) async {
    // Normal sıralamayı alıyoruz, pinliler de kendi içinde taşınabilir
    final currentIndex = _lists.indexWhere((l) => l.id == listM.id);
    if (currentIndex == -1) return;

    final targetIndex = moveUp ? currentIndex - 1 : currentIndex + 1;
    if (targetIndex < 0 || targetIndex >= _lists.length) return;

    final targetList = _lists[targetIndex];

    try {
      final updatedCurrent = await _service.updateListOrder(listM.id, targetList.order);
      final updatedTarget = await _service.updateListOrder(targetList.id, listM.order);
      
      setState(() {
        _lists[currentIndex] = updatedCurrent;
        _lists[targetIndex] = updatedTarget;
        _sortLists();
      });
      SemanticsService.announce(moveUp ? "Liste yukarı taşındı" : "Liste aşağı taşındı", TextDirection.ltr);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
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
        title: _isSearching ? TextField(
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Kart Ara (isim, #id veya etiket)',
            hintStyle: TextStyle(color: Colors.white54),
            border: InputBorder.none,
          ),
          onChanged: (val) {
            setState(() {
              _searchQuery = val.toLowerCase();
            });
          },
        ) : Text(widget.board.name),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            tooltip: _isSearching ? 'Aramayı Kapat' : 'Kartlarda Ara',
            onPressed: () {
              setState(() {
                if (_isSearching) {
                  _isSearching = false;
                  _searchQuery = '';
                } else {
                  _isSearching = true;
                }
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.group_add),
            tooltip: 'Üye Davet Et',
            onPressed: () async {
              final emailCtrl = TextEditingController();
              final isAdded = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Üye Davet Et'),
                  content: TextField(
                    controller: emailCtrl,
                    decoration: const InputDecoration(hintText: 'Kullanıcının e-posta adresi'),
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('İptal')),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Davet Et'),
                    ),
                  ],
                )
              );

              if (isAdded == true && emailCtrl.text.isNotEmpty) {
                try {
                  await _service.addMemberByEmail(widget.board.id, emailCtrl.text.trim());
                  SemanticsService.announce("Kullanıcı panoya eklendi", TextDirection.ltr);
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kullanıcı başarıyla eklendi!')));
                } catch (e) {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
                }
              }
            },
          ),
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
                  List<TaskItem> tasks = _tasksByList[list.id] ?? [];
                  
                  if (_searchQuery.isNotEmpty) {
                    tasks = tasks.where((t) {
                      final titleMatch = t.title.toLowerCase().contains(_searchQuery);
                      final numMatch = '#${t.taskNumber}'.contains(_searchQuery);
                      final labelMatch = t.labels.any((l) => (l['text'] as String? ?? '').toLowerCase().contains(_searchQuery));
                      return titleMatch || numMatch || labelMatch;
                    }).toList();
                  }

                  final isPinned = _currentUserId != null && list.pinnedBy.contains(_currentUserId);
                  final isCollapsed = _currentUserId != null && list.collapsedBy.contains(_currentUserId);
                  
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
                              children: [
                                IconButton(
                                  icon: Icon(isCollapsed ? Icons.expand_more : Icons.expand_less),
                                  tooltip: isCollapsed ? 'Listeyi Genişlet' : 'Listeyi Daralt',
                                  onPressed: () => _toggleCollapse(list),
                                ),
                                Expanded(
                                  child: Text(
                                    list.name,
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(isPinned ? Icons.push_pin : Icons.push_pin_outlined, color: isPinned ? Colors.blue : null),
                                  tooltip: isPinned ? 'Başa Tutturmayı Kaldır' : 'Başa Tuttur',
                                  onPressed: () => _togglePin(list),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.arrow_upward),
                                  tooltip: 'Yukarı Taşı',
                                  onPressed: index > 0 ? () => _moveList(list, true) : null,
                                ),
                                IconButton(
                                  icon: const Icon(Icons.arrow_downward),
                                  tooltip: 'Aşağı Taşı',
                                  onPressed: index < _lists.length - 1 ? () => _moveList(list, false) : null,
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add),
                                  tooltip: '${list.name} içerisine görev ekle',
                                  onPressed: () => _createTaskDialog(list.id),
                                )
                              ],
                            ),
                          ),
                          if (!isCollapsed) ...[
                            const Divider(),
                            if (tasks.isEmpty)
                              const Padding(
                                padding: EdgeInsets.all(16.0),
                                child: Text('Bu listede henüz görev yok.'),
                              ),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(8.0),
                              child: Wrap(
                                spacing: 12.0,
                                runSpacing: 12.0,
                                children: tasks.map((task) {
                                  return SizedBox(
                                    width: 180, // Kütüphane raflarındaki gibi dizilim için sabit genişlik
                                    child: Card(
                                      elevation: 2,
                                      child: InkWell(
                                        onTap: () async {
                                          final refresh = await Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => TaskDetailScreen(task: task, allLists: _lists),
                                            ),
                                          );
                                          if (refresh == true) _fetchData();
                                        },
                                        child: Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                Expanded(
                                                  child: Text(
                                                    '#${task.taskNumber}',
                                                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                Checkbox(
                                                  value: task.isCompleted,
                                                  onChanged: (val) {
                                                    if (val != null) _toggleTaskState(task);
                                                  },
                                                )
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              task.title,
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            if (task.description.isNotEmpty) ...[
                                              const SizedBox(height: 8),
                                              Text(
                                                task.description,
                                                style: const TextStyle(fontSize: 12),
                                                maxLines: 3,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            )
                          ]
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
