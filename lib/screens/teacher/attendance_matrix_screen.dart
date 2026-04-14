import 'package:flutter/material.dart';
import '../../models/subject_model.dart';
import '../../services/firebase_service.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/ai_translated_text.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../models/user_model.dart';
import '../../widgets/custom_button.dart';
import '../../services/pdf_service.dart';
import '../../models/institution_model.dart';

class AttendanceMatrixScreen extends StatefulWidget {
  final Subject subject;

  const AttendanceMatrixScreen({super.key, required this.subject});

  @override
  State<AttendanceMatrixScreen> createState() => _AttendanceMatrixScreenState();
}

class _AttendanceMatrixScreenState extends State<AttendanceMatrixScreen> {
  bool _isLoading = true;
  UserModel? _currentUser;
  InstitutionModel? _institution;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final service = context.read<FirebaseService>();
    try {
      final user = await service.getUserModel(service.currentUser!.uid);
      final institution = await service.getInstitution(widget.subject.institutionId);

      if (mounted) {
        setState(() {
          _currentUser = user;
          _institution = institution;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar dados fixos: $e')),
        );
      }
    }
  }

  Future<void> _toggleAttendance(Enrollment student, SyllabusSession session, bool isCurrentPresent) async {
    if (_currentUser?.role == UserRole.student) return;

    final service = context.read<FirebaseService>();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: AiTranslatedText(isCurrentPresent ? 'Remover Presença' : 'Marcar Presença Manual'),
        content: AiTranslatedText(
          isCurrentPresent
              ? 'Deseja remover a presença de ${student.studentName} na sessão ${session.sessionNumber}?'
              : 'Deseja marcar manualmente a presença de ${student.studentName} na sessão ${session.sessionNumber}?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const AiTranslatedText('Cancelar')),
          CustomButton(
            onPressed: () => Navigator.pop(context, true),
            label: isCurrentPresent ? 'Remover' : 'Confirmar',
            variant: isCurrentPresent ? CustomButtonVariant.danger : CustomButtonVariant.primary,
            height: 32,
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (isCurrentPresent) {
        await service.deleteAttendanceBySession(student.userId, session.id);
      } else {
        final att = Attendance(
          id: const Uuid().v4(),
          userId: student.userId,
          userName: student.studentName,
          subjectId: widget.subject.id,
          sessionId: session.id,
          timestamp: DateTime.now(),
          isManualEntry: true,
          registeredByUserId: _currentUser?.id,
        );
        await service.saveAttendance(att);
      }
      // No need for _loadData() here as the stream will update automatically
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = context.read<FirebaseService>();

    return StreamBuilder<Subject?>(
      stream: service.getSubjectStream(widget.subject.id),
      initialData: widget.subject,
      builder: (context, subjectSnapshot) {
        final currentSubject = subjectSnapshot.data ?? widget.subject;
        final finalizedSessions = currentSubject.sessions.where((s) => s.isFinalized).toList()
          ..sort((a, b) => a.sessionNumber.compareTo(b.sessionNumber));

        return StreamBuilder<List<Enrollment>>(
          stream: _currentUser?.role == UserRole.student
              ? service.getEnrollmentsForSubjectByUser(currentSubject.id, _currentUser!.id)
              : service.getEnrollmentsForSubject(currentSubject.id),
          builder: (context, enrollmentSnapshot) {
            final students = (enrollmentSnapshot.data ?? [])
                .where((e) => e.status == 'accepted')
                .toList()
              ..sort((a, b) => a.studentName.compareTo(b.studentName));

            return StreamBuilder<List<Attendance>>(
              stream: service.getAttendanceStreamForSubject(currentSubject.id),
              builder: (context, attendanceSnapshot) {
                final allAttendances = attendanceSnapshot.data ?? [];

                return Scaffold(
                  extendBodyBehindAppBar: true,
                  appBar: AppBar(
                    title: const AiTranslatedText('Matrix de Presenças'),
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    actions: [
                      if (_currentUser?.role == UserRole.teacher && _currentUser != null)
                        IconButton(
                          icon: const Icon(Icons.picture_as_pdf),
                          onPressed: () => PdfService.generateAttendanceMatrixPDF(
                            subject: currentSubject,
                            students: students,
                            attendances: allAttendances,
                            finalizedSessions: finalizedSessions,
                            teacher: _currentUser!,
                            institution: _institution,
                          ),
                          tooltip: 'Exportar PDF',
                        ),
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        onPressed: () {
                           setState(() => _isLoading = true);
                           _loadData();
                        },
                        tooltip: 'Recarregar Dados Fixos',
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
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : SafeArea(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  GlassCard(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(Icons.info_outline, color: Color(0xFF00D1FF)),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: AiTranslatedText(
                                                '${currentSubject.name} - ${currentSubject.academicYear}',
                                                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (currentSubject.attendanceControlEnabled) ...[
                                          const SizedBox(height: 8),
                                          Text(
                                            'Controlo de Faltas Ativo: Mínimo ${currentSubject.requiredAttendancePercentage}%',
                                            style: const TextStyle(color: Colors.orangeAccent, fontSize: 12),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  Expanded(
                                    child: GlassCard(
                                      padding: EdgeInsets.zero,
                                      child: finalizedSessions.isEmpty
                                          ? const Center(
                                              child: AiTranslatedText(
                                                'Nenhuma sessão finalizada para exibir presenças.',
                                                style: TextStyle(color: Colors.white70),
                                              ),
                                            )
                                          : SingleChildScrollView(
                                              scrollDirection: Axis.vertical,
                                              child: SingleChildScrollView(
                                                scrollDirection: Axis.horizontal,
                                                child: DataTable(
                                                  columnSpacing: 20,
                                                  headingRowColor: WidgetStateProperty.all(Colors.white.withOpacity(0.1)),
                                                  columns: [
                                                    const DataColumn(
                                                      label: AiTranslatedText('Estudante',
                                                          style: TextStyle(color: Color(0xFF00D1FF), fontWeight: FontWeight.bold)),
                                                    ),
                                                    ...finalizedSessions.map((s) => DataColumn(
                                                          label: Tooltip(
                                                            message: s.topic,
                                                            child: Column(
                                                              mainAxisAlignment: MainAxisAlignment.center,
                                                              children: [
                                                                Text('S${s.sessionNumber}',
                                                                    style: const TextStyle(color: Colors.white, fontSize: 12)),
                                                                Text(DateFormat('dd/MM').format(s.date),
                                                                    style: const TextStyle(color: Colors.white54, fontSize: 10)),
                                                              ],
                                                            ),
                                                          ),
                                                        )),
                                                    const DataColumn(
                                                      label: AiTranslatedText('Status',
                                                          style: TextStyle(color: Color(0xFF00D1FF), fontWeight: FontWeight.bold)),
                                                    ),
                                                  ],
                                                  rows: students.map((student) {
                                                    int studentTotal = 0;
                                                    for (var s in finalizedSessions) {
                                                      if (allAttendances.any((a) => a.userId == student.userId && a.sessionId == s.id)) {
                                                        studentTotal++;
                                                      }
                                                    }

                                                    final percentage = finalizedSessions.isEmpty
                                                      ? 100.0
                                                      : (studentTotal / finalizedSessions.length) * 100;

                                                    return DataRow(
                                                      cells: [
                                                        DataCell(
                                                          SizedBox(
                                                            width: 120,
                                                            child: Text(student.studentName,
                                                                style: const TextStyle(color: Colors.white, fontSize: 13),
                                                                overflow: TextOverflow.ellipsis),
                                                          ),
                                                        ),
                                                        ...finalizedSessions.map((session) {
                                                          final isPresent = allAttendances.any(
                                                              (a) => a.userId == student.userId && a.sessionId == session.id);
                                                          return DataCell(
                                                            Center(
                                                              child: Icon(
                                                                isPresent ? Icons.check_circle : Icons.cancel,
                                                                color: isPresent ? Colors.greenAccent : Colors.white10,
                                                                size: 20,
                                                              ),
                                                            ),
                                                            onTap: () => _toggleAttendance(student, session, isPresent),
                                                          );
                                                        }),
                                                        DataCell(
                                                          Row(
                                                            children: [
                                                              Text(
                                                                '${percentage.toStringAsFixed(0)}%',
                                                                style: TextStyle(
                                                                  color: currentSubject.attendanceControlEnabled &&
                                                                          percentage < currentSubject.requiredAttendancePercentage
                                                                      ? Colors.redAccent
                                                                      : Colors.greenAccent,
                                                                  fontWeight: FontWeight.bold,
                                                                  fontSize: 12,
                                                                ),
                                                              ),
                                                              const SizedBox(width: 4),
                                                              Text(
                                                                '($studentTotal/${finalizedSessions.length})',
                                                                style: const TextStyle(color: Colors.white38, fontSize: 10),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ],
                                                    );
                                                  }).toList(),
                                                ),
                                              ),
                                            ),
                                    ),
                                  ),
                                ],
                              ),
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
}
