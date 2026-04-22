import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../services/firebase_service.dart';
import '../../../models/questionnaire_model.dart';
import '../../../models/institution_model.dart';
import '../../../models/user_model.dart';
import '../../../widgets/glass_card.dart';
import '../../../widgets/ai_translated_text.dart';
import 'survey_analysis_screen.dart';

class SurveyMonitoringScreen extends StatelessWidget {
  final Questionnaire survey;
  final InstitutionModel institution;

  const SurveyMonitoringScreen({
    super.key,
    required this.survey,
    required this.institution,
  });

  @override
  Widget build(BuildContext context) {
    final service = context.read<FirebaseService>();
    final fmt = DateFormat('dd/MM/yyyy HH:mm');

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: Text(
          survey.title,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
          overflow: TextOverflow.ellipsis,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          TextButton.icon(
            onPressed: () => _closeSurvey(context, service),
            icon: const Icon(Icons.stop_circle_outlined, color: Colors.orangeAccent, size: 18),
            label: const AiTranslatedText('Encerrar',
                style: TextStyle(color: Colors.orangeAccent, fontSize: 12)),
          ),
        ],
      ),
      body: StreamBuilder<List<QuestionnaireResponse>>(
        stream: service.getSurveyResponses(institution.id, survey.id),
        builder: (context, respSnap) {
          final responses = respSnap.data ?? [];
          final respondedIds = responses.map((r) => r.userId).toSet();
          final total = responses.length;

          return StreamBuilder<List<UserModel>>(
            stream: service.getUsersForInstitution(institution.id),
            builder: (context, allUsersSnap) {
              final allUsers = allUsersSnap.data ?? [];

              // Name lookup map: userId → name
              final nameMap = {for (final u in allUsers) u.id: u.name};

              // Targeted users (filtered by audience/individual IDs)
              final targetedUsers = _filterTargetedUsers(allUsers);
              final pendingUsers = targetedUsers
                  .where((u) => !respondedIds.contains(u.id))
                  .toList();
              final responseRate = targetedUsers.isEmpty
                  ? 0.0
                  : respondedIds.length / targetedUsers.length;

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Header stats
                  Row(
                    children: [
                      Expanded(child: _buildStatCard('Respostas', '$total', Icons.how_to_vote, const Color(0xFF00BFA5))),
                      const SizedBox(width: 12),
                      Expanded(child: _buildStatCard('Pendentes', '${pendingUsers.length}', Icons.hourglass_empty, Colors.amber)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildStatCard('Taxa', '${(responseRate * 100).toStringAsFixed(0)}%', Icons.percent, const Color(0xFF7B61FF))),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Response rate ring
                  GlassCard(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          const AiTranslatedText('Taxa de Resposta em Tempo Real',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                          const SizedBox(height: 20),
                          SizedBox(
                            height: 140,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                SizedBox(
                                  width: 140,
                                  height: 140,
                                  child: CircularProgressIndicator(
                                    value: responseRate,
                                    strokeWidth: 10,
                                    backgroundColor: Colors.white12,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      responseRate < 0.3
                                          ? Colors.redAccent
                                          : responseRate < 0.7
                                              ? Colors.amber
                                              : const Color(0xFF00C853),
                                    ),
                                  ),
                                ),
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '${(responseRate * 100).toStringAsFixed(0)}%',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 32,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    AiTranslatedText(
                                      '$total / ${targetedUsers.isEmpty ? '?' : targetedUsers.length}',
                                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          AiTranslatedText(
                            'Período: ${DateFormat('dd/MM/yyyy').format(survey.startDate)} → ${DateFormat('dd/MM/yyyy').format(survey.endDate)}',
                            style: const TextStyle(color: Colors.white54, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Pending respondents + reminder button
                  if (pendingUsers.isNotEmpty) ...[
                    GlassCard(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.notification_important_outlined,
                                    size: 18, color: Colors.amber),
                                const SizedBox(width: 8),
                                AiTranslatedText(
                                    'Ainda não responderam (${pendingUsers.length})',
                                    style: const TextStyle(
                                        color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                                const Spacer(),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.amber,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  onPressed: () => _sendReminders(context, pendingUsers),
                                  icon: const Icon(Icons.send, size: 14, color: Colors.black),
                                  label: const AiTranslatedText('Enviar Lembrete',
                                      style: TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            ...pendingUsers.take(5).map((u) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 14,
                                    backgroundColor: Colors.white12,
                                    child: Text(u.name.isNotEmpty ? u.name[0].toUpperCase() : '?',
                                        style: const TextStyle(color: Colors.white, fontSize: 12)),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(child: Text(u.name,
                                      style: const TextStyle(color: Colors.white70, fontSize: 13))),
                                  Text(u.email,
                                      style: const TextStyle(color: Colors.white38, fontSize: 11)),
                                ],
                              ),
                            )),
                            if (pendingUsers.length > 5)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: AiTranslatedText(
                                  '+ ${pendingUsers.length - 5} utilizadores adicionais',
                                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Responded list
                  if (responses.isNotEmpty) ...[
                    GlassCard(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              const Icon(Icons.check_circle_outline, size: 18, color: Color(0xFF00C853)),
                              const SizedBox(width: 8),
                              AiTranslatedText('Responderam (${responses.length})',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                            ]),
                            const SizedBox(height: 12),
                            ...responses.take(10).map((r) {
                              final isAnon = r.isAnonymous || r.userId.startsWith('anonymous_');
                              final name = isAnon
                                  ? 'Resposta Anónima'
                                  : (nameMap[r.userId] ?? 'Utilizador desconhecido');
                              final avatarLabel = isAnon ? '?' : name[0].toUpperCase();
                              final avatarColor = isAnon ? Colors.white24 : const Color(0xFF00C853);
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 5),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 14,
                                      backgroundColor: avatarColor.withValues(alpha: 0.2),
                                      child: Text(
                                        avatarLabel,
                                        style: TextStyle(
                                          color: isAnon ? Colors.white38 : const Color(0xFF00C853),
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        name,
                                        style: TextStyle(
                                          color: isAnon ? Colors.white38 : Colors.white70,
                                          fontSize: 12,
                                          fontStyle: isAnon ? FontStyle.italic : FontStyle.normal,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      fmt.format(r.timestamp),
                                      style: const TextStyle(color: Colors.white38, fontSize: 11),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Go to analysis (if closed)
                  if (survey.status == SurveyStatus.closed || survey.status == SurveyStatus.locked)
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7B61FF),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        minimumSize: const Size(double.infinity, 0),
                      ),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SurveyAnalysisScreen(
                            survey: survey,
                            institution: institution,
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.bar_chart, color: Colors.white),
                      label: const AiTranslatedText('Ver Análise e Relatório',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  List<UserModel> _filterTargetedUsers(List<UserModel> allUsers) {
    // If there are specific individual targets, use those exclusively.
    if (survey.individualTargetIds.isNotEmpty) {
      return allUsers.where((u) {
        final notExcluded = !survey.excludedTargetIds.contains(u.id) &&
            !survey.excludedTargetIds.contains(u.email);
        final isTargeted = survey.individualTargetIds.contains(u.id) ||
            survey.individualTargetIds.contains(u.email);
        return isTargeted && notExcluded;
      }).toList();
    }

    // Otherwise filter by broad audience roles.
    return allUsers.where((u) {
      final notExcluded = !survey.excludedTargetIds.contains(u.id) &&
          !survey.excludedTargetIds.contains(u.email);
      bool roleMatch = false;
      for (final audience in survey.audiences) {
        if (audience == SurveyAudience.teachers && u.role == UserRole.teacher) roleMatch = true;
        if (audience == SurveyAudience.students && u.role == UserRole.student) roleMatch = true;
        if (audience == SurveyAudience.parents && u.role == UserRole.parent) roleMatch = true;
        if (audience == SurveyAudience.nonTeachingStaff && u.role == UserRole.other) roleMatch = true;
      }
      return roleMatch && notExcluded;
    }).toList();
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(value, style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            AiTranslatedText(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  void _sendReminders(BuildContext context, List<UserModel> pending) {
    // In a real app this would call a Cloud Function to send emails.
    // For now, show the list and simulate the action.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.amber,
        content: AiTranslatedText(
          'Lembrete enviado para ${pending.length} destinatário(s) pendente(s).',
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _closeSurvey(BuildContext context, FirebaseService service) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const AiTranslatedText('Encerrar Inquérito',
            style: TextStyle(color: Colors.white)),
        content: const AiTranslatedText(
          'Ao encerrar, ninguém poderá submeter novas respostas. Poderá ainda editar e finalizar a análise.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const AiTranslatedText('Cancelar', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () => Navigator.pop(ctx, true),
            child: const AiTranslatedText('Encerrar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await service.updateSurveyStatus(institution.id, survey.id, SurveyStatus.closed);
      if (context.mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => SurveyAnalysisScreen(survey: survey, institution: institution),
          ),
        );
      }
    }
  }
}
