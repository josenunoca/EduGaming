import 'package:flutter/material.dart';
import '../../../models/subject_model.dart';
import '../../../widgets/glass_card.dart';
import '../../../widgets/ai_translated_text.dart';
import '../../../services/pdf_service.dart';
import '../../../services/firebase_service.dart';
import '../../../services/ai_chat_service.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:audioplayers/audioplayers.dart';

class StudentExamDetailScreen extends StatefulWidget {
  final AiGameResult result;
  final AiGame game;
  final String studentName;

  const StudentExamDetailScreen({
    super.key,
    required this.result,
    required this.game,
    required this.studentName,
  });

  @override
  State<StudentExamDetailScreen> createState() =>
      _StudentExamDetailScreenState();
}

class _StudentExamDetailScreenState extends State<StudentExamDetailScreen> {
  late Map<int, double> _teacherAdjustments;
  bool _isSavingAdjustment = false;

  final AudioPlayer _audioPlayer = AudioPlayer();
  int? _playingIndex;

  @override
  void initState() {
    super.initState();
    _teacherAdjustments = Map.from(widget.result.teacherAdjustments);
  }

  Future<void> _saveAdjustment(int qIndex, double newScore) async {
    setState(() => _isSavingAdjustment = true);
    try {
      final service = context.read<FirebaseService>();
      final updatedAdjustments = Map<int, double>.from(_teacherAdjustments);
      updatedAdjustments[qIndex] = newScore;

      // Re-calculate final score
      double finalScore =
          widget.game.questions.asMap().entries.fold(0.0, (sum, entry) {
        int idx = entry.key;
        GameQuestion q = entry.value;
        if (updatedAdjustments.containsKey(idx)) {
          return sum + updatedAdjustments[idx]!;
        }
        if (widget.result.correctAnswers.contains(idx)) return sum + q.points;
        return sum;
      });

      final updatedResult = AiGameResult(
        id: widget.result.id,
        gameId: widget.result.gameId,
        studentId: widget.result.studentId,
        studentName: widget.result.studentName,
        subjectId: widget.result.subjectId,
        score: finalScore,
        correctAnswers: widget.result.correctAnswers,
        incorrectAnswers: widget.result.incorrectAnswers,
        selectedOptions: widget.result.selectedOptions,
        studentResponses: widget.result.studentResponses,
        aiGradingDetails: widget.result.aiGradingDetails,
        teacherAdjustments: updatedAdjustments,
        playedAt: widget.result.playedAt,
        isEvaluation: widget.result.isEvaluation,
      );

      await service.saveAiGameResult(updatedResult);
      setState(() => _teacherAdjustments = updatedAdjustments);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: AiTranslatedText('Pontuação atualizada!'),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSavingAdjustment = false);
    }
  }

  Future<void> _requestAiGrading(int qIndex) async {
    final question = widget.game.questions[qIndex];
    final response = widget.result.studentResponses[qIndex];
    if (response == null) return;

    setState(() => _isSavingAdjustment = true);
    try {
      final aiService = context.read<AiChatService>();
      final evaluation = await aiService.evaluateMultimodalResponse(
        question: question.question,
        criteria: question.evaluationCriteria,
        responseType: response['type'] ?? 'unknown',
        responseValue: response['value'] ?? '',
      );

      if (evaluation != null && mounted) {
        final suggestedScore = evaluation['suggestedScore'] as num? ?? 0.0;
        final reasoning = evaluation['reasoning'] as String? ?? '';

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF1E293B),
            title: const AiTranslatedText('Sugestão da IA'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AiTranslatedText(
                    'Pontuação Sugerida: ${suggestedScore.toDouble()} / ${question.points}'),
                const SizedBox(height: 12),
                const AiTranslatedText('Justificação:',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                Text(reasoning,
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 13)),
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const AiTranslatedText('Agora Não')),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _saveAdjustment(qIndex, suggestedScore.toDouble());
                },
                child: const AiTranslatedText('Aceitar Sugestão'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro na IA: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSavingAdjustment = false);
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _toggleAudio(int qIndex, String url) async {
    if (_playingIndex == qIndex) {
      await _audioPlayer.stop();
      setState(() => _playingIndex = null);
    } else {
      await _audioPlayer.stop();
      await _audioPlayer.play(UrlSource(url));
      setState(() => _playingIndex = qIndex);

      _audioPlayer.onPlayerComplete.listen((_) {
        if (mounted) setState(() => _playingIndex = null);
      });
    }
  }

  void _showFullScreenImage(String url) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: InkWell(
          onTap: () => Navigator.pop(context),
          child: InteractiveViewer(
            child: Image.network(url),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double maxScore =
        widget.game.questions.fold(0.0, (sum, q) => sum + q.points);
    final String formattedDate =
        DateFormat('dd/MM/yyyy HH:mm').format(widget.result.playedAt);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const AiTranslatedText('Detalhes da Prova'),
        actions: [
          if (_isSavingAdjustment)
            const Center(
                child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2)))),
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: () => _downloadPDF(context),
            tooltip: 'Descarregar PDF',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Card
            GlassCard(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  AiTranslatedText(widget.studentName,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  AiTranslatedText(widget.game.title,
                      style: const TextStyle(
                          color: Color(0xFF00D1FF), fontSize: 16)),
                  const SizedBox(height: 16),
                  const Divider(color: Colors.white10),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildInfoItem('Data/Hora', formattedDate),
                      _buildInfoItem('Nota Final',
                          '${widget.result.score.toInt()} / ${maxScore.toInt()}',
                          isLarge: true),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            const AiTranslatedText('Respostas Detalhadas',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),

            // Questions List
            ...List.generate(widget.game.questions.length, (index) {
              final question = widget.game.questions[index];
              return _buildQuestionCardExtended(index, question);
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionCardExtended(int index, GameQuestion question) {
    final int? selectedOption = widget.result.selectedOptions[index];
    final bool isCorrect = widget.result.correctAnswers.contains(index);
    final response = widget.result.studentResponses[index];
    final teacherScore = _teacherAdjustments[index];
    final actualScore = teacherScore ?? (isCorrect ? question.points : 0.0);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: GlassCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                AiTranslatedText('Pergunta ${index + 1}',
                    style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 13,
                        fontWeight: FontWeight.bold)),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: (actualScore > 0 ? Colors.green : Colors.red)
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: actualScore > 0 ? Colors.green : Colors.red,
                        width: 0.5),
                  ),
                  child: Text(
                    '${actualScore.toDouble()} pts',
                    style: TextStyle(
                        color: actualScore > 0 ? Colors.green : Colors.red,
                        fontSize: 11,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            AiTranslatedText(question.question,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 16),
            if (question.allowedAnswerTypes.contains('options')) ...[
              ...List.generate(question.options.length, (i) {
                final bool isOptionSelected = selectedOption == i;
                final bool isCorrectOption = i == question.correctOptionIndex;
                Color textColor = Colors.white70;
                if (isCorrectOption) {
                  textColor = Colors.greenAccent;
                } else if (isOptionSelected && !isCorrectOption)
                  textColor = Colors.redAccent;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 6.0),
                  child: Row(
                    children: [
                      Icon(
                          isOptionSelected
                              ? Icons.radio_button_checked
                              : Icons.radio_button_off,
                          size: 14,
                          color: isOptionSelected
                              ? const Color(0xFF00D1FF)
                              : Colors.white10),
                      const SizedBox(width: 10),
                      Expanded(
                          child: AiTranslatedText(question.options[i],
                              style:
                                  TextStyle(color: textColor, fontSize: 13))),
                    ],
                  ),
                );
              }),
            ],
            if (response != null) ...[
              const Divider(color: Colors.white10, height: 24),
              const AiTranslatedText('Resposta do Aluno:',
                  style: TextStyle(color: Colors.white38, fontSize: 12)),
              const SizedBox(height: 8),
              _buildResponseValue(index, response),
            ],
            if (question.allowedAnswerTypes.any((t) => t != 'options')) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _requestAiGrading(index),
                    icon: const Icon(Icons.auto_awesome, size: 16),
                    label: const AiTranslatedText('Sugestão IA'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor:
                            const Color(0xFF7B61FF).withValues(alpha: 0.3),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8)),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () => _editScoreManual(index, question),
                    icon: const Icon(Icons.edit, size: 16),
                    label: const AiTranslatedText('Ajustar Nota'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white10,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8)),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResponseValue(int index, Map<String, dynamic> response) {
    final type = response['type'];
    final value = response['value'];

    if (type == 'text') {
      return Text(value,
          style: const TextStyle(color: Colors.white, fontSize: 14));
    }

    if (type == 'audio') {
      final isPlaying = _playingIndex == index;
      return Row(
        children: [
          IconButton(
            onPressed: () => _toggleAudio(index, value),
            icon: Icon(isPlaying ? Icons.stop_circle : Icons.play_circle,
                color: const Color(0xFF00D1FF), size: 32),
          ),
          const SizedBox(width: 8),
          AiTranslatedText(
              isPlaying ? 'A reproduzir áudio...' : 'Ouvir Resposta Gravada',
              style: const TextStyle(color: Colors.white, fontSize: 13)),
        ],
      );
    }

    if (type == 'image') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AiTranslatedText('Toque na imagem para ampliar:',
              style: TextStyle(color: Colors.white38, fontSize: 11)),
          const SizedBox(height: 8),
          InkWell(
            onTap: () => _showFullScreenImage(value),
            child: Hero(
              tag: 'img_$index',
              child: Container(
                height: 120,
                width: 200,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white10),
                  image: DecorationImage(
                      image: NetworkImage(value), fit: BoxFit.cover),
                ),
              ),
            ),
          ),
        ],
      );
    }
    return const AiTranslatedText('Tipo desconhecido',
        style: TextStyle(color: Colors.white24));
  }

  void _editScoreManual(int index, GameQuestion question) {
    final controller = TextEditingController(
        text: (_teacherAdjustments[index] ??
                (widget.result.correctAnswers.contains(index)
                    ? question.points
                    : 0.0))
            .toString());
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const AiTranslatedText('Ajustar Pontuação'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white),
          decoration:
              InputDecoration(labelText: 'Pontos (0 - ${question.points})'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const AiTranslatedText('Cancelar')),
          ElevatedButton(
            onPressed: () {
              final score = double.tryParse(controller.text);
              if (score != null) {
                Navigator.pop(context);
                _saveAdjustment(index, score);
              }
            },
            child: const AiTranslatedText('Guardar'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String label, String value, {bool isLarge = false}) {
    return Column(
      children: [
        AiTranslatedText(label,
            style: const TextStyle(color: Colors.white38, fontSize: 12)),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                color: isLarge ? const Color(0xFF00D1FF) : Colors.white,
                fontSize: isLarge ? 28 : 14,
                fontWeight: FontWeight.bold)),
      ],
    );
  }

  Future<void> _downloadPDF(BuildContext context) async {
    try {
      final pdfBytes = await PdfService.generateStudentExamReport(
        game: widget.game,
        result: widget.result,
        studentName: widget.studentName,
      );

      final fileName =
          'Exame_${widget.studentName.replaceAll(' ', '_')}_${widget.game.title.replaceAll(' ', '_')}.pdf';
      await PdfService.downloadPdf(pdfBytes, fileName);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: AiTranslatedText('PDF gerado com sucesso!')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro ao gerar PDF: $e')));
      }
    }
  }
}
