import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../services/firebase_service.dart';
import '../models/questionnaire_model.dart';

class SurveyRunnerWidget extends StatefulWidget {
  final Questionnaire q;
  final String userId;

  const SurveyRunnerWidget({
    super.key,
    required this.q,
    required this.userId,
  });

  @override
  State<SurveyRunnerWidget> createState() => _SurveyRunnerWidgetState();
}

class _SurveyRunnerWidgetState extends State<SurveyRunnerWidget> {
  final Map<String, dynamic> _answers = {};
  bool _gdprConsent = false;
  bool _consentToSpecialist = false;

  @override
  Widget build(BuildContext context) {
    // Determine background and text colors based on context or survey type
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDarkMode ? const Color(0xFF0F172A) : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black87;

    final fbService = context.read<FirebaseService>();

    return StreamBuilder<Set<String>>(
      stream: fbService.getUserAnsweredSurveysStream(widget.userId),
      builder: (context, snapshot) {
        final answeredIds = snapshot.data ?? {};
        final isAlreadyAnswered = answeredIds.contains(widget.q.id);
        final isClosed = widget.q.status != SurveyStatus.active || DateTime.now().isAfter(widget.q.endDate);

        if (isAlreadyAnswered || isClosed) {
          return _buildBlockedOverlay(context, isAlreadyAnswered, isClosed, textColor, backgroundColor);
        }

        return Container(
          height: MediaQuery.of(context).size.height * 0.9,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 16, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.q.title,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (widget.q.isAnonymous) ...[
                        const SizedBox(height: 4),
                        const Row(
                          children: [
                            Icon(Icons.visibility_off, size: 12, color: Colors.greenAccent),
                            SizedBox(width: 4),
                            Text('Preenchimento Anónimo', style: TextStyle(color: Colors.greenAccent, fontSize: 12)),
                          ],
                        ),
                      ],
                      if (widget.q.isSensitive) ...[
                        const SizedBox(height: 4),
                        const Row(
                          children: [
                            Icon(Icons.shield, size: 12, color: Colors.amber),
                            SizedBox(width: 4),
                            Text('Dados Sensíveis (Blindagem Ativa)', style: TextStyle(color: Colors.amber, fontSize: 12)),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: textColor.withOpacity(0.5)),
                  onPressed: () => Navigator.pop(context),
                )
              ],
            ),
          ),
          
          // Question List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              itemCount: widget.q.questions.length,
              itemBuilder: (context, index) {
                final question = widget.q.questions[index];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${index + 1}. ${question.text}',
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildAnswerField(question, (val) {
                      setState(() => _answers[question.id] = val);
                    }),
                    const SizedBox(height: 32),
                  ],
                );
              },
            ),
          ),
          
          const Divider(height: 1),
          
          // Consent Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Column(
              children: [
                // Sensitive Data Specialist Consent
                if (widget.q.isSensitive)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Autorizo partilha com especialista', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    subtitle: const Text('Designado pela instituição (ex: médico/psicólogo) para aconselhamento proativo.', style: TextStyle(fontSize: 11)),
                    secondary: const Icon(Icons.medical_services, color: Colors.blue),
                    value: _consentToSpecialist,
                    onChanged: (v) => setState(() => _consentToSpecialist = v),
                  ),
                
                // GDPR Consent (Mandatory if not anonymous)
                Row(
                  children: [
                    Checkbox(
                      value: _gdprConsent,
                      activeColor: const Color(0xFF7B61FF),
                      onChanged: (v) => setState(() => _gdprConsent = v ?? false),
                    ),
                    Expanded(
                      child: Text(
                        widget.q.isAnonymous
                            ? 'Confirmo a submissão anónima. Os dados não serão rastreáveis segundo o RGPD.'
                            : 'Autorizo o tratamento dos dados pela Instituição no âmbito das suas competências (RGPD).',
                        style: TextStyle(
                            color: _gdprConsent ? textColor : textColor.withOpacity(0.5),
                            fontSize: 11),
                      ),
                    )
                  ],
                ),
              ],
            ),
          ),
          
          // Submit Button
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: ElevatedButton(
              onPressed: _gdprConsent ? _submit : null,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
                backgroundColor: _gdprConsent ? const Color(0xFF7B61FF) : Colors.grey.withOpacity(0.2),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('Submeter Resposta', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  },
);
  }

