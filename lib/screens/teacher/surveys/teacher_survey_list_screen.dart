import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../services/firebase_service.dart';
import '../../../models/questionnaire_model.dart';
import '../../../models/institution_model.dart';
import '../../../models/user_model.dart';
import '../../../widgets/glass_card.dart';
import '../../../widgets/ai_translated_text.dart';
import '../../institution/surveys/survey_monitoring_screen.dart';
import '../../institution/surveys/survey_analysis_screen.dart';
import 'teacher_survey_builder_screen.dart';
import '../../../widgets/survey_runner_widget.dart';

class TeacherSurveyListScreen extends StatelessWidget {
  final UserModel teacher;
  final InstitutionModel institution;

  const TeacherSurveyListScreen({
    super.key,
    required this.teacher,
    required this.institution,
  });

  @override
  Widget build(BuildContext context) {
    final service = context.read<FirebaseService>();

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: TabBar(
            indicatorColor: const Color(0xFF7B61FF),
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white38,
            tabs: [
              Tab(child: AiTranslatedText('Os Meus Inquéritos', style: const TextStyle(fontSize: 13))),
              Tab(child: AiTranslatedText('Para Responder', style: const TextStyle(fontSize: 13))),
              Tab(child: AiTranslatedText('Respondidos', style: const TextStyle(fontSize: 13))),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: const Color(0xFF7B61FF),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TeacherSurveyBuilderScreen(
                teacher: teacher,
                institution: institution,
              ),
            ),
          ),
          icon: const Icon(Icons.add, color: Colors.white),
          label: const AiTranslatedText(
            'Novo Inquérito',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        body: TabBarView(
          children: [
            // TAB 1: Created by teacher
            StreamBuilder<List<Questionnaire>>(
              stream: service.getSurveysForTeacher(institution.id, teacher.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFF7B61FF)));
                }
                final surveys = snapshot.data ?? [];
                if (surveys.isEmpty) return _buildEmptyState(context);

                final drafts = surveys.where((s) => s.status == SurveyStatus.draft).toList();
                final active = surveys.where((s) => s.status == SurveyStatus.active).toList();
                final closed = surveys.where((s) => s.status == SurveyStatus.closed || s.status == SurveyStatus.locked).toList();

                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  children: [
                    if (active.isNotEmpty) ...[
                      _sectionLabel('Ativos', Icons.radio_button_checked, const Color(0xFF00C853)),
                      ...active.map((s) => _TeacherSurveyCard(survey: s, institution: institution, service: service, teacher: teacher)),
                      const SizedBox(height: 12),
                    ],
                    if (drafts.isNotEmpty) ...[
                      _sectionLabel('Rascunhos', Icons.edit_note, Colors.amber),
                      ...drafts.map((s) => _TeacherSurveyCard(survey: s, institution: institution, service: service, teacher: teacher)),
                      const SizedBox(height: 12),
                    ],
                    if (closed.isNotEmpty) ...[
                      _sectionLabel('Encerrados', Icons.lock_outline, Colors.grey),
                      ...closed.map((s) => _TeacherSurveyCard(survey: s, institution: institution, service: service, teacher: teacher)),
                    ],
                  ],
                );
              },
            ),
            StreamBuilder<List<Questionnaire>>(
              stream: service.getAvailableQuestionnaires(
                teacher.id, 
                teacher.email, 
                UserRole.teacher,
                institution.id
              ),
              builder: (context, availableSnap) {
                return StreamBuilder<Set<String>>(
                  stream: service.getUserAnsweredSurveysStream(teacher.id),
                  builder: (context, answeredSnap) {
                    if (availableSnap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final allAvailable = availableSnap.data ?? [];
                    final answeredIds = answeredSnap.data ?? {};
                    
                    // Filter: Not created by me AND active AND NOT answered
                    final surveys = allAvailable.where((q) => 
                      q.creatorId != teacher.id && 
                      !answeredIds.contains(q.id) &&
                      q.status == SurveyStatus.active
                    ).toList();

                    if (surveys.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.done_all, size: 64, color: Colors.white24),
                            const SizedBox(height: 16),
                            AiTranslatedText('Não tem inquéritos pendentes.', style: const TextStyle(color: Colors.white54)),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: surveys.length,
                      itemBuilder: (context, index) => _PendingSurveyCard(survey: surveys[index], role: UserRole.teacher),
                    );
                  },
                );
              },
            ),

            // TAB 3: Respondidos (Answered OR Closed)
            StreamBuilder<List<Questionnaire>>(
              stream: service.getQuestionnaires(institution.id),
              builder: (context, allSnap) {
                return StreamBuilder<Set<String>>(
                  stream: service.getUserAnsweredSurveysStream(teacher.id),
                  builder: (context, answeredSnap) {
                    if (allSnap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final all = allSnap.data ?? [];
                    final answeredIds = answeredSnap.data ?? {};
                    
                    // Filter: I am targeted (but not creator) AND (it is closed OR I already answered)
                    // We check if I was targeted by looking at getAvailableQuestionnaires logic or just if I'm in answeredIds
                    final surveys = all.where((q) {
                      if (q.creatorId == teacher.id) return false;
                      final wasAnswered = answeredIds.contains(q.id);
                      final isClosed = q.status != SurveyStatus.active;
                      
                      // Show if it was answered OR (targeted but closed)
                      // For simplicity, we'll show finalized surveys that the user was involved in
                      return wasAnswered || (isClosed && _isUserTargeted(q, teacher));
                    }).toList();

                    if (surveys.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.history, size: 64, color: Colors.white24),
                            const SizedBox(height: 16),
                            AiTranslatedText('Nenhum inquérito arquivado.', style: const TextStyle(color: Colors.white54)),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: surveys.length,
                      itemBuilder: (context, index) {
                        final survey = surveys[index];
                        final isAnswered = answeredIds.contains(survey.id);
                        return _ArchivedSurveyCard(survey: survey, isAnswered: isAnswered);
                      },
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String label, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label.toUpperCase(),
            style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF7B61FF).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.quiz_outlined,
                  size: 56, color: Color(0xFF7B61FF)),
            ),
            const SizedBox(height: 24),
            const AiTranslatedText(
              'Sem inquéritos criados',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const AiTranslatedText(
              'Crie um inquérito para recolher\nfeedback dos seus alunos.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7B61FF),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TeacherSurveyBuilderScreen(
                    teacher: teacher,
                    institution: institution,
                  ),
                ),
              ),
              icon: const Icon(Icons.add, color: Colors.white, size: 18),
              label: const AiTranslatedText('Criar Inquérito',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  bool _isUserTargeted(Questionnaire q, UserModel user) {
    if (q.individualTargetIds.contains(user.id) || q.individualTargetIds.contains(user.email)) return true;
    if (q.excludedTargetIds.contains(user.id) || q.excludedTargetIds.contains(user.email)) return false;
    
    final roleMatch = q.targetRoles.contains('teacher') || q.targetRoles.contains('all');
    final audienceMatch = q.audiences.contains(SurveyAudience.teachers);
    
    return roleMatch || audienceMatch;
  }
}

class _TeacherSurveyCard extends StatelessWidget {
  final Questionnaire survey;
  final InstitutionModel institution;
  final FirebaseService service;
  final UserModel teacher;

  const _TeacherSurveyCard({
    required this.survey,
    required this.institution,
    required this.service,
    required this.teacher,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MM/yy');

    Color statusColor;
    String statusLabel;
    switch (survey.status) {
      case SurveyStatus.active:
        statusColor = const Color(0xFF00C853);
        statusLabel = 'Ativo';
        break;
      case SurveyStatus.draft:
        statusColor = Colors.amber;
        statusLabel = 'Rascunho';
        break;
      case SurveyStatus.closed:
        statusColor = Colors.orange;
        statusLabel = 'Encerrado';
        break;
      case SurveyStatus.locked:
        statusColor = Colors.grey;
        statusLabel = 'Finalizado';
        break;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _onTap(context),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              survey.title,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (survey.creatorRole == 'institution')
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF00BFA5).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: const Color(0xFF00BFA5).withValues(alpha: 0.5)),
                              ),
                              child: const AiTranslatedText(
                                'Estabelecimento',
                                style: TextStyle(color: Color(0xFF00BFA5), fontSize: 9, fontWeight: FontWeight.bold),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: statusColor.withValues(alpha: 0.4)),
                      ),
                      child: Text(statusLabel,
                          style: TextStyle(
                              color: statusColor,
                              fontSize: 10,
                              fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                if (survey.subjectId != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(children: [
                      const Icon(Icons.book, size: 12, color: Color(0xFF7B61FF)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: AiTranslatedText(
                          'Disciplina: ${survey.subjectId}',
                          style: const TextStyle(
                              color: Color(0xFF7B61FF), fontSize: 11),
                        ),
                      ),
                    ]),
                  ),
                const SizedBox(height: 8),
                Row(children: [
                  const Icon(Icons.calendar_today,
                      size: 11, color: Colors.white38),
                  const SizedBox(width: 4),
                  Text(
                    '${fmt.format(survey.startDate)} → ${fmt.format(survey.endDate)}',
                    style:
                        const TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                  const Spacer(),
                  StreamBuilder<List<QuestionnaireResponse>>(
                    stream:
                        service.getSurveyResponses(institution.id, survey.id),
                    builder: (ctx, snap) {
                      final count = snap.data?.length ?? 0;
                      return Row(children: [
                        const Icon(Icons.how_to_vote_outlined,
                            size: 13, color: Colors.white38),
                        const SizedBox(width: 4),
                        Text('$count resposta${count != 1 ? 's' : ''}',
                            style: const TextStyle(
                                color: Colors.white54, fontSize: 11)),
                      ]);
                    },
                  ),
                ]),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: _buildActions(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildActions(BuildContext context) {
    if (survey.status == SurveyStatus.draft) {
      return [
        TextButton.icon(
          onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => TeacherSurveyBuilderScreen(
                      teacher: teacher,
                      institution: institution,
                      existingSurvey: survey))),
          icon: const Icon(Icons.edit, size: 14, color: Colors.amber),
          label: const AiTranslatedText('Editar',
              style: TextStyle(color: Colors.amber, fontSize: 12)),
        ),
        TextButton.icon(
          onPressed: () => _confirmDelete(context),
          icon: const Icon(Icons.delete_outline, size: 14, color: Colors.red),
          label: const AiTranslatedText('Eliminar',
              style: TextStyle(color: Colors.red, fontSize: 12)),
        ),
      ];
    }
    if (survey.status == SurveyStatus.active) {
      return [
        TextButton.icon(
          onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => SurveyMonitoringScreen(
                      survey: survey, institution: institution))),
          icon: const Icon(Icons.monitor_heart, size: 14, color: Color(0xFF00C853)),
          label: const AiTranslatedText('Monitorizar',
              style: TextStyle(color: Color(0xFF00C853), fontSize: 12)),
        ),
      ];
    }
    return [
      TextButton.icon(
        onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => SurveyAnalysisScreen(
                    survey: survey, institution: institution))),
        icon: const Icon(Icons.bar_chart, size: 14, color: Color(0xFF7B61FF)),
        label: const AiTranslatedText('Ver Análise',
            style: TextStyle(color: Color(0xFF7B61FF), fontSize: 12)),
      ),
    ];
  }

  void _onTap(BuildContext context) {
    switch (survey.status) {
      case SurveyStatus.draft:
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => TeacherSurveyBuilderScreen(
                    teacher: teacher,
                    institution: institution,
                    existingSurvey: survey)));
        break;
      case SurveyStatus.active:
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => SurveyMonitoringScreen(
                    survey: survey, institution: institution)));
        break;
      case SurveyStatus.closed:
      case SurveyStatus.locked:
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => SurveyAnalysisScreen(
                    survey: survey, institution: institution)));
        break;
    }
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const AiTranslatedText('Eliminar',
            style: TextStyle(color: Colors.white)),
        content: AiTranslatedText(
          'Eliminar o inquérito "${survey.title}"?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const AiTranslatedText('Cancelar',
                  style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              Navigator.pop(ctx);
              await service.deleteSurvey(institution.id, survey.id);
            },
            child: const AiTranslatedText('Eliminar',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _PendingSurveyCard extends StatelessWidget {
  final Questionnaire survey;
  final UserRole role;

  const _PendingSurveyCard({required this.survey, required this.role});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        child: ListTile(
          contentPadding: const EdgeInsets.all(16),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  survey.title, 
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
                ),
              ),
              if (survey.creatorRole == 'institution')
                Container(
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
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              AiTranslatedText(survey.description, style: const TextStyle(color: Colors.white54, fontSize: 12)),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.timer, size: 14, color: Colors.orangeAccent),
                  const SizedBox(width: 4),
                  AiTranslatedText(
                    'Termina em: ${DateFormat('dd/MM/yyyy').format(survey.endDate)}',
                    style: const TextStyle(color: Colors.orangeAccent, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
          trailing: ElevatedButton(
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) => SurveyRunnerWidget(
                  q: survey,
                  userId: context.read<FirebaseService>().currentUser?.uid ?? 'teacher_default',
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7B61FF)),
            child: const AiTranslatedText('Responder'),
          ),
        ),
      ),
    );
  }
}

class _ArchivedSurveyCard extends StatelessWidget {
  final Questionnaire survey;
  final bool isAnswered;

  const _ArchivedSurveyCard({required this.survey, required this.isAnswered});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        child: ListTile(
          contentPadding: const EdgeInsets.all(16),
          title: Text(survey.title, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              AiTranslatedText(survey.description, style: const TextStyle(color: Colors.white38, fontSize: 12)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    isAnswered ? Icons.check_circle : Icons.lock_clock, 
                    size: 14, 
                    color: isAnswered ? Colors.greenAccent : Colors.grey
                  ),
                  const SizedBox(width: 4),
                  AiTranslatedText(
                    isAnswered ? 'Inquérito Respondido' : 'Inquérito Encerrado',
                    style: TextStyle(color: isAnswered ? Colors.greenAccent : Colors.grey, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
          trailing: isAnswered 
            ? const Icon(Icons.check, color: Colors.greenAccent)
            : const Icon(Icons.block, color: Colors.grey),
        ),
      ),
    );
  }
}
