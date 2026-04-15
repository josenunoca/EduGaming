import 'package:flutter/material.dart';
import '../../models/subject_model.dart';
import '../../widgets/ai_translated_text.dart';
import '../../widgets/glass_card.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/pdf_service.dart';
import '../../services/firebase_service.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StudentSyllabusScreen extends StatelessWidget {
  final Subject subject;
  const StudentSyllabusScreen({super.key, required this.subject});

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    return StreamBuilder<Subject?>(
      stream: context.read<FirebaseService>().getSubjectStream(subject.id),
      builder: (context, snapshot) {
        final currentSubject = snapshot.data ?? subject;
        final sessions = List<SyllabusSession>.from(currentSubject.sessions);
        sessions.sort((a, b) => a.sessionNumber.compareTo(b.sessionNumber));

        return StreamBuilder<List<Attendance>>(
          stream: context
              .read<FirebaseService>()
              .getAttendanceStreamForSubject(currentSubject.id),
          builder: (context, attendanceSnapshot) {
            final attendances = attendanceSnapshot.data ?? [];
            final studentAttendances =
                attendances.where((a) => a.userId == userId).toList();
            final finalizedSessions =
                sessions.where((s) => s.isFinalized).toList();

            double attendancePercentage = 100.0;
            if (finalizedSessions.isNotEmpty) {
              int presentCount = 0;
              for (var s in finalizedSessions) {
                if (studentAttendances.any((a) => a.sessionId == s.id)) {
                  presentCount++;
                }
              }
              attendancePercentage =
                  (presentCount / finalizedSessions.length) * 100;
            }

            return Column(
              children: [
                // Header with Attendance Summary and Download Buttons
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 8.0),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF7B61FF), Color(0xFF00D1FF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF7B61FF).withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const AiTranslatedText(
                                  'A Tua Assiduidade',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  '${attendancePercentage.toStringAsFixed(1)}%',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            if (currentSubject.attendanceControlEnabled)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  'Mínimo: ${currentSubject.requiredAttendancePercentage}%',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Divider(color: Colors.white24, height: 1),
                        const SizedBox(height: 12),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildDownloadButton(
                                icon: Icons.assignment_outlined,
                                label: 'Programa',
                                onTap: () => PdfService.generateProgramPDF(
                                    currentSubject),
                              ),
                              const SizedBox(width: 16),
                              _buildDownloadButton(
                                icon: Icons.summarize_outlined,
                                label: 'Sumários',
                                onTap: () async {
                                  await PdfService.generateSummariesPDF(
                                      currentSubject, attendances,
                                      includeAttendance: false);
                                },
                              ),
                              const SizedBox(width: 16),
                              _buildDownloadButton(
                                icon: Icons.playlist_add_check,
                                label: 'Minhas Presenças',
                                onTap: () async {
                                  final service =
                                      context.read<FirebaseService>();
                                  final user =
                                      await service.getUserData(userId ?? '');
                                  final institution =
                                      await service.getInstitution(
                                          currentSubject.institutionId);
                                  await PdfService.generateStudentAttendancePDF(
                                    subject: currentSubject,
                                    attendances: studentAttendances,
                                    finalizedSessions: finalizedSessions,
                                    studentName: user?.name ?? 'Estudante',
                                    studentId: userId ?? '',
                                    institution: institution,
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

                // Program Description
                if (currentSubject.programDescription != null &&
                    currentSubject.programDescription!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 8.0),
                    child: GlassCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const AiTranslatedText(
                            'Programa da Disciplina',
                            style: TextStyle(
                                color: Color(0xFF00D1FF),
                                fontSize: 14,
                                fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            currentSubject.programDescription!,
                            style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                                height: 1.5),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Session List
                Expanded(
                  child: sessions.isEmpty
                      ? const Center(
                          child: AiTranslatedText(
                            'Ainda não existem sessões definidas.',
                            style: TextStyle(color: Colors.white54),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: sessions.length,
                          itemBuilder: (context, index) {
                            final s = sessions[index];
                            return _buildSessionCard(
                                context, s, currentSubject, studentAttendances);
                          },
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildDownloadButton(
      {required IconData icon,
      required String label,
      required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(height: 4),
          AiTranslatedText(
            label,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionCard(BuildContext context, SyllabusSession s,
      Subject currentSubject, List<Attendance> studentAttendances) {
    final isPresent = studentAttendances.any((a) => a.sessionId == s.id);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GlassCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: const Color(0xFF00D1FF).withOpacity(0.1),
                      child: Text(s.sessionNumber.toString(),
                          style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF00D1FF),
                              fontWeight: FontWeight.bold)),
                    ),
                    if (s.isFinalized)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: isPresent ? Colors.green : Colors.red,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.topic,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.calendar_today,
                              size: 12, color: Colors.white.withOpacity(0.5)),
                          const SizedBox(width: 4),
                          Text(DateFormat('dd/MM/yyyy').format(s.date),
                              style: TextStyle(
                                  color: Colors.white.withOpacity(0.5),
                                  fontSize: 12)),
                          if (s.startTime != null) ...[
                            const SizedBox(width: 8),
                            Icon(Icons.access_time,
                                size: 12, color: Colors.white.withOpacity(0.5)),
                            const SizedBox(width: 4),
                            Text('${s.startTime} - ${s.endTime ?? ""}',
                                style: TextStyle(
                                    color: Colors.white.withOpacity(0.5),
                                    fontSize: 12)),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                if (s.isFinalized)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: (isPresent ? Colors.green : Colors.red)
                          .withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      isPresent ? 'Presente' : 'Falta',
                      style: TextStyle(
                        color: isPresent ? Colors.green : Colors.red,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            if (s.finalSummary != null) ...[
              const Divider(height: 32, color: Colors.white10),
              const AiTranslatedText('SUMÁRIO REALIZADO:',
                  style: TextStyle(
                      color: Color(0xFF00D1FF),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2)),
              const SizedBox(height: 8),
              Text(s.finalSummary!,
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 14, height: 1.5)),
              if (s.materialIds.isNotEmpty) ...[
                const SizedBox(height: 12),
                const AiTranslatedText('MATERIAIS DE APOIO:',
                    style: TextStyle(
                        color: Colors.white54,
                        fontSize: 9,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: s.materialIds.map((id) {
                    final content = currentSubject.contents.firstWhere(
                      (c) => c.id == id,
                      orElse: () => SubjectContent(
                          id: '', name: 'Material', url: '', type: ''),
                    );
                    if (content.url.isEmpty) return const SizedBox();
                    return InkWell(
                      onTap: () async {
                        final uri = Uri.tryParse(content.url);
                        if (uri != null && await canLaunchUrl(uri)) {
                          await launchUrl(uri,
                              mode: LaunchMode.externalApplication);
                        }
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.link,
                              size: 14, color: Color(0xFF00D1FF)),
                          const SizedBox(width: 4),
                          Text(content.name,
                              style: const TextStyle(
                                  color: Color(0xFF00D1FF),
                                  fontSize: 11,
                                  decoration: TextDecoration.underline)),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
            const SizedBox(height: 16),
            const AiTranslatedText('BIBLIOGRAFIA:',
                style: TextStyle(
                    color: Colors.white38,
                    fontSize: 9,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(s.bibliography,
                style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                    fontStyle: FontStyle.italic)),
          ],
        ),
      ),
    );
  }
}
