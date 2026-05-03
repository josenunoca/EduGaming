import 'package:flutter/material.dart';
import '../../models/institution_model.dart';
import '../../models/user_model.dart';
import '../../widgets/ai_translated_text.dart';
import '../../widgets/glass_card.dart';
import 'academic_management_screen.dart';
import '../institutional/institutional_organs_screen.dart';
import 'facility_management_screen.dart';
import 'knowledge/knowledge_management_screen.dart';
import 'activity_management_screen.dart';
import '../user/institutional_ai_chat_screen.dart';
import 'surveys/survey_list_screen.dart';

import '../../widgets/app_tile.dart';
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
        actions: [
          IconButton(
            icon: const Icon(Icons.psychology, color: Colors.cyanAccent),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => InstitutionalAiChatScreen(
                    institution: institution,
                    user: currentUser ?? _defaultUser(),
                  ),
                ),
              );
            },
            tooltip: 'Apoio Institucional IA',
          ),
        ],
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
                  AppTile(
                    label: 'Gestão Académica',
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
                  AppTile(
                    label: 'Órgãos e Atas',
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
                  AppTile(
                    label: 'Espaços e Horários',
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
                  AppTile(
                    label: 'Repositório e Docs',
                    subtitle: 'Regulamentos e Propostas',
                    icon: Icons.folder_shared,
                    color: const Color(0xFF00FF85),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            KnowledgeManagementScreen(institution: institution),
                      ),
                    ),
                  ),
                  AppTile(
                    label: 'Plano de Atividades',
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
                  AppTile(
                    label: 'Inquéritos e Avaliação',
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
                  AppTile(
                    label: 'Administração ERP 360º',
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
                  AppTile(
                    label: 'Apoio Institucional IA',
                    subtitle: 'Perguntas sobre a Instituição',
                    icon: Icons.psychology,
                    color: const Color(0xFF00D1FF),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => InstitutionalAiChatScreen(
                          institution: institution,
                          user: currentUser ?? _defaultUser(),
                        ),
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

