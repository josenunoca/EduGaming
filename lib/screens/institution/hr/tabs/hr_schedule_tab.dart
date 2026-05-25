import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../../../models/institution_model.dart';
import '../../../../models/user_model.dart';
import '../../../../models/hr/hr_schedule_model.dart';
import '../../../../models/hr/hr_absence_model.dart';
import '../../../../services/firebase_service.dart';
import '../../../../widgets/ai_translated_text.dart';
import '../widgets/hr_schedule_planner.dart';

class HRScheduleTab extends StatefulWidget {
  final InstitutionModel institution;

  const HRScheduleTab({super.key, required this.institution});

  @override
  State<HRScheduleTab> createState() => _HRScheduleTabState();
}

class _HRScheduleTabState extends State<HRScheduleTab> {
  @override
  Widget build(BuildContext context) {
    final service = context.read<FirebaseService>();

    return StreamBuilder<List<HRShift>>(
      stream: service.getHRShifts(widget.institution.id),
      builder: (context, shiftSnapshot) {
        return FutureBuilder<List<UserModel>>(
          future: service.getAllInstitutionMembers(widget.institution.id),
          builder: (context, empSnapshot) {
            if (empSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final shifts = shiftSnapshot.data ?? [
              HRShift(id: '1', institutionId: widget.institution.id, name: 'Turno Manhã', type: ShiftType.fixed, startTime: '08:00', endTime: '13:00', color: '#00D1FF'),
              HRShift(id: '2', institutionId: widget.institution.id, name: 'Turno Tarde', type: ShiftType.fixed, startTime: '13:00', endTime: '18:00', color: '#00FF85'),
              HRShift(id: '3', institutionId: widget.institution.id, name: 'Dia Completo', type: ShiftType.fixed, startTime: '09:00', endTime: '18:00', color: '#7B61FF'),
            ];

            final employees = empSnapshot.data ?? [];

            return StreamBuilder<List<HRAbsence>>(
              stream: service.getHRAbsences(widget.institution.id),
              builder: (context, absencesSnapshot) {
                final absences = absencesSnapshot.data ?? [];

                return StreamBuilder<List<HRScheduleEntry>>(
                  stream: service.getHRScheduleEntries(
                    widget.institution.id,
                    start: DateTime.now().subtract(const Duration(days: 30)),
                    end: DateTime.now().add(const Duration(days: 60)),
                  ),
                  builder: (context, entriesSnapshot) {
                    final entries = entriesSnapshot.data ?? [];

                    return StreamBuilder<List<Map<String, dynamic>>>(
                      stream: service.getHRClosedDays(widget.institution.id),
                      builder: (context, closedDaysSnapshot) {
                        final closedDays = closedDaysSnapshot.data ?? [];

                        return HRSchedulePlanner(
                          institution: widget.institution,
                          employees: employees,
                          availableShifts: shifts,
                          entries: entries,
                          closedDays: closedDays,
                          absences: absences,
                          onAssign: (newEntries) async {
                            for (var i = 0; i < newEntries.length; i++) {
                              if (newEntries[i].id.isEmpty) {
                                newEntries[i] = HRScheduleEntry(
                                  id: const Uuid().v4(),
                                  employeeId: newEntries[i].employeeId,
                                  institutionId: newEntries[i].institutionId,
                                  date: newEntries[i].date,
                                  shiftId: newEntries[i].shiftId,
                                  customStartTime: newEntries[i].customStartTime,
                                  customEndTime: newEntries[i].customEndTime,
                                  mealStartTime: newEntries[i].mealStartTime,
                                  mealEndTime: newEntries[i].mealEndTime,
                                  isOffDay: newEntries[i].isOffDay,
                                  status: newEntries[i].status,
                                );
                              }
                            }
                            await service.saveHRScheduleEntries(widget.institution.id, newEntries);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: AiTranslatedText('Escala atualizada com sucesso!')),
                              );
                            }
                          },
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}