Widget _buildBlockedOverlay(BuildContext context, bool alreadyAnswered, bool isClosed, Color textColor, Color bgColor) {
  return Container(
    height: MediaQuery.of(context).size.height * 0.5,
    decoration: BoxDecoration(
      color: bgColor,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
    ),
    padding: const EdgeInsets.all(32),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          alreadyAnswered ? Icons.check_circle : Icons.lock_clock,
          size: 64,
          color: alreadyAnswered ? Colors.green : Colors.orangeAccent,
        ),
        const SizedBox(height: 24),
        Text(
          alreadyAnswered ? 'Inquérito Respondido' : 'Inquérito Encerrado',
          style: TextStyle(color: textColor, fontSize: 22, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          alreadyAnswered
              ? 'Já submeteu a sua resposta para este inquérito. Não é possível responder múltiplas vezes.'
              : 'Este inquérito já não se encontra disponível para recolha de respostas.',
          style: TextStyle(color: textColor.withOpacity(0.7), fontSize: 14),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF7B61FF),
            minimumSize: const Size(200, 50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('Fechar', style: TextStyle(color: Colors.white)),
        ),
      ],
    ),
  );
}

  void _submit() async {
    final response = QuestionnaireResponse(
      id: const Uuid().v4(),
      userId: widget.q.isAnonymous ? 'anonymous_${widget.userId.substring(0, 5)}' : widget.userId,
      questionnaireId: widget.q.id,
      answers: _answers,
      timestamp: DateTime.now(),
      consentToSpecialist: _consentToSpecialist,
      isAnonymous: widget.q.isAnonymous,
      rgpdConsentDate: DateTime.now(),
    );

    try {
      await context.read<FirebaseService>().submitQuestionnaireResponse(
        response, 
        widget.userId,
        institutionId: widget.q.institutionId,
      );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Inquérito submetido com sucesso!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao submeter: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildAnswerField(Question q, Function(dynamic) onChanged) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final fieldFillColor = isDarkMode ? const Color(0xFF1E293B) : Colors.grey.shade100;
    final fieldTextColor = isDarkMode ? Colors.white70 : Colors.black54;

    switch (q.type) {
      case QuestionType.text:
      case QuestionType.openText:
        return TextField(
            onChanged: onChanged,
            style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87),
            maxLines: 3,
            decoration: InputDecoration(
                hintText: 'A sua resposta...',
                hintStyle: TextStyle(color: fieldTextColor.withOpacity(0.5)),
                filled: true,
                fillColor: fieldFillColor,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)));
      
      case QuestionType.selection:
      case QuestionType.singleChoice:
      case QuestionType.multipleChoice:
        return Column(
          children: q.options
              .map((opt) => RadioListTile(
                    title: Text(opt, style: TextStyle(color: fieldTextColor)),
                    value: opt,
                    activeColor: const Color(0xFF7B61FF),
                    groupValue: _answers[q.id],
                    onChanged: onChanged,
                  ))
              .toList(),
        );
      
      case QuestionType.likertScale:
        return Column(
          children: [
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: const Color(0xFF7B61FF),
                inactiveTrackColor: Colors.grey.shade300,
                thumbColor: const Color(0xFF7B61FF),
                valueIndicatorTextStyle: const TextStyle(color: Colors.white),
              ),
              child: Slider(
                value: (_answers[q.id] as num?)?.toDouble() ?? 3.0,
                min: 1,
                max: 5,
                divisions: 4,
                label: (_answers[q.id] ?? 3).toString(),
                onChanged: (v) => onChanged(v.toInt()),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(q.likertMinLabel ?? 'Discordo', style: TextStyle(color: fieldTextColor, fontSize: 10)),
                Text(q.likertMaxLabel ?? 'Concordo', style: TextStyle(color: fieldTextColor, fontSize: 10)),
              ],
            )
          ],
        );
      
      case QuestionType.audio:
      case QuestionType.video:
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: fieldFillColor, borderRadius: BorderRadius.circular(12)),
          child: Row(
            children: [
              Icon(q.type == QuestionType.audio ? Icons.mic : Icons.videocam, color: fieldTextColor),
              const SizedBox(width: 8),
              const Expanded(child: Text('Funcionalidade de média requer integração nativa.', style: TextStyle(fontSize: 12))),
            ],
          ),
        );
    }
  }
}
