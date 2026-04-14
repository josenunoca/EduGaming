import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/firebase_service.dart';
import '../../models/user_model.dart';
import '../../models/institution_model.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/ai_translated_text.dart';
import '../../widgets/branded_title.dart';
import '../../widgets/messaging_badge.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/user_notices_widget.dart';
import '../common/communication_center_screen.dart';
import 'institution_professor_management_screen.dart';
import 'institutional_management_screen.dart';
import 'credit_management_screen.dart';
import 'academic_management_screen.dart';
import '../common/personal_profile_screen.dart';
import 'lifestyle_management_screen.dart';
import '../login_screen.dart';

class InstitutionDashboard extends StatelessWidget {
  const InstitutionDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final service = context.watch<FirebaseService>();
    
    return StreamBuilder<User?>(
      stream: service.user,
      builder: (context, authSnap) {
        if (authSnap.hasError) {
          return Scaffold(body: Center(child: Text('Erro de autenticação: ${authSnap.error}')));
        }
        if (authSnap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (!authSnap.hasData) {
          return const Scaffold(body: Center(child: AiTranslatedText('Por favor, faça login novamente.')));
        }

        return StreamBuilder<UserModel?>(
          stream: service.getUserStream(authSnap.data!.uid),
          builder: (context, userSnap) {
            if (userSnap.hasError) {
              return Scaffold(body: Center(child: Text('Erro ao carregar perfil: ${userSnap.error}')));
            }
            if (userSnap.connectionState == ConnectionState.waiting) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }
            
            final user = userSnap.data;
            if (user == null) {
              return const Scaffold(body: Center(child: AiTranslatedText('Perfil de utilizador não encontrado.')));
            }
            
            if (user.institutionId == null) {
              return Scaffold(
                body: FutureBuilder(
                  future: service.repairInstitutionLink(authSnap.data!.uid, authSnap.data!.email!),
                  builder: (context, repairSnap) {
                    if (repairSnap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24.0),
                        child: AiTranslatedText(
                          'Erro: Vincule este utilizador a uma instituição no painel de Administrador ou verifique o email.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  },
                ),
              );
            }

            return StreamBuilder<InstitutionModel?>(
              stream: service.getInstitutionStream(user.institutionId!),
              builder: (context, instSnap) {
                if (instSnap.hasError) {
                  return Scaffold(body: Center(child: Text('Erro ao carregar instituição: ${instSnap.error}')));
                }
                if (instSnap.connectionState == ConnectionState.waiting) {
                  return const Scaffold(body: Center(child: CircularProgressIndicator()));
                }

                final institution = instSnap.data;
                if (institution == null) {
                  return const Scaffold(body: Center(child: AiTranslatedText('Instituição não encontrada ou sem permissões de acesso.')));
                }

                if (institution.isSuspended) {
                  return Scaffold(body: _buildSuspendedView('Esta instituição está suspensa pela administração.'));
                }

                return Scaffold(
                  backgroundColor: const Color(0xFF0F172A),
                  appBar: AppBar(
                    title: BrandedTitle(
                      logoUrl: institution.logoUrl,
                      institutionName: institution.name,
                      defaultTitle: 'Painel da Instituição',
                    ),
                    actions: [
                      IconButton(
                        icon: const Icon(Icons.person),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => PersonalProfileScreen(user: user)),
                        ),
                        tooltip: 'Área Pessoal',
                      ),
                      MessagingBadge(
                        icon: const Icon(Icons.mail),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const CommunicationCenterScreen()),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.logout),
                        onPressed: () async {
                          await FirebaseAuth.instance.signOut();
                          if (context.mounted) {
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(builder: (_) => const LoginScreen()),
                              (route) => false,
                            );
                          }
                        },
                        tooltip: 'Sair',
                      ),
                    ],
                  ),
                  body: Container(
                    padding: const EdgeInsets.all(24),
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          _buildBrandingSection(context, service, institution),
                          const SizedBox(height: 24),
                          UserNoticesWidget(user: user),
                          const SizedBox(height: 24),
                          GridView.count(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisCount: 4,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                            childAspectRatio: 1.5,
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
                              _DashboardActionCard(
                                icon: Icons.token,
                                label: 'Gestão de Créditos',
                                color: Colors.amber,
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          InstitutionCreditManagementScreen(
                                              institution: institution)),
                                ),
                              ),
                              _DashboardActionCard(
                                icon: Icons.school,
                                label: 'Gestão Académica',
                                color: Colors.indigo,
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          AcademicManagementScreen(
                                              institution: institution)),
                                ),
                              ),
                              _DashboardActionCard(
                                icon: Icons.favorite,
                                label: 'Estilo de Vida',
                                color: Colors.pinkAccent,
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => const LifestyleManagementScreen()),
                                )
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildBrandingSection(BuildContext context, FirebaseService service, InstitutionModel inst) {
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: Colors.white10,
              backgroundImage: inst.logoUrl != null ? NetworkImage(inst.logoUrl!) : null,
              child: inst.logoUrl == null ? const Icon(Icons.business, color: Colors.white54) : null,
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AiTranslatedText('Logótipo da Instituição',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  AiTranslatedText('Este logótipo será usado em todos os documentos oficiais.',
                      style: TextStyle(color: Colors.white54, fontSize: 12)),
                ],
              ),
            ),
            CustomButton(
              onPressed: () => _pickAndUploadLogo(context, service, inst.id),
              icon: Icons.upload,
              label: 'Alterar',
              variant: CustomButtonVariant.secondary,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndUploadLogo(BuildContext context, FirebaseService service, String institutionId) async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null && result.files.single.bytes != null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: AiTranslatedText('A carregar logótipo...')),
        );
      }
      await service.uploadInstitutionLogo(institutionId, result.files.single.bytes!);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: AiTranslatedText('Logótipo atualizado com sucesso!')),
        );
      }
    }
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
            Icon(icon, size: 28, color: color),
            const SizedBox(height: 2),
            AiTranslatedText(label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
