import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:blind_social/core/services/pocketbase_service.dart';
import 'package:blind_social/core/services/tts_service.dart';
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

class _QuizGameScreenState extends State<QuizGameScreen> with TickerProviderStateMixin {
  RecordModel? _game;
  bool _isLoading = true;
  UnsubscribeFunc? _unsub;
  bool _answering = false;
  String? _selectedOption;
  bool _scoreAdded = false;
  int _currentQuestionIndex = -1;
  final FocusNode _questionFocusNode = FocusNode();

  final player = AudioPlayer();
  bool _hasSpokenGameOver = false;

  late final AnimationController _blinkController;

  @override
  void initState() {
    super.initState();
    _blinkController = AnimationController(
       vsync: this,
       duration: const Duration(milliseconds: 600),
    );
    _fetchGame();
    if (!widget.isSinglePlayer) {
      _subscribeToGame();
    }
  }

  Offset? _lastTapPosition;

  @override
  void dispose() {
    _unsub?.call();
    player.dispose();
    TtsService().stop();
    _questionFocusNode.dispose();
    _blinkController.dispose();
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
      final sub = await PocketBaseService.client.collection('quiz_games').subscribe(widget.gameId, (e) {
        if (mounted) {
          setState(() {
            _game = e.record;
            _answering = false;
            _selectedOption = null;
            _blinkController.stop();
          });
          
          // Also call it here so multiplayer clients apply score on update
          _checkAndAddScore();
          
          if (e.record!.getStringValue('status') == 'finished') {
             _playEndSound();
          }
        }
      });
      if (!mounted) {
        sub.call();
        return;
      }
      _unsub = sub;
    } catch (e) {
      AppLogger.instance.error('Abonelik hatası: $e');
    }
  }
  
  Future<void> _readQuestionAloud() async {
    if (_game == null) return;
    final questions = _game!.getDataValue<List>('questions_json');
    final currentIndex = _game!.getIntValue('current_question_index');
    if (currentIndex < questions.length) {
      final currentQLocal = questions[currentIndex] as Map<String, dynamic>;
      final textToAnnounce = "${currentQLocal['question']} A şıkkı: ${currentQLocal['option_a']}, B şıkkı: ${currentQLocal['option_b']}, C şıkkı: ${currentQLocal['option_c']}, D şıkkı: ${currentQLocal['option_d']}";
      SemanticsService.announce(textToAnnounce, TextDirection.ltr);
    }
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
      SemanticsService.announce('Doğru cevap!', TextDirection.ltr);
      Vibration.vibrate(pattern: [0, 100, 50, 100, 50, 300]);
      try {
        await player.setVolume(0.5);
        await player.play(UrlSource('https://api.cabukcan.com/sounds/games/quiz/dogru_cevap.mp3'));
      } catch (e) {
        AppLogger.instance.error('Doğru cevap sesi çalınamadı: $e');
      }
    } else {
      // Wrong feedback (long, long)
      final correctOpt = currentQuestion['correct_answer'].toString().toUpperCase();
      final correctText = currentQuestion['option_${currentQuestion['correct_answer']}'];
      SemanticsService.announce('Yanlış cevap verdiniz. Doğru cevap $correctOpt şıkkı: $correctText.', TextDirection.ltr);
      Vibration.vibrate(pattern: [0, 400, 100, 400]);
      _blinkController.repeat(reverse: true);
      try {
        await player.setVolume(1.0);
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

      // Wait for sound to play before transition
      await Future.delayed(const Duration(milliseconds: 3000));

      int currentIndex = _game!.getIntValue('current_question_index');
      
      String nextStatus = _game!.getStringValue('status');
      String nextTurnId = _game!.getStringValue('current_turn_id');
      
      if (widget.isSinglePlayer) {
        if (!isCorrect) {
          nextStatus = 'finished';
        } else {
          currentIndex++;
          if (currentIndex >= _game!.getDataValue<List>('questions_json').length) {
            nextStatus = 'finished';
          }
        }
      } else {
        // Multiplayer alternating logic
        if (isPlayer1) {
          nextTurnId = _game!.getStringValue('player2_id');
        } else {
          nextTurnId = _game!.getStringValue('player1_id');
          currentIndex++; // Both players answered this question
        }
        
        // Let's use the explicit length from the list
        if (currentIndex >= _game!.getDataValue<List>('questions_json').length) {
          nextStatus = 'finished';
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
          _blinkController.stop();
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
      final myId = PocketBaseService.client.authStore.model?.id;
      final isPlayer1 = _game!.getStringValue('player1_id') == myId;
      
      final myScore = isPlayer1 ? p1Score : p2Score;
      final opponentScore = isPlayer1 ? p2Score : p1Score;
      
      String resultText = '';
      if (!widget.isSinglePlayer) {
        if (myScore > opponentScore) {
          resultText = 'Tebrikler, Kazandınız!';
        } else if (opponentScore > myScore) {
          resultText = 'Rakip Kazandı!';
        } else {
          resultText = 'Berabere!';
        }
      }
      
      if (!_hasSpokenGameOver) {
        _hasSpokenGameOver = true;
        final String speechText = widget.isSinglePlayer 
            ? 'Oyun Bitti! Kazandığınız Puan: $p1Score'
            : 'Oyun Bitti! $resultText Siz $myScore, Rakibiniz ise $opponentScore puan aldı.';
        
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          // Yanlış veya doğru cevap sesinin bitmesini bekleyelim
          await Future.delayed(const Duration(milliseconds: 1500));
          SemanticsService.announce(speechText, TextDirection.ltr);
        });
      }
      
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
                Text(
                  widget.isSinglePlayer ? 'Oyun Bitti' : resultText,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Text(
                  widget.isSinglePlayer ? 'Kazandığınız Puan: $p1Score' : 'Siz: $myScore - Rakip: $opponentScore',
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
      final prevIndex = _currentQuestionIndex;
      _currentQuestionIndex = currentIndex;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (prevIndex != -1) {
          await Future.delayed(const Duration(milliseconds: 5000));
        }
        if (mounted) {
          if (_questionFocusNode.canRequestFocus) {
             _questionFocusNode.requestFocus();
          }
          Vibration.vibrate(duration: 100);
          _readQuestionAloud();
        }
      });
    }

    if (currentIndex >= questions.length) {
      return const Scaffold(body: Center(child: Text('Hata: Soru indeksi sınırların dışında.')));
    }

    final currentQ = questions[currentIndex] as Map<String, dynamic>;
    final isMyTurn = currentTurnId == myId;
    final isPlayer1 = _game!.getStringValue('player1_id') == myId;

    void replayQuestion() {
      Vibration.vibrate(duration: 100);
      if (mounted) {
        if (_questionFocusNode.canRequestFocus) {
           _questionFocusNode.requestFocus();
        }
        _readQuestionAloud();
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Soru ${currentIndex + 1} / ${questions.length}'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.replay),
            tooltip: 'Soruyu Tekrar Dinle',
            onPressed: replayQuestion,
          ),
        ],
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
                  Text('Puanım: ${isPlayer1 ? _game!.getIntValue("player1_score") : _game!.getIntValue("player2_score")}'),
                  if (!widget.isSinglePlayer)
                    Text('Rakip Puan: ${isPlayer1 ? _game!.getIntValue("player2_score") : _game!.getIntValue("player1_score")}'),
                ],
              ),
              const SizedBox(height: 24),
              Expanded(
                child: GestureDetector(
                  onDoubleTap: replayQuestion,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3))],
                    ),
                    padding: const EdgeInsets.all(24.0),
                    child: Center(
                      child: Focus(
                        focusNode: _questionFocusNode,
                        child: Text(
                          currentQ['question'] ?? '',
                          style: const TextStyle(
                            fontSize: 26, 
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                            height: 1.3,
                          ),
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
                _buildOptionButton('a', currentQ['option_a'], currentQ, Colors.blue),
                const SizedBox(height: 12),
                _buildOptionButton('b', currentQ['option_b'], currentQ, Colors.red),
                const SizedBox(height: 12),
                _buildOptionButton('c', currentQ['option_c'], currentQ, Colors.green),
                const SizedBox(height: 12),
                _buildOptionButton('d', currentQ['option_d'], currentQ, Colors.orange),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionButton(String optionKey, String? text, Map<String, dynamic> currentQ, Color defaultColor) {
    final isSelected = _selectedOption == optionKey;
    final isCorrect = currentQ['correct_answer'] == optionKey;
    
    Color bgColor = Colors.white;
    Color textColor = Colors.black87;
    bool shouldBlink = false;

    if (_answering) {
      if (isSelected) {
        bgColor = isCorrect ? Colors.green[600]! : Colors.red[600]!;
        textColor = Colors.white;
      } else if (isCorrect) {
        bgColor = Colors.green[600]!;
        textColor = Colors.white;
        shouldBlink = true;
      }
    }

    Widget content = Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Center(
        child: Text(
          text ?? '',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );

    if (shouldBlink) {
      content = AnimatedBuilder(
        animation: _blinkController,
        builder: (context, child) {
          // Opacity varies between 0.3 and 1.0
          return Opacity(
            opacity: 0.3 + 0.7 * _blinkController.value,
            child: child,
          );
        },
        child: content,
      );
    }

    return Semantics(
      button: true,
      label: text ?? '',
      excludeSemantics: true,
      child: GestureDetector(
         onTap: _answering ? null : () => _submitAnswer(optionKey, currentQ),
         child: content,
      ),
    );
  }
}
