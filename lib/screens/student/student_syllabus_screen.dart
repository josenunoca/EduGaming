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
    return StreamBuilder<Subject?>(
      stream: context.read<FirebaseService>().getSubjectStream(subject.id),
      builder: (context, snapshot) {
        final currentSubject = snapshot.data ?? subject;
        final sessions = List<SyllabusSession>.from(currentSubject.sessions);
        sessions.sort((a, b) => a.sessionNumber.compareTo(b.sessionNumber));

        final userId = FirebaseAuth.instance.currentUser?.uid;

        return Column(
          children: [
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF7B61FF),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF7B61FF).withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildDownloadButton(
                      icon: Icons.assignment_outlined,
                      label: 'Download Programa',
                      onTap: () =>
                          PdfService.generateProgramPDF(currentSubject),
                    ),
                    Container(width: 1, height: 24, color: Colors.white24),
                    _buildDownloadButton(
                      icon: Icons.summarize_outlined,
                      label: 'Download Sumários',
                      onTap: () async {
                        final service = context.read<FirebaseService>();
                        final attendances =
                            await service.getAttendanceForSubject(currentSubject.id);
                        await PdfService.generateSummariesPDF(
                            currentSubject, attendances);
                      },
                    ),
                  ],
                ),
              ),
            ),
            if (currentSubject.programDescription != null &&
                currentSubject.programDescription!.isNotEmpty)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
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
                            color: Colors.white70, fontSize: 13, height: 1.5),
                      ),
                    ],
                  ),
                ),
              ),
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
                            context, s, userId, currentSubject);
                      },
                    ),
            ),
          ],
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
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          AiTranslatedText(
            label,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionCard(BuildContext context, SyllabusSession s,
      String? userId, Subject currentSubject) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GlassCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: const Color(0xFF00D1FF).withValues(alpha: 0.1),
                  child: Text(s.sessionNumber.toString(),
                      style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF00D1FF),
                          fontWeight: FontWeight.bold)),
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
                              size: 12, color: Colors.white.withValues(alpha: 0.5)),
                          const SizedBox(width: 4),
                          Text(DateFormat('dd/MM/yyyy').format(s.date),
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.5),
                                  fontSize: 12)),
                          if (s.startTime != null) ...[
                            const SizedBox(width: 8),
                            Icon(Icons.access_time,
                                size: 12, color: Colors.white.withValues(alpha: 0.5)),
                            const SizedBox(width: 4),
                            Text('${s.startTime} - ${s.endTime ?? ""}',
                                style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.5),
                                    fontSize: 12)),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                if (userId != null)
                  FutureBuilder<bool>(
                    future: context
                        .read<FirebaseService>()
                        .hasAlreadyRecordedAttendance(userId, s.id),
                    builder: (context, snapshot) {
                      final present = snapshot.data ?? false;

                      bool hasPassed = false;
                      if (s.endTime != null) {
                        try {
                          final parts = s.endTime!.split(':');
                          final endDateTime = DateTime(
                            s.date.year,
                            s.date.month,
                            s.date.day,
                            int.parse(parts[0]),
                            int.parse(parts[1]),
                          );
                          hasPassed = DateTime.now().isAfter(endDateTime);
                        } catch (_) {
                          hasPassed = DateTime.now().isAfter(DateTime(
                              s.date.year, s.date.month, s.date.day, 23, 59));
                        }
                      } else {
                        hasPassed = DateTime.now().isAfter(DateTime(
                            s.date.year, s.date.month, s.date.day, 23, 59));
                      }

                      if (present) {
                        return Container(
                          width: 12,
                          height: 12,
                          decoration: const BoxDecoration(
                              color: Colors.greenAccent,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.greenAccent, blurRadius: 4)
                              ]),
                        );
                      } else if (hasPassed) {
                        return Container(
                          width: 12,
                          height: 12,
                          decoration: const BoxDecoration(
                              color: Colors.redAccent,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.redAccent, blurRadius: 4)
                              ]),
                        );
                      }
                      return const SizedBox();
                    },
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
