import 'package:flutter/material.dart';
import 'package:blind_social/features/profile/data/services/feedback_service.dart';
import 'package:blind_social/core/utils/logger.dart';
import 'dart:async';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();
  String _selectedCategory = 'Suggestion';
  bool _isSending = false;
  bool _isSuccess = false;

  final List<Map<String, String>> _categories = [
    {'value': 'Request', 'label': 'İstek'},
    {'value': 'Suggestion', 'label': 'Öneri'},
    {'value': 'Complaint', 'label': 'Şikayet'},
    {'value': 'Thank you', 'label': 'Teşekkür'},
    {'value': 'Other', 'label': 'Diğer'},
  ];

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submitFeedback() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSending = true);

    try {
      final logsString = AppLogger.instance.logs
          .map((e) => '[${e.timestamp}] [${e.level.name.toUpperCase()}] ${e.message}')
          .join('\n');

      await FeedbackService().sendFeedback(
        category: _selectedCategory,
        subject: _subjectController.text.trim(),
        message: _messageController.text.trim(),
        logs: logsString,
      );

      setState(() {
        _isSending = false;
        _isSuccess = true;
      });

      // 5 saniye sonra ana sayfaya yönlendir
      Timer(const Duration(seconds: 5), () {
        if (mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      });
    } catch (e) {
      setState(() => _isSending = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata oluştu: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isSuccess) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle_outline, size: 80, color: Colors.green),
                const SizedBox(height: 24),
                const Text(
                  'Geri Bildiriminiz Alınmıştır',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Uygulamamızı geliştirmemize yardımcı olduğunuz için teşekkür ederiz. 5 saniye içinde ana sayfaya yönlendirileceksiniz.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                  child: const Text('Hemen Dön'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('İstek, Öneri ve Şikayet'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Size daha iyi hizmet verebilmemiz için lütfen görüşlerinizi bizimle paylaşın.',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Kategori Seçin',
                  border: OutlineInputBorder(),
                ),
                items: _categories.map((cat) {
                  return DropdownMenuItem(
                    value: cat['value'],
                    child: Text(cat['label']!),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedCategory = val);
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _subjectController,
                maxLength: 100,
                decoration: const InputDecoration(
                  labelText: 'Konu Başlığı',
                  hintText: 'Bildiriminizin konusunu kısaca belirtin',
                  border: OutlineInputBorder(),
                  counterText: "Maksimum 100 karakter",
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return 'Lütfen bir konu başlığı girin';
                  if (value.trim().length < 3) return 'Konu başlığı çok kısa';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _messageController,
                maxLength: 1000,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'Mesajınız',
                  hintText: 'Detaylı mesajınızı buraya yazabilirsiniz...',
                  border: OutlineInputBorder(),
                  counterText: "Maksimum 1000 karakter",
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return 'Lütfen mesajınızı girin';
                  if (value.trim().length < 10) return 'Mesajınız en az 10 karakter olmalıdır';
                  return null;
                },
              ),
              const SizedBox(height: 32),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSending ? null : _submitFeedback,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.black,
                  ),
                  child: _isSending
                      ? const CircularProgressIndicator()
                      : const Text('Bildirimi Gönder', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
