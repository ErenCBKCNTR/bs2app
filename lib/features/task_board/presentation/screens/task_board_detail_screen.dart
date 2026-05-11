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
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:blind_social/core/providers/localization_provider.dart';

class TaskBoardDetailScreen extends ConsumerStatefulWidget {
  final TaskBoard board;
  const TaskBoardDetailScreen({super.key, required this.board});

  @override
  ConsumerState<TaskBoardDetailScreen> createState() => _TaskBoardDetailScreenState();
}

class _TaskBoardDetailScreenState extends ConsumerState<TaskBoardDetailScreen> {
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
      if (mounted) {
        final lang = ref.read(localizationProvider);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${lang.error}: $e')));
      }
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
    final lang = ref.read(localizationProvider);
    try {
      final updated = await _service.toggleListPinned(listM);
      setState(() {
        final index = _lists.indexWhere((l) => l.id == listM.id);
        if (index != -1) _lists[index] = updated;
        _sortLists();
      });
      final isPinned = _currentUserId != null && updated.pinnedBy.contains(_currentUserId);
      SemanticsService.announce(isPinned ? "${listM.name} ${lang.listPinnedSuccess}" : "${listM.name} ${lang.listUnpinnedSuccess}", TextDirection.ltr);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${lang.error}: $e')));
    }
  }

  void _toggleCollapse(TaskListM listM) {
    final lang = ref.read(localizationProvider);
    setState(() {
      if (_expandedLists.contains(listM.id)) {
        _expandedLists.remove(listM.id);
        SemanticsService.announce("${listM.name} ${lang.listCollapsed}", TextDirection.ltr);
      } else {
        _expandedLists.add(listM.id);
        SemanticsService.announce("${listM.name} ${lang.listExpanded}", TextDirection.ltr);
      }
    });
  }

  void _showListOptionsBottomSheet(BuildContext context, TaskListM list, int index, bool canEdit, bool isPinned) {
    final lang = ref.read(localizationProvider);
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            if (canEdit)
              ListTile(
                leading: const Icon(Icons.add),
                title: Text(lang.addTask),
                onTap: () { Navigator.pop(ctx); _createTaskDialog(list.id); },
              ),
            ListTile(
              leading: const Icon(Icons.push_pin),
              title: Text(isPinned ? lang.unpinList : lang.pinList),
              onTap: () { Navigator.pop(ctx); _togglePin(list); },
            ),
            if (canEdit && index > 0)
              ListTile(
                leading: const Icon(Icons.arrow_upward),
                title: Text(lang.moveUp),
                onTap: () { Navigator.pop(ctx); _moveList(list, true); },
              ),
            if (canEdit && index < _lists.length - 1)
              ListTile(
                leading: const Icon(Icons.arrow_downward),
                title: Text(lang.moveDown),
                onTap: () { Navigator.pop(ctx); _moveList(list, false); },
              ),
            if (canEdit)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: Text(lang.deleteList, style: const TextStyle(color: Colors.red)),
                onTap: () { Navigator.pop(ctx); _deleteListDialog(list); },
              ),
          ],
        ),
      ),
    );
  }

  void _showTaskOptionsBottomSheet(BuildContext context, TaskItem task, bool canEdit, bool isTaskCompleted) {
    final lang = ref.read(localizationProvider);
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            if (canEdit || task.assignees.contains(_currentUserId))
              ListTile(
                leading: Icon(isTaskCompleted ? Icons.close : Icons.check),
                title: Text(isTaskCompleted ? lang.markAsIncomplete : lang.markAsCompleted),
                onTap: () { Navigator.pop(ctx); _toggleTaskState(task); },
              ),
            if (canEdit)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: Text(lang.deleteTask, style: const TextStyle(color: Colors.red)),
                onTap: () { Navigator.pop(ctx); _deleteTaskDialog(task); },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _moveList(TaskListM listM, bool moveUp) async {
    final lang = ref.read(localizationProvider);
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
      SemanticsService.announce(moveUp ? "${listM.name} ${lang.moveListUp}" : "${listM.name} ${lang.moveListDown}", TextDirection.ltr);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${lang.error}: $e')));
    }
  }

  Future<void> _deleteListDialog(TaskListM list) async {
    final lang = ref.read(localizationProvider);
    final isConfirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(lang.deleteListTitle),
        content: Text('"${list.name}" ${lang.deleteListConfirm}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(lang.cancel)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: Text(lang.yesDelete, style: const TextStyle(color: Colors.white)),
          ),
        ],
      )
    );

    if (isConfirmed == true) {
      try {
        await _service.deleteList(list.id);
        SemanticsService.announce("${list.name} ${lang.deleteListSuccess}", TextDirection.ltr);
        _fetchData(showLoading: false);
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${lang.error}: $e')));
      }
    }
  }

  Future<void> _deleteTaskDialog(TaskItem task) async {
    final lang = ref.read(localizationProvider);
    final isConfirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(lang.deleteTaskTitle),
        content: Text('"${task.title}" ${lang.deleteTaskConfirm}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(lang.cancel)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: Text(lang.yesDelete, style: const TextStyle(color: Colors.white)),
          ),
        ],
      )
    );

    if (isConfirmed == true) {
      try {
        await _service.deleteTask(task.id);
        SemanticsService.announce("${task.title} ${lang.deleteTaskSuccess}", TextDirection.ltr);
        _fetchData(showLoading: false);
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${lang.error}: $e')));
      }
    }
  }

  Future<void> _createListDialog() async {
    final lang = ref.read(localizationProvider);
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
              title: Text(lang.newListTitle),
              content: Form(
                key: formKey,
                child: TextFormField(
                  controller: nameCtrl,
                  maxLength: 100,
                  enabled: !isSaving,
                  decoration: InputDecoration(labelText: lang.boardName, hintText: lang.listNameHint),
                  validator: (v) => v != null && v.trim().isEmpty ? lang.listNameRequired : null,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(context),
                  child: Text(lang.cancel),
                ),
                ElevatedButton(
                  onPressed: isSaving ? null : () async {
                    if (!formKey.currentState!.validate()) return;
                    setStateDialog(() => isSaving = true);
                    try {
                      final order = _lists.length + 1;
                      await _service.createList(widget.board.id, nameCtrl.text.trim(), order);
                      SemanticsService.announce("${nameCtrl.text.trim()} ${lang.listCreatedSuccess}", TextDirection.ltr);
                      if (context.mounted) {
                        Navigator.pop(context);
                        _fetchData(showLoading: false);
                      }
                    } catch (e) {
                      setStateDialog(() => isSaving = false);
                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${lang.error}: $e')));
                    }
                  },
                  child: isSaving ? const CircularProgressIndicator() : Text(lang.addTask),
                ),
              ],
            );
          }
        );
      }
    );
  }

  Future<void> _createTaskDialog(String listId) async {
    final lang = ref.read(localizationProvider);
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
              title: Text(lang.addTaskTitle),
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
                        decoration: InputDecoration(labelText: lang.taskName),
                        validator: (v) => v != null && v.trim().isEmpty ? lang.taskNameRequired : null,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: descCtrl,
                        maxLength: 500,
                        enabled: !isSaving,
                        maxLines: 3,
                        decoration: InputDecoration(labelText: lang.taskDesc),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(context),
                  child: Text(lang.cancel),
                ),
                ElevatedButton(
                  onPressed: isSaving ? null : () async {
                    if (!formKey.currentState!.validate()) return;
                    setStateDialog(() => isSaving = true);
                    try {
                      final currentTasksCount = _tasksByList[listId]?.length ?? 0;
                      await _service.createTask(listId, titleCtrl.text.trim(), descCtrl.text.trim(), currentTasksCount + 1);
                      SemanticsService.announce("${titleCtrl.text.trim()} ${lang.taskAddedSuccess}", TextDirection.ltr);
                      if (context.mounted) {
                        Navigator.pop(context);
                        _fetchData(showLoading: false);
                      }
                    } catch (e) {
                      setStateDialog(() => isSaving = false);
                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${lang.error}: $e')));
                    }
                  },
                  child: isSaving ? const CircularProgressIndicator() : Text(lang.addTask),
                ),
              ],
            );
          }
        );
      }
    );
  }

  Future<void> _toggleTaskState(TaskItem task) async {
    final lang = ref.read(localizationProvider);
    try {
      await _service.updateTaskState(task.id, !task.isCompleted);
      _fetchData(showLoading: false);
      SemanticsService.announce(!task.isCompleted ? "${task.title} ${lang.markAsCompleted}" : "${task.title} ${lang.markAsIncomplete}", TextDirection.ltr);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${lang.error}: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(localizationProvider);
    bool canEdit = widget.board.ownerId == _currentUserId || widget.board.editors.contains(_currentUserId);
    
    return Scaffold(
      appBar: AppBar(
        title: _isSearching ? TextField(
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: lang.searchCards,
            hintStyle: const TextStyle(color: Colors.white54),
            border: InputBorder.none,
          ),
          onChanged: (val) {
            setState(() {
              _searchQuery = val.toLowerCase();
            });
          },
        ) : Semantics(
          label: lang.boardDetailAnnouncement(widget.board.name),
          child: Text(widget.board.name),
        ),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            tooltip: _isSearching ? lang.cancel : lang.searchCards,
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
            tooltip: lang.boardMembers,
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
            tooltip: lang.inviteUser,
            onPressed: () async {
              final emailCtrl = TextEditingController();
              final isAdded = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text(lang.inviteUser),
                  content: TextField(
                    controller: emailCtrl,
                    decoration: InputDecoration(hintText: lang.inviteUserHint),
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: Text(lang.cancel)),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: Text(lang.inviteAction),
                    ),
                  ],
                )
              );

              if (isAdded == true && emailCtrl.text.isNotEmpty) {
                try {
                  await _service.addMember(widget.board.id, emailCtrl.text.trim());
                  SemanticsService.announce(lang.inviteSuccess, TextDirection.ltr);
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(lang.inviteSuccess)));
                } catch (e) {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${lang.error}: $e')));
                }
              }
            },
          ),
          if (canEdit)
            IconButton(
              icon: const Icon(Icons.add_card),
              tooltip: lang.newListTitle,
              onPressed: _createListDialog,
            )
        ],
      ),
      body: SafeArea(
        child: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : _lists.isEmpty
            ? Center(child: Text(lang.emptyList, textAlign: TextAlign.center))
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
                          label: '${list.name} ${lang.listOptionsHint}. $totalTasks ${lang.tasks}. $percentage% ${lang.completedPercentage.toLowerCase()}. ${kIsWeb ? lang.taskOptionsHint : lang.listOptionsHint}',
                          button: true,
                          onTapHint: isCollapsed ? lang.listExpanded : lang.listCollapsed,
                          onTap: () => _toggleCollapse(list),
                          onLongPressHint: lang.options,
                          onLongPress: () => _showListOptionsBottomSheet(context, list, index, canEdit, isPinned),
                          customSemanticsActions: {
                            CustomSemanticsAction(label: '${lang.listExpanded}/${lang.listCollapsed}'): () => _toggleCollapse(list),
                            CustomSemanticsAction(label: isPinned ? lang.unpinList : lang.pinList): () => _togglePin(list),
                            if (canEdit && index > 0) CustomSemanticsAction(label: lang.moveUp): () => _moveList(list, true),
                            if (canEdit && index < _lists.length - 1) CustomSemanticsAction(label: lang.moveDown): () => _moveList(list, false),
                            if (canEdit) CustomSemanticsAction(label: lang.addTask): () => _createTaskDialog(list.id),
                            if (canEdit) CustomSemanticsAction(label: lang.deleteList): () => _deleteListDialog(list),
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
                                                '%$percentage ${lang.completedPercentage} ($completedTasks/$totalTasks)',
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
                                      tooltip: lang.options,
                                      onSelected: (val) {
                                        if (val == 'pin') _togglePin(list);
                                        else if (val == 'up') _moveList(list, true);
                                        else if (val == 'down') _moveList(list, false);
                                        else if (val == 'add') _createTaskDialog(list.id);
                                        else if (val == 'delete') _deleteListDialog(list);
                                      },
                                      itemBuilder: (context) => [
                                        PopupMenuItem(value: 'add', child: Text(lang.addTask)),
                                        PopupMenuItem(value: 'pin', child: Text(isPinned ? lang.unpinList : lang.pinList)),
                                        if (index > 0) PopupMenuItem(value: 'up', child: Text(lang.moveUp)),
                                        if (index < _lists.length - 1) PopupMenuItem(value: 'down', child: Text(lang.moveDown)),
                                        PopupMenuItem(value: 'delete', child: Text(lang.deleteList, style: const TextStyle(color: Colors.red))),
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
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Text(lang.noTasksInList),
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
                                      if(days > 0) p.add("$days ${lang.days}");
                                      if(hours > 0) p.add("$hours ${lang.hours}");
                                      if(mins > 0) p.add("$mins ${lang.minutes}");
                                      if(p.isEmpty) p.add(lang.lessThanAMinute);
                                      timeSpentStr = " ${lang.timeSpentOnTask.replaceAll("{time}", p.join(" "))}";
                                    }
                                  }

                                  return SizedBox(
                                    width: 160,
                                    child: Semantics(
                                      label: '${lang.task} #${task.taskNumber}: ${task.title}. ${isTaskCompleted ? lang.markAsCompleted : lang.markAsIncomplete}.$timeSpentStr ${lang.taskDetailAction} ${kIsWeb ? lang.options : lang.taskOptionsHint}',
                                      button: true,
                                      onTapHint: lang.taskDetailAction,
                                      onLongPressHint: lang.options,
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
                                        if (canEdit) CustomSemanticsAction(label: lang.deleteTask): () => _deleteTaskDialog(task),
                                        if (canEdit || task.assignees.contains(_currentUserId)) CustomSemanticsAction(label: isTaskCompleted ? lang.markAsIncomplete : lang.markAsCompleted): () => _toggleTaskState(task),
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
                                                        label: isTaskCompleted ? lang.markAsIncomplete : lang.markAsCompleted,
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
    final lang = ref.read(localizationProvider);
    final now = DateTime.now();
    final months = ["", lang.january, lang.february, lang.march, lang.april, lang.may, lang.june, lang.july, lang.august, lang.september, lang.october, lang.november, lang.december];
    if (now.year == dt.year) return "${dt.day} ${months[dt.month]}";
    return "${dt.day} ${months[dt.month]} ${dt.year}";
  }
}
