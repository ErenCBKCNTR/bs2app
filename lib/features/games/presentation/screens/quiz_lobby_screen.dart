import 'package:flutter/material.dart';
import 'package:blind_social/core/services/pocketbase_service.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:blind_social/core/utils/logger.dart';
import 'package:blind_social/features/games/presentation/screens/quiz_game_screen.dart';
import 'package:blind_social/features/games/presentation/screens/quiz_leaderboard_screen.dart';

class QuizLobbyScreen extends StatefulWidget {
  const QuizLobbyScreen({super.key});

  @override
  State<QuizLobbyScreen> createState() => _QuizLobbyScreenState();
}

class _QuizLobbyScreenState extends State<QuizLobbyScreen> {
  bool _isLoading = false;
  int _myScore = 0;
  bool _serverReadsQuestions = false;

  @override
  void initState() {
    super.initState();
    _fetchMyScore();
  }

  Future<void> _fetchMyScore() async {
    try {
      final myId = PocketBaseService.client.authStore.model!.id;
      final user = await PocketBaseService.client.collection('users').getOne(myId);
      if (mounted) {
        setState(() {
          _myScore = user.getIntValue('quiz_score');
        });
      }
    } catch (e) {
      AppLogger.instance.error('Skor çekilemedi: $e');
    }
  }

