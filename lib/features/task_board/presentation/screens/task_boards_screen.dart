import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:blind_social/core/services/pocketbase_service.dart';
import 'package:blind_social/features/task_board/data/models/task_board.dart';
import 'package:blind_social/features/task_board/data/services/task_board_service.dart';
import 'package:blind_social/features/task_board/presentation/screens/task_board_detail_screen.dart';
import 'package:blind_social/features/task_board/presentation/screens/task_overview_screen.dart';

class TaskBoardsScreen extends StatefulWidget {
  const TaskBoardsScreen({super.key});

  @override
  State<TaskBoardsScreen> createState() => _TaskBoardsScreenState();
}

enum BoardFilter { all, myBoards, sharedWithMe }

class _TaskBoardsScreenState extends State<TaskBoardsScreen> {
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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleFavorite(TaskBoard board) async {
    try {
      final updatedBoard = await _service.toggleFavoriteBoard(board);
      setState(() {
        final index = _boards.indexWhere((b) => b.id == board.id);
        if (index != -1) {
          _boards[index] = updatedBoard;
        }
      });
      final isFav = updatedBoard.favoritedBy.contains(_currentUserId);
      SemanticsService.announce(isFav ? "Pano favorilere eklendi" : "Pano favorilerden çıkarıldı", TextDirection.ltr);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
    }
  }

