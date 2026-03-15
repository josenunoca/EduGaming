import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../services/firebase_service.dart';
import '../../models/questionnaire_model.dart';
import '../../models/user_model.dart';

class UserLifestyleScreen extends StatefulWidget {
  const UserLifestyleScreen({super.key});

  @override
  State<UserLifestyleScreen> createState() => _UserLifestyleScreenState();
}

class _UserLifestyleScreenState extends State<UserLifestyleScreen> {
  @override
  Widget build(BuildContext context) {
    final fbService = context.read<FirebaseService>();
    final userId = fbService.currentUser?.uid ?? 'user_default';

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Meu Estilo de Vida'),
        centerTitle: true,
      ),
      body: StreamBuilder<UserModel?>(
          stream: fbService.getUserStream(userId),
          builder: (context, userSnap) {
            final user = userSnap.data;
            final role = user?.role.name ?? 'student';

            return StreamBuilder<List<Questionnaire>>(
              stream: fbService.getAvailableQuestionnaires(userId, role),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final list = snapshot.data!;

                if (list.isEmpty) {
                  return const Center(
                      child: Text('Nenhum questionário disponível no momento.'));
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    final q = list[index];
                    return Card(
                      child: ListTile(
                        leading: const CircleAvatar(
                            child: Icon(Icons.favorite, color: Colors.redAccent)),
                        title: Text(q.title),
                        subtitle: Text(
                            'Expira em: ${DateFormat('dd/MM').format(q.endDate)}'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _takeQuestionnaire(context, q, userId),
                      ),
                    );
                  },
                );
              },
            );
          }),
    );
  }

  void _takeQuestionnaire(
      BuildContext context, Questionnaire q, String userId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _QuestionnaireRunner(q: q, userId: userId),
    );
  }
}

class _QuestionnaireRunner extends StatefulWidget {
  final Questionnaire q;
  final String userId;

  const _QuestionnaireRunner({required this.q, required this.userId});

  @override
  State<_QuestionnaireRunner> createState() => _QuestionnaireRunnerState();
}

class _QuestionnaireRunnerState extends State<_QuestionnaireRunner> {
  final Map<String, dynamic> _answers = {};
  bool _consentToSpecialist = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(widget.q.title,
                      style: Theme.of(context).textTheme.titleLarge),
                ),
                if (widget.q.isSensitive)
                  const Chip(
                    label: Text('SENSÍVEL', style: TextStyle(fontSize: 10)),
                    backgroundColor: Colors.amber,
                  ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              itemCount: widget.q.questions.length,
              itemBuilder: (context, index) {
                final question = widget.q.questions[index];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${index + 1}. ${question.text}',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    _buildAnswerField(question, (val) {
                      setState(() => _answers[question.id] = val);
                    }),
                    const SizedBox(height: 32),
                  ],
                );
              },
            ),
          ),
          if (widget.q.isSensitive) ...[
            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Blindagem de Dados e Privacidade (RGPD)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Este questionário contém dados de saúde. Você autoriza que um especialista (médico/nutricionista) designado pela instituição tenha acesso às suas respostas para fins de aconselhamento proativo?',
                    style: TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                  SwitchListTile(
                    title: const Text('Autorizo partilha com especialista',
                        style: TextStyle(fontSize: 14)),
                    secondary: const Icon(Icons.shield, color: Colors.blue),
                    value: _consentToSpecialist,
                    onChanged: (v) => setState(() => _consentToSpecialist = v),
                  ),
                ],
              ),
            ),
          ],
          Padding(
            padding: const EdgeInsets.all(24),
            child: ElevatedButton(
              onPressed: () async {
                final response = QuestionnaireResponse(
                  id: const Uuid().v4(),
                  userId: widget.userId,
                  questionnaireId: widget.q.id,
                  answers: _answers,
                  timestamp: DateTime.now(),
                  consentToSpecialist: _consentToSpecialist,
                  rgpdConsentDate: _consentToSpecialist ? DateTime.now() : null,
                );
                await context
                    .read<FirebaseService>()
                    .submitQuestionnaireResponse(response);
                if (!context.mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Resposta enviada com sucesso!')));
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Submeter Resposta'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnswerField(Question q, Function(dynamic) onChanged) {
    switch (q.type) {
      case QuestionType.text:
        return TextField(
            onChanged: onChanged,
            decoration: const InputDecoration(hintText: 'Sua resposta...'));
      case QuestionType.selection:
        return Column(
          children: q.options
              .map((opt) => RadioListTile(
                    title: Text(opt),
                    value: opt,
                    groupValue: _answers[q.id],
                    onChanged: onChanged,
                  ))
              .toList(),
        );
      case QuestionType.audio:
        return ElevatedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.mic),
            label: const Text('Gravar Áudio'));
      case QuestionType.video:
        return ElevatedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.videocam),
            label: const Text('Gravar Vídeo'));
    }
  }
}
