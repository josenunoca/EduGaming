import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../login_screen.dart';
import '../../widgets/branded_title.dart';
import '../../services/firebase_service.dart';
import '../../models/user_model.dart';
import '../../models/institution_model.dart';
import '../../models/subject_model.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/app_tile.dart';
import 'subject_selection_screen.dart';
import '../common/personal_profile_screen.dart';
import '../common/timetable_user_screen.dart';
import '../../widgets/ai_translated_text.dart';
import '../common/communication_center_screen.dart';
import '../../widgets/messaging_badge.dart';
import 'student_subject_screen.dart';
import '../../widgets/user_notices_widget.dart';
import 'student_surveys_screen.dart';
import '../user/user_uniform_catalog_screen.dart';
import '../user/institutional_ai_chat_screen.dart';

class StudentDashboard extends StatelessWidget {
  final String? studentId;
  const StudentDashboard({super.key, this.studentId});

  @override
  Widget build(BuildContext context) {
    final service = context.watch<FirebaseService>();

    return StreamBuilder<User?>(
      stream: service.user,
      builder: (context, authSnapshot) {
        final currentUserId = authSnapshot.data?.uid ?? '';
        final effectiveStudentId = studentId ?? currentUserId;

        if (currentUserId.isEmpty) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }

        return StreamBuilder<UserModel?>(
          stream: service.getUserStream(effectiveStudentId),
          builder: (context, userSnapshot) {
            final student = userSnapshot.data;
            if (student == null) {
              return const Scaffold(
                  body: Center(child: CircularProgressIndicator()));
            }

            final bool isViewingAsParent =
                studentId != null && studentId != currentUserId;

            if (student.isSuspended) {
              return Scaffold(
                backgroundColor: const Color(0xFF0F172A),
                appBar: AppBar(
                  title: AiTranslatedText(isViewingAsParent
                      ? 'Conta Suspensa: ${student.name}'
                      : 'Acesso Suspenso'),
                  actions: [
                    StreamBuilder<InstitutionModel?>(
                      stream: student.institutionId != null
                          ? service.getInstitutionStream(student.institutionId!)
                          : Stream.value(null),
                      builder: (context, instSnap) {
                        final institution = instSnap.data;
                        if (institution == null) return const SizedBox.shrink();
                        return IconButton(
                          icon: const Icon(Icons.psychology, color: Colors.cyanAccent),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => InstitutionalAiChatScreen(
                                  user: student,
                                  institution: institution,
                                ),
                              ),
                            );
                          },
                          tooltip: 'Apoio Institucional IA',
                        );
                      },
                    ),
                    if (!isViewingAsParent)
                      IconButton(
                        icon: const Icon(Icons.logout),
                        onPressed: () async {
                          await FirebaseAuth.instance.signOut();
                          if (context.mounted) {
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const LoginScreen()),
                              (route) => false,
                            );
                          }
                        },
                      ),
                  ],
                ),
                body: const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.lock_person, size: 80, color: Colors.red),
                        SizedBox(height: 24),
                        AiTranslatedText(
                          'Esta conta de aluno está suspensa.',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 8),
                        AiTranslatedText(
                          'O acesso a todos os conteúdos e disciplinas foi bloqueado pela Administração ou pela Instituição.',
                          style: TextStyle(color: Colors.white54),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }
            return Scaffold(
              backgroundColor: const Color(0xFF0F172A),
              appBar: AppBar(
                title: StreamBuilder<InstitutionModel?>(
                  stream: student.institutionId != null
                      ? service.getInstitutionStream(student.institutionId!)
                      : Stream.value(null),
                  builder: (context, instSnap) {
                    final institution = instSnap.data;
                    return BrandedTitle(
                      logoUrl: institution?.logoUrl,
                      institutionName: institution?.name,
                      defaultTitle: isViewingAsParent
                          ? 'Acompanhamento: ${student.name}'
                          : 'Painel do Aluno',
                    );
                  },
                ),
                actions: [
                  if (!isViewingAsParent) ...[
                    IconButton(
                      icon: const Icon(Icons.person),
                      onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  PersonalProfileScreen(user: student))),
                      tooltip: 'Ver e editar os seus dados pessoais',
                    ),
                    IconButton(
                      icon: const Icon(Icons.calendar_month),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TimetableUserScreen(user: student),
                        ),
                      ),
                      tooltip: 'Ver o meu horário escolar',
                    ),
                    StreamBuilder<InstitutionModel?>(
                      stream: student.institutionId != null
                          ? service.getInstitutionStream(student.institutionId!)
                          : Stream.value(null),
                      builder: (context, instSnap) {
                        final institution = instSnap.data;
                        if (institution == null) return const SizedBox.shrink();
                        return IconButton(
                          icon: const Icon(Icons.psychology, color: Colors.cyanAccent),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => InstitutionalAiChatScreen(
                                  user: student,
                                  institution: institution,
                                ),
                              ),
                            );
                          },
                          tooltip: 'Apoio Institucional IA',
                        );
                      },
                    ),
                    Tooltip(
                      message: 'Abrir centro de mensagens e correspondência',
                      child: MessagingBadge(
                        icon: const Icon(Icons.mail),
                        onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => CommunicationCenterScreen(
                                    forUserId: effectiveStudentId))),
                      ),
                    ),
                    Tooltip(
                      message: 'Sair da conta e voltar ao ecrã de login',
                      child: IconButton(
                        icon: const Icon(Icons.logout),
                        onPressed: () async {
                          await FirebaseAuth.instance.signOut();
                          if (context.mounted) {
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const LoginScreen()),
                              (route) => false,
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ],
              ),
              body: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: Colors.white10,
                          backgroundImage: student.photoUrl != null ? NetworkImage(student.photoUrl!) : null,
                          child: student.photoUrl == null ? const Icon(Icons.person, color: Colors.white24, size: 20) : null,
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AiTranslatedText('Olá, ${student.name}',
                                style: const TextStyle(
                                    fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
                            const AiTranslatedText('Bem-vindo ao teu painel de aprendizagem',
                                style: TextStyle(
                                    fontSize: 11, color: Colors.white38)),
                          ],
                        ),
                      ],
                    ),
                    const AiTranslatedText('As Tuas Disciplinas',
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                    const SizedBox(height: 12),
                    Tooltip(
                      message:
                          'Clique para navegar e inscrever-se em novas disciplinas disponíveis',
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  SubjectSelectionScreen(student: student)),
                        ),
                        icon: const Icon(Icons.search),
                        label: const AiTranslatedText(
                            'Procurar Novas Disciplinas'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7B61FF),
                          minimumSize: const Size(double.infinity, 36),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    UserNoticesWidget(user: student),
                    const SizedBox(height: 12),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: double.infinity),
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Color(0xFF7B61FF)),
                          minimumSize: const Size(double.infinity, 36),
                          backgroundColor: const Color(0xFF7B61FF).withValues(alpha: 0.1),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => StudentSurveysScreen(student: student),
                            ),
                          );
                        },
                        icon: const Icon(Icons.assignment_outlined),
                        label: const AiTranslatedText('Inquéritos e Avaliações'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    StreamBuilder<InstitutionModel?>(
                      stream: student.institutionId != null
                          ? service.getInstitutionStream(student.institutionId!)
                          : Stream.value(null),
                      builder: (context, instSnap) {
                        final institution = instSnap.data;
                        if (institution == null) return const SizedBox.shrink();
                        return GridView(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            mainAxisExtent: 160,
                          ),
                          children: [
                            AppTile(
                              icon: Icons.shopping_bag_outlined,
                              label: 'Loja de Uniformes',
                              color: const Color(0xFFFF9F1C),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => UserUniformCatalogScreen(
                                      institution: institution,
                                      user: student,
                                    ),
                                  ),
                                );
                              },
                            ),
                            AppTile(
                              icon: Icons.auto_awesome,
                              label: 'Apoio IA',
                              color: Colors.cyanAccent,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => InstitutionalAiChatScreen(
                                      user: student,
                                      institution: institution,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 32),
                    const AiTranslatedText('Inscrições e Acesso',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white70)),
                    const SizedBox(height: 12),
                    Expanded(
                      child: StreamBuilder<List<Enrollment>>(
                        stream: service.getEnrollmentsForStudent(student.id),
                        builder: (context, enrollmentSnapshot) {
                          if (!enrollmentSnapshot.hasData) {
                            return const Center(
                                child: CircularProgressIndicator());
                          }
                          final enrollments = enrollmentSnapshot.data!;

                          if (enrollments.isEmpty) {
                            return const Center(
                                child: AiTranslatedText(
                                    'Ainda não se inscreveu em nenhuma disciplina.',
                                    style: TextStyle(color: Colors.white38)));
                          }

                          return ListView.builder(
                            itemCount: enrollments.length,
                            itemBuilder: (context, index) {
                              final enrollment = enrollments[index];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: GlassCard(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 4),
                                  child: StreamBuilder<Subject?>(
                                      stream: service.getSubjectStream(
                                          enrollment.subjectId),
                                      builder: (context, subjectSnapshot) {
                                        final subjectName = subjectSnapshot
                                                .data?.name ??
                                            'Disciplina ID: ${enrollment.subjectId}';
                                        return ListTile(
                                          title: AiTranslatedText(subjectName,
                                              style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16)),
                                          subtitle: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              AiTranslatedText(
                                                  'Estado: ${_getStatusLabel(enrollment.status)}',
                                                  style: TextStyle(
                                                      color: _getStatusColor(
                                                          enrollment.status),
                                                      fontSize: 12)),
                                              if (enrollment.isSuspended)
                                                const Padding(
                                                  padding:
                                                      EdgeInsets.only(top: 4.0),
                                                  child: AiTranslatedText(
                                                    'ACESSO SUSPENSO PELO DOCENTE',
                                                    style: TextStyle(
                                                        color: Colors.orange,
                                                        fontSize: 10,
                                                        fontWeight:
                                                            FontWeight.bold),
                                                  ),
                                                ),
                                            ],
                                          ),
                                          trailing: (enrollment.status ==
                                                      'accepted' &&
                                                  !enrollment.isSuspended)
                                              ? const Icon(
                                                  Icons.play_circle_fill,
                                                  color: Color(0xFF00D1FF))
                                              : const Icon(Icons.lock_clock,
                                                  color: Colors.white24),
                                          onTap: (enrollment.status ==
                                                      'accepted' &&
                                                  !enrollment.isSuspended)
                                              ? () {
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (_) =>
                                                          StudentSubjectScreen(
                                                              subjectId:
                                                                  enrollment
                                                                      .subjectId,
                                                              studentId:
                                                                  effectiveStudentId),
                                                    ),
                                                  );
                                                }
                                              : null,
                                        );
                                      }),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'pending_admin':
        return 'A aguardar pagamento (Administrador)';
      case 'pending_teacher':
        return 'Pendente de validação (Professor)';
      case 'accepted':
        return 'Acesso autorizado';
      case 'rejected':
        return 'Pedido recusado';
      default:
        return 'Pendente';
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending_admin':
        return Colors.orange;
      case 'pending_teacher':
        return Colors.blue;
      case 'accepted':
        return Colors.greenAccent;
      case 'rejected':
        return Colors.redAccent;
      default:
        return Colors.white;
    }
  }
}
