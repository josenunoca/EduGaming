import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../../../models/institution_model.dart';
import '../../../../models/user_model.dart';
import '../../../../models/hr/hr_schedule_model.dart';
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

            return HRSchedulePlanner(
              employees: employees,
              availableShifts: shifts,
              onAssign: (empIds, dates, shift) async {
                final entries = <HRScheduleEntry>[];
                for (var empId in empIds) {
                  for (var date in dates) {
                    entries.add(HRScheduleEntry(
                      id: const Uuid().v4(),
                      employeeId: empId,
                      institutionId: widget.institution.id,
                      date: date,
                      shiftId: shift.id,
                      customStartTime: shift.startTime,
                      customEndTime: shift.endTime,
                      status: 'planned'
                    ));
                  }
                }
                await service.saveHRScheduleEntries(widget.institution.id, entries);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: AiTranslatedText('Horários atualizados com sucesso!')),
                  );
                }
              },
            );
          },
        );
      },
    );
  }
}
