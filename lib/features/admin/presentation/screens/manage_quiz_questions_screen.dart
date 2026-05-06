import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
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
  
  int _totalQuestions = 0;
  int _diff1Questions = 0;
  int _diff2Questions = 0;
  int _diff3Questions = 0;

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
          _totalQuestions = res.length;
          _diff1Questions = res.where((q) => q.getIntValue('difficulty') == 1).length;
          _diff2Questions = res.where((q) => q.getIntValue('difficulty') == 2).length;
          _diff3Questions = res.where((q) => q.getIntValue('difficulty') == 3).length;
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

  Future<void> _uploadAudioForQuestion(String questionId) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
    );

    if (result != null && result.files.single.bytes != null) {
      final fileBytes = result.files.single.bytes!;
      final fileName = result.files.single.name;

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ses dosyası yükleniyor...')));

      try {
        await PocketBaseService.client.collection('quiz_questions').update(
          questionId,
          files: [
            http.MultipartFile.fromBytes(
              'audio_file',
              fileBytes,
              filename: fileName,
            ),
          ],
        );
        _fetchQuestions(); // Refresh
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ses dosyası başarıyla yüklendi.')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ses dosyası yüklenirken hata: $e')));
        }
      }
    }
  }

  Widget _buildStatCard(String title, int count, Color color) {
    return Expanded(
      child: Card(
        color: color.withOpacity(0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: color.withOpacity(0.5), width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0),
          child: Column(
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
        child: Column(
          children: [
            // Stats section
            if (!_isLoading)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Card(
                      color: Colors.blue.withOpacity(0.1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.blue.withOpacity(0.5), width: 1),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.quiz, color: Colors.blue),
                            const SizedBox(width: 8),
                            Text(
                              'Toplam Soru: $_totalQuestions',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildStatCard('Zorluk 1', _diff1Questions, Colors.green),
                        const SizedBox(width: 8),
                        _buildStatCard('Zorluk 2', _diff2Questions, Colors.orange),
                        const SizedBox(width: 8),
                        _buildStatCard('Zorluk 3', _diff3Questions, Colors.red),
                      ],
                    ),
                  ],
                ),
              ),
            
            Expanded(
              child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _questions.isEmpty
                    ? const Center(child: Text('Henüz soru yüklenmemiş.'))
                    : ListView.builder(
                        addAutomaticKeepAlives: false,
                        addRepaintBoundaries: true,
                        itemCount: _questions.length,
                        itemBuilder: (context, index) {
                          final q = _questions[index];
                          final correctAnswer = q.getStringValue('correct_answer');
                          final hasAudio = q.getStringValue('audio_file').isNotEmpty;
                          
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: ExpansionTile(
                              title: Text(q.getStringValue('question'), style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Row(
                                children: [
                                  Text('Zorluk: ${q.getIntValue('difficulty')}'),
                                  if (hasAudio) ...[
                                    const SizedBox(width: 8),
                                    const Icon(Icons.audiotrack, size: 16, color: Colors.green),
                                    const Text(' Ses Yüklü', style: TextStyle(color: Colors.green, fontSize: 12)),
                                  ]
                                ],
                              ),
                              childrenPadding: const EdgeInsets.all(16),
                              children: [
                                _buildOption('A', q.getStringValue('option_a'), correctAnswer == 'a'),
                                _buildOption('B', q.getStringValue('option_b'), correctAnswer == 'b'),
                                _buildOption('C', q.getStringValue('option_c'), correctAnswer == 'c'),
                                _buildOption('D', q.getStringValue('option_d'), correctAnswer == 'd'),
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                                      onPressed: () => _uploadAudioForQuestion(q.id),
                                      icon: const Icon(Icons.upload_file),
                                      label: const Text('Ses Yükle'),
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                                      onPressed: () => _deleteQuestion(q.id),
                                      icon: const Icon(Icons.delete),
                                      label: const Text('Sil'),
                                    ),
                                  ],
                                )
                              ],
                            ),
                          );
                        },
                      ),
            ),
          ],
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
