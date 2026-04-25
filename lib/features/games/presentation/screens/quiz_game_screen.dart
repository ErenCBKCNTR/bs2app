import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:blind_social/core/services/pocketbase_service.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:blind_social/core/utils/logger.dart';
import 'package:vibration/vibration.dart';
import 'package:audioplayers/audioplayers.dart';

class QuizGameScreen extends StatefulWidget {
  final String gameId;
  final bool isSinglePlayer;
  final bool isWaiting;

  const QuizGameScreen({
    super.key,
    required this.gameId,
    required this.isSinglePlayer,
    this.isWaiting = false,
  });

  @override
  State<QuizGameScreen> createState() => _QuizGameScreenState();
}

class _QuizGameScreenState extends State<QuizGameScreen> {
  RecordModel? _game;
  bool _isLoading = true;
  UnsubscribeFunc? _unsub;
  bool _answering = false;
  String? _selectedOption;
  bool _scoreAdded = false;
  int _currentQuestionIndex = -1;
  final FocusNode _questionFocusNode = FocusNode();

  final player = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _fetchGame();
    if (!widget.isSinglePlayer) {
      _subscribeToGame();
    }
  }

  @override
  void dispose() {
    _unsub?.call();
    player.dispose();
    _questionFocusNode.dispose();
    super.dispose();
  }

  Future<void> _checkAndAddScore() async {
    if (_game == null) return;
    if (_scoreAdded) return;
    if (_game!.getStringValue('status') == 'finished') {
      _scoreAdded = true;
      final myId = PocketBaseService.client.authStore.model!.id;
      final isPlayer1 = _game!.getStringValue('player1_id') == myId;
      final myEarnedScore = isPlayer1 ? _game!.getIntValue('player1_score') : _game!.getIntValue('player2_score');
      
      if (myEarnedScore > 0) {
        try {
          final user = await PocketBaseService.client.collection('users').getOne(myId);
          final currentScore = user.getIntValue('quiz_score');
          await PocketBaseService.client.collection('users').update(myId, body: {
            'quiz_score': currentScore + myEarnedScore
          });
        } catch (e) {
          AppLogger.instance.error('Skor ekleme hatası: $e');
        }
      }
    }
  }

  Future<void> _fetchGame() async {
    try {
      final game = await PocketBaseService.client.collection('quiz_games').getOne(widget.gameId);
      if (mounted) {
        setState(() {
          _game = game;
          _isLoading = false;
        });
        _checkAndAddScore();
      }
    } catch (e) {
      AppLogger.instance.error('Oyun yüklenemedi: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Oyun yüklenemedi: $e')));
        Navigator.pop(context);
      }
    }
  }

  Future<void> _subscribeToGame() async {
    try {
      _unsub = await PocketBaseService.client.collection('quiz_games').subscribe(widget.gameId, (e) {
        if (mounted) {
          setState(() {
            _game = e.record;
            _answering = false;
            _selectedOption = null;
          });
          
          // Also call it here so multiplayer clients apply score on update
          _checkAndAddScore();
          
          if (e.record!.getStringValue('status') == 'finished') {
             _playEndSound();
          } else {
             // Play turn sound
             _playTurnSound();
          }
        }
      });
    } catch (e) {
      AppLogger.instance.error('Abonelik hatası: $e');
    }
  }
  
  void _playTurnSound() {
    // We can play a simple system tone or an online sound if we have one.
    // For now we'll just vibrate briefly.
    Vibration.vibrate(duration: 100);
  }

  void _playEndSound() {
    Vibration.vibrate(pattern: [0, 500, 200, 500, 200, 1000]);
  }

  Future<void> _submitAnswer(String option, Map<String, dynamic> currentQuestion) async {
    if (_answering) return;
    setState(() {
      _answering = true;
      _selectedOption = option;
    });

    final isCorrect = currentQuestion['correct_answer'] == option;
    
    // Feedback
    if (isCorrect) {
      // Correct feedback (short, short, long)
      Vibration.vibrate(pattern: [0, 100, 50, 100, 50, 300]);
      try {
        await player.play(UrlSource('https://api.cabukcan.com/sounds/games/quiz/dogru_cevap.mp3'));
      } catch (e) {
        AppLogger.instance.error('Doğru cevap sesi çalınamadı: $e');
      }
    } else {
      // Wrong feedback (long, long)
      Vibration.vibrate(pattern: [0, 400, 100, 400]);
      try {
        await player.play(UrlSource('https://api.cabukcan.com/sounds/games/quiz/yanlis_cevap.mp3'));
      } catch (e) {
        AppLogger.instance.error('Yanlış cevap sesi çalınamadı: $e');
      }
    }

    try {
      final myId = PocketBaseService.client.authStore.model!.id;
      final isPlayer1 = _game!.getStringValue('player1_id') == myId;
      
      int p1Score = _game!.getIntValue('player1_score');
      int p2Score = _game!.getIntValue('player2_score');
      
      if (isCorrect) {
        if (isPlayer1) {
          p1Score += 10;
        } else {
          p2Score += 10;
        }
      }

      int currentIndex = _game!.getIntValue('current_question_index');
      
      String nextStatus = _game!.getStringValue('status');
      String nextTurnId = _game!.getStringValue('current_turn_id');
      
      if (!isCorrect) {
        nextStatus = 'finished';
      } else {
        if (widget.isSinglePlayer) {
          currentIndex++;
          if (currentIndex >= _game!.getDataValue<List>('questions_json').length) {
            nextStatus = 'finished';
          }
        } else {
          // Multiplayer alternating logic
          if (isPlayer1) {
            nextTurnId = _game!.getStringValue('player2_id');
          } else {
            nextTurnId = _game!.getStringValue('player1_id');
            currentIndex++; // Both players answered this question
          }
          
          if (currentIndex >= _game!.getDataValue<List>('questions_json').length) {
            nextStatus = 'finished';
          }
        }
      }

      await PocketBaseService.client.collection('quiz_games').update(widget.gameId, body: {
        'player1_score': p1Score,
        'player2_score': p2Score,
        'current_question_index': currentIndex,
        'status': nextStatus,
        'current_turn_id': nextTurnId,
      });

      if (widget.isSinglePlayer) {
        _fetchGame();
        setState(() {
          _answering = false;
          _selectedOption = null;
        });
        if (nextStatus == 'finished' && isCorrect) {
           _playEndSound();
        }
      }
    } catch (e) {
      AppLogger.instance.error('Cevap gönderilirken hata: $e');
      setState(() => _answering = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _game == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final status = _game!.getStringValue('status');
    if (status == 'waiting') {
      return Scaffold(
        appBar: AppBar(title: const Text('Bekleniyor...')),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Rakibin daveti kabul etmesi bekleniyor...', style: TextStyle(fontSize: 16)),
            ],
          ),
        ),
      );
    }

    if (status == 'finished') {
      final p1Score = _game!.getIntValue('player1_score');
      final p2Score = _game!.getIntValue('player2_score');
      
      return Scaffold(
        appBar: AppBar(title: const Text('Oyun Bitti')),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.emoji_events, size: 80, color: Colors.amber),
                const SizedBox(height: 24),
                const Text(
                  'Skor Tablosu',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Text(
                  widget.isSinglePlayer ? 'Puanınız: $p1Score' : 'Siz: $p1Score - Rakip: $p2Score',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 20),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Menüye Dön'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Active
    final questions = _game!.getDataValue<List>('questions_json');
    final currentIndex = _game!.getIntValue('current_question_index');
    final currentTurnId = _game!.getStringValue('current_turn_id');
    final myId = PocketBaseService.client.authStore.model!.id;

    if (currentIndex != _currentQuestionIndex) {
      _currentQuestionIndex = currentIndex;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _questionFocusNode.canRequestFocus) {
          _questionFocusNode.requestFocus();
          SemanticsService.announce(questions[currentIndex]['question'] ?? '', TextDirection.ltr);
        }
      });
    }

    if (currentIndex >= questions.length) {
      return const Scaffold(body: Center(child: Text('Hata: Soru indeksi sınırların dışında.')));
    }

    final currentQ = questions[currentIndex] as Map<String, dynamic>;
    final isMyTurn = currentTurnId == myId;

    return Scaffold(
      appBar: AppBar(
        title: Text('Soru ${currentIndex + 1} / ${questions.length}'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Puan: ${_game!.getIntValue("player1_score")}'),
                  if (!widget.isSinglePlayer) Text('Rakip Puan: ${_game!.getIntValue("player2_score")}'),
                ],
              ),
              const SizedBox(height: 24),
              Expanded(
                child: Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Center(
                      child: Focus(
                        focusNode: _questionFocusNode,
                        child: Text(
                          currentQ['question'] ?? '',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              if (!isMyTurn && !widget.isSinglePlayer)
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('Sıra rakipte, bekleniyor...', textAlign: TextAlign.center, style: TextStyle(fontSize: 16)),
                )
              else ...[
                _buildOptionButton('a', currentQ['option_a'], currentQ),
                const SizedBox(height: 12),
                _buildOptionButton('b', currentQ['option_b'], currentQ),
                const SizedBox(height: 12),
                _buildOptionButton('c', currentQ['option_c'], currentQ),
                const SizedBox(height: 12),
                _buildOptionButton('d', currentQ['option_d'], currentQ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionButton(String optionKey, String? text, Map<String, dynamic> currentQ) {
    final isSelected = _selectedOption == optionKey;
    final isCorrect = currentQ['correct_answer'] == optionKey;
    
    Color bgColor = Theme.of(context).cardColor;
    if (_answering && isSelected) {
      bgColor = isCorrect ? Colors.green : Colors.red;
    }

    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        backgroundColor: bgColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: _answering ? null : () => _submitAnswer(optionKey, currentQ),
      child: Text(
        text ?? '',
        style: const TextStyle(fontSize: 16),
      ),
    );
  }
}
