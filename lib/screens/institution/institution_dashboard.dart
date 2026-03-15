import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/firebase_service.dart';
import '../../models/user_model.dart';
import '../../models/institution_model.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/ai_translated_text.dart';
import '../../widgets/messaging_badge.dart';
import '../common/communication_center_screen.dart';
import 'institution_professor_management_screen.dart';
import 'institutional_management_screen.dart';

class InstitutionDashboard extends StatelessWidget {
  const InstitutionDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final service = context.watch<FirebaseService>();
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const AiTranslatedText('Painel da Instituição'),
        actions: [
          MessagingBadge(
            icon: const Icon(Icons.mail),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const CommunicationCenterScreen()),
            ),
          ),
        ],
      ),
      body: StreamBuilder<User?>(
        stream: service.user,
        builder: (context, authSnap) {
          if (authSnap.hasError) {
            return Center(child: Text('Erro de autenticação: ${authSnap.error}'));
          }
          if (authSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!authSnap.hasData) {
            return const Center(child: AiTranslatedText('Por favor, faça login novamente.'));
          }

          return StreamBuilder<UserModel?>(
            stream: service.getUserStream(authSnap.data!.uid),
            builder: (context, userSnap) {
              if (userSnap.hasError) {
                return Center(child: Text('Erro ao carregar perfil: ${userSnap.error}'));
              }
              if (userSnap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              
              final user = userSnap.data;
              if (user == null) {
                return const Center(child: AiTranslatedText('Perfil de utilizador não encontrado.'));
              }
              
              if (user.institutionId == null) {
                return const Center(child: AiTranslatedText('Erro: Esta conta não está associada a nenhuma instituição.'));
              }

              return StreamBuilder<InstitutionModel?>(
                stream: service.getInstitutionStream(user.institutionId!),
                builder: (context, instSnap) {
                  if (instSnap.hasError) {
                    return Center(child: Text('Erro ao carregar instituição: ${instSnap.error}'));
                  }
                  if (instSnap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final institution = instSnap.data;
                  if (institution == null) {
                    return const Center(child: AiTranslatedText('Instituição não encontrada ou sem permissões de acesso.'));
                  }

                  // Access check
                  if (institution.isSuspended) {
                    return _buildSuspendedView(
                        'Esta instituição está suspensa pela administração.');
                  }

                  return Container(
                    padding: const EdgeInsets.all(24),
                    child: GridView.count(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      children: [
                        _DashboardActionCard(
                          icon: Icons.people,
                          label: 'Gerir Professores',
                          color: const Color(0xFF00D1FF),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    InstitutionProfessorManagementScreen(
                                        institution: institution)),
                          ),
                        ),
                        _DashboardActionCard(
                          icon: Icons.admin_panel_settings,
                          label: 'Gestão Global 360º',
                          color: const Color(0xFF7B61FF),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    InstitutionalManagementScreen(
                                        institution: institution)),
                          ),
                        ),
                        // Future: Add other institution actions
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildSuspendedView(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.lock_person, size: 80, color: Colors.red),
          const SizedBox(height: 24),
          AiTranslatedText(message,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const AiTranslatedText(
              'Contacte a administração para mais informações.',
              style: TextStyle(color: Colors.white54)),
        ],
      ),
    );
  }
}

class _DashboardActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _DashboardActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: GlassCard(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: color),
            const SizedBox(height: 12),
            AiTranslatedText(label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
