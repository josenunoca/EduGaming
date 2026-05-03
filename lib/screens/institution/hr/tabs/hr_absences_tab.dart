import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../models/institution_model.dart';
import '../../../../models/hr/hr_absence_model.dart';
import '../../../../services/firebase_service.dart';
import '../../../../widgets/ai_translated_text.dart';
import '../../../../widgets/glass_card.dart';

class HRAbsencesTab extends StatelessWidget {
  final InstitutionModel institution;

  const HRAbsencesTab({super.key, required this.institution});

  @override
  Widget build(BuildContext context) {
    final service = context.read<FirebaseService>();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: Row(
            children: [
              const AiTranslatedText(
                'Gestão de Férias e Ausências',
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.add),
                label: const AiTranslatedText('Registar Ausência'),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00FF85), foregroundColor: Colors.black),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<List<HRAbsence>>(
            stream: service.getHRAbsences(institution.id),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              final absences = snapshot.data ?? [];
              
              if (absences.isEmpty) {
                return const Center(child: AiTranslatedText('Sem registos de ausência.', style: TextStyle(color: Colors.white24)));
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: absences.length,
                itemBuilder: (context, index) => _AbsenceCard(absence: absences[index]),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _AbsenceCard extends StatelessWidget {
  final HRAbsence absence;

  const _AbsenceCard({required this.absence});

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    switch (absence.status) {
      case 'approved': statusColor = Colors.green; break;
      case 'rejected': statusColor = Colors.red; break;
      default: statusColor = Colors.orange;
    }

    return GlassCard(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(_getIcon(absence.type), color: const Color(0xFF00D1FF), size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AiTranslatedText(
                    _getTypeName(absence.type),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  Text(
                    '${DateFormat('dd/MM').format(absence.startDate)} - ${DateFormat('dd/MM').format(absence.endDate)}',
                    style: const TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: statusColor.withValues(alpha: 0.3)),
              ),
              child: AiTranslatedText(
                absence.status.toUpperCase(),
                style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIcon(AbsenceType type) {
    switch (type) {
      case AbsenceType.vacation: return Icons.beach_access;
      case AbsenceType.sickLeave: return Icons.medical_services_outlined;
      case AbsenceType.justified: return Icons.assignment_turned_in_outlined;
      default: return Icons.error_outline;
    }
  }

  String _getTypeName(AbsenceType type) {
    switch (type) {
      case AbsenceType.vacation: return 'Férias';
      case AbsenceType.sickLeave: return 'Doença / Baixa';
      case AbsenceType.justified: return 'Falta Justificada';
      default: return 'Falta Injustificada';
    }
  }
}
