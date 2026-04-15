import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/firebase_service.dart';
import '../../models/facility_model.dart';
import '../../models/user_model.dart';
import '../../models/institution_model.dart';
import '../../models/subject_model.dart';
import '../../widgets/ai_translated_text.dart';
import 'package:intl/intl.dart';

class TimetableUserScreen extends StatefulWidget {
  final UserModel user;
  const TimetableUserScreen({super.key, required this.user});

  @override
  State<TimetableUserScreen> createState() => _TimetableUserScreenState();
}

class _TimetableUserScreenState extends State<TimetableUserScreen> {
  DateTime _referenceDate = DateTime.now();
  String _selectedAcademicYear = '2024/2025';

  @override
  Widget build(BuildContext context) {
    final service = context.watch<FirebaseService>();

    return StreamBuilder<InstitutionModel?>(
      stream: widget.user.institutionId != null
          ? service.getInstitutionStream(widget.user.institutionId!)
          : Stream.value(null),
      builder: (context, instSnap) {
        final institution = instSnap.data;
        if (institution == null)
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));

        return StreamBuilder<List<TimetableEntry>>(
          stream: service.getTimetableEntries(institution.id,
              academicYear: _selectedAcademicYear),
          builder: (context, entrySnap) {
            final allEntries = entrySnap.data ?? [];

            // Filter by Reference Date
            final dateFilteredEntries = allEntries.where((e) {
              if (e.startDate == null || e.endDate == null) return true;
              return !_referenceDate.isBefore(e.startDate!) &&
                  !_referenceDate.isAfter(e.endDate!);
            }).toList();

            return StreamBuilder<List<Subject>>(
              stream: service.getSubjectsByInstitution(institution.id),
              builder: (context, subSnap) {
                final subjects = subSnap.data ?? [];

                return StreamBuilder<List<Classroom>>(
                  stream: service.getClassrooms(institution.id),
                  builder: (context, roomSnap) {
                    final classrooms = roomSnap.data ?? [];

                    return StreamBuilder<List<UserModel>>(
                      stream: service.getTeachersByInstitution(institution.id),
                      builder: (context, teacherSnap) {
                        final teachers = teacherSnap.data ?? [];

                        if (widget.user.role == 'student') {
                          return StreamBuilder<List<Enrollment>>(
                            stream: service
                                .getEnrollmentsForStudent(widget.user.id),
                            builder: (context, enrollSnap) {
                              final acceptedSubjectIds = (enrollSnap.data ?? [])
                                  .where((en) => en.status == 'accepted')
                                  .map((en) => en.subjectId)
                                  .toSet();

                              final filteredEntries =
                                  dateFilteredEntries.where((e) {
                                return e.isBreak ||
                                    e.isClosed ||
                                    acceptedSubjectIds.contains(e.subjectId);
                              }).toList();

                              return _buildScaffold(
                                  institution,
                                  filteredEntries,
                                  subjects,
                                  teachers,
                                  classrooms);
                            },
                          );
                        } else if (widget.user.role == 'teacher') {
                          final filteredEntries =
                              dateFilteredEntries.where((e) {
                            return e.isBreak ||
                                e.isClosed ||
                                e.teacherId == widget.user.id;
                          }).toList();
                          return _buildScaffold(institution, filteredEntries,
                              subjects, teachers, classrooms);
                        } else {
                          return _buildScaffold(
                              institution,
                              dateFilteredEntries,
                              subjects,
                              teachers,
                              classrooms);
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
  }

  Widget _buildScaffold(
    InstitutionModel institution,
    List<TimetableEntry> entries,
    List<Subject> subjects,
    List<UserModel> teachers,
    List<Classroom> classrooms,
  ) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const AiTranslatedText('O Meu Horário'),
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _referenceDate,
                firstDate: DateTime(2023),
                lastDate: DateTime(2030),
              );
              if (picked != null) setState(() => _referenceDate = picked);
            },
            tooltip: 'Data de Referência',
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: DropdownButton<String>(
              value: _selectedAcademicYear,
              dropdownColor: const Color(0xFF1E293B),
              style: const TextStyle(color: Colors.white, fontSize: 12),
              underline: const SizedBox(),
              items: ['2023/2024', '2024/2025', '2025/2026']
                  .map((y) => DropdownMenuItem(value: y, child: Text(y)))
                  .toList(),
              onChanged: (val) => setState(
                  () => _selectedAcademicYear = val ?? _selectedAcademicYear),
            ),
          ),
        ],
      ),
      body: _buildWeeklyGrid(
          institution, entries, subjects, teachers, classrooms),
    );
  }

  Widget _buildWeeklyGrid(
    InstitutionModel institution,
    List<TimetableEntry> entries,
    List<Subject> subjects,
    List<UserModel> teachers,
    List<Classroom> classrooms,
  ) {
    final startTime = institution.scheduleStartTime ?? '08:00';
    final endTime = institution.scheduleEndTime ?? '18:00';
    final startHour = int.parse(startTime.split(':')[0]);
    final endHour = int.parse(endTime.split(':')[0]);

    final days = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb'];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: AiTranslatedText(
            'Semana de ${DateFormat('dd/MM/yyyy').format(_referenceDate)}',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ),
        // Header
        Row(
          children: [
            const SizedBox(width: 60),
            ...days.map((d) => Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    alignment: Alignment.center,
                    child: AiTranslatedText(d,
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                )),
          ],
        ),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: List.generate((endHour - startHour + 1) * 2, (index) {
                final hour = startHour + (index ~/ 2);
                final minute = (index % 2) * 30;
                final timeStr =
                    '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 60,
                      constraints: const BoxConstraints(minHeight: 50),
                      alignment: Alignment.center,
                      child: Text(timeStr,
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 10)),
                    ),
                    ...List.generate(6, (dayIndex) {
                      final slotEntries = entries
                          .where((e) =>
                              e.weekday == dayIndex + 1 &&
                              _isTimeInSlot(e, timeStr))
                          .toList();

                      return Expanded(
                        child: Container(
                          constraints: const BoxConstraints(minHeight: 50),
                          margin: const EdgeInsets.all(1),
                          child: Column(
                            children: slotEntries
                                .map((e) => _buildEntryWidget(
                                    e, subjects, teachers, classrooms))
                                .toList(),
                          ),
                        ),
                      );
                    }),
                  ],
                );
              }),
            ),
          ),
        ),
      ],
    );
  }

  bool _isTimeInSlot(TimetableEntry entry, String slotTime) {
    final slot = _timeToMinutes(slotTime);
    final start = _timeToMinutes(entry.startTime);
    final end = start + entry.durationMinutes;
    return slot >= start && slot < end;
  }

  int _timeToMinutes(String time) {
    final parts = time.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }

  Widget _buildEntryWidget(
    TimetableEntry entry,
    List<Subject> subjects,
    List<UserModel> teachers,
    List<Classroom> classrooms,
  ) {
    final subject = subjects.firstWhere(
      (s) => s.id == (entry.subjectId ?? ''),
      orElse: () => Subject(
        id: '',
        name: entry.subjectId ?? 'N/A',
        level: '',
        academicYear: '',
        teacherId: '',
        institutionId: '',
        courseId: '',
        allowedStudentEmails: [],
        contents: [],
        games: [],
      ),
    );
    final teacher = teachers.firstWhere(
      (t) => t.id == (entry.teacherId ?? ''),
      orElse: () => UserModel(
        id: '',
        name: 'N/A',
        email: '',
        role: UserRole.teacher,
        adConsent: true,
        dataConsent: true,
      ),
    );
    final classroom = classrooms.firstWhere(
      (r) => r.id == (entry.classroomId ?? ''),
      orElse: () => Classroom(id: '', name: 'N/A', institutionId: ''),
    );

    final Color bgColor = entry.isClosed
        ? Colors.red.withValues(alpha: 0.3)
        : (entry.isBreak
            ? Colors.orange.withValues(alpha: 0.3)
            : const Color(0xFF7B61FF).withValues(alpha: 0.2));

    final Color borderColor = entry.isClosed
        ? Colors.red
        : (entry.isBreak ? Colors.orange : const Color(0xFF7B61FF));

    return Container(
      height: 50,
      width: double.infinity,
      decoration: BoxDecoration(
        color: bgColor,
        border: Border.all(color: borderColor.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (entry.isClosed)
            const AiTranslatedText('Escola Encerrada',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold))
          else ...[
            Text(entry.isBreak ? 'Intervalo' : subject.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold)),
            if (!entry.isBreak) ...[
              Text(teacher.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 8)),
              Text(classroom.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white54, fontSize: 8)),
            ],
          ],
        ],
      ),
    );
  }
}
