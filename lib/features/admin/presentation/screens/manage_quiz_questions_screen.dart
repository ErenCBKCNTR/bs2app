import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:blind_social/features/admin/data/services/admin_service.dart';
import 'package:blind_social/core/services/pocketbase_service.dart';
import 'package:blind_social/core/utils/logger.dart';

class ManageQuizQuestionsScreen extends StatefulWidget {
  const ManageQuizQuestionsScreen({super.key});

  @override
  State<ManageQuizQuestionsScreen> createState() => _ManageQuizQuestionsScreenState();
}

class _ManageQuizQuestionsScreenState extends State<ManageQuizQuestionsScreen> {
  List<RecordModel> _questions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchQuestions();
  }

  Future<void> _fetchQuestions() async {
    setState(() => _isLoading = true);
    try {
      final res = await PocketBaseService.client.collection('quiz_questions').getFullList(
        sort: '-created',
      );
      if (mounted) {
        setState(() {
          _questions = res;
          _isLoading = false;
        });
      }
    } catch (e) {
      AppLogger.instance.error('Soruları çekerken hata: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
      }
    }
  }

  Future<void> _deleteQuestion(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Soruyu Sil'),
        content: const Text('Bu soruyu veritabanından kalıcı olarak silmek istediğinize emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await PocketBaseService.client.collection('quiz_questions').delete(id);
      _fetchQuestions(); // Refresh list automatically
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Soru silindi.')));
      }
    } catch (e) {
      AppLogger.instance.error('Soru silinirken hata: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Soru silinirken hata: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!AdminService().isAdmin()) {
      return Scaffold(
        appBar: AppBar(title: const Text('Erişim Engellendi')),
        body: const Center(child: Text('Bu sayfayı görüntülemek için yetkiniz yok.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Soruları Yönet'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchQuestions,
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _questions.isEmpty
                ? const Center(child: Text('Henüz soru yüklenmemiş.'))
                : ListView.builder(
                    itemCount: _questions.length,
                    itemBuilder: (context, index) {
                      final q = _questions[index];
                      final correctAnswer = q.getStringValue('correct_answer');
                      
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: ExpansionTile(
                          title: Text(q.getStringValue('question'), style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('Zorluk: ${q.getIntValue('difficulty')}'),
                          childrenPadding: const EdgeInsets.all(16),
                          children: [
                            _buildOption('A', q.getStringValue('option_a'), correctAnswer == 'a'),
                            _buildOption('B', q.getStringValue('option_b'), correctAnswer == 'b'),
                            _buildOption('C', q.getStringValue('option_c'), correctAnswer == 'c'),
                            _buildOption('D', q.getStringValue('option_d'), correctAnswer == 'd'),
                            const SizedBox(height: 16),
                            Align(
                              alignment: Alignment.centerRight,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                                onPressed: () => _deleteQuestion(q.id),
                                icon: const Icon(Icons.delete),
                                label: const Text('Soruyu Sil'),
                              ),
                            )
                          ],
                        ),
                      );
                    },
                  ),
      ),
    );
  }

  Widget _buildOption(String label, String text, bool isCorrect) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isCorrect ? Colors.green.withOpacity(0.2) : Colors.transparent,
        border: Border.all(color: isCorrect ? Colors.green : Colors.grey.withOpacity(0.5)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$label) $text',
        style: TextStyle(
          fontWeight: isCorrect ? FontWeight.bold : FontWeight.normal,
          color: isCorrect ? Colors.green[800] : null,
        ),
      ),
    );
  }
}
