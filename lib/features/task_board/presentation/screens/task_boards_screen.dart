import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:blind_social/core/services/pocketbase_service.dart';
import 'package:blind_social/features/task_board/data/models/task_board.dart';
import 'package:blind_social/features/task_board/data/services/task_board_service.dart';
import 'package:blind_social/features/task_board/presentation/screens/task_board_detail_screen.dart';
import 'package:blind_social/features/task_board/presentation/screens/task_overview_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:blind_social/core/providers/localization_provider.dart';

class TaskBoardsScreen extends ConsumerStatefulWidget {
  const TaskBoardsScreen({super.key});

  @override
  ConsumerState<TaskBoardsScreen> createState() => _TaskBoardsScreenState();
}

enum BoardFilter { all, myBoards, sharedWithMe }

class _TaskBoardsScreenState extends ConsumerState<TaskBoardsScreen> {
  final TaskBoardService _service = TaskBoardService();
  List<TaskBoard> _boards = [];
  Map<String, int> _boardListCounts = {};
  bool _isLoading = true;
  bool _showFavoritesOnly = false;
  BoardFilter _currentFilter = BoardFilter.all;
  bool _isSearching = false;
  String _searchQuery = '';
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _currentUserId = PocketBaseService.client.authStore.model?.id;
    _fetchBoards();
  }

  Future<void> _fetchBoards() async {
    final lang = ref.read(localizationProvider);
    setState(() => _isLoading = true);
    try {
      final list = await _service.getMyBoards();
      
      final Map<String, int> counts = {};
      for (var board in list) {
        try {
          final res = await PocketBaseService.client.collection('task_lists').getList(
            filter: 'board_id = "${board.id}"',
            page: 1,
            perPage: 1,
          );
          counts[board.id] = res.totalItems;
        } catch (_) {
          counts[board.id] = 0;
        }
      }

      if (mounted) setState(() {
        _boards = list;
        _boardListCounts = counts;
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${lang.error}: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleFavorite(TaskBoard board) async {
    final lang = ref.read(localizationProvider);
    try {
      final updatedBoard = await _service.toggleFavoriteBoard(board);
      setState(() {
        final index = _boards.indexWhere((b) => b.id == board.id);
        if (index != -1) {
          _boards[index] = updatedBoard;
        }
      });
      final isFav = updatedBoard.favoritedBy.contains(_currentUserId);
      SemanticsService.announce(isFav ? lang.favAdded : lang.favRemoved, TextDirection.ltr);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${lang.error}: $e')));
    }
  }

  Future<void> _createBoardDialog() async {
    final lang = ref.read(localizationProvider);
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;
    
    final Map<String, List<String>> templates = {
      lang.emptyTemplate: [],
      lang.softwareDevTemplate: ['İncelenecekler', 'Yapılacaklar', 'Sürüyor', 'Test Bekleyen', 'Tamamlananlar'],
      lang.dailyTasksTemplate: ['Yapılacak', 'Hafta İçi', 'Hafta Sonu', 'Bitenler'],
      lang.projectMgmtTemplate: ['Fikirler', 'Planlama', 'Uygulama', 'Değerlendirme', 'Tamamlananlar'],
    };
    String selectedTemplate = templates.keys.first;

    await showDialog(
      context: context,
      barrierDismissible: false,
      useSafeArea: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text(lang.newBoardTitle),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameCtrl,
                        maxLength: 100,
                        enabled: !isSaving,
                        decoration: InputDecoration(labelText: lang.boardName, hintText: lang.boardNameHint),
                        validator: (v) => v != null && v.trim().isEmpty ? lang.boardNameRequired : null,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: descCtrl,
                        maxLength: 255,
                        enabled: !isSaving,
                        maxLines: 2,
                        decoration: InputDecoration(labelText: lang.descOptional),
                      ),
                      const SizedBox(height: 16),
                      Semantics(
                        hint: lang.dropdownHint,
                        child: DropdownButtonFormField<String>(
                          value: selectedTemplate,
                          decoration: InputDecoration(labelText: lang.selectTemplate, border: const OutlineInputBorder()),
                          items: templates.keys.map((String key) {
                            return DropdownMenuItem<String>(
                              value: key,
                              child: Text(key),
                            );
                          }).toList(),
                          onChanged: isSaving ? null : (val) {
                            if (val != null) setStateDialog(() => selectedTemplate = val);
                          },
                        ),
                      ),
                      if (templates[selectedTemplate]!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text('${lang.description}:\n${templates[selectedTemplate]!.join(', ')}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      ]
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
                       final board = await _service.createBoard(nameCtrl.text.trim(), descCtrl.text.trim());
                       
                       // Create template lists
                       final listsToCreate = templates[selectedTemplate]!;
                       for (int i = 0; i < listsToCreate.length; i++) {
                          // PocketBase considers 0 as an empty value for required numbers, so we start from 1
                          await _service.createList(board.id, listsToCreate[i], i + 1);
                       }
                       
                       SemanticsService.announce(lang.boardCreatedSuccess, TextDirection.ltr);
                       if (context.mounted) {
                         Navigator.pop(context);
                         _fetchBoards();
                       }
                    } catch (e) {
                      setStateDialog(() => isSaving = false);
                      if (context.mounted) {
                         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${lang.error}: $e')));
                      }
                    }
                  },
                  child: isSaving ? const CircularProgressIndicator() : Text(lang.createBoard),
                ),
              ],
            );
          }
        );
      }
    );
  }

  Future<void> _editBoardDialog(TaskBoard board) async {
    final lang = ref.read(localizationProvider);
    final nameCtrl = TextEditingController(text: board.name);
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text(lang.editName),
              content: Form(
                key: formKey,
                child: TextFormField(
                  controller: nameCtrl,
                  maxLength: 100,
                  enabled: !isSaving,
                  decoration: InputDecoration(labelText: lang.boardName),
                  validator: (v) => v != null && v.trim().isEmpty ? lang.boardNameRequired : null,
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
                      await _service.updateBoard(board.id, nameCtrl.text.trim());
                      SemanticsService.announce(lang.boardUpdateSuccess, TextDirection.ltr);
                      if (context.mounted) {
                        Navigator.pop(context);
                        _fetchBoards();
                      }
                    } catch (e) {
                      setStateDialog(() => isSaving = false);
                      if (context.mounted) {
                         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${lang.error}: $e')));
                      }
                    }
                  },
                  child: isSaving ? const CircularProgressIndicator() : Text(lang.save),
                ),
              ],
            );
          }
        );
      }
    );
  }

  Future<void> _deleteBoardDialog(TaskBoard board) async {
    final lang = ref.read(localizationProvider);
    final isConfirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(lang.deleteBoardTitle),
        content: Text('"${board.name}" ${lang.deleteBoardConfirm}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(lang.cancel),
          ),
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
        await _service.deleteBoard(board.id);
        SemanticsService.announce(lang.deleteBoardSuccess, TextDirection.ltr);
        _fetchBoards();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${lang.error}: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(localizationProvider);
    List<TaskBoard> filteredBoards = _showFavoritesOnly
        ? _boards.where((b) => _currentUserId != null && b.favoritedBy.contains(_currentUserId)).toList()
        : _boards;

    if (_currentFilter == BoardFilter.myBoards) {
      filteredBoards = filteredBoards.where((b) => _currentUserId == b.ownerId).toList();
    } else if (_currentFilter == BoardFilter.sharedWithMe) {
      filteredBoards = filteredBoards.where((b) => _currentUserId != b.ownerId).toList();
    }

    if (_searchQuery.isNotEmpty) {
      filteredBoards = filteredBoards.where((b) => b.name.toLowerCase().contains(_searchQuery)).toList();
    }

    return Scaffold(
      appBar: AppBar(
        title: _isSearching ? TextField(
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: lang.searchBoards,
            hintStyle: const TextStyle(color: Colors.white54),
            border: InputBorder.none,
          ),
          onChanged: (val) {
            setState(() {
              _searchQuery = val.toLowerCase();
            });
          },
        ) : Text(lang.taskBoard),
        actions: [
          PopupMenuButton<BoardFilter>(
            icon: const Icon(Icons.filter_list),
            tooltip: 'Panoları Filtrele',
            onSelected: (BoardFilter result) {
              setState(() {
                _currentFilter = result;
              });
              String anno = "";
              if (result == BoardFilter.all) anno = lang.boardFilterAll;
              if (result == BoardFilter.myBoards) anno = lang.boardFilterMy;
              if (result == BoardFilter.sharedWithMe) anno = lang.boardFilterShared;
              SemanticsService.announce(anno, TextDirection.ltr);
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<BoardFilter>>[
              PopupMenuItem<BoardFilter>(
                value: BoardFilter.all,
                child: Text(lang.all),
              ),
              PopupMenuItem<BoardFilter>(
                value: BoardFilter.myBoards,
                child: Text(lang.myBoards),
              ),
              PopupMenuItem<BoardFilter>(
                value: BoardFilter.sharedWithMe,
                child: Text(lang.sharedWithMe),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.analytics),
            tooltip: lang.overview,
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const TaskOverviewScreen()));
            },
          ),
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            tooltip: _isSearching ? lang.cancel : lang.searchBoards,
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
            icon: Icon(_showFavoritesOnly ? Icons.star : Icons.star_border),
            tooltip: _showFavoritesOnly ? lang.allBoards : lang.favoritesOnly,
            onPressed: () {
              setState(() {
                _showFavoritesOnly = !_showFavoritesOnly;
              });
              SemanticsService.announce(
                _showFavoritesOnly ? lang.favoritesOnly : lang.boardFilterAll,
                TextDirection.ltr,
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createBoardDialog,
        icon: const Icon(Icons.add),
        label: Text(lang.createBoard),
        tooltip: lang.newBoardTitle,
      ),
      body: SafeArea(
        child: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : filteredBoards.isEmpty
            ? Center(child: Text(_showFavoritesOnly ? lang.emptyFavs : lang.emptyBoards, textAlign: TextAlign.center))
            : GridView.builder(
                padding: const EdgeInsets.all(16.0),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16.0,
                  mainAxisSpacing: 16.0,
                  childAspectRatio: 1.0, 
                ),
                itemCount: filteredBoards.length,
                itemBuilder: (context, index) {
                  final board = filteredBoards[index];
                  final isFav = _currentUserId != null && board.favoritedBy.contains(_currentUserId);
                  final listCount = _boardListCounts[board.id] ?? 0;
                  
                  final colorIndex = board.id.codeUnitAt(0) % Colors.primaries.length;
                  final boxColor = Colors.primaries[colorIndex].withOpacity(0.2);
                  final borderColor = Colors.primaries[colorIndex].withOpacity(0.5);

                  final isOwner = _currentUserId == board.ownerId;
                  final favText = isFav ? lang.inFavorites : lang.notInFavorites;
                  String label = lang.boardAnnouncement(board.name, favText, listCount, isOwner);

                  return Semantics(
                    label: label,
                    button: true,
                    onLongPressHint: isFav ? lang.favRemoved : lang.favAdded,
                    onTapHint: lang.openBoard,
                    customSemanticsActions: {
                      if (isOwner) CustomSemanticsAction(label: lang.deleteBoardTitle): () => _deleteBoardDialog(board),
                      if (isOwner) CustomSemanticsAction(label: lang.editName): () => _editBoardDialog(board),
                    },
                    child: ExcludeSemantics(
                      child: InkWell(
                        onTap: () async {
                          await Navigator.push(context, MaterialPageRoute(builder: (_) => TaskBoardDetailScreen(board: board)));
                          _fetchBoards();
                        },
                        onLongPress: () => _toggleFavorite(board),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          decoration: BoxDecoration(
                            color: boxColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: borderColor, width: 1.5),
                          ),
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Icon(isFav ? Icons.star : Icons.star_border, color: isFav ? Colors.amber : Colors.white70),
                                  if (isOwner)
                                    GestureDetector(
                                      onTap: () => _deleteBoardDialog(board),
                                      child: const Padding(
                                        padding: EdgeInsets.all(4.0),
                                        child: Icon(Icons.delete, color: Colors.white70, size: 20),
                                      ),
                                    ),
                                ],
                              ),
                              const Spacer(),
                              Text(
                                board.name,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                lang.listCount.replaceFirst('{count}', listCount.toString()),
                                style: const TextStyle(fontSize: 14, color: Colors.white70),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
