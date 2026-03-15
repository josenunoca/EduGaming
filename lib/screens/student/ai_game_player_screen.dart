import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import 'package:record/record.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:firebase_storage/firebase_storage.dart';
import '../../../services/firebase_service.dart';
import '../../../models/subject_model.dart';
import '../../../widgets/glass_card.dart';
import '../../../widgets/ai_translated_text.dart';
import '../../../widgets/jigsaw_puzzle_widget.dart';
import '../../../widgets/word_search_widget.dart';
import '../../../widgets/memory_game_widget.dart';
import '../../../widgets/matching_pairs_widget.dart';
import '../../../widgets/ai_chat_dialog.dart';
import 'package:flutter_animate/flutter_animate.dart';

class AiGamePlayerScreen extends StatefulWidget {
  final AiGame game;
  final bool isEvaluation;

  const AiGamePlayerScreen({
    super.key,
    required this.game,
    this.isEvaluation = false,
  });

  @override
  State<AiGamePlayerScreen> createState() => _AiGamePlayerScreenState();
}

class _AiGamePlayerScreenState extends State<AiGamePlayerScreen> {
  int _currentQuestionIndex = 0;
  int _timeLeft = 20;
  Timer? _timer;
  double _score = 0;
  bool _isFinished = false;
  bool _pinVerified = false;
  final TextEditingController _pinController = TextEditingController();
  int? _selectedIdx;
  bool _showCorrectness = false;
  final List<int> _correctAnswersIndices = [];
  final List<int> _incorrectAnswersIndices = [];

  // New state for evaluation mode
  final Map<int, int?> _selectedAnswers = {};
  final Map<int, Map<String, dynamic>> _studentResponses =
      {}; // questionIndex -> { 'type': ..., 'value': ... }
  final TextEditingController _textResponseController = TextEditingController();

  final _audioRecorder = AudioRecorder();
  final _imagePicker = ImagePicker();
  bool _isRecording = false;
  bool _isUploading = false;

  // Real-time session fields
  ExamSession? _currentSession;
  Timer? _heartbeatTimer;
  bool _isBlocked = false;
  String? _blockMessage;

  @override
  void initState() {
    super.initState();
    if (widget.isEvaluation) {
      _initializeSession();
    } else {
      _startTimer();
    }
  }

  Future<void> _initializeSession() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final existing = await context
        .read<FirebaseService>()
        .getExamSession(user.uid, widget.game.id);
    if (!mounted) return;

    if (existing != null) {
      if (existing.status == 'completed') {
        setState(() {
          _isBlocked = true;
          _blockMessage = 'Já completou esta avaliação.';
        });
        return;
      }

      if (existing.status == 'abandoned' && !existing.authorizedReentry) {
        setState(() {
          _isBlocked = true;
          _blockMessage =
              'A avaliação foi interrompida. Solicite autorização ao professor para continuar.';
        });
        return;
      }

      _currentSession = existing;
      // Mark as active again if it was authorized or just reopening
      if (!mounted) return;
      await context
          .read<FirebaseService>()
          .setExamSessionStatus(existing.id, 'active');
    } else {
      // Create new session
      final newSession = ExamSession(
        id: const Uuid().v4(),
        studentId: user.uid,
        studentName:
            user.displayName ?? user.email?.split('@').first ?? 'Aluno',
        subjectId: widget.game.subjectId,
        gameId: widget.game.id,
        status: 'active',
        startTime: DateTime.now(),
        lastHeartbeat: DateTime.now(),
      );
      if (!mounted) return;
      await context.read<FirebaseService>().saveExamSession(newSession);
      _currentSession = newSession;
    }

