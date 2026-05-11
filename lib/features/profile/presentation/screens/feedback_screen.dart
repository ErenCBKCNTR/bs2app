import 'package:flutter/material.dart';
import 'package:blind_social/features/profile/data/services/feedback_service.dart';
import 'package:blind_social/core/utils/performance_monitor.dart';
import 'package:blind_social/core/utils/logger.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/localization_provider.dart';
import 'dart:async';

class FeedbackScreen extends ConsumerStatefulWidget {
  const FeedbackScreen({super.key});

  @override
  ConsumerState<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends ConsumerState<FeedbackScreen> {
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
    final lang = ref.read(localizationProvider);
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSending = true);

    try {
      final logsString = AppLogger.instance.logs
          .map((e) => '[${e.timestamp}] [${e.level.name.toUpperCase()}] ${e.message}')
          .join('\n');
          
      final performanceString = '--- PERFORMANS METRİKLERİ ---\n'
          'En Yüksek RAM Kullanımı: ${PerformanceMonitor.maxRamUsedMB.toStringAsFixed(1)} MB\n'
          'Çizim Takılma (Jank) Oranı: ${PerformanceMonitor.cpuJankCount}\n'
          '-----------------------------\n';

      await FeedbackService().sendFeedback(
        category: _selectedCategory,
        subject: _subjectController.text.trim(),
        message: _messageController.text.trim(),
        logs: performanceString + logsString,
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
          SnackBar(content: Text('${lang.error}: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(localizationProvider);
    final List<Map<String, String>> categories = [
      {'value': 'Request', 'label': lang.feedbackRequest},
      {'value': 'Suggestion', 'label': lang.feedbackSuggestion},
      {'value': 'Complaint', 'label': lang.feedbackComplaint},
      {'value': 'Thank you', 'label': lang.feedbackThankYou},
      {'value': 'Other', 'label': lang.feedbackOther},
    ];

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
                Text(
                  lang.feedbackReceived,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Text(
                  lang.feedbackThanksRedirect,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                  child: Text(lang.returnNow),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(lang.feedback),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                lang.feedbackPrompt,
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),
              Semantics(
                hint: lang.dropdownAccessibilityHint,
                child: DropdownButtonFormField<String>(
                  value: _selectedCategory,
                  decoration: InputDecoration(
                    labelText: lang.selectCategory,
                    border: const OutlineInputBorder(),
                  ),
                  items: categories.map((cat) {
                    return DropdownMenuItem(
                      value: cat['value'],
                      child: Text(cat['label']!),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedCategory = val);
                  },
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _subjectController,
                maxLength: 100,
                decoration: InputDecoration(
                  labelText: lang.subjectTitle,
                  hintText: lang.subjectHint,
                  border: const OutlineInputBorder(),
                  counterText: lang.maxCharacters100,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return lang.enterSubject;
                  if (value.trim().length < 3) return lang.subjectTooShort;
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _messageController,
                maxLength: 1000,
                maxLines: 6,
                decoration: InputDecoration(
                  labelText: lang.yourMessage,
                  hintText: lang.messageHint,
                  border: const OutlineInputBorder(),
                  counterText: lang.maxCharacters1000,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return lang.enterMessage;
                  if (value.trim().length < 10) return lang.messageTooShort;
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
                      : Text(lang.sendFeedback, style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
