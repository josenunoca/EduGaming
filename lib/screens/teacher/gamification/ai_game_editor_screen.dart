import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/subject_model.dart';
import '../../../services/firebase_service.dart';
import '../../../widgets/glass_card.dart';
import '../../../widgets/ai_translated_text.dart';

class AiGameEditorScreen extends StatefulWidget {
  final Subject subject;
  final AiGame game;

  const AiGameEditorScreen({
    super.key,
    required this.subject,
    required this.game,
  });

  @override
  State<AiGameEditorScreen> createState() => _AiGameEditorScreenState();
}

class _AiGameEditorScreenState extends State<AiGameEditorScreen> {
  late List<GameQuestion> _questions;
  late String _title;
  late bool _isAssessment;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _questions = List.from(widget.game.questions);
    _title = widget.game.title;
    _isAssessment = widget.game.isAssessment;
  }

  Future<void> _saveGame() async {
    setState(() => _isSaving = true);
    try {
      final service = context.read<FirebaseService>();
      final updatedGame = AiGame(
        id: widget.game.id,
        title: _title,
        questions: _questions,
        type: widget.game.type,
        isAssessment: _isAssessment,
        subjectId: widget.game.subjectId,
        sourceContentIds: widget.game.sourceContentIds,
      );

      await service.saveAiGame(updatedGame);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: AiTranslatedText('Jogo guardado com sucesso!'),
              backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao guardar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _editQuestion(int index) {
    final q = _questions[index];
    final qController = TextEditingController(text: q.question);
    final pointsController = TextEditingController(text: q.points.toString());
    final timeController =
        TextEditingController(text: q.timeLimitSeconds.toString());
    List<TextEditingController> optionControllers =
        q.options.map((opt) => TextEditingController(text: opt)).toList();
    int correctIdx = q.correctOptionIndex;
    List<String> allowedTypes = List.from(q.allowedAnswerTypes);
    final criteriaController = TextEditingController(text: q.evaluationCriteria);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const AiTranslatedText('Editar Pergunta',
              style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: qController,
                  maxLines: 3,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'Pergunta'),
                ),
                const SizedBox(height: 16),
                ...List.generate(optionControllers.length, (i) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      children: [
                        Radio<int>(
                          value: i,
                          groupValue: correctIdx,
                          activeColor: const Color(0xFF00D1FF),
                          onChanged: (val) =>
                              setDialogState(() => correctIdx = val!),
                        ),
                        Expanded(
                          child: TextField(
                            controller: optionControllers[i],
                            style: const TextStyle(
                                color: Colors.white, fontSize: 13),
                            decoration: InputDecoration(
                                labelText:
                                    'Opção ${String.fromCharCode(65 + i)}'),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: pointsController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(labelText: 'Pontos'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextField(
                        controller: timeController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white),
                        decoration:
                            const InputDecoration(labelText: 'Tempo (s)'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const AiTranslatedText('Tipos de Resposta Permitidos:',
                    style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    FilterChip(
                      label: const AiTranslatedText('Opções'),
                      selected: allowedTypes.contains('options'),
                      onSelected: (val) {
                        setDialogState(() {
                          if (val) {
                            allowedTypes.add('options');
                          } else if (allowedTypes.length > 1) allowedTypes.remove('options');
                        });
                      },
                    ),
                    FilterChip(
                      label: const AiTranslatedText('Escrita'),
                      selected: allowedTypes.contains('text'),
                      onSelected: (val) {
                        setDialogState(() {
                          if (val) {
                            allowedTypes.add('text');
                          } else if (allowedTypes.length > 1) allowedTypes.remove('text');
                        });
                      },
                    ),
                    FilterChip(
                      label: const AiTranslatedText('Áudio'),
                      selected: allowedTypes.contains('audio'),
                      onSelected: (val) {
                        setDialogState(() {
                          if (val) {
                            allowedTypes.add('audio');
                          } else if (allowedTypes.length > 1) allowedTypes.remove('audio');
                        });
                      },
                    ),
                    FilterChip(
                      label: const AiTranslatedText('Imagem'),
                      selected: allowedTypes.contains('image'),
                      onSelected: (val) {
                        setDialogState(() {
                          if (val) {
                            allowedTypes.add('image');
                          } else if (allowedTypes.length > 1) allowedTypes.remove('image');
                        });
                      },
                    ),
                  ],
                ),
                if (!allowedTypes.contains('options') || allowedTypes.length > 1) ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: criteriaController,
                    maxLines: 2,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: const InputDecoration(
                      labelText: 'Critérios de Avaliação / Resposta Esperada',
                      hintText: 'Explique o que a IA deve procurar na resposta...',
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const AiTranslatedText('Cancelar')),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _questions[index] = GameQuestion(
                    id: q.id,
                    question: qController.text,
                    options: optionControllers.map((c) => c.text).toList(),
                    correctOptionIndex: correctIdx,
                    points: double.tryParse(pointsController.text) ?? 10.0,
                    timeLimitSeconds: int.tryParse(timeController.text) ?? 20,
                    allowedAnswerTypes: allowedTypes,
                    evaluationCriteria: criteriaController.text.isNotEmpty 
                        ? criteriaController.text 
                        : null,
                  );
                });
                Navigator.pop(context);
              },
              child: const AiTranslatedText('Confirmar'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const AiTranslatedText('Refinar Jogo AI'),
        actions: [
          if (_isSaving)
            const Center(
                child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: CircularProgressIndicator(strokeWidth: 2)))
          else
            IconButton(
                onPressed: _saveGame,
                icon: const Icon(Icons.save, color: Color(0xFF00D1FF))),
        ],
      ),
      body: Column(
        children: [
          _buildSettingsHeader(),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _questions.length,
              itemBuilder: (context, index) {
                final q = _questions[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: GlassCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 12,
                              backgroundColor: const Color(0xFF7B61FF),
                              child: Text('${index + 1}',
                                  style: const TextStyle(
                                      fontSize: 12, color: Colors.white)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                q.question,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit,
                                  size: 18, color: Colors.white54),
                              onPressed: () => _editQuestion(index),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ...List.generate(q.options.length, (i) {
                          final isCorrect = i == q.correctOptionIndex;
                          return Padding(
                            padding:
                                const EdgeInsets.only(left: 36.0, bottom: 4.0),
                            child: Row(
                              children: [
                                Icon(
                                  isCorrect
                                      ? Icons.check_circle
                                      : Icons.circle_outlined,
                                  size: 14,
                                  color: isCorrect
                                      ? Colors.greenAccent
                                      : Colors.white24,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    q.options[i],
                                    style: TextStyle(
                                      color: isCorrect
                                          ? Colors.greenAccent
                                          : Colors.white60,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                        const Divider(color: Colors.white10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            AiTranslatedText('${q.points} pts',
                                style: const TextStyle(
                                    color: Color(0xFF00D1FF), fontSize: 11)),
                            const SizedBox(width: 12),
                            AiTranslatedText('${q.timeLimitSeconds}s',
                                style: const TextStyle(
                                    color: Colors.white38, fontSize: 11)),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      color: Colors.white.withValues(alpha: 0.02),
      child: Column(
        children: [
          TextField(
            onChanged: (val) => _title = val,
            style: const TextStyle(
                color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            decoration: const InputDecoration(
              labelText: 'Título do Jogo',
              border: InputBorder.none,
            ),
            controller: TextEditingController(text: _title),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const AiTranslatedText('Propósito:',
                  style: TextStyle(color: Colors.white54)),
              const SizedBox(width: 12),
              ChoiceChip(
                label: const AiTranslatedText('Treino'),
                selected: !_isAssessment,
                onSelected: (val) => setState(() => _isAssessment = !val),
                selectedColor: const Color(0xFF00D1FF).withValues(alpha: 0.3),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const AiTranslatedText('Avaliação'),
                selected: _isAssessment,
                onSelected: (val) => setState(() => _isAssessment = val),
                selectedColor: Colors.redAccent.withValues(alpha: 0.3),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
