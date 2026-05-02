import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/foundation.dart';
import 'package:blind_social/core/services/pocketbase_service.dart';
import 'package:blind_social/features/task_board/presentation/screens/board_members_screen.dart';
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
  Set<String> _expandedLists = {};

  @override
  void initState() {
    super.initState();
    _currentUserId = PocketBaseService.client.authStore.model?.id;
    _fetchData();
  }

  Future<void> _fetchData({bool showLoading = true}) async {
    if (showLoading) setState(() => _isLoading = true);
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
      if (mounted && showLoading) setState(() => _isLoading = false);
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
      SemanticsService.announce(isPinned ? "${listM.name} isimli liste başa tutturuldu" : "${listM.name} isimli listenin başa tutturulması kaldırıldı", TextDirection.ltr);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
    }
  }

  void _toggleCollapse(TaskListM listM) {
    setState(() {
      if (_expandedLists.contains(listM.id)) {
        _expandedLists.remove(listM.id);
        SemanticsService.announce("${listM.name} isimli liste daraltıldı", TextDirection.ltr);
      } else {
        _expandedLists.add(listM.id);
        SemanticsService.announce("${listM.name} isimli liste genişletildi", TextDirection.ltr);
      }
    });
  }

  void _showListOptionsBottomSheet(BuildContext context, TaskListM list, int index, bool canEdit, bool isPinned) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            if (canEdit)
              ListTile(
                leading: const Icon(Icons.add),
                title: const Text('Görev Ekle'),
                onTap: () { Navigator.pop(ctx); _createTaskDialog(list.id); },
              ),
            ListTile(
              leading: const Icon(Icons.push_pin),
              title: Text(isPinned ? 'Başa Tutturmayı Kaldır' : 'Başa Tuttur'),
              onTap: () { Navigator.pop(ctx); _togglePin(list); },
            ),
            if (canEdit && index > 0)
              ListTile(
                leading: const Icon(Icons.arrow_upward),
                title: const Text('Yukarı Taşı'),
                onTap: () { Navigator.pop(ctx); _moveList(list, true); },
              ),
            if (canEdit && index < _lists.length - 1)
              ListTile(
                leading: const Icon(Icons.arrow_downward),
                title: const Text('Aşağı Taşı'),
                onTap: () { Navigator.pop(ctx); _moveList(list, false); },
              ),
            if (canEdit)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Listeyi Sil', style: TextStyle(color: Colors.red)),
                onTap: () { Navigator.pop(ctx); _deleteListDialog(list); },
              ),
          ],
        ),
      ),
    );
  }

  void _showTaskOptionsBottomSheet(BuildContext context, TaskItem task, bool canEdit, bool isTaskCompleted) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            if (canEdit || task.assignees.contains(_currentUserId))
              ListTile(
                leading: Icon(isTaskCompleted ? Icons.close : Icons.check),
                title: Text(isTaskCompleted ? 'Tamamlanmadı Olarak İşaretle' : 'Tamamlandı Olarak İşaretle'),
                onTap: () { Navigator.pop(ctx); _toggleTaskState(task); },
              ),
            if (canEdit)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Görevi Sil', style: TextStyle(color: Colors.red)),
                onTap: () { Navigator.pop(ctx); _deleteTaskDialog(task); },
              ),
          ],
        ),
      ),
    );
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
      SemanticsService.announce(moveUp ? "${listM.name} isimli liste yukarı taşındı" : "${listM.name} isimli liste aşağı taşındı", TextDirection.ltr);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
    }
  }

  Future<void> _deleteListDialog(TaskListM list) async {
    final isConfirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Listeyi Sil'),
        content: Text('"${list.name}" isimli listeyi ve içindeki tüm görevleri silmek istediğinize emin misiniz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('İptal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Evet, Sil', style: TextStyle(color: Colors.white)),
          ),
        ],
      )
    );

    if (isConfirmed == true) {
      try {
        await _service.deleteList(list.id);
        SemanticsService.announce("${list.name} isimli liste silindi", TextDirection.ltr);
        _fetchData(showLoading: false);
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
      }
    }
  }

  Future<void> _deleteTaskDialog(TaskItem task) async {
    final isConfirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Görevi Sil'),
        content: Text('"${task.title}" isimli görevi silmek istediğinize emin misiniz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('İptal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Evet, Sil', style: TextStyle(color: Colors.white)),
          ),
        ],
      )
    );

    if (isConfirmed == true) {
      try {
        await _service.deleteTask(task.id);
        SemanticsService.announce("${task.title} isimli görev silindi", TextDirection.ltr);
        _fetchData(showLoading: false);
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
      }
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
                      SemanticsService.announce("${nameCtrl.text.trim()} isimli liste oluşturuldu", TextDirection.ltr);
                      if (context.mounted) {
                        Navigator.pop(context);
                        _fetchData(showLoading: false);
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
                      SemanticsService.announce("${titleCtrl.text.trim()} isimli görev eklendi", TextDirection.ltr);
                      if (context.mounted) {
                        Navigator.pop(context);
                        _fetchData(showLoading: false);
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
      _fetchData(showLoading: false);
      SemanticsService.announce(!task.isCompleted ? "${task.title} isimli görev tamamlandı olarak işaretlendi" : "${task.title} isimli görev tamamlanmadı olarak işaretlendi", TextDirection.ltr);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    bool canEdit = widget.board.ownerId == _currentUserId || widget.board.editors.contains(_currentUserId);
    
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
        ) : Semantics(
          label: "${widget.board.name} isimli pano içerisindesiniz.",
          child: Text(widget.board.name),
        ),
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
            icon: const Icon(Icons.people),
            tooltip: 'Bağlı Kullanıcılar',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => BoardMembersScreen(board: widget.board, service: _service),
                )
              ).then((_) => _fetchData(showLoading: false));
            },
          ),
          if (canEdit)
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
                    decoration: const InputDecoration(hintText: 'Kullanıcı adı veya e-posta adresi'),
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
                  await _service.addMember(widget.board.id, emailCtrl.text.trim());
                  SemanticsService.announce("Kullanıcı panoya eklendi", TextDirection.ltr);
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kullanıcı başarıyla eklendi!')));
                } catch (e) {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
                }
              }
            },
          ),
          if (canEdit)
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
addAutomaticKeepAlives: false,
addRepaintBoundaries: true,
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
                  final isCollapsed = !_expandedLists.contains(list.id);
                  
                  int totalTasks = tasks.length;
                  int completedTasks = tasks.where((t) => t.isCompleted).length;
                  int percentage = totalTasks > 0 ? ((completedTasks / totalTasks) * 100).round() : 0;
                  
                  final colorIndex = list.id.codeUnitAt(0) % Colors.primaries.length;
                  final listColor = Colors.primaries[colorIndex].withOpacity(0.15);
                  final borderColor = Colors.primaries[colorIndex].withOpacity(0.4);

                  return Card(
                    margin: const EdgeInsets.only(bottom: 24),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: borderColor, width: 1.5),
                    ),
                    color: listColor,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Semantics(
                          label: '${list.name} isimli liste içerisinde $totalTasks adet görev mevcut. Yüzde $percentage tamamlandı. ${kIsWeb ? "Seçenekleri açmak için uzun basılı tutun." : "Liste ile alakalı işlem yapmak için parmağınızı yukarı ya da aşağı kaydırın."}',
                          button: true,
                          onTapHint: isCollapsed ? "Genişlet" : "Daralt",
                          onTap: () => _toggleCollapse(list),
                          onLongPressHint: "Seçenekleri Göster",
                          onLongPress: () => _showListOptionsBottomSheet(context, list, index, canEdit, isPinned),
                          customSemanticsActions: {
                            const CustomSemanticsAction(label: 'Listeyi Genişlet/Daralt'): () => _toggleCollapse(list),
                            CustomSemanticsAction(label: isPinned ? 'Başa Tutturmayı Kaldır' : 'Başa Tuttur'): () => _togglePin(list),
                            if (canEdit && index > 0) const CustomSemanticsAction(label: 'Yukarı Taşı'): () => _moveList(list, true),
                            if (canEdit && index < _lists.length - 1) const CustomSemanticsAction(label: 'Aşağı Taşı'): () => _moveList(list, false),
                            if (canEdit) const CustomSemanticsAction(label: 'Görev Ekle'): () => _createTaskDialog(list.id),
                            if (canEdit) const CustomSemanticsAction(label: 'Listeyi Sil'): () => _deleteListDialog(list),
                          },
                          child: ExcludeSemantics(
                            child: InkWell(
                              onTap: () => _toggleCollapse(list),
                              onLongPress: () => _showListOptionsBottomSheet(context, list, index, canEdit, isPinned),
                              borderRadius: isCollapsed ? BorderRadius.circular(16) : const BorderRadius.vertical(top: Radius.circular(16)),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
                                child: Row(
                                  children: [
                                    Icon(isCollapsed ? Icons.expand_more : Icons.expand_less, size: 28),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            list.name,
                                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                                          ),
                                          if (totalTasks > 0)
                                            Padding(
                                              padding: const EdgeInsets.only(top: 4.0),
                                              child: Text(
                                                '%$percentage Tamamlandı ($completedTasks/$totalTasks)',
                                                style: const TextStyle(fontSize: 13, color: Colors.white70),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    if (isPinned)
                                      const Icon(Icons.push_pin, color: Colors.blue),
                                    const SizedBox(width: 8),
                                    PopupMenuButton<String>(
                                      icon: const Icon(Icons.more_vert),
                                      tooltip: 'Liste İşlemleri',
                                      onSelected: (val) {
                                        if (val == 'pin') _togglePin(list);
                                        else if (val == 'up') _moveList(list, true);
                                        else if (val == 'down') _moveList(list, false);
                                        else if (val == 'add') _createTaskDialog(list.id);
                                        else if (val == 'delete') _deleteListDialog(list);
                                      },
                                      itemBuilder: (context) => [
                                        const PopupMenuItem(value: 'add', child: Text('Görev Ekle')),
                                        PopupMenuItem(value: 'pin', child: Text(isPinned ? 'Başa Tutturmayı Kaldır' : 'Başa Tuttur')),
                                        if (index > 0) const PopupMenuItem(value: 'up', child: Text('Yukarı Taşı')),
                                        if (index < _lists.length - 1) const PopupMenuItem(value: 'down', child: Text('Aşağı Taşı')),
                                        const PopupMenuItem(value: 'delete', child: Text('Listeyi Sil', style: TextStyle(color: Colors.red))),
                                      ],
                                    )
                                  ],
                                ),
                              ),
                            ),
                          )
                        ),
                        if (!isCollapsed) ...[
                          const Divider(height: 1),
                          if (tasks.isEmpty)
                            const Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Text('Bu listede henüz görev yok.'),
                            ),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12.0),
                              child: Wrap(
                                spacing: 12.0,
                                runSpacing: 12.0,
                                children: tasks.map((task) {
                                  final isTaskCompleted = task.isCompleted;
                                  final taskColorIndex = task.id.codeUnitAt(0) % Colors.primaries.length;
                                  final taskColor = isTaskCompleted ? Colors.grey.withOpacity(0.1) : Colors.primaries[taskColorIndex].withOpacity(0.1);
                                  
                                  String timeSpentStr = "";
                                  if (task.timeLogs.isNotEmpty) {
                                    Duration total = Duration.zero;
                                    for (var log in task.timeLogs) {
                                      final start = DateTime.parse(log['start']);
                                      final end = log['end'] != null ? DateTime.parse(log['end']) : DateTime.now().toUtc();
                                      total += end.difference(start);
                                    }
                                    if (total.inSeconds > 0) {
                                      int days = total.inDays;
                                      int hours = total.inHours % 24;
                                      int mins = total.inMinutes % 60;
                                      List<String> p = [];
                                      if(days > 0) p.add("$days gün");
                                      if(hours > 0) p.add("$hours saat");
                                      if(mins > 0) p.add("$mins dakika");
                                      if(p.isEmpty) p.add("1 dakikadan az");
                                      timeSpentStr = " Görev üzerinde toplam ${p.join(" ")} çalışıldı.";
                                    }
                                  }

                                  return SizedBox(
                                    width: 160,
                                    child: Semantics(
                                      label: 'Görev numarası ${task.taskNumber}: ${task.title}. ${isTaskCompleted ? "Tamamlandı" : "Devam ediyor"}.$timeSpentStr Düzenlemek veya görüntülemek için çift tıklayın. ${kIsWeb ? "Seçenekleri açmak için uzun basılı tutun." : "İşlem seçenekleri için parmağınızı yukarı veya aşağı kaydırın."}',
                                      button: true,
                                      onTapHint: 'Görevi Aç',
                                      onLongPressHint: 'Seçenekleri Göster',
                                      onTap: () async {
                                        final refresh = await Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => TaskDetailScreen(task: task, allLists: _lists),
                                          ),
                                        );
                                        if (refresh == true) _fetchData(showLoading: false);
                                      },
                                      onLongPress: () => _showTaskOptionsBottomSheet(context, task, canEdit, isTaskCompleted),
                                      customSemanticsActions: {
                                        if (canEdit) const CustomSemanticsAction(label: 'Görevi Sil'): () => _deleteTaskDialog(task),
                                        if (canEdit || task.assignees.contains(_currentUserId)) CustomSemanticsAction(label: isTaskCompleted ? 'Tamamlanmadı Olarak İşaretle' : 'Tamamlandı Olarak İşaretle'): () => _toggleTaskState(task),
                                      },
                                      child: ExcludeSemantics(
                                        child: Card(
                                          elevation: 2,
                                          color: taskColor,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                          child: InkWell(
                                            borderRadius: BorderRadius.circular(12),
                                            onLongPress: () => _showTaskOptionsBottomSheet(context, task, canEdit, isTaskCompleted),
                                            onTap: () async {
                                              final refresh = await Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) => TaskDetailScreen(task: task, allLists: _lists),
                                                ),
                                              );
                                              if (refresh == true) _fetchData(showLoading: false);
                                            },
                                            child: Padding(
                                              padding: const EdgeInsets.all(12.0),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Expanded(
                                                        child: Text(
                                                          '#${task.taskNumber}',
                                                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                                                          maxLines: 1,
                                                        ),
                                                      ),
                                                      Semantics(
                                                        label: isTaskCompleted ? 'Tamamlandı olarak işaretli. Tıklayarak tamamlanmadı olarak işaretle' : 'Tamamlanmadı. Tıklayarak tamamlandı olarak işaretle',
                                                        button: true,
                                                        child: GestureDetector(
                                                          onTap: () => _toggleTaskState(task),
                                                          child: Icon(
                                                            isTaskCompleted ? Icons.check_box : Icons.check_box_outline_blank,
                                                            color: isTaskCompleted ? Colors.green : Colors.grey,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 8),
                                                  Text(
                                                    task.title,
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      decoration: isTaskCompleted ? TextDecoration.lineThrough : null,
                                                    ),
                                                    maxLines: 3,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                  if (task.labels.isNotEmpty) ...[
                                                    const SizedBox(height: 8),
                                                    Wrap(
                                                      spacing: 4,
                                                      runSpacing: 4,
                                                      children: task.labels.take(3).map((l) {
                                                        final hex = l['color'] as String? ?? '000000';
                                                        final cInfo = _parseColor(hex);
                                                        return Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                          decoration: BoxDecoration(
                                                            color: cInfo,
                                                            borderRadius: BorderRadius.circular(4),
                                                          ),
                                                          child: Text(
                                                            l['text'] as String? ?? '',
                                                            style: const TextStyle(fontSize: 10, color: Colors.white),
                                                            maxLines: 1,
                                                            overflow: TextOverflow.ellipsis,
                                                          ),
                                                        );
                                                      }).toList(),
                                                    )
                                                  ]
                                                ],
                                              ),
                                            ),
                                          ),
                                        )
                                      ),
                                    )
                                  );
                                }).toList(),
                              ),
                            )
                          ]
                        ],
                      ),
                  );
                },
              ),
      ),
    );
  }

  Color _parseColor(String colorStr) {
    String hex = colorStr.toUpperCase().replaceAll("#", "");
    if (hex.length == 6) hex = "FF$hex";
    return Color(int.tryParse(hex, radix: 16) ?? 0xFF000000);
  }

  String _formatDt(DateTime dt) {
    final now = DateTime.now();
    const months = ["", "Ocak", "Şubat", "Mart", "Nisan", "Mayıs", "Haziran", "Temmuz", "Ağustos", "Eylül", "Ekim", "Kasım", "Aralık"];
    if (now.year == dt.year) return "${dt.day} ${months[dt.month]}";
    return "${dt.day} ${months[dt.month]} ${dt.year}";
  }
}
