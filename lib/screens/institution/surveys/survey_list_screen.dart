import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../services/firebase_service.dart';
import '../../../models/questionnaire_model.dart';
import '../../../models/institution_model.dart';
import '../../../models/user_model.dart';
import '../../../widgets/glass_card.dart';
import '../../../widgets/ai_translated_text.dart';
import 'survey_builder_screen.dart';
import 'survey_monitoring_screen.dart';
import 'survey_analysis_screen.dart';

class SurveyListScreen extends StatelessWidget {
  final InstitutionModel institution;
  final UserModel currentUser;

  const SurveyListScreen({
    super.key,
    required this.institution,
    required this.currentUser,
  });

  @override
  Widget build(BuildContext context) {
    final service = context.read<FirebaseService>();

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: const AiTranslatedText(
          'Inquéritos e Avaliação',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF00BFA5),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SurveyBuilderScreen(
              institution: institution,
              currentUser: currentUser,
            ),
          ),
        ),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const AiTranslatedText(
          'Novo Inquérito',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: StreamBuilder<List<Questionnaire>>(
        stream: service.getSurveysForInstitution(institution.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF00BFA5)));
          }
          if (snapshot.hasError) {
            return Center(
              child: AiTranslatedText('Erro ao carregar inquéritos: ${snapshot.error}',
                  style: const TextStyle(color: Colors.red)),
            );
          }

          final surveys = snapshot.data ?? [];

          if (surveys.isEmpty) {
            return _buildEmptyState(context);
          }

          // Group surveys by status
          final drafts = surveys.where((s) => s.status == SurveyStatus.draft).toList();
          final active = surveys.where((s) => s.status == SurveyStatus.active).toList();
          final closed = surveys.where((s) => s.status == SurveyStatus.closed || s.status == SurveyStatus.locked).toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (active.isNotEmpty) ...[
                _buildSectionHeader('Ativos', Icons.radio_button_checked, const Color(0xFF00C853)),
                ...active.map((s) => _SurveyCard(
                    survey: s,
                    institution: institution,
                    service: service,
                    currentUser: currentUser)),
                const SizedBox(height: 16),
              ],
              if (drafts.isNotEmpty) ...[
                _buildSectionHeader('Rascunhos', Icons.edit_note, Colors.amber),
                ...drafts.map((s) => _SurveyCard(
                    survey: s,
                    institution: institution,
                    service: service,
                    currentUser: currentUser)),
                const SizedBox(height: 16),
              ],
              if (closed.isNotEmpty) ...[
                _buildSectionHeader('Encerrados / Finalizados', Icons.lock_outline, Colors.grey),
                ...closed.map((s) => _SurveyCard(
                    survey: s,
                    institution: institution,
                    service: service,
                    currentUser: currentUser)),
              ],
              const SizedBox(height: 80),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            title.toUpperCase(),
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF00BFA5).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.poll_outlined, size: 64, color: Color(0xFF00BFA5)),
          ),
          const SizedBox(height: 24),
          const AiTranslatedText(
            'Sem inquéritos criados',
            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const AiTranslatedText(
            'Crie o seu primeiro inquérito para\nrecolher feedback da comunidade escolar.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54, fontSize: 14),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00BFA5),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SurveyBuilderScreen(
                  institution: institution,
                  currentUser: currentUser,
                ),
              ),
            ),
            icon: const Icon(Icons.add, color: Colors.white),
            label: const AiTranslatedText(
              'Criar Inquérito',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

class _SurveyCard extends StatelessWidget {
  final Questionnaire survey;
  final InstitutionModel institution;
  final FirebaseService service;
  final UserModel currentUser;

  const _SurveyCard({
    required this.survey,
    required this.institution,
    required this.service,
    required this.currentUser,
  });

  Color get _statusColor {
    switch (survey.status) {
      case SurveyStatus.active:
        return const Color(0xFF00C853);
      case SurveyStatus.draft:
        return Colors.amber;
      case SurveyStatus.closed:
        return Colors.orange;
      case SurveyStatus.locked:
        return Colors.grey;
    }
  }

  String get _statusLabel {
    switch (survey.status) {
      case SurveyStatus.active:
        return 'Ativo';
      case SurveyStatus.draft:
        return 'Rascunho';
      case SurveyStatus.closed:
        return 'Encerrado';
      case SurveyStatus.locked:
        return 'Finalizado';
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MM/yyyy');
    final now = DateTime.now();
    final daysLeft = survey.endDate.difference(now).inDays;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _onCardTap(context),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        survey.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _statusColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _statusColor.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        _statusLabel,
                        style: TextStyle(
                          color: _statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Objectives chips
                if (survey.objectives.isNotEmpty)
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: survey.objectives.take(2).map((obj) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00BFA5).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        obj.label,
                        style: const TextStyle(color: Color(0xFF00BFA5), fontSize: 10),
                      ),
                    )).toList(),
                  ),

                const SizedBox(height: 10),

                // Date range + response counter
                Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 12, color: Colors.white38),
                    const SizedBox(width: 4),
                    Text(
                      '${fmt.format(survey.startDate)} → ${fmt.format(survey.endDate)}',
                      style: const TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                    const Spacer(),
                    if (survey.status == SurveyStatus.active && daysLeft >= 0)
                      Text(
                        '$daysLeft dia${daysLeft != 1 ? 's' : ''} restante${daysLeft != 1 ? 's' : ''}',
                        style: TextStyle(
                          color: daysLeft <= 3 ? Colors.orange : Colors.white38,
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 12),

                // Real-time response rate
                StreamBuilder<List<QuestionnaireResponse>>(
                  stream: service.getSurveyResponses(institution.id, survey.id),
                  builder: (ctx, respSnap) {
                    final count = respSnap.data?.length ?? 0;
                    return Row(
                      children: [
                        const Icon(Icons.people_outline, size: 14, color: Colors.white54),
                        const SizedBox(width: 6),
                        Text(
                          '$count resposta${count != 1 ? 's' : ''}',
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                        const Spacer(),
                        _buildActionRow(context, count),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionRow(BuildContext context, int responseCount) {
    if (survey.status == SurveyStatus.draft) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit, size: 18, color: Colors.amber),
            tooltip: 'Editar rascunho',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SurveyBuilderScreen(
                  institution: institution,
                  currentUser: currentUser,
                  existingSurvey: survey,
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
            tooltip: 'Eliminar',
            onPressed: () => _confirmDelete(context),
          ),
        ],
      );
    }

    if (survey.status == SurveyStatus.active) {
      return IconButton(
        icon: const Icon(Icons.monitor_heart, size: 18, color: Color(0xFF00C853)),
        tooltip: 'Monitorizar',
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SurveyMonitoringScreen(
              survey: survey,
              institution: institution,
            ),
          ),
        ),
      );
    }

    if (survey.status == SurveyStatus.closed || survey.status == SurveyStatus.locked) {
      return IconButton(
        icon: const Icon(Icons.bar_chart, size: 18, color: Color(0xFF7B61FF)),
        tooltip: 'Ver análise',
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SurveyAnalysisScreen(
              survey: survey,
              institution: institution,
            ),
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  void _onCardTap(BuildContext context) {
    switch (survey.status) {
      case SurveyStatus.draft:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SurveyBuilderScreen(
              institution: institution,
              currentUser: currentUser,
              existingSurvey: survey,
            ),
          ),
        );
        break;
      case SurveyStatus.active:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SurveyMonitoringScreen(
              survey: survey,
              institution: institution,
            ),
          ),
        );
        break;
      case SurveyStatus.closed:
      case SurveyStatus.locked:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SurveyAnalysisScreen(
              survey: survey,
              institution: institution,
            ),
          ),
        );
        break;
    }
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const AiTranslatedText('Eliminar Rascunho',
            style: TextStyle(color: Colors.white)),
        content: AiTranslatedText(
          'Tem a certeza que quer eliminar o inquérito "${survey.title}"?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const AiTranslatedText('Cancelar',
                style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              Navigator.pop(ctx);
              await service.deleteSurvey(institution.id, survey.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: AiTranslatedText('Inquérito eliminado.')),
                );
              }
            },
            child: const AiTranslatedText('Eliminar',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