  Future<void> _createBoardDialog() async {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;
    
    final Map<String, List<String>> templates = {
      'Boş Şablon': [],
      'Yazılım Geliştirme': ['İncelenecekler', 'Yapılacaklar', 'Sürüyor', 'Test Bekleyen', 'Tamamlananlar'],
      'Günlük İşler': ['Yapılacak', 'Hafta İçi', 'Hafta Sonu', 'Bitenler'],
      'Proje Yönetimi': ['Fikirler', 'Planlama', 'Uygulama', 'Değerlendirme', 'Tamamlananlar'],
    };
    String selectedTemplate = 'Boş Şablon';

    await showDialog(
      context: context,
      barrierDismissible: false,
      useSafeArea: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Yeni Görev Panosu Oluştur'),
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
                        decoration: const InputDecoration(labelText: 'Pano Adı', hintText: 'Örn: Okul Projesi'),
                        validator: (v) => v != null && v.trim().isEmpty ? 'Lütfen pano adı giriniz' : null,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: descCtrl,
                        maxLength: 255,
                        enabled: !isSaving,
                        maxLines: 2,
                        decoration: const InputDecoration(labelText: 'Açıklama (İsteğe Bağlı)'),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: selectedTemplate,
                        decoration: const InputDecoration(labelText: 'Pano Şablonu Seçin', border: OutlineInputBorder()),
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
                      if (templates[selectedTemplate]!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text('Bu şablon ile şunlar eklenecek:\n${templates[selectedTemplate]!.join(', ')}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      ]
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
                       final board = await _service.createBoard(nameCtrl.text.trim(), descCtrl.text.trim());
                       
                       // Create template lists
                       final listsToCreate = templates[selectedTemplate]!;
                       for (int i = 0; i < listsToCreate.length; i++) {
                          // PocketBase considers 0 as an empty value for required numbers, so we start from 1
                          await _service.createList(board.id, listsToCreate[i], i + 1);
                       }
                       
                       SemanticsService.announce("Görev panosu başarıyla oluşturuldu", TextDirection.ltr);
                       if (context.mounted) {
                         Navigator.pop(context);
                         _fetchBoards();
                       }
                    } catch (e) {
                      setStateDialog(() => isSaving = false);
                      if (context.mounted) {
                         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
                      }
                    }
                  },
                  child: isSaving ? const CircularProgressIndicator() : const Text('Oluştur'),
                ),
              ],
            );
          }
        );
      }
    );
  }

  Future<void> _editBoardDialog(TaskBoard board) async {
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
              title: const Text('Pano Adını Düzenle'),
              content: Form(
                key: formKey,
                child: TextFormField(
                  controller: nameCtrl,
                  maxLength: 100,
                  enabled: !isSaving,
                  decoration: const InputDecoration(labelText: 'Pano Adı'),
                  validator: (v) => v != null && v.trim().isEmpty ? 'Lütfen pano adı giriniz' : null,
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
                      await _service.updateBoard(board.id, nameCtrl.text.trim());
                      SemanticsService.announce("Pano adı güncellendi", TextDirection.ltr);
                      if (context.mounted) {
                        Navigator.pop(context);
                        _fetchBoards();
                      }
                    } catch (e) {
                      setStateDialog(() => isSaving = false);
                      if (context.mounted) {
                         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
                      }
                    }
                  },
                  child: isSaving ? const CircularProgressIndicator() : const Text('Kaydet'),
                ),
              ],
            );
          }
        );
      }
    );
  }

  Future<void> _deleteBoardDialog(TaskBoard board) async {
    final isConfirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Panoyu Sil'),
        content: Text('"${board.name}" isimli panoyu silmek istediğinize emin misiniz? Bu işlem geri alınamaz.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
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
        await _service.deleteBoard(board.id);
        SemanticsService.announce("Pano başarıyla silindi", TextDirection.ltr);
        _fetchBoards();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
          decoration: const InputDecoration(
            hintText: 'Pano Ara',
            hintStyle: TextStyle(color: Colors.white54),
            border: InputBorder.none,
          ),
          onChanged: (val) {
            setState(() {
              _searchQuery = val.toLowerCase();
            });
          },
        ) : const Text('Görev Panoları'),
        actions: [
          PopupMenuButton<BoardFilter>(
            icon: const Icon(Icons.filter_list),
            tooltip: 'Panoları Filtrele',
            onSelected: (BoardFilter result) {
              setState(() {
                _currentFilter = result;
              });
              String anno = "";
              if (result == BoardFilter.all) anno = "Tüm panolar listeleniyor";
              if (result == BoardFilter.myBoards) anno = "Sadece kendi panolarınız listeleniyor";
              if (result == BoardFilter.sharedWithMe) anno = "Sadece sizinle paylaşılan panolar listeleniyor";
              SemanticsService.announce(anno, TextDirection.ltr);
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<BoardFilter>>[
              const PopupMenuItem<BoardFilter>(
                value: BoardFilter.all,
                child: Text('Tümü'),
              ),
              const PopupMenuItem<BoardFilter>(
                value: BoardFilter.myBoards,
                child: Text('Kendi Panolarım'),
              ),
              const PopupMenuItem<BoardFilter>(
                value: BoardFilter.sharedWithMe,
                child: Text('Benimle Paylaşılan Panolar'),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.analytics),
            tooltip: 'Görev Geçmişi ve Özeti',
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const TaskOverviewScreen()));
            },
          ),
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            tooltip: _isSearching ? 'Aramayı Kapat' : 'Panolarda Ara',
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
            tooltip: _showFavoritesOnly ? 'Tüm Panoları Göster' : 'Sadece Favorileri Göster',
            onPressed: () {
              setState(() {
                _showFavoritesOnly = !_showFavoritesOnly;
              });
              SemanticsService.announce(
                _showFavoritesOnly ? 'Sadece favori panolar listeleniyor' : 'Tüm panolar listeleniyor',
                TextDirection.ltr,
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createBoardDialog,
        icon: const Icon(Icons.add),
        label: const Text('Pano Oluştur'),
        tooltip: 'Yeni bir görev panosu oluştur',
      ),
      body: SafeArea(
        child: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : filteredBoards.isEmpty
            ? Center(child: Text(_showFavoritesOnly ? 'Favori panonuz bulunmuyor.' : 'Henüz bir görev panosu bulunmuyor\nEkranın sağ altından Pano Oluştur butonuna tıklayabilirsiniz.', textAlign: TextAlign.center))
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
                  final favText = isFav ? "Favorilerinizde." : "Favorilerinizde değil.";
                  String label = "";
                  if (!isOwner) {
                    label = "Sizinle paylaşılmış ${board.name} isimli pano, $favText İçerisinde $listCount adet liste mevcut. Panoya girmek için çift tıklayın, favori durumunu değiştirmek için uzun basın.";
                  } else {
                    label = "${board.name} isimli pano, $favText İçerisinde $listCount adet liste mevcut. Panoya girmek için çift tıklayın, favori durumunu değiştirmek için uzun basın.";
                  }

                  return Semantics(
                    label: label,
                    button: true,
                    onLongPressHint: isFav ? "Favorilerden Çıkar" : "Favorilere Ekle",
                    onTapHint: "Panoya Gir",
                    customSemanticsActions: {
                      if (isOwner) const CustomSemanticsAction(label: 'Panoyu Sil'): () => _deleteBoardDialog(board),
                      if (isOwner) const CustomSemanticsAction(label: 'Adını Düzenle'): () => _editBoardDialog(board),
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
                                "$listCount Liste",
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