    _startTimer();
    _startHeartbeat();
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (_currentSession != null && !_isFinished) {
        context.read<FirebaseService>().updateExamSessionHeartbeat(
            _currentSession!.id, _score, _currentQuestionIndex);
      }
    });
  }

  void _startTimer() {
    if (widget.isEvaluation) return;
    _timeLeft = widget.game.questions[_currentQuestionIndex].timeLimitSeconds;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timeLeft > 0) {
        setState(() => _timeLeft--);
      } else {
        _timer?.cancel();
        if (!widget.isEvaluation) {
          _submitAnswer(null); // Time's up
        }
      }
    });
  }

  void _submitAnswer(int? index) {
    if (_showCorrectness) return;
    _timer?.cancel();

    setState(() {
      _selectedIdx = index;
      _showCorrectness = true;
      final q = widget.game.questions[_currentQuestionIndex];
      if (index == q.correctOptionIndex) {
        _correctAnswersIndices.add(_currentQuestionIndex);
        final speedBonus = (_timeLeft / q.timeLimitSeconds) * 5;
        _score += q.points + speedBonus;
      } else {
        _incorrectAnswersIndices.add(_currentQuestionIndex);
      }
    });

    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      if (_currentQuestionIndex < widget.game.questions.length - 1) {
        setState(() {
          _currentQuestionIndex++;
          _showCorrectness = false;
          _selectedIdx = null;
        });
        _startTimer();
      } else {
        _finishGame();
      }
    });
  }

  void _confirmSubmission() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const AiTranslatedText('Submeter Avaliação',
            style: TextStyle(color: Colors.white)),
        content: const AiTranslatedText(
            'Tem a certeza que deseja submeter a sua avaliação? Não poderá alterar as respostas depois.',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const AiTranslatedText('Rever'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _finishEvaluation();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const AiTranslatedText('Confirmar e Submeter'),
          ),
        ],
      ),
    );
  }

  void _finishEvaluation() {
    // Calculate final score for evaluation
    double finalScore = 0;
    final List<int> corrects = [];
    final List<int> incorrects = [];
    final Map<int, int> selectedOptions = {};

    for (int i = 0; i < widget.game.questions.length; i++) {
      final q = widget.game.questions[i];
      final answer = _selectedAnswers[i];

      if (answer != null) {
        selectedOptions[i] = answer;
      }

      // Points calculation for options
      if (answer != null && answer == q.correctOptionIndex) {
        corrects.add(i);
        finalScore += q.points;
      } else if (answer != null) {
        // Only add to incorrects if an option was selected and it was wrong
        incorrects.add(i);
      }

      // If it's multimodal, we might need manual grading, so score stays 0 for now or uses special logic
      // For now, we only score multiple choice questions automatically.
      // Multimodal responses (text, audio, image) will be saved but not automatically scored here.
    }

    _score = finalScore;
    _correctAnswersIndices.clear();
    _correctAnswersIndices.addAll(corrects);
    _incorrectAnswersIndices.clear();
    _incorrectAnswersIndices.addAll(incorrects);

    _finishGame(selectedOptions, _studentResponses);
  }

  void _finishGame(
      [Map<int, int>? finalSelectedOptions,
      Map<int, Map<String, dynamic>>? studentResponses]) {
    setState(() => _isFinished = true);
    _heartbeatTimer?.cancel();

    if (_currentSession != null) {
      context
          .read<FirebaseService>()
          .setExamSessionStatus(_currentSession!.id, 'completed');
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      Map<int, int> optionsToSave = finalSelectedOptions ?? {};
      Map<int, Map<String, dynamic>> responsesToSave = studentResponses ?? {};

      if (!widget.isEvaluation && _selectedIdx != null) {
        optionsToSave[_currentQuestionIndex] = _selectedIdx!;
      }

      final result = AiGameResult(
        id: const Uuid().v4(),
        gameId: widget.game.id,
        studentId: user.uid,
        studentName:
            user.displayName ?? user.email?.split('@').first ?? 'Aluno',
        subjectId: widget.game.subjectId,
        score: _score,
        correctAnswers: _correctAnswersIndices,
        incorrectAnswers: _incorrectAnswersIndices,
        selectedOptions: optionsToSave,
        studentResponses: responsesToSave,
        playedAt: DateTime.now(),
        isEvaluation: widget.isEvaluation,
      );
      context.read<FirebaseService>().saveAiGameResult(result);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _heartbeatTimer?.cancel();
    _pinController.dispose();
    _textResponseController.dispose();
    _audioRecorder.dispose();
    super.dispose();
  }

  Future<String?> _uploadFile(String filePath, String folder) async {
    final file = File(filePath);
    if (!file.existsSync()) return null;

    setState(() => _isUploading = true);
    try {
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${p.basename(filePath)}';
      final ref =
          FirebaseStorage.instance.ref().child('evaluations/$folder/$fileName');
      await ref.putFile(file);
      return await ref.getDownloadURL();
    } catch (e) {
      debugPrint('Upload error: $e');
      return null;
    } finally {
      setState(() => _isUploading = false);
    }
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final directory = await getApplicationDocumentsDirectory();
        final path = p.join(directory.path,
            'recording_${DateTime.now().millisecondsSinceEpoch}.m4a');

        const config = RecordConfig();
        await _audioRecorder.start(config, path: path);
        setState(() => _isRecording = true);
      }
    } catch (e) {
      debugPrint('Start recording error: $e');
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _audioRecorder.stop();
      setState(() => _isRecording = false);

      if (path != null) {
        final url = await _uploadFile(path, 'audio');
        if (url != null) {
          setState(() {
            _studentResponses[_currentQuestionIndex] = {
              'type': 'audio',
              'value': url
            };
          });
        }
      }
    } catch (e) {
      debugPrint('Stop recording error: $e');
    }
  }

  Future<void> _takePhoto() async {
    try {
      final XFile? photo =
          await _imagePicker.pickImage(source: ImageSource.camera);
      if (photo != null) {
        final url = await _uploadFile(photo.path, 'images');
        if (url != null) {
          setState(() {
            _studentResponses[_currentQuestionIndex] = {
              'type': 'image',
              'value': url
            };
          });
        }
      }
    } catch (e) {
      debugPrint('Photo error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isBlocked) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        body: Center(
          child: GlassCard(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock, color: Colors.redAccent, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    _blockMessage ?? 'Acesso Bloqueado',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const AiTranslatedText('Voltar'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (widget.game.pin != null &&
        widget.game.pin!.isNotEmpty &&
        !_pinVerified) {
      return _buildPinEntry();
    }

    if (_isFinished) return _buildResults();

    final q = widget.game.questions[_currentQuestionIndex];
    final progress = (_currentQuestionIndex + 1) / widget.game.questions.length;

    return PopScope(
      canPop: !widget.isEvaluation || _isFinished,
      onPopInvoked: (didPop) {
        if (didPop) return;
        _showExitConfirmation();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white54),
                        onPressed: () {
                          if (widget.isEvaluation) {
                            _showExitConfirmation();
                          } else {
                            Navigator.pop(context);
                          }
                        },
                      ),
                      if (!widget.isEvaluation)
                        Text(
                          'Score: ${_score.toInt()}',
                          style: const TextStyle(
                              color: Color(0xFF00D1FF),
                              fontWeight: FontWeight.bold,
                              fontSize: 18),
                        ),
                      if (widget.isEvaluation)
                        const Chip(
                          label: AiTranslatedText('MODO EXAME',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12)),
                          backgroundColor: Colors.redAccent,
                        ),
                      if (!widget.isEvaluation)
                        FutureBuilder<Subject?>(
                          future: context
                              .read<FirebaseService>()
                              .getSubject(widget.game.subjectId),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) return const SizedBox();
                            final subject = snapshot.data!;
                            final gameContents = subject.contents
                                .where((c) =>
                                    widget.game.sourceContentIds.contains(c.id))
                                .toList();

                            if (gameContents.isEmpty) return const SizedBox();

                            return IconButton(
                              icon: const Icon(Icons.auto_awesome,
                                  color: Colors.amber),
                              onPressed: () {
                                showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  backgroundColor: Colors.transparent,
                                  builder: (context) => SizedBox(
                                    height: MediaQuery.of(context).size.height *
                                        0.8,
                                    child: AiChatDialog(
                                      selectedContents: gameContents,
                                      isStudent: true,
                                    ),
                                  ),
                                );
                              },
                              tooltip: 'IA Professor: Pedir Ajuda',
                            );
                          },
                        ),
                    ],
                  ),
                  LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.white10,
                    color: const Color(0xFF7B61FF),
                  ),
                  const SizedBox(height: 20),
                  if (!widget.isEvaluation) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 50,
                              height: 50,
                              child: CircularProgressIndicator(
                                value: _timeLeft / q.timeLimitSeconds,
                                color: _timeLeft < 5
                                    ? Colors.redAccent
                                    : const Color(0xFF00D1FF),
                                backgroundColor: Colors.white10,
                              ),
                            ),
                            Text(
                              '$_timeLeft',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 20),
                  if (_isUploading)
                    const LinearProgressIndicator(
                      backgroundColor: Colors.white12,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Color(0xFF00D1FF)),
                    ),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          if (widget.game.type == 'jigsaw' &&
                              widget.game.imageUrl != null)
                            JigsawPuzzleWidget(
                              imageUrl: widget.game.imageUrl!,
                              onWin: _finishGame,
                            )
                          else if (widget.game.type == 'word_search')
                            WordSearchWidget(
                              words: widget.game.questions
                                  .map((q) => q.question)
                                  .toList(),
                              onWin: _finishGame,
                            )
                          else if (widget.game.type == 'memory' &&
                              widget.game.settings?['pairs'] != null)
                            MemoryGameWidget(
                              pairs: List<Map<String, String>>.from(
                                  (widget.game.settings!['pairs'] as List)
                                      .map((p) => Map<String, String>.from(p))),
                              onWin: _finishGame,
                            )
                          else if (widget.game.type == 'matching' &&
                              widget.game.settings?['pairs'] != null)
                            MatchingPairsWidget(
                              pairs: List<Map<String, String>>.from(
                                  (widget.game.settings!['pairs'] as List)
                                      .map((p) => Map<String, String>.from(p))),
                              onWin: _finishGame,
                            )
                          else ...[
                            AiTranslatedText(
                              q.question,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  fontSize: 22,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 32),
                            if (q.allowedAnswerTypes.contains('options')) ...[
                              ...List.generate(
                                  q.options.length, (i) => _buildOption(i, q)),
                              const SizedBox(height: 24),
                            ],
                            if (q.allowedAnswerTypes.contains('text'))
                              _buildTextInput(),
                            if (q.allowedAnswerTypes.contains('audio'))
                              _buildAudioInput(),
                            if (q.allowedAnswerTypes.contains('image'))
                              _buildImageInput(),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildNavigationButtons(),
                  const SizedBox(height: 8),
                  AiTranslatedText(
                    'Pergunta ${_currentQuestionIndex + 1} de ${widget.game.questions.length}',
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavigationButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (widget.isEvaluation)
          ElevatedButton.icon(
            onPressed: _currentQuestionIndex == 0
                ? null
                : () {
                    setState(() {
                      _currentQuestionIndex--;
                    });
                  },
            icon: const Icon(Icons.arrow_back),
            label: const AiTranslatedText('Anterior'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white10,
              foregroundColor: Colors.white,
            ),
          ),
        if (widget.isEvaluation)
          _currentQuestionIndex == widget.game.questions.length - 1
              ? ElevatedButton.icon(
                  onPressed: _confirmSubmission,
                  icon: const Icon(Icons.check_circle),
                  label: const AiTranslatedText('Submeter'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                )
              : ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _currentQuestionIndex++;
                    });
                  },
                  icon: const Icon(Icons.arrow_forward),
                  label: const AiTranslatedText('Próximo'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7B61FF),
                    foregroundColor: Colors.white,
                  ),
                ),
      ],
    );
  }

  Widget _buildOption(int index, GameQuestion q) {
    bool isSelected;
    if (widget.isEvaluation) {
      isSelected = _selectedAnswers[_currentQuestionIndex] == index;
    } else {
      isSelected = _selectedIdx == index;
    }

    final bool isCorrect = index == q.correctOptionIndex;

    Color color = Colors.white.withOpacity(0.05);
    Color borderColor = Colors.white10;

    if (!widget.isEvaluation && _showCorrectness) {
      if (isCorrect) {
        color = Colors.greenAccent.withOpacity(0.2);
        borderColor = Colors.greenAccent;
      } else if (isSelected) {
        color = Colors.redAccent.withOpacity(0.2);
        borderColor = Colors.redAccent;
      }
    } else if (isSelected) {
      borderColor = const Color(0xFF00D1FF);
      color = const Color(0xFF00D1FF).withOpacity(0.1);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: InkWell(
        onTap: () {
          if (widget.isEvaluation) {
            setState(() {
              _selectedAnswers[_currentQuestionIndex] = index;
            });
          } else {
            _submitAnswer(index);
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(16),
          width: double.infinity,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: 2),
          ),
          child: Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF00D1FF) : Colors.white10,
                  borderRadius: BorderRadius.circular(6),
                ),
                alignment: Alignment.center,
                child: Text(
                  String.fromCharCode(65 + index),
                  style: TextStyle(
                    color: isSelected ? Colors.black : Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AiTranslatedText(
                  q.options[index],
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                ),
              ),
              if (!widget.isEvaluation && _showCorrectness && isCorrect)
                const Icon(Icons.check_circle,
                        color: Colors.greenAccent, size: 20)
                    .animate()
                    .scale(duration: 200.ms)
                    .then()
                    .shake(),
              if (!widget.isEvaluation &&
                  _showCorrectness &&
                  isSelected &&
                  !isCorrect)
                const Icon(Icons.cancel, color: Colors.redAccent, size: 20)
                    .animate()
                    .shake(),
              if (widget.isEvaluation && isSelected)
                const Icon(Icons.radio_button_checked,
                    color: Color(0xFF00D1FF), size: 20),
            ],
          ),
        )
            .animate(target: isSelected ? 1 : 0)
            .scale(begin: const Offset(1, 1), end: const Offset(1.02, 1.02)),
      ),
    );
  }

  Widget _buildPinEntry() {
    return Center(
      child: GlassCard(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, color: Color(0xFF00D1FF), size: 48),
            const SizedBox(height: 16),
            const AiTranslatedText('PIN de Acesso Necessário',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const AiTranslatedText(
                'Este jogo está protegido. Introduza o PIN para começar.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 24),
            TextField(
              controller: _pinController,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              obscureText: true,
              style: const TextStyle(
                  color: Colors.white, fontSize: 24, letterSpacing: 8),
              decoration: const InputDecoration(
                hintText: '****',
                hintStyle: TextStyle(color: Colors.white10),
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                if (_pinController.text == widget.game.pin) {
                  setState(() => _pinVerified = true);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('PIN Incorreto'),
                        backgroundColor: Colors.redAccent),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: const Color(0xFF7B61FF),
              ),
              child: const AiTranslatedText('COMEÇAR JOGO'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResults() {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(40.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.emoji_events, size: 80, color: Colors.amber),
              const SizedBox(height: 24),
              AiTranslatedText(
                widget.isEvaluation ? 'Avaliação Submetida!' : 'Parabéns!',
                style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
              ),
              const SizedBox(height: 8),
              AiTranslatedText(
                widget.isEvaluation
                    ? 'A sua prova foi gravada com sucesso.'
                    : 'Completaste o desafio com sucesso.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white54),
              ),
              const SizedBox(height: 40),
              GlassCard(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    const AiTranslatedText('Pontuação Final',
                        style: TextStyle(color: Colors.white70)),
                    const SizedBox(height: 12),
                    Text(
                      _score.toInt().toString(),
                      style: const TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF00D1FF)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 48),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7B61FF),
                  minimumSize: const Size(200, 60),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30)),
                ),
                child: const AiTranslatedText('Voltar à Disciplina',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
              ).animate().scale(delay: 1.seconds).fadeIn(),
            ],
          ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.1, end: 0),
        ),
      ),
    );
  }

  Widget _buildTextInput() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AiTranslatedText('Responda por escrito:',
              style: TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 8),
          TextField(
            controller: _textResponseController,
            maxLines: 5,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Digite aqui a sua resposta...',
              hintStyle: const TextStyle(color: Colors.white24),
              fillColor: Colors.white.withValues(alpha: 0.05),
              filled: true,
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onChanged: (val) {
              _studentResponses[_currentQuestionIndex] = {
                'type': 'text',
                'value': val
              };
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAudioInput() {
    final hasResponse =
        _studentResponses[_currentQuestionIndex]?['type'] == 'audio';
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AiTranslatedText('Responda por áudio:',
              style: TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 8),
          InkWell(
            onTap: _isRecording ? _stopRecording : _startRecording,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _isRecording
                    ? Colors.red.withValues(alpha: 0.2)
                    : (hasResponse
                        ? Colors.green.withValues(alpha: 0.2)
                        : Colors.white.withValues(alpha: 0.05)),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: _isRecording
                        ? Colors.red
                        : (hasResponse ? Colors.green : Colors.white10)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                      _isRecording
                          ? Icons.stop
                          : (hasResponse ? Icons.check_circle : Icons.mic),
                      color: Colors.white),
                  const SizedBox(width: 12),
                  AiTranslatedText(
                      _isRecording
                          ? 'Parar Gravação...'
                          : (hasResponse
                              ? 'Áudio Gravado com Sucesso'
                              : 'Premia para Gravar Áudio'),
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageInput() {
    final response = _studentResponses[_currentQuestionIndex];
    final hasResponse = response?['type'] == 'image';
    final imageUrl = response?['value'];

    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AiTranslatedText('Responda por imagem:',
              style: TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 8),
          InkWell(
            onTap: _takePhoto,
            child: Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: hasResponse ? Colors.greenAccent : Colors.white10),
                image: hasResponse && imageUrl != null
                    ? DecorationImage(
                        image: NetworkImage(imageUrl),
                        fit: BoxFit.contain,
                      )
                    : null,
              ),
              child: !hasResponse
                  ? const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.camera_alt, color: Colors.white, size: 40),
                        SizedBox(height: 12),
                        AiTranslatedText('Capturar Foto da Resposta',
                            style: TextStyle(color: Colors.white54)),
                      ],
                    )
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  void _showExitConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const AiTranslatedText('Sair do Exame?',
            style: TextStyle(color: Colors.white)),
        content: const AiTranslatedText(
            'ATENÇÃO: Se sair agora, o exame será marcado como ABANDONADO e precisará de autorização expressa do professor para voltar a tentar. Deseja sair?',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const AiTranslatedText('Ficar'),
          ),
          TextButton(
            onPressed: () async {
              if (_currentSession != null) {
                await context
                    .read<FirebaseService>()
                    .setExamSessionStatus(_currentSession!.id, 'abandoned');
              }
              if (mounted) {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Exit screen
              }
            },
            child: const AiTranslatedText('Sair e Abandonar',
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}
