import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
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

  @override
  void initState() {
    super.initState();
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Görev Panoları'),
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
          : _boards.isEmpty
            ? const Center(child: Text('Henüz bir görev panosu bulunmuyor\nEkranın sağ altından Pano Oluştur butonuna tıklayabilirsiniz.', textAlign: TextAlign.center))
            : ListView.builder(
                padding: const EdgeInsets.all(16.0),
                itemCount: _boards.length,
                itemBuilder: (context, index) {
                  final board = _boards[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
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