  Future<void> _startSinglePlayerGame() async {
    setState(() => _isLoading = true);
    try {
      final myId = PocketBaseService.client.authStore.model!.id;
      
      // Get 15 random questions.
      // Since PocketBase doesn't have native "random", we can just fetch some and shuffle in Dart.
      final questionsResult = await PocketBaseService.client.collection('quiz_questions').getList(
        page: 1,
        perPage: 100, // Fetch up to 100
      );
      
      final List<RecordModel> allQuestions = questionsResult.items;
      if (_serverReadsQuestions) {
        allQuestions.retainWhere((q) => q.getStringValue('audio_file').isNotEmpty);
      }
      allQuestions.shuffle();
      final selectedQuestions = allQuestions.take(15).toList();
      
      if (selectedQuestions.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Veri tabanında uygun soru bulunamadı!')),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      // Convert questions to JSON list so we can freeze them for this game
      final questionsJson = selectedQuestions.map((q) => q.toJson()).toList();

      final game = await PocketBaseService.client.collection('quiz_games').create(body: {
        'player1_id': myId,
        'status': 'active',
        'current_turn_id': myId,
        'player1_score': 0,
        'current_question_index': 0,
        'questions_json': questionsJson,
        'is_singleplayer': true,
      });

      if (mounted) {
        if (_serverReadsQuestions) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              title: const Text('Önemli Uyarı', style: TextStyle(color: Colors.red)),
              content: const Text(
                'Lütfen ekran okuyucunuzu kapatın. Sorular sistem tarafından otomatik okunacaktır. Ekran 4\'e bölünecektir. Sadece gerekli alana dokunarak cevap verebilirsiniz.'
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => QuizGameScreen(gameId: game.id, isSinglePlayer: true, serverReadsQuestions: _serverReadsQuestions)),
                    );
                  },
                  child: const Text('Anladım, Başla'),
                )
              ],
            ),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => QuizGameScreen(gameId: game.id, isSinglePlayer: true, serverReadsQuestions: _serverReadsQuestions)),
          );
        }
      }
    } catch (e) {
      AppLogger.instance.error('Tek kişilik oyun başlatılamadı: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata oluştu: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showMultiplayerInviteDialog() {
    final controller = TextEditingController();
    int selectedQuestionCount = 10;
    
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Arkadaşını Davet Et'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: controller,
                    decoration: const InputDecoration(
                      hintText: 'Kullanıcı adı veya tam ad',
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    value: selectedQuestionCount,
                    decoration: const InputDecoration(
                      labelText: 'Soru Sayısı',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 10, child: Text('10 Soru')),
                      DropdownMenuItem(value: 20, child: Text('20 Soru')),
                      DropdownMenuItem(value: 30, child: Text('30 Soru')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setStateDialog(() => selectedQuestionCount = val);
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('İptal'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _inviteMultiplayer(controller.text, selectedQuestionCount);
                  },
                  child: const Text('Davet Et'),
                ),
              ],
            );
          }
        );
      },
    );
  }
  
  Future<void> _inviteMultiplayer(String query, int questionCount) async {
    if (query.isEmpty) return;
    setState(() => _isLoading = true);
    
    try {
      final users = await PocketBaseService.client.collection('users').getList(
        page: 1,
        perPage: 1,
        filter: 'username = "$query" || full_name ~ "$query"',
      );
      
      if (users.items.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Kullanıcı bulunamadı.')),
          );
        }
        setState(() => _isLoading = false);
        return;
      }
      
      final targetUser = users.items.first;
      final targetId = targetUser.id;
      final myId = PocketBaseService.client.authStore.model!.id;
      
      if (targetId == myId) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Kendinizi davet edemezsiniz.')),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      final questionsResult = await PocketBaseService.client.collection('quiz_questions').getList(
        page: 1,
        perPage: 100,
      );
      final List<RecordModel> allQuestions = questionsResult.items;
      if (_serverReadsQuestions) {
        allQuestions.retainWhere((q) => q.getStringValue('audio_file').isNotEmpty);
      }
      allQuestions.shuffle();
      final selectedQuestions = allQuestions.take(questionCount).toList();
      
      if (selectedQuestions.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Veri tabanında uygun soru bulunamadı!')),
          );
        }
        setState(() => _isLoading = false);
        return;
      }
      
      final questionsJson = selectedQuestions.map((q) => q.toJson()).toList();

      final game = await PocketBaseService.client.collection('quiz_games').create(body: {
        'player1_id': myId,
        'player2_id': targetId,
        'status': 'waiting',
        'current_turn_id': myId,
        'player1_score': 0,
        'player2_score': 0,
        'current_question_index': 0,
        'questions_json': questionsJson,
        'is_singleplayer': false,
      });

      if (mounted) {
        // We go to the game screen as waiting.
        if (_serverReadsQuestions) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              title: const Text('Önemli Uyarı', style: TextStyle(color: Colors.red)),
              content: const Text(
                'Lütfen ekran okuyucunuzu kapatın. Sorular sistem tarafından otomatik okunacaktır. Ekran 4\'e bölünecektir. Sadece gerekli alana dokunarak cevap verebilirsiniz.'
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => QuizGameScreen(gameId: game.id, isSinglePlayer: false, isWaiting: true, serverReadsQuestions: _serverReadsQuestions)),
                    );
                  },
                  child: const Text('Anladım, Başla'),
                )
              ],
            ),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => QuizGameScreen(gameId: game.id, isSinglePlayer: false, isWaiting: true, serverReadsQuestions: _serverReadsQuestions)),
          );
        }
      }
      
    } catch (e) {
      AppLogger.instance.error('Davet gönderilemedi: $e');
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bilgi Yarışması'),
        actions: [
          Semantics(
            label: 'Toplam Puanınız $_myScore',
            child: Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Center(
                child: Text(
                  '$_myScore Puan',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          )
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _startSinglePlayerGame,
                      icon: const Icon(Icons.person, size: 32),
                      label: const Text('Tek Kişilik Oyna', style: TextStyle(fontSize: 20)),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        backgroundColor: Colors.blueAccent,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _showMultiplayerInviteDialog,
                      icon: const Icon(Icons.people, size: 32),
                      label: const Text('Arkadaşınla Oyna', style: TextStyle(fontSize: 20)),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const QuizLeaderboardScreen()),
                        ).then((_) => _fetchMyScore());
                      },
                      icon: const Icon(Icons.leaderboard, size: 32),
                      label: const Text('Puan Tablosu', style: TextStyle(fontSize: 20)),
                    ),
                    const SizedBox(height: 24),
                    CheckboxListTile(
                      title: const Text('Soruları Sunucu Okusun', style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: const Text('Bu mod seçildiğinde sadece sesi yüklenmiş sorular gelir, özel bölünmüş ekran açılır.'),
                      value: _serverReadsQuestions,
                      onChanged: (val) {
                        setState(() {
                          _serverReadsQuestions = val ?? false;
                        });
                      },
                      activeColor: Colors.blueAccent,
                      checkColor: Colors.white,
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
