import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../services/firebase_service.dart';
import '../../models/questionnaire_model.dart';
import '../../models/user_model.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/ai_translated_text.dart';

class SurveyRespondScreen extends StatefulWidget {
  final Questionnaire survey;
  final UserModel currentUser;
  final String institutionId;

  const SurveyRespondScreen({
    super.key,
    required this.survey,
    required this.currentUser,
    required this.institutionId,
  });

  @override
  State<SurveyRespondScreen> createState() => _SurveyRespondScreenState();
}

class _SurveyRespondScreenState extends State<SurveyRespondScreen> {
  final Map<String, dynamic> _answers = {};
  int _currentQuestionIndex = 0;
  bool _rgpdConsent = false;
  bool _isSubmitting = false;
  bool _submitted = false;

  Question get _currentQuestion =>
      widget.survey.questions[_currentQuestionIndex];

  bool get _isLastQuestion =>
      _currentQuestionIndex == widget.survey.questions.length - 1;

  double get _progress =>
      widget.survey.questions.isEmpty
          ? 0
          : (_currentQuestionIndex + 1) / widget.survey.questions.length;

  bool get _currentAnswered => _answers.containsKey(_currentQuestion.id) &&
      _answers[_currentQuestion.id] != null &&
      _answers[_currentQuestion.id].toString().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    if (_submitted) return _buildThankYouScreen();
    if (widget.survey.questions.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1E293B),
          title: Text(widget.survey.title,
              style: const TextStyle(color: Colors.white)),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: const Center(
          child: AiTranslatedText('Este inquérito não tem perguntas disponíveis.',
              style: TextStyle(color: Colors.white54)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: Text(
          widget.survey.title,
          style: const TextStyle(color: Colors.white, fontSize: 15),
          overflow: TextOverflow.ellipsis,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: _progress,
            backgroundColor: Colors.white12,
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00BFA5)),
          ),
        ),
      ),
      body: Column(
        children: [
          // Progress indicator
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Pergunta ${_currentQuestionIndex + 1} de ${widget.survey.questions.length}',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
                Text(
                  '${(_progress * 100).toStringAsFixed(0)}% concluído',
                  style: const TextStyle(color: Color(0xFF00BFA5), fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),

          // Question
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: _buildQuestion(_currentQuestion),
            ),
          ),

          // Navigation
          _buildNavigationBar(),
        ],
      ),
    );
  }

  Widget _buildQuestion(Question q) {
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Optional indicator
            if (q.isRequired)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Row(children: [
                  Icon(Icons.star, size: 10, color: Colors.redAccent),
                  SizedBox(width: 4),
                  Text('Obrigatória', style: TextStyle(color: Colors.redAccent, fontSize: 10)),
                ]),
              ),

            Text(
              q.text,
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 20),

            // Input based on type
            if (q.type == QuestionType.singleChoice || q.type == QuestionType.selection)
              _buildSingleChoice(q),
            if (q.type == QuestionType.multipleChoice)
              _buildMultipleChoice(q),
            if (q.type == QuestionType.likertScale)
              _buildLikertScale(q),
            if (q.type == QuestionType.openText || q.type == QuestionType.text)
              _buildOpenText(q),
          ],
        ),
      ),
    );
  }

  Widget _buildSingleChoice(Question q) {
    return Column(
      children: q.options.map((opt) {
        final selected = _answers[q.id] == opt;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() => _answers[q.id] = opt),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: selected
                    ? const Color(0xFF00BFA5).withValues(alpha: 0.15)
                    : Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected
                      ? const Color(0xFF00BFA5)
                      : Colors.white.withValues(alpha: 0.12),
                  width: selected ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    selected ? Icons.radio_button_checked : Icons.radio_button_off,
                    color: selected ? const Color(0xFF00BFA5) : Colors.white38,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(opt,
                      style: TextStyle(color: selected ? Colors.white : Colors.white70, fontSize: 14))),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMultipleChoice(Question q) {
    final selected = (_answers[q.id] as List<String>?) ?? [];
    return Column(
      children: q.options.map((opt) {
        final isSelected = selected.contains(opt);
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              setState(() {
                final current = List<String>.from(selected);
                if (isSelected) current.remove(opt);
                else current.add(opt);
                _answers[q.id] = current;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF00BFA5).withValues(alpha: 0.15)
                    : Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF00BFA5)
                      : Colors.white.withValues(alpha: 0.12),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isSelected ? Icons.check_box : Icons.check_box_outline_blank,
                    color: isSelected ? const Color(0xFF00BFA5) : Colors.white38,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(opt,
                      style: TextStyle(color: isSelected ? Colors.white : Colors.white70, fontSize: 14))),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildLikertScale(Question q) {
    final currentValue = _answers[q.id] as int?;
    final min = q.likertMin ?? 1;
    final max = q.likertMax ?? 5;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(q.likertMinLabel ?? 'Discordo totalmente',
                style: const TextStyle(color: Colors.white38, fontSize: 11)),
            Text(q.likertMaxLabel ?? 'Concordo totalmente',
                style: const TextStyle(color: Colors.white38, fontSize: 11)),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(max - min + 1, (i) {
            final value = min + i;
            final isSelected = currentValue == value;
            return GestureDetector(
              onTap: () => setState(() => _answers[q.id] = value),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected
                      ? const Color(0xFF00BFA5)
                      : Colors.white.withValues(alpha: 0.08),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF00BFA5)
                        : Colors.white.withValues(alpha: 0.2),
                  ),
                ),
                child: Text(
                  '$value',
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white54,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 16,
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildOpenText(Question q) {
    return TextField(
      maxLines: 5,
      style: const TextStyle(color: Colors.white),
      onChanged: (v) => setState(() => _answers[q.id] = v),
      decoration: InputDecoration(
        hintText: 'Escreva a sua resposta aqui...',
        hintStyle: const TextStyle(color: Colors.white30),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.06),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF00BFA5)),
        ),
      ),
    );
  }

  Widget _buildNavigationBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      color: const Color(0xFF1E293B),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // RGPD consent on last question
          if (_isLastQuestion) ...[
            Row(
              children: [
                Checkbox(
                  value: _rgpdConsent,
                  activeColor: const Color(0xFF00BFA5),
                  onChanged: (v) => setState(() => _rgpdConsent = v ?? false),
                ),
                const Expanded(
                  child: AiTranslatedText(
                    'Consinto no tratamento dos meus dados para fins estatísticos, ao abrigo do RGPD.',
                    style: TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              if (_currentQuestionIndex > 0) ...[
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white54,
                      side: const BorderSide(color: Colors.white24),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => setState(() => _currentQuestionIndex--),
                    child: const AiTranslatedText('Anterior'),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isLastQuestion
                        ? (_rgpdConsent ? const Color(0xFF00C853) : Colors.grey)
                        : const Color(0xFF00BFA5),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _canAdvance() ? _handleNext : null,
                  child: _isSubmitting
                      ? const SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : AiTranslatedText(
                          _isLastQuestion ? 'Submeter Resposta' : 'Seguinte',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  bool _canAdvance() {
    if (_currentQuestion.isRequired && !_currentAnswered) return false;
    if (_isLastQuestion && !_rgpdConsent) return false;
    return true;
  }

  Future<void> _handleNext() async {
    if (_isLastQuestion) {
      await _submit();
    } else {
      setState(() => _currentQuestionIndex++);
    }
  }

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);
    try {
      final service = context.read<FirebaseService>();
      final response = QuestionnaireResponse(
        id: const Uuid().v4(),
        userId: widget.currentUser.id,
        questionnaireId: widget.survey.id,
        answers: _answers,
        timestamp: DateTime.now(),
        consentToSpecialist: false,
        rgpdConsentDate: DateTime.now(),
        isAnonymous: widget.survey.isSensitive,
      );
      await service.submitSurveyResponse(widget.institutionId, response);
      setState(() => _submitted = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: AiTranslatedText('Erro ao submeter: $e'),
          backgroundColor: Colors.redAccent,
        ));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Widget _buildThankYouScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100, height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF00BFA5).withValues(alpha: 0.15),
                ),
                child: const Icon(Icons.check_circle_outline,
                    size: 60, color: Color(0xFF00BFA5)),
              ),
              const SizedBox(height: 32),
              const AiTranslatedText(
                'Obrigado pela sua participação!',
                style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const AiTranslatedText(
                'A sua resposta foi registada com sucesso e será utilizada para melhorar a qualidade dos nossos serviços.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, fontSize: 14),
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00BFA5),
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Navigator.pop(context),
                child: const AiTranslatedText('Voltar',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
