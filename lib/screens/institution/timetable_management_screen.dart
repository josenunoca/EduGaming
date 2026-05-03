import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/facility_model.dart';
import '../../models/subject_model.dart';
import '../../models/user_model.dart';
import '../../models/institution_model.dart';
import '../../services/firebase_service.dart';
import '../../widgets/ai_translated_text.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/custom_button.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class TimetableManagementScreen extends StatefulWidget {
  final InstitutionModel institution;

  const TimetableManagementScreen({super.key, required this.institution});

  @override
  State<TimetableManagementScreen> createState() =>
      _TimetableManagementScreenState();
}

class _TimetableManagementScreenState extends State<TimetableManagementScreen> {
  String? _selectedAcademicYear;
  String? _selectedClassroomId;
  String? _selectedTeacherId;

  List<TimetableEntry> _copiedDayEntries = [];
  int? _copiedDayIndex;
  DateTime _dateReference = DateTime.now();

  @override
  void initState() {
    super.initState();
    _selectedAcademicYear = '2024/2025'; // Default or from current date
  }

  @override
  Widget build(BuildContext context) {
    final service = context.read<FirebaseService>();

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const AiTranslatedText('Gestão de Horários'),
        actions: [
          if (_copiedDayEntries.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: TextButton.icon(
                onPressed: () => setState(() {
                  _copiedDayEntries = [];
                  _copiedDayIndex = null;
                }),
                icon: const Icon(Icons.clear, color: Colors.red),
                label: const AiTranslatedText('Limpar Cópia',
                    style: TextStyle(color: Colors.red)),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.auto_fix_high),
            tooltip: 'Preenchimento Automático',
            onPressed: () => _showAutoFillDialog(),
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep, color: Colors.orange),
            tooltip: 'Limpar Período',
            onPressed: () => _showClearDialog(),
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Exportar PDF',
            onPressed: () => _showExportOptions(),
          ),
        ],
      ),
      body: StreamBuilder<List<Subject>>(
        stream: service.getSubjectsByInstitution(widget.institution.id),
        builder: (context, subjectSnapshot) {
          final subjects = subjectSnapshot.data ?? [];
          return StreamBuilder<List<UserModel>>(
            stream: service.getTeachersByInstitution(widget.institution.id),
            builder: (context, teacherSnapshot) {
              final teachers = teacherSnapshot.data ?? [];
              return StreamBuilder<List<Classroom>>(
                stream: service.getClassrooms(widget.institution.id),
                builder: (context, roomSnapshot) {
                  final classrooms = roomSnapshot.data ?? [];
                  return Column(
                    children: [
                      _buildFilters(service),
                      Expanded(
                        child: StreamBuilder<List<TimetableEntry>>(
                          stream: service.getTimetableEntriesStream(
                            institutionId: widget.institution.id,
                            academicYear: _selectedAcademicYear,
                            classroomId: _selectedClassroomId,
                            teacherId: _selectedTeacherId,
                          ),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                  child: CircularProgressIndicator());
                            }
                            final entries = (snapshot.data ?? []).where((e) {
                              if (e.startDate != null &&
                                  _dateReference.isBefore(e.startDate!))
                                return false;
                              if (e.endDate != null &&
                                  _dateReference.isAfter(e.endDate!))
                                return false;
                              return true;
                            }).toList();
                            return _buildWeeklyGrid(
                                entries, subjects, teachers, classrooms);
                          },
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildFilters(FirebaseService service) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: GlassCard(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedAcademicYear,
                  decoration: const InputDecoration(labelText: 'Ano Letivo'),
                  items: ['2024/2025', '2025/2026', '2026/2027']
                      .map((y) => DropdownMenuItem(value: y, child: Text(y)))
                      .toList(),
                  onChanged: (val) =>
                      setState(() => _selectedAcademicYear = val),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: StreamBuilder<List<Classroom>>(
                  stream: service.getClassrooms(widget.institution.id),
                  builder: (context, snapshot) {
                    final rooms = snapshot.data ?? [];
                    return DropdownButtonFormField<String>(
                      value: _selectedClassroomId,
                      decoration:
                          const InputDecoration(labelText: 'Sala de Aula'),
                      items: [
                        const DropdownMenuItem(
                            value: null,
                            child: AiTranslatedText('Todas as Salas')),
                        ...rooms.map((r) =>
                            DropdownMenuItem(value: r.id, child: Text(r.name))),
                      ],
                      onChanged: (val) =>
                          setState(() => _selectedClassroomId = val),
                    );
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: StreamBuilder<List<UserModel>>(
                  stream:
                      service.getTeachersByInstitution(widget.institution.id),
                  builder: (context, snapshot) {
                    final teachers = snapshot.data ?? [];
                    return DropdownButtonFormField<String>(
                      value: _selectedTeacherId,
                      decoration: const InputDecoration(labelText: 'Docente'),
                      items: [
                        const DropdownMenuItem(
                            value: null,
                            child: AiTranslatedText('Todos os Docentes')),
                        ...teachers.map((t) =>
                            DropdownMenuItem(value: t.id, child: Text(t.name))),
                      ],
                      onChanged: (val) =>
                          setState(() => _selectedTeacherId = val),
                    );
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ListTile(
                  title: const AiTranslatedText('Data de Referência',
                      style: TextStyle(color: Colors.white70, fontSize: 12)),
                  subtitle: Text(
                    '${_dateReference.day}/${_dateReference.month}/${_dateReference.year}',
                    style: const TextStyle(color: Colors.white),
                  ),
                  trailing: const Icon(Icons.calendar_today,
                      size: 16, color: Colors.blueAccent),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _dateReference,
                      firstDate: DateTime(2023),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) setState(() => _dateReference = picked);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWeeklyGrid(
    List<TimetableEntry> entries,
    List<Subject> subjects,
    List<UserModel> teachers,
    List<Classroom> classrooms,
  ) {
    final days = ['Segunda', 'Terça', 'Quarta', 'Quinta', 'Sexta', 'Sábado'];
    const startTime = 8;
    const endTime = 21;
    const slotDuration = 30; // Minutes

    return ListView(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row (Days)
              Row(
                children: [
                  const SizedBox(width: 60), // Time labels column
                  ...List.generate(
                      6, (i) => _buildDayHeader(i, days[i], entries)),
                ],
              ),
              const Divider(color: Colors.white10),
              // Time Slots Row
              ...List.generate((endTime - startTime) * (60 ~/ slotDuration),
                  (index) {
                final totalMinutes = startTime * 60 + index * slotDuration;
                final hour = totalMinutes ~/ 60;
                final minute = totalMinutes % 60;
                final timeStr =
                    '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Time Label
                    Container(
                      width: 60,
                      constraints: const BoxConstraints(minHeight: 50),
                      alignment: Alignment.center,
                      child: Text(timeStr,
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 10)),
                    ),
                    // Day Slots
                    ...List.generate(6, (dayIndex) {
                      final dayEntries = entries
                          .where((e) => e.weekday == dayIndex + 1)
                          .toList();
                      final slotEntries = dayEntries
                          .where(
                            (e) => _isTimeInSlot(e, timeStr),
                          )
                          .toList();

                      return _buildSlotCell(dayIndex + 1, timeStr, slotEntries,
                          subjects, teachers, classrooms);
                    }),
                  ],
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDayHeader(int index, String name, List<TimetableEntry> entries) {
    final dayIndex = index + 1;
    return Container(
      width: 180,
      padding: const EdgeInsets.all(8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AiTranslatedText(name,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold)),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.copy, size: 16, color: Colors.white70),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () => _copyDay(dayIndex, entries),
            tooltip: 'Copiar Dia',
          ),
          if (_copiedDayEntries.isNotEmpty && _copiedDayIndex != dayIndex)
            IconButton(
              icon: const Icon(Icons.paste, size: 16, color: Colors.blueAccent),
              padding: const EdgeInsets.only(left: 8),
              constraints: const BoxConstraints(),
              onPressed: () => _pasteDay(dayIndex),
              tooltip: 'Colar Aqui',
            ),
        ],
      ),
    );
  }

  Widget _buildSlotCell(
    int weekday,
    String time,
    List<TimetableEntry> slotEntries,
    List<Subject> subjects,
    List<UserModel> teachers,
    List<Classroom> classrooms,
  ) {
    return Container(
      width: 180,
      constraints: const BoxConstraints(minHeight: 50),
      margin: const EdgeInsets.all(1),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ...slotEntries.map((entry) => SizedBox(
                height: 50,
                width: double.infinity,
                child: GestureDetector(
                  onTap: () => _editEntry(entry),
                  child: Draggable<TimetableEntry>(
                    data: entry,
                    feedback: SizedBox(
                      width: 180,
                      height: 50,
                      child: Material(
                        color: Colors.transparent,
                        child: _buildEntryWidget(
                            entry, subjects, teachers, classrooms,
                            isDragging: true),
                      ),
                    ),
                    childWhenDragging: Opacity(
                      opacity: 0.3,
                      child: _buildEntryWidget(
                          entry, subjects, teachers, classrooms),
                    ),
                    child: _buildEntryWidget(
                        entry, subjects, teachers, classrooms),
                  ),
                ),
              )),
          // Add button visible if viewing "All Rooms" OR if no entries yet
          DragTarget<TimetableEntry>(
            onAcceptWithDetails: (details) async {
              final draggedEntry = details.data;
              final newEntry = TimetableEntry(
                id: draggedEntry.id,
                subjectId: draggedEntry.subjectId,
                classroomId: _selectedClassroomId ?? draggedEntry.classroomId,
                teacherId: draggedEntry.teacherId,
                startTime: time,
                durationMinutes: draggedEntry.durationMinutes,
                weekday: weekday,
                institutionId: widget.institution.id,
                academicYear: draggedEntry.academicYear,
                isBreak: draggedEntry.isBreak,
                isClosed: draggedEntry.isClosed,
                startDate: draggedEntry.startDate,
                endDate: draggedEntry.endDate,
                customActivityName: draggedEntry.customActivityName,
              );
              await context.read<FirebaseService>().saveTimetableEntry(newEntry);
            },
            builder: (context, candidateData, rejectedData) {
              final isHovering = candidateData.isNotEmpty;
              return SizedBox(
                height: slotEntries.isEmpty ? 50 : 30,
                width: double.infinity,
                child: GestureDetector(
                  onTap: () => _addEntry(weekday, time),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isHovering
                          ? Colors.blue.withValues(alpha: 0.2)
                          : Colors.white.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(4),
                      border: isHovering
                          ? Border.all(color: Colors.blueAccent)
                          : null,
                    ),
                    child: Icon(Icons.add,
                        color: isHovering ? Colors.blueAccent : Colors.white10,
                        size: slotEntries.isEmpty ? 16 : 14),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEntryWidget(
    TimetableEntry entry,
    List<Subject> subjects,
    List<UserModel> teachers,
    List<Classroom> classrooms, {
    bool isDragging = false,
  }) {
    final subject = subjects.firstWhere((s) => s.id == entry.subjectId,
        orElse: () => Subject(
              id: '',
              name: entry.customActivityName ??
                  entry.subjectId ??
                  (entry.isBreak ? 'Intervalo' : 'Aula'),
              level: '',
              academicYear: '',
              teacherId: '',
              institutionId: '',
              courseId: '',
              allowedStudentEmails: [],
              contents: [],
              games: [],
            ));

    final teacher = teachers.firstWhere((t) => t.id == entry.teacherId,
        orElse: () => UserModel(
              id: '',
              name: entry.teacherId ?? '',
              email: '',
              role: UserRole.teacher,
              adConsent: true,
              dataConsent: true,
            ));

    final classroom = classrooms.firstWhere((r) => r.id == entry.classroomId,
        orElse: () => Classroom(
              id: '',
              name: entry.classroomId ?? '',
              institutionId: '',
            ));

    if (entry.isClosed) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
        ),
        child: const Center(
          child: AiTranslatedText('Escola Encerrada',
              style: TextStyle(
                  color: Colors.red,
                  fontSize: 10,
                  fontWeight: FontWeight.bold)),
        ),
      );
    }

    if (entry.isBreak) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
        ),
        child: Center(
          child: AiTranslatedText(
              entry.subjectId == 'Intervalo' ? 'Intervalo' : subject.name,
              style: const TextStyle(
                  color: Colors.orange,
                  fontSize: 10,
                  fontWeight: FontWeight.bold)),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.4)),
      ),
      padding: const EdgeInsets.all(4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AiTranslatedText(
            subject.name,
            style: const TextStyle(
                color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          if (classroom.name.isNotEmpty)
            Text(
              classroom.name,
              style: const TextStyle(color: Colors.blueAccent, fontSize: 8),
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          if (teacher.name.isNotEmpty)
            Text(
              teacher.name,
              style: const TextStyle(color: Colors.white70, fontSize: 8),
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
        ],
      ),
    );
  }

  bool _isTimeInSlot(TimetableEntry entry, String slotStartTime) {
    if (entry.id.isEmpty) return false;

    final slotTime = _parseTime(slotStartTime);
    final entryStart = _parseTime(entry.startTime);
    final durationMinutes = entry.durationMinutes;
    final entryEnd = entryStart + durationMinutes;

    return slotTime >= entryStart && slotTime < entryEnd;
  }

  int _parseTime(String time) {
    final parts = time.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }

  void _copyDay(int weekday, List<TimetableEntry> allEntries) {
    setState(() {
      _copiedDayEntries =
          allEntries.where((e) => e.weekday == weekday).toList();
      _copiedDayIndex = weekday;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: AiTranslatedText(
                'Dia copiado! Selecione outro dia para colar.')),
      );
    }
  }

  Future<void> _pasteDay(int targetWeekday) async {
    final service = context.read<FirebaseService>();
    final newEntries = _copiedDayEntries
        .map((e) => TimetableEntry(
              id: const Uuid().v4(),
              subjectId: e.subjectId,
              classroomId: e.classroomId,
              teacherId: e.teacherId,
              startTime: e.startTime,
              durationMinutes: e.durationMinutes,
              weekday: targetWeekday,
              institutionId: widget.institution.id,
              academicYear: _selectedAcademicYear,
              isBreak: e.isBreak,
            ))
        .toList();

    await service.bulkSaveTimetableEntries(newEntries);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: AiTranslatedText('Horário colado com sucesso!')),
      );
    }
  }

  void _addEntry(int weekday, String startTime) {
    _showEntryDialog(TimetableEntry(
      id: const Uuid().v4(),
      weekday: weekday,
      startTime: startTime,
      institutionId: widget.institution.id,
      academicYear: _selectedAcademicYear,
    ));
  }

  void _editEntry(TimetableEntry entry) {
    _showEntryDialog(entry);
  }

  void _showEntryDialog(TimetableEntry initialEntry) {
    final service = context.read<FirebaseService>();
    bool isBreak = initialEntry.isBreak;
    bool isClosed = initialEntry.isClosed;
    String? subjectId = initialEntry.subjectId;
    String? teacherId = initialEntry.teacherId;
    String? customName = initialEntry.customActivityName;
    bool isCustomActivity = initialEntry.customActivityName != null;
    String? classroomId = initialEntry.classroomId ?? _selectedClassroomId;
    int durationMinutes = initialEntry.durationMinutes;
    bool isCustomDuration = ![
      15,
      30,
      45,
      60,
      75,
      90,
      105,
      120,
      135,
      150,
      165,
      180
    ].contains(durationMinutes);
    final TextEditingController customDurationController =
        TextEditingController(text: durationMinutes.toString());

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: AiTranslatedText(
              initialEntry.id.isEmpty ? 'Novo Horário' : 'Editar Horário'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SwitchListTile(
                  title: const AiTranslatedText('É Intervalo?'),
                  value: isBreak,
                  onChanged: (val) {
                    setDialogState(() {
                      isBreak = val;
                      if (val) isClosed = false;
                    });
                  },
                ),
                SwitchListTile(
                  title: const AiTranslatedText('É Encerramento?'),
                  value: isClosed,
                  onChanged: (val) {
                    setDialogState(() {
                      isClosed = val;
                      if (val) isBreak = false;
                    });
                  },
                ),
                if (!isBreak && !isClosed) ...[
                  SwitchListTile(
                    title: const AiTranslatedText('Atividade Personalizada?'),
                    subtitle:
                        const AiTranslatedText('Conferência, Aluguer, etc.'),
                    value: isCustomActivity,
                    onChanged: (val) {
                      setDialogState(() {
                        isCustomActivity = val;
                        if (val) subjectId = null;
                      });
                    },
                  ),
                  if (isCustomActivity)
                    TextFormField(
                      initialValue: customName,
                      decoration: const InputDecoration(
                          labelText: 'Nome da Atividade'),
                      onChanged: (val) => customName = val,
                    )
                  else
                    StreamBuilder<List<Subject>>(
                      stream: service
                          .getSubjectsByInstitution(widget.institution.id),
                      builder: (context, snapshot) {
                        final subjects = snapshot.data ?? [];
                        return DropdownButtonFormField<String>(
                          value: (subjects.any((s) => s.id == subjectId))
                              ? subjectId
                              : null,
                          decoration:
                              const InputDecoration(labelText: 'Disciplina'),
                          items: subjects
                              .map((s) => DropdownMenuItem(
                                  value: s.id, child: Text(s.name)))
                              .toList(),
                          onChanged: (val) =>
                              setDialogState(() => subjectId = val),
                        );
                      },
                    ),
                  const SizedBox(height: 16),
                  StreamBuilder<List<UserModel>>(
                    stream:
                        service.getTeachersByInstitution(widget.institution.id),
                    builder: (context, snapshot) {
                      final teachers = snapshot.data ?? [];
                      return DropdownButtonFormField<String>(
                        value: (teachers.any((t) => t.id == teacherId))
                            ? teacherId
                            : null,
                        decoration:
                            const InputDecoration(labelText: 'Professor'),
                        items: teachers
                            .map((t) => DropdownMenuItem(
                                value: t.id, child: Text(t.name)))
                            .toList(),
                        onChanged: (val) =>
                            setDialogState(() => teacherId = val),
                      );
                    },
                  ),
                ],
                if (!isClosed) ...[
                  const SizedBox(height: 16),
                  StreamBuilder<List<Classroom>>(
                    stream: service.getClassrooms(widget.institution.id),
                    builder: (context, snapshot) {
                      final rooms = snapshot.data ?? [];
                      return DropdownButtonFormField<String>(
                        value: (rooms.any((r) => r.id == classroomId))
                            ? classroomId
                            : null,
                        decoration: const InputDecoration(labelText: 'Sala'),
                        items: rooms
                            .map((r) => DropdownMenuItem(
                                value: r.id, child: Text(r.name)))
                            .toList(),
                        onChanged: (val) =>
                            setDialogState(() => classroomId = val),
                      );
                    },
                  ),
                ],
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  value: isCustomDuration ? -1 : durationMinutes,
                  decoration:
                      const InputDecoration(labelText: 'Duração (Minutos)'),
                  items: [
                    ...[15, 30, 45, 60, 75, 90, 105, 120, 135, 150, 165, 180]
                        .map((d) =>
                            DropdownMenuItem(value: d, child: Text('$d min'))),
                    const DropdownMenuItem(
                        value: -1, child: AiTranslatedText('Personalizada...')),
                  ],
                  onChanged: (val) {
                    setDialogState(() {
                      if (val == -1) {
                        isCustomDuration = true;
                      } else {
                        isCustomDuration = false;
                        durationMinutes = val ?? 60;
                        customDurationController.text =
                            durationMinutes.toString();
                      }
                    });
                  },
                ),
                if (isCustomDuration) ...[
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: customDurationController,
                    decoration: const InputDecoration(
                        labelText: 'Duração Personalizada (min)'),
                    keyboardType: TextInputType.number,
                    onChanged: (val) {
                      final parsed = int.tryParse(val);
                      if (parsed != null) durationMinutes = parsed;
                    },
                  ),
                ],
              ],
            ),
          ),
          actions: [
            if (initialEntry.id.isNotEmpty)
              TextButton(
                onPressed: () async {
                  await service.deleteTimetableEntry(initialEntry.id);
                  if (context.mounted) Navigator.pop(context);
                },
                child: const AiTranslatedText('Eliminar',
                    style: TextStyle(color: Colors.red)),
              ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const AiTranslatedText('Cancelar'),
            ),
            CustomButton(
              label: 'Guardar',
              onPressed: () async {
                final entry = TimetableEntry(
                  id: initialEntry.id.isEmpty
                      ? const Uuid().v4()
                      : initialEntry.id,
                  subjectId: isClosed
                      ? 'Encerramento'
                      : (isBreak ? 'Intervalo' : subjectId),
                  classroomId: isClosed ? null : classroomId,
                  teacherId: (isBreak || isClosed) ? null : teacherId,
                  startTime: initialEntry.startTime,
                  durationMinutes: durationMinutes,
                  weekday: initialEntry.weekday,
                  institutionId: widget.institution.id,
                  academicYear: _selectedAcademicYear,
                   isBreak: isBreak,
                  isClosed: isClosed,
                  customActivityName: isCustomActivity ? customName : null,
                );
                await service.saveTimetableEntry(entry);
                if (context.mounted) Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAutoFillDialog() {
    final service = context.read<FirebaseService>();
    String? subjectId;
    String? teacherId;
    String? classroomId = _selectedClassroomId;
    DateTime startDate = DateTime.now();
    DateTime endDate =
        DateTime.now().add(const Duration(days: 90)); // 3 months default
    List<int> selectedWeekdays = []; // 1-7
    String startTime = '09:00';
    int durationMinutes = 60;
    bool isCustomDuration = false;
    final TextEditingController customDurationController =
        TextEditingController(text: '60');
    String type = 'aula'; // aula, intervalo, encerramento

    final days = [
      {'val': 1, 'name': 'Segunda'},
      {'val': 2, 'name': 'Terça'},
      {'val': 3, 'name': 'Quarta'},
      {'val': 4, 'name': 'Quinta'},
      {'val': 5, 'name': 'Sexta'},
      {'val': 6, 'name': 'Sábado'},
    ];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const AiTranslatedText('Preenchimento Automático'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                        value: 'aula', label: AiTranslatedText('Aula')),
                    ButtonSegment(
                        value: 'intervalo',
                        label: AiTranslatedText('Intervalo')),
                    ButtonSegment(
                        value: 'encerramento',
                        label: AiTranslatedText('Encerramento')),
                  ],
                  selected: {type},
                  onSelectionChanged: (val) =>
                      setDialogState(() => type = val.first),
                ),
                const SizedBox(height: 16),
                if (type == 'aula') ...[
                  StreamBuilder<List<Subject>>(
                    stream:
                        service.getSubjectsByInstitution(widget.institution.id),
                    builder: (context, snapshot) {
                      final subjects = snapshot.data ?? [];
                      return DropdownButtonFormField<String>(
                        value: (subjects.any((s) => s.id == subjectId))
                            ? subjectId
                            : null,
                        decoration:
                            const InputDecoration(labelText: 'Disciplina'),
                        items: subjects
                            .map((s) => DropdownMenuItem(
                                value: s.id, child: Text(s.name)))
                            .toList(),
                        onChanged: (val) =>
                            setDialogState(() => subjectId = val),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  StreamBuilder<List<UserModel>>(
                    stream:
                        service.getTeachersByInstitution(widget.institution.id),
                    builder: (context, snapshot) {
                      final teachers = snapshot.data ?? [];
                      return DropdownButtonFormField<String>(
                        value: (teachers.any((t) => t.id == teacherId))
                            ? teacherId
                            : null,
                        decoration:
                            const InputDecoration(labelText: 'Professor'),
                        items: teachers
                            .map((t) => DropdownMenuItem(
                                value: t.id, child: Text(t.name)))
                            .toList(),
                        onChanged: (val) =>
                            setDialogState(() => teacherId = val),
                      );
                    },
                  ),
                ],
                if (type != 'encerramento') ...[
                  const SizedBox(height: 16),
                  StreamBuilder<List<Classroom>>(
                    stream: service.getClassrooms(widget.institution.id),
                    builder: (context, snapshot) {
                      final rooms = snapshot.data ?? [];
                      return DropdownButtonFormField<String>(
                        value: (rooms.any((r) => r.id == classroomId))
                            ? classroomId
                            : null,
                        decoration: const InputDecoration(labelText: 'Sala'),
                        items: rooms
                            .map((r) => DropdownMenuItem(
                                value: r.id, child: Text(r.name)))
                            .toList(),
                        onChanged: (val) =>
                            setDialogState(() => classroomId = val),
                      );
                    },
                  ),
                ],
                const SizedBox(height: 16),
                ListTile(
                  title: const AiTranslatedText('Período',
                      style: TextStyle(fontSize: 12)),
                  subtitle: Text(
                    '${startDate.day}/${startDate.month} até ${endDate.day}/${endDate.month}/${endDate.year}',
                    style: const TextStyle(fontSize: 14),
                  ),
                  trailing: const Icon(Icons.date_range),
                  onTap: () async {
                    final picked = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2023),
                      lastDate: DateTime(2030),
                      initialDateRange:
                          DateTimeRange(start: startDate, end: endDate),
                    );
                    if (picked != null) {
                      setDialogState(() {
                        startDate = picked.start;
                        endDate = picked.end;
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),
                const AiTranslatedText('Dias da Semana',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Wrap(
                  spacing: 8,
                  children: days.map((d) {
                    final isSelected = selectedWeekdays.contains(d['val']);
                    return FilterChip(
                      label: Text(d['name'] as String,
                          style: const TextStyle(fontSize: 10)),
                      selected: isSelected,
                      onSelected: (val) {
                        setDialogState(() {
                          if (val) {
                            selectedWeekdays.add(d['val'] as int);
                          } else {
                            selectedWeekdays.remove(d['val']);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 1,
                      child: GestureDetector(
                        onTap: () async {
                          final time = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay(
                              hour: int.parse(startTime.split(':')[0]),
                              minute: int.parse(startTime.split(':')[1]),
                            ),
                          );
                          if (time != null) {
                            setDialogState(() => startTime =
                                '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}');
                          }
                        },
                        child: InputDecorator(
                          decoration:
                              const InputDecoration(labelText: 'Início'),
                          child: Text(startTime),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          DropdownButtonFormField<int>(
                            value: isCustomDuration ? -1 : durationMinutes,
                            decoration:
                                const InputDecoration(labelText: 'Duração'),
                            items: [
                              ...[
                                15,
                                30,
                                45,
                                60,
                                75,
                                90,
                                105,
                                120,
                                135,
                                150,
                                165,
                                180
                              ].map((d) => DropdownMenuItem(
                                  value: d, child: Text('$d min'))),
                              const DropdownMenuItem(
                                  value: -1,
                                  child: AiTranslatedText('Personalizada...')),
                            ],
                            onChanged: (val) {
                              setDialogState(() {
                                if (val == -1) {
                                  isCustomDuration = true;
                                } else {
                                  isCustomDuration = false;
                                  durationMinutes = val ?? 60;
                                  customDurationController.text =
                                      durationMinutes.toString();
                                }
                              });
                            },
                          ),
                          if (isCustomDuration) ...[
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: customDurationController,
                              decoration:
                                  const InputDecoration(labelText: 'Mins'),
                              keyboardType: TextInputType.number,
                              onChanged: (val) {
                                final parsed = int.tryParse(val);
                                if (parsed != null) durationMinutes = parsed;
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const AiTranslatedText('Cancelar'),
            ),
            CustomButton(
              label: 'Gerar Horários',
              onPressed: () async {
                if (type == 'aula' && subjectId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: AiTranslatedText('Selecione uma disciplina.')),
                  );
                  return;
                }
                if (selectedWeekdays.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content:
                            AiTranslatedText('Selecione pelo menos um dia.')),
                  );
                  return;
                }

                final List<TimetableEntry> newEntries = [];
                for (final day in selectedWeekdays) {
                  newEntries.add(TimetableEntry(
                    id: const Uuid().v4(),
                    subjectId: type == 'encerramento'
                        ? 'Encerramento'
                        : (type == 'intervalo' ? 'Intervalo' : subjectId),
                    teacherId: type == 'aula' ? teacherId : null,
                    classroomId: type != 'encerramento' ? classroomId : null,
                    weekday: day,
                    startTime: startTime,
                    durationMinutes: durationMinutes,
                    institutionId: widget.institution.id,
                    academicYear: _selectedAcademicYear,
                    startDate: startDate,
                    endDate: endDate,
                    isBreak: type == 'intervalo',
                    isClosed: type == 'encerramento',
                  ));
                }

                await service.bulkSaveTimetableEntries(newEntries);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content:
                            AiTranslatedText('Horários gerados com sucesso!')),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
  void _showClearDialog() {
    DateTime start = DateTime.now();
    DateTime end = DateTime.now().add(const Duration(days: 30));
    String? roomId = _selectedClassroomId;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const AiTranslatedText('Limpar Horário'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AiTranslatedText('Selecione o intervalo para limpar:'),
              ListTile(
                title: const AiTranslatedText('Início'),
                subtitle: Text('${start.day}/${start.month}/${start.year}'),
                onTap: () async {
                  final p = await showDatePicker(
                      context: context,
                      initialDate: start,
                      firstDate: DateTime(2023),
                      lastDate: DateTime(2030));
                  if (p != null) setDialogState(() => start = p);
                },
              ),
              ListTile(
                title: const AiTranslatedText('Fim'),
                subtitle: Text('${end.day}/${end.month}/${end.year}'),
                onTap: () async {
                  final p = await showDatePicker(
                      context: context,
                      initialDate: end,
                      firstDate: DateTime(2023),
                      lastDate: DateTime(2030));
                  if (p != null) setDialogState(() => end = p);
                },
              ),
              const SizedBox(height: 16),
              StreamBuilder<List<Classroom>>(
                stream: context
                    .read<FirebaseService>()
                    .getClassrooms(widget.institution.id),
                builder: (context, snapshot) {
                  final rooms = snapshot.data ?? [];
                  return DropdownButtonFormField<String>(
                    value: roomId,
                    decoration:
                        const InputDecoration(labelText: 'Sala (Opcional)'),
                    items: [
                      const DropdownMenuItem(
                          value: null,
                          child: AiTranslatedText('Todas as Salas')),
                      ...rooms.map((r) =>
                          DropdownMenuItem(value: r.id, child: Text(r.name))),
                    ],
                    onChanged: (val) => setDialogState(() => roomId = val),
                  );
                },
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const AiTranslatedText('Cancelar')),
            CustomButton(
              label: 'Limpar Agora',
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const AiTranslatedText('Confirmar Exclusão'),
                    content: const AiTranslatedText(
                        'Esta ação é irreversível. Deseja continuar?'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const AiTranslatedText('Não')),
                      TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const AiTranslatedText('Sim')),
                    ],
                  ),
                );
                if (confirm == true) {
                  await context
                      .read<FirebaseService>()
                      .deleteTimetableEntriesBulk(
                        widget.institution.id,
                        classroomId: roomId,
                        startDate: start,
                        endDate: end,
                      );
                  if (context.mounted) Navigator.pop(context);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showExportOptions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const AiTranslatedText('Exportar Horário (PDF)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.grid_view),
              title: const AiTranslatedText('Horário Geral'),
              subtitle: const AiTranslatedText('Todas as salas num único PDF'),
              onTap: () {
                Navigator.pop(context);
                _generatePdf(isGlobal: true);
              },
            ),
            ListTile(
              leading: const Icon(Icons.room),
              title: const AiTranslatedText('Por Sala'),
              subtitle: const AiTranslatedText('Uma folha por cada sala'),
              onTap: () {
                Navigator.pop(context);
                _generatePdf(isGlobal: false);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _generatePdf({required bool isGlobal}) async {
    final service = context.read<FirebaseService>();
    final pdf = pw.Document();

    final subjects =
        await service.getSubjectsByInstitution(widget.institution.id).first;
    final classrooms = await service.getClassrooms(widget.institution.id).first;
    final teachers =
        await service.getTeachersByInstitution(widget.institution.id).first;
    final entries = await service
        .getTimetableEntriesStream(
          institutionId: widget.institution.id,
          academicYear: _selectedAcademicYear,
        )
        .first;

    final filteredEntries = entries.where((e) {
      if (e.startDate != null && _dateReference.isBefore(e.startDate!))
        return false;
      if (e.endDate != null && _dateReference.isAfter(e.endDate!)) return false;
      return true;
    }).toList();

    const days = ['Segunda', 'Terça', 'Quarta', 'Quinta', 'Sexta', 'Sábado'];
    const hours = [8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20];

    final roomsToPrint = isGlobal ? [null] : classrooms.map((r) => r.id).toList();

    for (var roomId in roomsToPrint) {
      final roomEntries = roomId == null
          ? filteredEntries
          : filteredEntries.where((e) => e.classroomId == roomId).toList();

      final roomName = roomId == null
          ? 'Horário Geral'
          : classrooms.firstWhere((r) => r.id == roomId).name;

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4.landscape,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(widget.institution.name,
                            style: pw.TextStyle(
                                fontSize: 18, fontWeight: pw.FontWeight.bold)),
                        pw.Text(roomName,
                            style: const pw.TextStyle(fontSize: 14)),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('Ano Letivo: $_selectedAcademicYear'),
                        pw.Text(
                            'Data: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}'),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 20),
                pw.Table(
                  border: pw.TableBorder.all(),
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                      children: [
                        pw.Padding(
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Text('Hora')),
                        ...days.map((d) => pw.Padding(
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Text(d))),
                      ],
                    ),
                    ...hours.map((h) {
                      return pw.TableRow(
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Text('${h.toString().padLeft(2, '0')}:00'),
                          ),
                          ...List.generate(6, (dayIdx) {
                            final wDay = dayIdx + 1;
                            final cellEntries = roomEntries
                                .where((e) =>
                                    e.weekday == wDay &&
                                    e.startTime.startsWith(
                                        '${h.toString().padLeft(2, '0')}:'))
                                .toList();

                            return pw.Padding(
                              padding: const pw.EdgeInsets.all(2),
                              child: pw.Column(
                                children: cellEntries.map((e) {
                                  final sName = e.customActivityName ??
                                      subjects
                                          .firstWhere((s) => s.id == e.subjectId,
                                              orElse: () => Subject(
                                                  id: '',
                                                  name: e.subjectId ?? '',
                                                  level: '',
                                                  academicYear: '',
                                                  teacherId: '',
                                                  institutionId: '',
                                                  courseId: '',
                                                  allowedStudentEmails: [],
                                                  contents: [],
                                                  games: []))
                                          .name;

                                  final teacher = teachers.firstWhere(
                                    (t) => t.id == e.teacherId,
                                    orElse: () => UserModel(
                                      id: '',
                                      email: '',
                                      name: e.teacherId ?? '',
                                      role: UserRole.teacher,
                                      adConsent: true,
                                      dataConsent: true,
                                    ),
                                  );

                                  final classroom = classrooms.firstWhere(
                                    (r) => r.id == e.classroomId,
                                    orElse: () => Classroom(
                                      id: '',
                                      name: e.classroomId ?? '',
                                      institutionId: '',
                                    ),
                                  );

                                  return pw.Padding(
                                    padding: const pw.EdgeInsets.symmetric(
                                        vertical: 1),
                                    child: pw.Column(
                                      children: [
                                        pw.Text(
                                          sName,
                                          style: pw.TextStyle(
                                              fontSize: 9,
                                              fontWeight: pw.FontWeight.bold),
                                          textAlign: pw.TextAlign.center,
                                        ),
                                        if (classroom.name.isNotEmpty && isGlobal)
                                          pw.Text(
                                            'Sala: ${classroom.name}',
                                            style: const pw.TextStyle(
                                                fontSize: 7,
                                                color: PdfColors.blue900),
                                            textAlign: pw.TextAlign.center,
                                          ),
                                        if (teacher.name.isNotEmpty)
                                          pw.Text(
                                            'Prof: ${teacher.name}',
                                            style: const pw.TextStyle(
                                                fontSize: 7,
                                                color: PdfColors.grey900),
                                            textAlign: pw.TextAlign.center,
                                          ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            );
                          }),
                        ],
                      );
                    }),
                  ],
                ),
                pw.Spacer(),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Gerado por EduGaming',
                        style: const pw.TextStyle(
                            fontSize: 8, color: PdfColors.grey600)),
                    pw.Column(
                      children: [
                        pw.Container(
                          width: 200,
                          decoration: const pw.BoxDecoration(
                            border: pw.Border(
                                bottom: pw.BorderSide(color: PdfColors.black)),
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text('Responsável pela Gestão dos Equipamentos',
                            style: const pw.TextStyle(fontSize: 10)),
                      ],
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      );
    }

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }
}
