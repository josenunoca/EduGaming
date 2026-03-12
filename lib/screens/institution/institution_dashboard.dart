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
              MaterialPageRoute(builder: (_) => const CommunicationCenterScreen()),
            ),
          ),
        ],
      ),
      body: StreamBuilder<User?>(
        stream: service.user,
        builder: (context, authSnap) {
          if (!authSnap.hasData) return const SizedBox();
          return StreamBuilder<UserModel?>(
            stream: service.getUserStream(authSnap.data!.uid),
            builder: (context, userSnap) {
              final user = userSnap.data;
              if (user == null || user.institutionId == null) return const Center(child: CircularProgressIndicator());
              
              return StreamBuilder<InstitutionModel?>(
                stream: service.getInstitutionStream(user.institutionId!),
                builder: (context, instSnap) {
                  final institution = instSnap.data;
                  if (institution == null) return const Center(child: CircularProgressIndicator());

                  // Access check
                  if (institution.isSuspended) {
                    return _buildSuspendedView('Esta instituição está suspensa pela administração.');
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
                            MaterialPageRoute(builder: (_) => InstitutionProfessorManagementScreen(institution: institution)),
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
          AiTranslatedText(message, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const AiTranslatedText('Contacte a administração para mais informações.', style: TextStyle(color: Colors.white54)),
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
            AiTranslatedText(label, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
