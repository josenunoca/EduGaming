import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../services/firebase_service.dart';
import '../../models/questionnaire_model.dart';
import '../../models/user_model.dart';
import 'package:uuid/uuid.dart';
import '../../widgets/survey_runner_widget.dart';
import 'package:rxdart/rxdart.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/ai_translated_text.dart';

class StudentSurveysScreen extends StatefulWidget {
  final UserModel student;
  const StudentSurveysScreen({super.key, required this.student});

  @override
  State<StudentSurveysScreen> createState() => _StudentSurveysScreenState();
}

class _StudentSurveysScreenState extends State<StudentSurveysScreen> {
  @override
  Widget build(BuildContext context) {
    final fbService = context.read<FirebaseService>();
    final userId = widget.student.id;
    final role = widget.student.role.name;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        appBar: AppBar(
          title: const AiTranslatedText('Inquéritos e Avaliações'),
          centerTitle: true,
          backgroundColor: const Color(0xFF1E293B),
          elevation: 0,
          bottom: const TabBar(
            indicatorColor: Color(0xFF7B61FF),
            labelColor: Color(0xFF7B61FF),
            unselectedLabelColor: Colors.white54,
            tabs: [
              Tab(text: 'Pendentes'),
              Tab(text: 'Respondidos'),
            ],
          ),
        ),
        body: StreamBuilder<List<Questionnaire>>(
          stream: fbService.getAvailableQuestionnaires(
            userId, 
            widget.student.email, 
            UserRole.student, 
            widget.student.institutionId ?? ''
          ),
          builder: (context, snapshot) {
            return StreamBuilder<Set<String>>(
              stream: fbService.getUserAnsweredSurveysStream(userId),
              builder: (context, answeredSnap) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final all = snapshot.data ?? [];
                final answeredIds = answeredSnap.data ?? {};
                
                // Filter surveys where the student is targeted
                final targetedSurveys = all.where((q) => _isUserTargeted(q, widget.student)).toList();

                final pending = targetedSurveys.where((q) => 
                  !answeredIds.contains(q.id) && 
                  q.status == SurveyStatus.active
                ).toList();

                final archived = targetedSurveys.where((q) => 
                  answeredIds.contains(q.id) || 
                  q.status != SurveyStatus.active
                ).toList();

                return TabBarView(
                  children: [
                    _buildSurveyList(context, pending, userId, answeredIds, isPending: true),
                    _buildSurveyList(context, archived, userId, answeredIds, isPending: false),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  bool _isUserTargeted(Questionnaire q, UserModel user) {
    if (q.individualTargetIds.contains(user.id) || q.individualTargetIds.contains(user.email)) return true;
    if (q.excludedTargetIds.contains(user.id) || q.excludedTargetIds.contains(user.email)) return false;
    
    final roleMatch = q.targetRoles.contains('student') || q.targetRoles.contains('all');
    final audienceMatch = q.audiences.contains(SurveyAudience.students);
    
    return roleMatch || audienceMatch;
  }

  Widget _buildSurveyList(BuildContext context, List<Questionnaire> list, String userId, Set<String> answeredIds, {required bool isPending}) {
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(isPending ? Icons.check_circle_outline : Icons.history_toggle_off, size: 80, color: Colors.white24),
            const SizedBox(height: 16),
            AiTranslatedText(
              isPending ? 'Tudo em dia!' : 'Ainda sem histórico',
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            AiTranslatedText(
              isPending ? 'Não tem inquéritos pendentes.' : 'Os inquéritos que responder aparecerão aqui.',
              style: const TextStyle(color: Colors.white54),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final q = list[index];
        final isAnswered = answeredIds.contains(q.id);
        final isClosed = q.status != SurveyStatus.active;

        return Card(
          color: const Color(0xFF1E293B),
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: CircleAvatar(
              backgroundColor: (isPending ? const Color(0xFF7B61FF) : (isAnswered ? Colors.green : Colors.grey)).withOpacity(0.2),
              child: Icon(
                isPending ? Icons.assignment : (isAnswered ? Icons.check_circle : Icons.lock), 
                color: isPending ? const Color(0xFF7B61FF) : (isAnswered ? Colors.green : Colors.grey)
              ),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    q.title,
                    style: TextStyle(
                      color: isPending || isAnswered ? Colors.white : Colors.white54, 
                      fontWeight: FontWeight.bold
                    ),
                  ),
                ),
                if (q.creatorRole == 'institution')
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7B61FF).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFF7B61FF).withValues(alpha: 0.5)),
                    ),
                    child: const AiTranslatedText(
                      'Institucional',
                      style: TextStyle(color: Color(0xFF7B61FF), fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (q.description.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(q.description, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white38, fontSize: 11)),
                    ),
                  Row(
                    children: [
                      Icon(
                        isAnswered ? Icons.check_circle : Icons.timer, 
                        size: 14, 
                        color: isPending ? Colors.orangeAccent : (isAnswered ? Colors.greenAccent : Colors.white38)
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isAnswered 
                          ? 'Respondido' 
                          : (isClosed ? 'Encerrado em ${DateFormat('dd/MM/yy').format(q.endDate)}' : 'Expira a: ${DateFormat('dd/MM/yyyy').format(q.endDate)}'),
                        style: TextStyle(
                          color: isPending ? Colors.orangeAccent : (isAnswered ? Colors.greenAccent : Colors.white38), 
                          fontSize: 12
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            trailing: isPending 
                ? const Icon(Icons.chevron_right, color: Colors.white54)
                : (isAnswered ? const Icon(Icons.check, color: Colors.greenAccent) : const Icon(Icons.lock_outline, color: Colors.white24)),
            onTap: isClosed && !isAnswered ? null : () => _takeQuestionnaire(context, q, userId),
          ),
        );
      },
    );
  }

  void _takeQuestionnaire(BuildContext context, Questionnaire q, String userId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SurveyRunnerWidget(q: q, userId: userId),
    );
  }
}

