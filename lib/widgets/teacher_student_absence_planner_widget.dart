import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/student_absence_model.dart';
import '../models/user_model.dart';
import '../services/firebase_service.dart';
import 'glass_card.dart';
import 'ai_translated_text.dart';

class TeacherStudentAbsencePlannerWidget extends StatefulWidget {
  final UserModel teacher;

  const TeacherStudentAbsencePlannerWidget({
    super.key,
    required this.teacher,
  });

  @override
  State<TeacherStudentAbsencePlannerWidget> createState() =>
      _TeacherStudentAbsencePlannerWidgetState();
}

class _TeacherStudentAbsencePlannerWidgetState
    extends State<TeacherStudentAbsencePlannerWidget>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime date) {
    try {
      return DateFormat('dd/MM/yyyy').format(date);
    } catch (_) {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  Color _getTypeColor(StudentAbsenceType type) {
    switch (type) {
      case StudentAbsenceType.sickLeave:
        return Colors.orangeAccent;
      case StudentAbsenceType.vacation:
        return Colors.blueAccent;
      case StudentAbsenceType.medicalAppointment:
        return Colors.purpleAccent;
      case StudentAbsenceType.familyReason:
        return Colors.tealAccent;
      case StudentAbsenceType.other:
        return Colors.grey;
    }
  }

  String _getTypeLabel(StudentAbsenceType type) {
    switch (type) {
      case StudentAbsenceType.sickLeave:
        return 'Doença / Baixa';
      case StudentAbsenceType.vacation:
        return 'Férias em Família';
      case StudentAbsenceType.medicalAppointment:
        return 'Consulta Médica';
      case StudentAbsenceType.familyReason:
        return 'Motivo Familiar';
      case StudentAbsenceType.other:
        return 'Outro Motivo';
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<FirebaseService>();
    final institutionId = widget.teacher.institutionId ?? '';

    return StreamBuilder<List<StudentAbsence>>(
      stream: service.getStudentAbsences(institutionId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final absences = snapshot.data ?? [];
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final nextWeekEnd = today.add(const Duration(days: 7));

        // Filter absences for TODAY
        final todayAbsences = absences.where((a) => a.isDateAbsent(today)).toList();

        // Filter absences for UPCOMING NEXT WEEK
        final nextWeekAbsences = absences.where((a) {
          final start = DateTime(a.startDate.year, a.startDate.month, a.startDate.day);
          final end = DateTime(a.endDate.year, a.endDate.month, a.endDate.day);
          return (start.isAfter(today) && start.isBefore(nextWeekEnd.add(const Duration(days: 1)))) ||
              (end.isAfter(today) && end.isBefore(nextWeekEnd.add(const Duration(days: 1))));
        }).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(Icons.event_busy, color: Color(0xFF00D1FF)),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Alunos Ausentes (Planeamento Semanal)',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7B61FF).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${todayAbsences.length} Hoje | ${nextWeekAbsences.length} Próx. Semana',
                      style: const TextStyle(
                          color: Color(0xFF00D1FF),
                          fontSize: 12,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Tabs Header
            TabBar(
              controller: _tabController,
              indicatorColor: const Color(0xFF00D1FF),
              labelColor: const Color(0xFF00D1FF),
              unselectedLabelColor: Colors.white60,
              tabs: [
                Tab(text: 'Hoje (${todayAbsences.length})'),
                Tab(text: 'Próxima Semana (${nextWeekAbsences.length})'),
              ],
            ),
            const SizedBox(height: 12),

            // Tab View Body
            SizedBox(
              height: 320,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildAbsenceList(todayAbsences, 'Nenhum aluno ausente registado para hoje.'),
                  _buildAbsenceList(nextWeekAbsences, 'Nenhuma ausência agendada para a próxima semana.'),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAbsenceList(List<StudentAbsence> items, String emptyMessage) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle_outline, size: 48, color: Colors.white24),
            const SizedBox(height: 12),
            Text(
              emptyMessage,
              style: const TextStyle(color: Colors.white54, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) {
        final absence = items[index];
        final typeColor = _getTypeColor(absence.type);

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: GlassCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: typeColor.withValues(alpha: 0.2),
                      child: Icon(Icons.person_off, color: typeColor, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            absence.studentName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Encarregado(a): ${absence.parentName}',
                            style: const TextStyle(
                                color: Colors.white60, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: typeColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: typeColor.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        _getTypeLabel(absence.type),
                        style: TextStyle(
                            color: typeColor,
                            fontSize: 11,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.date_range, color: Colors.white38, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      'Período: ${_formatDate(absence.startDate)} até ${_formatDate(absence.endDate)}',
                      style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                if (absence.description != null &&
                    absence.description!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Obs: ${absence.description}',
                    style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                        fontStyle: FontStyle.italic),
                  ),
                ],
                if (absence.proofUrl != null &&
                    absence.proofUrl!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () => launchUrl(Uri.parse(absence.proofUrl!)),
                    child: const Row(
                      children: [
                        Icon(Icons.attachment, color: Color(0xFF00D1FF), size: 14),
                        SizedBox(width: 4),
                        Text(
                          'Ver Comprovativo / Baixa Anexada',
                          style: TextStyle(
                            color: Color(0xFF00D1FF),
                            fontSize: 12,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
