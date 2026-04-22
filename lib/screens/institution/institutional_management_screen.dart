import 'package:flutter/material.dart';
import '../../models/institution_model.dart';
import '../../models/user_model.dart';
import '../../widgets/ai_translated_text.dart';
import '../../widgets/glass_card.dart';
import 'academic_management_screen.dart';
import '../institutional/institutional_organs_screen.dart';
import 'facility_management_screen.dart';
import 'document_repository_screen.dart';
import 'activity_management_screen.dart';
import 'surveys/survey_list_screen.dart';

import 'erp/erp_dashboard.dart';

class InstitutionalManagementScreen extends StatelessWidget {
  final InstitutionModel institution;
  final UserModel? currentUser;
  final int? initialTab;
  const InstitutionalManagementScreen({
    super.key,
    required this.institution,
    this.currentUser,
    this.initialTab,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: AiTranslatedText('Gestão 360º - ${institution.name}'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AiTranslatedText(
              'Painel de Controlo Abrangente',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const AiTranslatedText(
              'Gerencie todos os aspetos da sua instituição num só lugar.',
              style: TextStyle(color: Colors.white54),
            ),
            const SizedBox(height: 32),
            Expanded(
              child: GridView(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  mainAxisExtent: 160,
                ),
                children: [
                  _ManagementCard(
                    title: 'Gestão Académica',
                    subtitle: 'Cursos, Ciclos e Disciplinas',
                    icon: Icons.school,
                    color: const Color(0xFF00D1FF),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            AcademicManagementScreen(institution: institution),
                      ),
                    ),
                  ),
                  _ManagementCard(
                    title: 'Órgãos e Atas',
                    subtitle: 'Conselhos e Reuniões IA',
                    icon: Icons.gavel,
                    color: const Color(0xFF7B61FF),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            InstitutionalOrgansScreen(institution: institution),
                      ),
                    ),
                  ),
                  _ManagementCard(
                    title: 'Espaços e Horários',
                    subtitle: 'Salas e Calendários',
                    icon: Icons.calendar_month,
                    color: const Color(0xFFFFB800),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            FacilityManagementScreen(institution: institution),
                      ),
                    ),
                  ),
                  _ManagementCard(
                    title: 'Repositório e Docs',
                    subtitle: 'Regulamentos e Propostas',
                    icon: Icons.folder_shared,
                    color: const Color(0xFF00FF85),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            DocumentRepositoryScreen(institution: institution),
                      ),
                    ),
                  ),
                  _ManagementCard(
                    title: 'Plano de Atividades',
                    subtitle: 'Eventos, Logística e Relatórios',
                    icon: Icons.event_available,
                    color: const Color(0xFFFF4D4D),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            ActivityManagementScreen(institution: institution),
                      ),
                    ),
                  ),
                  _ManagementCard(
                    title: 'Inquéritos e Avaliação',
                    subtitle: 'Satisfação e Desempenho',
                    icon: Icons.poll,
                    color: const Color(0xFF00BFA5),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SurveyListScreen(
                          institution: institution,
                          currentUser: currentUser ?? _defaultUser(),
                        ),
                      ),
                    ),
                  ),
                  _ManagementCard(
                    title: 'Administração ERP 360º',
                    subtitle: 'RH, Finanças e Operações',
                    icon: Icons.business,
                    color: const Color(0xFFE91E63),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ErpDashboard(institution: institution),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  UserModel _defaultUser() => UserModel(
        id: institution.id,
        email: institution.email,
        name: institution.name,
        role: UserRole.institution,
        adConsent: false,
        dataConsent: false,
      );
}

class _ManagementCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ManagementCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: title,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        splashColor: color.withValues(alpha: 0.1),
        highlightColor: color.withValues(alpha: 0.05),
        child: GlassCard(
          child: Padding(
            padding: const EdgeInsets.all(4.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 24, color: color),
                ),
                const SizedBox(height: 4),
                Flexible(
                  child: AiTranslatedText(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Flexible(
                  child: AiTranslatedText(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
