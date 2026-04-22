import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../services/firebase_service.dart';
import '../../models/user_model.dart';
import '../../models/course_model.dart';
import '../../models/subject_model.dart';
import '../../widgets/ai_translated_text.dart';
import '../common/communication_center_screen.dart';
import 'course_coordinator_monitor_screen.dart';
import 'course_report_screen.dart';

class CoordinatorDashboard extends StatefulWidget {
  const CoordinatorDashboard({super.key});

  @override
  State<CoordinatorDashboard> createState() => _CoordinatorDashboardState();
}

class _CoordinatorDashboardState extends State<CoordinatorDashboard> {
  @override
  Widget build(BuildContext context) {
    final service = context.read<FirebaseService>();
    final user = service.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const AiTranslatedText('Painel do Coordenador'),
        actions: [
          IconButton(
            icon: const Icon(Icons.mail),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const CommunicationCenterScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => service.signOut(),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AiTranslatedText(
                'Bem-vindo, Coordenador ${user?.displayName ?? ""}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const AiTranslatedText(
                'Gestão Académica e do Curso',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
              const SizedBox(height: 32),
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  children: [
                    StreamBuilder<List<Course>>(
                      stream: service.getCoordinatorCourses(user!.uid),
                      builder: (context, snapshot) {
                        final courses = snapshot.data ?? [];
                        return _MenuCard(
                          icon: Icons.subject,
                          title: 'Disciplinas & Sumários',
                          subtitle: 'Monitorização de conteúdos',
                          color: const Color(0xFF7B61FF),
                          onTap: () {
                            if (courses.isNotEmpty) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => CourseCoordinatorMonitorScreen(course: courses.first),
                                ),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Nenhum curso associado.')),
                              );
                            }
                          },
                        );
                      },
                    ),
                    _MenuCard(
                      icon: Icons.people,
                      title: 'Alunos & Delegados',
                      subtitle: 'Gestão de turma',
                      color: const Color(0xFF00D1FF),
                      onTap: () => _showDelegateNominationDialog(),
                    ),
                    _MenuCard(
                      icon: Icons.assignment,
                      title: 'Provas & Avaliações',
                      subtitle: 'Resultados e estatísticas',
                      color: const Color(0xFF10B981),
                      onTap: () {},
                    ),
                    _MenuCard(
                      icon: Icons.history,
                      title: 'Log de Alterações',
                      subtitle: 'Audit académico',
                      color: const Color(0xFFF59E0B),
                      onTap: () => _showAuditLogDialog(),
                    ),
                    StreamBuilder<List<Course>>(
                      stream: service.getCoordinatorCourses(user.uid),
                      builder: (context, snapshot) {
                        final courses = snapshot.data ?? [];
                        return _MenuCard(
                          icon: Icons.analytics,
                          title: 'Relatórios de Curso',
                          subtitle: 'Estatísticas e fotos',
                          color: const Color(0xFFEC4899),
                          onTap: () {
                            if (courses.isNotEmpty) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => CourseReportScreen(course: courses.first),
                                ),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Nenhum curso associado.')),
                              );
                            }
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDelegateNominationDialog() {
    final service = context.read<FirebaseService>();
    final user = service.currentUser;
    if (user == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        title: const AiTranslatedText('Nomear Delegado de Turma',
            style: TextStyle(color: Colors.white)),
        content: SizedBox(
          width: double.maxFinite,
          child: StreamBuilder<List<Course>>(
            stream: service.getCoordinatorCourses(user.uid),
            builder: (context, courseSnapshot) {
              if (!courseSnapshot.hasData)
                return const Center(child: CircularProgressIndicator());
              final courses = courseSnapshot.data!;
              if (courses.isEmpty)
                return const AiTranslatedText(
                    'Não está associado a nenhum curso como coordenador.',
                    style: TextStyle(color: Colors.white54));

              return ListView.builder(
                shrinkWrap: true,
                itemCount: courses.length,
                itemBuilder: (context, idx) {
                  final course = courses[idx];
                  return ExpansionTile(
                    title: Text(course.name,
                        style: const TextStyle(color: Colors.white)),
                    children: [
                      StreamBuilder<List<UserModel>>(
                        stream: service.getEligibleDelegates(course.id),
                        builder: (context, studentSnapshot) {
                          if (!studentSnapshot.hasData)
                            return const Center(
                                child: CircularProgressIndicator());
                          final students = studentSnapshot.data!;
                          return Column(
                            children: students
                                .map((s) => ListTile(
                                      title: Text(s.name,
                                          style: const TextStyle(
                                              color: Colors.white70)),
                                      trailing: course.delegateId == s.id
                                          ? const Icon(Icons.star,
                                              color: Colors.amber)
                                          : null,
                                      onTap: () async {
                                        await service.assignClassDelegate(
                                            course.id, s.id);
                                        Navigator.pop(context);
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(SnackBar(
                                                content: Text(
                                                    'Delegado nomeado para ${course.name}!')));
                                      },
                                    ))
                                .toList(),
                          );
                        },
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  void _showAuditLogDialog() {
    final service = context.read<FirebaseService>();
    final user = service.currentUser;
    if (user == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        title: const AiTranslatedText('Resumo de Alterações Académicas',
            style: TextStyle(color: Colors.white)),
        content: SizedBox(
          width: double.maxFinite,
          child: StreamBuilder<List<Course>>(
            stream: service.getCoordinatorCourses(user.uid),
            builder: (context, courseSnapshot) {
              if (!courseSnapshot.hasData)
                return const Center(child: CircularProgressIndicator());
              final courses = courseSnapshot.data!;
              return ListView.builder(
                shrinkWrap: true,
                itemCount: courses.length,
                itemBuilder: (context, ci) {
                  final course = courses[ci];
                  return StreamBuilder<List<Subject>>(
                    stream: service.getSubjectsStreamByCourse(course.id),
                    builder: (context, subSnapshot) {
                      final subjects = subSnapshot.data ?? [];
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Text(course.name,
                                style: const TextStyle(
                                    color: Colors.amber,
                                    fontWeight: FontWeight.bold)),
                          ),
                          ...subjects.map((s) => ExpansionTile(
                                title: Text(s.name,
                                    style:
                                        const TextStyle(color: Colors.white70)),
                                children: [
                                  StreamBuilder<List<SyllabusSession>>(
                                    stream: service.getSessionsStream(s.id),
                                    builder: (context, sessionSnap) {
                                      final sessions = sessionSnap.data ?? [];
                                      final logs = sessions
                                          .expand(
                                              (sess) => sess.modificationLog)
                                          .toList();
                                      logs.sort((a, b) =>
                                          b.timestamp.compareTo(a.timestamp));

                                      if (logs.isEmpty)
                                        return const Padding(
                                            padding: EdgeInsets.all(8.0),
                                            child: Text(
                                                'Sem alterações registadas.',
                                                style: TextStyle(
                                                    color: Colors.white24,
                                                    fontSize: 12)));

                                      return Column(
                                        children: logs
                                            .map((log) => ListTile(
                                                  title: Text(log.action,
                                                      style: const TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 12)),
                                                  subtitle: Text(
                                                      'Por: ${log.userName} em ${DateFormat('dd/MM HH:mm').format(log.timestamp)}',
                                                      style: const TextStyle(
                                                          color: Colors.white54,
                                                          fontSize: 10)),
                                                  dense: true,
                                                ))
                                            .toList(),
                                      );
                                    },
                                  ),
                                ],
                              )),
                        ],
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _MenuCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: color),
            const SizedBox(height: 16),
            AiTranslatedText(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            AiTranslatedText(
              subtitle,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
