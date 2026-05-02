import 'package:flutter/material.dart';
import 'package:blind_social/features/profile/data/services/feedback_service.dart';
import 'package:pocketbase/pocketbase.dart';
import 'feedback_detail_screen.dart';

class FeedbackManagementScreen extends StatefulWidget {
  const FeedbackManagementScreen({super.key});

  @override
  State<FeedbackManagementScreen> createState() => _FeedbackManagementScreenState();
}

class _FeedbackManagementScreenState extends State<FeedbackManagementScreen> {
  final FeedbackService _feedbackService = FeedbackService();
  List<RecordModel> _feedbacks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchFeedbacks();
  }

  Future<void> _fetchFeedbacks() async {
    try {
      final feedbacks = await _feedbackService.getAllFeedback();
      if (mounted) {
        setState(() {
          _feedbacks = feedbacks;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Geri bildirimler çekilemedi: $e')),
        );
      }
    }
  }

  String _getCategoryTurkish(String category) {
    switch (category) {
      case 'Request': return 'İstek';
      case 'Suggestion': return 'Öneri';
      case 'Complaint': return 'Şikayet';
      case 'Thank you': return 'Teşekkür';
      default: return 'Diğer';
    }
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Request': return Colors.blue;
      case 'Suggestion': return Colors.green;
      case 'Complaint': return Colors.red;
      case 'Thank you': return Colors.orange;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Geri Bildirim Yönetimi'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _feedbacks.isEmpty
              ? const Center(child: Text('Henüz geri bildirim bulunmuyor.'))
              : ListView.separated(
addAutomaticKeepAlives: false,
addRepaintBoundaries: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: _feedbacks.length,
                  separatorBuilder: (context, index) => const Divider(),
                  itemBuilder: (context, index) {
                    final feedback = _feedbacks[index];
                    final user = feedback.expand['user_id']?.first;
                    final fullName = user?.getStringValue('full_name') ?? 'Bilinmiyor';
                    final username = user?.getStringValue('username') ?? 'bilinmiyor';
                    final category = feedback.getStringValue('category');
                    final subject = feedback.getStringValue('subject');

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: _getCategoryColor(category),
                        child: Text(
                          _getCategoryTurkish(category)[0],
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      title: Text(subject, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('$fullName (@$username)\n${_getCategoryTurkish(category)}'),
                      isThreeLine: true,
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => FeedbackDetailScreen(feedback: feedback),
                          ),
                        );
                      },
                    );
                  },
                ),
    );
  }
}
