import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:blind_social/features/admin/data/services/admin_service.dart';
import 'package:blind_social/core/services/pocketbase_service.dart';
import 'package:blind_social/core/utils/logger.dart';

class UploadQuizQuestionsScreen extends StatefulWidget {
  const UploadQuizQuestionsScreen({super.key});

  @override
  State<UploadQuizQuestionsScreen> createState() => _UploadQuizQuestionsScreenState();
}

class _UploadQuizQuestionsScreenState extends State<UploadQuizQuestionsScreen> {
  final TextEditingController _jsonController = TextEditingController();
  bool _isLoading = false;

  Future<void> _uploadQuestions() async {
    final text = _jsonController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lütfen geçerli bir JSON girin.')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final parsed = jsonDecode(text);
      if (parsed is! List) {
        throw Exception('JSON formatı bir dizi (Array) olmalıdır. Örneğin: [{...}, {...}]');
      }

      int successCount = 0;
      int errorCount = 0;

      for (var item in parsed) {
        if (item is Map<String, dynamic>) {
          try {
            await PocketBaseService.client.collection('quiz_questions').create(body: {
              'question': item['question'] ?? '',
              'option_a': item['option_a'] ?? '',
              'option_b': item['option_b'] ?? '',
              'option_c': item['option_c'] ?? '',
              'option_d': item['option_d'] ?? '',
              'correct_answer': item['correct_answer'] ?? 'a',
              'difficulty': item['difficulty'] ?? 1,
            });
            successCount++;
          } catch (e) {
            AppLogger.instance.error('Soru ekleme hatası: $e');
            errorCount++;
          }
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$successCount soru başarıyla yüklendi. $errorCount hata.')),
        );
        if (successCount > 0) {
          _jsonController.clear();
        }
      }
    } catch (e) {
      AppLogger.instance.error('JSON parse hatası: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _jsonController.dispose();
    super.dispose();
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
        title: const Text('Soru Yükle'),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.copy, color: Colors.white),
            label: const Text('Örnek JSON', style: TextStyle(color: Colors.white)),
            onPressed: () {
              const sampleJson = '[\n  {\n    "question": "Soru metni",\n    "option_a": "A şıkkı",\n    "option_b": "B şıkkı",\n    "option_c": "C şıkkı",\n    "option_d": "D şıkkı",\n    "correct_answer": "a",\n    "difficulty": 1\n  }\n]';
              Clipboard.setData(const ClipboardData(text: sampleJson));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Örnek JSON panoya kopyalandı!')),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'JSON formatında soru listesi yapıştırın. Format örneği:\n\n[\n  {\n    "question": "Soru metni",\n    "option_a": "A şıkkı",\n    "option_b": "B şıkkı",\n    "option_c": "C şıkkı",\n    "option_d": "D şıkkı",\n    "correct_answer": "a",\n    "difficulty": 1\n  }\n]',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: TextField(
                  controller: _jsonController,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  decoration: const InputDecoration(
                    hintText: '[{"question": "...", ...}]',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _isLoading ? null : _uploadQuestions,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading 
                  ? const CircularProgressIndicator() 
                  : const Text('Gönder', style: TextStyle(fontSize: 18)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
