import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../models/institution_model.dart';
import '../../../../models/user_model.dart';
import '../../../../models/hr/hr_absence_model.dart';
import '../../../../models/hr/hr_attendance_model.dart';
import '../../../../services/firebase_service.dart';
import '../../../../widgets/ai_translated_text.dart';
import '../../../../widgets/glass_card.dart';

class HRDashboardTab extends StatelessWidget {
  final InstitutionModel institution;
  final Function(int)? onTabRequested;

  const HRDashboardTab({
    super.key,
    required this.institution,
    this.onTabRequested,
  });

  @override
  Widget build(BuildContext context) {
    final service = context.read<FirebaseService>();

    return StreamBuilder<List<UserModel>>(
      stream: service.streamInstitutionMembers(institution.id),
      builder: (context, membersSnapshot) {
        final members = membersSnapshot.data ?? [];
        final activeEmployees = members.where((m) =>
            m.role != UserRole.student &&
            m.role != UserRole.parent &&
            !m.isSuspended).toList();
        final activeCount = activeEmployees.length;

        return StreamBuilder<List<HRAttendanceRecord>>(
          stream: service.getHRAttendance(institution.id, date: DateTime.now()),
          builder: (context, attendanceSnapshot) {
            final attendance = attendanceSnapshot.data ?? [];
            final checkedInCount = attendance
                .where((r) => r.type == AttendanceType.checkIn)
                .map((r) => r.employeeId)
                .toSet()
                .length;

            final attendancePct = activeCount > 0
                ? (checkedInCount / activeCount * 100).round()
                : 0;

            return StreamBuilder<List<HRAbsence>>(
              stream: service.getHRAbsences(institution.id),
              builder: (context, absencesSnapshot) {
                final absences = absencesSnapshot.data ?? [];
                
                final now = DateTime.now();
                final today = DateTime(now.year, now.month, now.day);

                // Count active approved vacations today
                final activeVacationsCount = absences.where((a) {
                  if (a.type != AbsenceType.vacation || a.status != 'approved') return false;
                  final start = DateTime(a.startDate.year, a.startDate.month, a.startDate.day);
                  final end = DateTime(a.endDate.year, a.endDate.month, a.endDate.day);
                  return (today.isAtSameMomentAs(start) || today.isAfter(start)) &&
                         (today.isAtSameMomentAs(end) || today.isBefore(end));
                }).length;

                // Pending absences
                final pendingVacationsCount = absences
                    .where((a) => a.type == AbsenceType.vacation && a.status == 'pending')
                    .length;
                final pendingJustificationsCount = absences
                    .where((a) => a.type != AbsenceType.vacation && a.status == 'pending')
                    .length;

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const AiTranslatedText(
                        'Visão Geral do Capital Humano',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => onTabRequested?.call(1), // Funcionários
                              borderRadius: BorderRadius.circular(15),
                              child: _StatCard(
                                title: 'Colaboradores Ativos',
                                value: '$activeCount',
                                icon: Icons.people,
                                color: const Color(0xFF00D1FF),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: InkWell(
                              onTap: () => onTabRequested?.call(3), // Assiduidade
                              borderRadius: BorderRadius.circular(15),
                              child: _StatCard(
                                title: 'Assiduidade Hoje',
                                value: '$attendancePct%',
                                icon: Icons.check_circle_outline,
                                color: const Color(0xFF00FF85),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: InkWell(
                              onTap: () => onTabRequested?.call(4), // Férias/Faltas
                              borderRadius: BorderRadius.circular(15),
                              child: _StatCard(
                                title: 'Férias Ativas',
                                value: '$activeVacationsCount',
                                icon: Icons.beach_access,
                                color: const Color(0xFFFFB800),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      const AiTranslatedText(
                        'Alertas e Pendências',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (pendingVacationsCount > 0)
                        InkWell(
                          onTap: () => onTabRequested?.call(4), // Férias/Faltas
                          child: _AlertItem(
                            title: '$pendingVacationsCount Pedidos de Férias Pendentes',
                            subtitle: 'Aguardando validação da direção de recursos humanos.',
                            icon: Icons.notifications_active,
                            color: Colors.orange,
                          ),
                        ),
                      if (pendingJustificationsCount > 0)
                        InkWell(
                          onTap: () => onTabRequested?.call(4), // Férias/Faltas
                          child: _AlertItem(
                            title: '$pendingJustificationsCount Justificações de Falta Pendentes',
                            subtitle: 'Necessita verificação e homologação dos comprovativos.',
                            icon: Icons.assignment_late,
                            color: Colors.blue,
                          ),
                        ),
                      if (pendingVacationsCount == 0 && pendingJustificationsCount == 0)
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.02),
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: const Center(
                            child: Column(
                              children: [
                                Icon(Icons.check_circle, color: Color(0xFF00FF85), size: 40),
                                SizedBox(height: 12),
                                AiTranslatedText(
                                  'Excelente! Sem pendências de recursos humanos no momento.',
                                  style: TextStyle(color: Colors.white70, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
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

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 16),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            AiTranslatedText(
              title,
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlertItem extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _AlertItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: Colors.white24),
        ],
      ),
    );
  }
}
