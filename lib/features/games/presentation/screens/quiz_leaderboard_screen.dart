import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:blind_social/core/services/pocketbase_service.dart';
import 'package:blind_social/core/utils/logger.dart';

class QuizLeaderboardScreen extends StatefulWidget {
  const QuizLeaderboardScreen({super.key});

  @override
  State<QuizLeaderboardScreen> createState() => _QuizLeaderboardScreenState();
}

class _QuizLeaderboardScreenState extends State<QuizLeaderboardScreen> {
  List<RecordModel> _users = [];
  bool _isLoading = true;
  String? _myId;
  int _myRank = -1;

  @override
  void initState() {
    super.initState();
    _myId = PocketBaseService.client.authStore.model?.id;
    _fetchLeaderboard();
  }

  Future<void> _fetchLeaderboard() async {
    try {
      final res = await PocketBaseService.client.collection('users').getList(
        page: 1,
        perPage: 10,
        sort: '-quiz_score',
        filter: 'quiz_score > 0',
      );
      
      if (mounted) {
        setState(() {
          _users = res.items;
          _isLoading = false;
          _myRank = _users.indexWhere((r) => r.id == _myId) + 1;
        });
      }
    } catch (e) {
      AppLogger.instance.error('Liderlik tablosu hatası: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Puan Tablosu'),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _users.isEmpty
                ? const Center(child: Text('Henüz puan alan oyuncu yok.'))
                : Column(
                    children: [
                      if (_myRank > 0)
                        Semantics(
                          label: 'Puan tablosunda $_myRank. sıradasınız.',
                          child: Container(
                            margin: const EdgeInsets.all(16),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.green),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.emoji_events, color: Colors.green, size: 32),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Text(
                                    'Puan tablosunda $_myRank. sıradasınız.',
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      Expanded(
                        child: ListView.separated(
addAutomaticKeepAlives: false,
addRepaintBoundaries: true,
                          itemCount: _users.length,
                          separatorBuilder: (_, __) => const Divider(),
                          itemBuilder: (context, index) {
                            final user = _users[index];
                            final isMe = user.id == _myId;
                            final score = user.getIntValue('quiz_score');
                            final name = user.getStringValue('username').isNotEmpty
                                ? user.getStringValue('username')
                                : 'Anonim';
                            
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: isMe ? Colors.blue : Colors.grey,
                                child: Text('${index + 1}', style: const TextStyle(color: Colors.white)),
                              ),
                              title: Text(
                                name,
                                style: TextStyle(
                                  fontWeight: isMe ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                              trailing: Text(
                                '$score Puan',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
}
