import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../services/firebase_service.dart';
import '../../models/subject_model.dart';
import '../../models/course_model.dart';
import '../../models/school_calendar_model.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/ai_translated_text.dart';

class CourseCoordinatorMonitorScreen extends StatefulWidget {
  final Course course;

  const CourseCoordinatorMonitorScreen({super.key, required this.course});

  @override
  State<CourseCoordinatorMonitorScreen> createState() => _CourseCoordinatorMonitorScreenState();
}

class _CourseCoordinatorMonitorScreenState extends State<CourseCoordinatorMonitorScreen> {
  final _academicYear = "2024/2025"; // In production, get from context/provider

  @override
  Widget build(BuildContext context) {
    final service = context.read<FirebaseService>();

    return Scaffold(
      appBar: AppBar(
        title: AiTranslatedText('Monitorização: ${widget.course.name}'),
        backgroundColor: const Color(0xFF0F172A),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          ),
        ),
        child: StreamBuilder<SchoolCalendar?>(
          stream: service.getSchoolCalendarStream(widget.course.institutionId, _academicYear),
          builder: (context, calendarSnap) {
            final calendar = calendarSnap.data;
            
            return StreamBuilder<List<Subject>>(
              stream: service.getSubjectsStreamByCourse(widget.course.id),
              builder: (context, subjectSnap) {
                if (!subjectSnap.hasData) return const Center(child: CircularProgressIndicator());
                final subjects = subjectSnap.data!;

                return LayoutBuilder(
                  builder: (context, constraints) {
                    final crossAxisCount = constraints.maxWidth > 800 ? 3 : (constraints.maxWidth > 600 ? 2 : 1);
                    return GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        mainAxisExtent: 220, // Height of the card
                      ),
                      itemCount: subjects.length,
                      itemBuilder: (context, index) {
                        final subject = subjects[index];
                        return _SubjectMonitorCard(
                          subject: subject,
                          calendar: calendar,
                          coordinatorName: service.currentUser?.displayName ?? 'Coordenador',
                        );
                      },
                    );
                  }
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _SubjectMonitorCard extends StatelessWidget {
  final Subject subject;
  final SchoolCalendar? calendar;
  final String coordinatorName;

  const _SubjectMonitorCard({
    required this.subject,
    this.calendar,
    required this.coordinatorName,
  });

  @override
  Widget build(BuildContext context) {
    final hasProgram = (subject.programDescription?.isNotEmpty ?? false) || 
                       (subject.contents.isNotEmpty);
    final summariesCount = subject.sessions.where((s) => s.isFinalized).length;
    
    // Heuristic: 2 sessions per week if not specified
    final now = DateTime.now();
    int expectedSessions = 0;
    if (calendar != null && calendar!.terms.isNotEmpty) {
      final activeTerm = calendar!.terms.first; // Simplified
      if (now.isAfter(activeTerm.startDate)) {
        final weeksElapsed = now.difference(activeTerm.startDate).inDays ~/ 7;
        expectedSessions = weeksElapsed * 2; // Assuming 2 classes/week
      }
    }
    
    final summaryDelay = expectedSessions > 0 ? (expectedSessions - summariesCount).clamp(0, 99) : 0;
    
    final isProgramLate = !hasProgram && (calendar?.deadlines?.programSubmissionDeadline?.isBefore(now) ?? false);
    final isGradesLate = subject.pautaStatus != PautaStatus.sealed && (calendar?.deadlines?.gradingDeadline?.isBefore(now) ?? false);

    return GlassCard(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subject.name,
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    AiTranslatedText(
                      'Ano: ${subject.level}º | Semestre: ${subject.academicYear}', // academicYear often used for sem in this context
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
              _buildStatusBadge(subject.syllabusStatus.name, _getStatusColor(subject.syllabusStatus)),
            ],
          ),
          const Divider(color: Colors.white10, height: 24),
          Row(
            children: [
              _buildMetric('Programa', hasProgram ? 'Carregado' : 'Faltam Conteúdos', hasProgram ? Colors.green : (isProgramLate ? Colors.red : Colors.orange)),
              _buildMetric('Sumários', '$summariesCount/$expectedSessions', summaryDelay > 2 ? Colors.red : (summaryDelay > 0 ? Colors.orange : Colors.green)),
              _buildMetric('Avaliação', subject.pautaStatus.name, isGradesLate ? Colors.red : Colors.blue),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () => _sendWarning(context),
                icon: const Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent),
                label: const AiTranslatedText('Enviar Alerta', style: TextStyle(color: Colors.orangeAccent)),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7B61FF)),
                child: const AiTranslatedText('Ver Detalhes'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetric(String label, String value, Color color) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AiTranslatedText(label, style: const TextStyle(color: Colors.white54, fontSize: 10)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  Color _getStatusColor(SyllabusStatus status) {
    switch (status) {
      case SyllabusStatus.approved: return Colors.green;
      case SyllabusStatus.provisional: return Colors.orange;
      case SyllabusStatus.inValidationScientific:
      case SyllabusStatus.inValidationPedagogical: return Colors.blue;
      case SyllabusStatus.rejected: return Colors.red;
    }
  }

  void _sendWarning(BuildContext context) {
    final service = context.read<FirebaseService>();
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: AiTranslatedText('Enviar Aviso ao Docente'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AiTranslatedText('Assunto: ${subject.name}', style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              maxLines: 4,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Escreva a mensagem ou selecione um template...',
                hintStyle: TextStyle(color: Colors.white30),
                filled: true,
                fillColor: Colors.black26,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const AiTranslatedText('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.isEmpty) return;
              await service.sendCoordinatorWarning(
                teacherId: subject.teacherId,
                subjectId: subject.id,
                subjectName: subject.name,
                message: controller.text,
                coordinatorName: coordinatorName,
              );
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Aviso enviado com sucesso!')));
            },
            child: const AiTranslatedText('Enviar'),
          ),
        ],
      ),
    );
  }
}
