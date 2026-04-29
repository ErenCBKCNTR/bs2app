import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:blind_social/core/services/pocketbase_service.dart';
import 'package:blind_social/features/task_board/data/models/task_board.dart';
import 'package:blind_social/features/task_board/data/services/task_board_service.dart';
import 'package:blind_social/features/task_board/presentation/screens/task_board_detail_screen.dart';

class TaskBoardsScreen extends StatefulWidget {
  const TaskBoardsScreen({super.key});

  @override
  State<TaskBoardsScreen> createState() => _TaskBoardsScreenState();
}

class _TaskBoardsScreenState extends State<TaskBoardsScreen> {
  final TaskBoardService _service = TaskBoardService();
  List<TaskBoard> _boards = [];
  bool _isLoading = true;
  bool _showFavoritesOnly = false;
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
      if (mounted) setState(() => _boards = list);
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
                      await _service.createBoard(nameCtrl.text.trim(), descCtrl.text.trim());
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

  @override
  Widget build(BuildContext context) {
    final filteredBoards = _showFavoritesOnly
        ? _boards.where((b) => _currentUserId != null && b.favoritedBy.contains(_currentUserId)).toList()
        : _boards;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Görev Panoları'),
        actions: [
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
            : ListView.builder(
                padding: const EdgeInsets.all(16.0),
                itemCount: filteredBoards.length,
                itemBuilder: (context, index) {
                  final board = filteredBoards[index];
                  final isFav = _currentUserId != null && board.favoritedBy.contains(_currentUserId);
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: IconButton(
                        icon: Icon(isFav ? Icons.star : Icons.star_border, color: isFav ? Colors.amber : null),
                        tooltip: isFav ? 'Favorilerden Çıkar' : 'Favorilere Ekle',
                        onPressed: () => _toggleFavorite(board),
                      ),
                      title: Text(board.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: board.description.isNotEmpty ? Text(board.description) : null,
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => TaskBoardDetailScreen(board: board)));
                      },
                    ),
                  );
                },
              ),
      ),
    );
  }
}
