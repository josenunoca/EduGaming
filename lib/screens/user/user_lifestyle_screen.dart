import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../services/firebase_service.dart';
import '../../models/questionnaire_model.dart';
import '../../models/user_model.dart';
import 'package:rxdart/rxdart.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/ai_translated_text.dart';
import '../../widgets/survey_runner_widget.dart';

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

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        appBar: AppBar(
          title: const AiTranslatedText('Meu Estilo de Vida'),
          centerTitle: true,
          bottom: const TabBar(
            indicatorColor: Color(0xFF7B61FF),
            labelColor: Color(0xFF7B61FF),
            tabs: [
              Tab(text: 'Pendentes'),
              Tab(text: 'Respondidos'),
            ],
          ),
        ),
        body: StreamBuilder<UserModel?>(
            stream: fbService.getUserStream(userId),
            builder: (context, userSnap) {
              final user = userSnap.data;

              return StreamBuilder<List<Questionnaire>>(
                stream: Rx.combineLatest2(
                  fbService.getAvailableQuestionnaires(userId, user?.email, user?.role, user?.institutionId ?? ''),
                  fbService.getUserAnsweredSurveysStream(userId),
                  (List<Questionnaire> all, Set<String> answeredIds) => all,
                ),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  return StreamBuilder<Set<String>>(
                    stream: fbService.getUserAnsweredSurveysStream(userId),
                    builder: (context, answeredSnap) {
                      final answeredIds = answeredSnap.data ?? {};
                      final all = snapshot.data!.where((q) => q.isSensitive).toList();
                      
                      final pending = all.where((q) => !answeredIds.contains(q.id)).toList();
                      final answered = all.where((q) => answeredIds.contains(q.id)).toList();

                      return TabBarView(
                        children: [
                          _buildSurveyList(context, pending, userId, isPending: true),
                          _buildSurveyList(context, answered, userId, isPending: false),
                        ],
                      );
                    },
                  );
                },
              );
            }),
      ),
    );
  }

  Widget _buildSurveyList(BuildContext context, List<Questionnaire> list, String userId, {required bool isPending}) {
    if (list.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: AiTranslatedText(
            isPending ? 'Nenhum questionário disponível no momento.' : 'Ainda não respondeu a nenhum questionário sensível.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final q = list[index];
        return Card(
          child: ListTile(
            leading: CircleAvatar(
                backgroundColor: isPending ? Colors.redAccent.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                child: Icon(isPending ? Icons.favorite : Icons.check_circle, 
                           color: isPending ? Colors.redAccent : Colors.green)),
            title: Text(q.title),
            subtitle: Text('Expira em: ${DateFormat('dd/MM').format(q.endDate)}'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _takeQuestionnaire(context, q, userId),
          ),
        );
      },
    );
  }

  void _takeQuestionnaire(
      BuildContext context, Questionnaire q, String userId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SurveyRunnerWidget(q: q, userId: userId),
    );
  }
}

