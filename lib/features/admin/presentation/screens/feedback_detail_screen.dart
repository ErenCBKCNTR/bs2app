import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:intl/intl.dart';

class FeedbackDetailScreen extends StatelessWidget {
  final RecordModel feedback;

  const FeedbackDetailScreen({super.key, required this.feedback});

  String _getCategoryTurkish(String category) {
    switch (category) {
      case 'Request': return 'İstek';
      case 'Suggestion': return 'Öneri';
      case 'Complaint': return 'Şikayet';
      case 'Thank you': return 'Teşekkür';
      default: return 'Diğer';
    }
  }

  void _showLogsDialog(BuildContext context, String logs) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Kullanıcı Hata Günlükleri'),
          content: SizedBox(
            width: double.maxFinite,
            child: logs.isEmpty
                ? const Text('Günlük kaydı bulunamadı.')
                : SingleChildScrollView(
                    child: SelectableText(
                      logs,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                    ),
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Kapat'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = feedback.expand['user_id']?.first;
    final fullName = user?.getStringValue('full_name') ?? 'Bilinmiyor';
    final username = user?.getStringValue('username') ?? 'bilinmiyor';
    final email = user?.getStringValue('email') ?? 'bilinmiyor';
    final category = feedback.getStringValue('category');
    final subject = feedback.getStringValue('subject');
    final message = feedback.getStringValue('message');
    final logs = feedback.getStringValue('logs');
    final created = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(feedback.created).toLocal());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bildirim Detayı'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoTile('Kullanıcı', '$fullName (@$username)'),
            _buildInfoTile('E-posta', email),
            _buildInfoTile('Tarih', created),
            _buildInfoTile('Kategori', _getCategoryTurkish(category)),
            const Divider(height: 32),
            const Text(
              'Konu Başlığı',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 4),
            Text(
              subject,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            const Text(
              'Mesaj İçeriği',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                message,
                style: const TextStyle(fontSize: 16),
              ),
            ),
            const SizedBox(height: 32),
            Center(
              child: ElevatedButton.icon(
                onPressed: () => _showLogsDialog(context, logs),
                icon: const Icon(Icons.bug_report_outlined),
                label: const Text('Kullanıcı Hata Günlüklerini Görüntüle'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }
}
