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

class TimetableManagementScreen extends StatefulWidget {
  final InstitutionModel institution;

  const TimetableManagementScreen({super.key, required this.institution});

  @override
  State<TimetableManagementScreen> createState() => _TimetableManagementScreenState();
}

class _TimetableManagementScreenState extends State<TimetableManagementScreen> {
  String? _selectedAcademicYear;
  String? _selectedClassroomId;
  String? _selectedTeacherId;
  
  List<TimetableEntry> _copiedDayEntries = [];
  int? _copiedDayIndex;

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
                label: const AiTranslatedText('Limpar Cópia', style: TextStyle(color: Colors.red)),
              ),
            ),
        ],
      ),
      body: Column(
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
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final entries = snapshot.data ?? [];
                return _buildWeeklyGrid(entries);
              },
            ),
          ),
        ],
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
                items: ['2024/2025', '2025/2026', '2026/2027'].map((y) => 
                  DropdownMenuItem(value: y, child: Text(y))
                ).toList(),
                onChanged: (val) => setState(() => _selectedAcademicYear = val),
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
                    decoration: const InputDecoration(labelText: 'Sala de Aula'),
                    items: [
                      const DropdownMenuItem(value: null, child: AiTranslatedText('Todas as Salas')),
                      ...rooms.map((r) => DropdownMenuItem(value: r.id, child: Text(r.name))),
                    ],
                    onChanged: (val) => setState(() => _selectedClassroomId = val),
                  );
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: StreamBuilder<List<UserModel>>(
                stream: service.getTeachersByInstitution(widget.institution.id),
                builder: (context, snapshot) {
                  final teachers = snapshot.data ?? [];
                  return DropdownButtonFormField<String>(
                    value: _selectedTeacherId,
                    decoration: const InputDecoration(labelText: 'Docente'),
                    items: [
                      const DropdownMenuItem(value: null, child: AiTranslatedText('Todos os Docentes')),
                      ...teachers.map((t) => DropdownMenuItem(value: t.id, child: Text(t.name))),
                    ],
                    onChanged: (val) => setState(() => _selectedTeacherId = val),
                  );
                },
              ),
            ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWeeklyGrid(List<TimetableEntry> entries) {
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
                  ...List.generate(6, (i) => _buildDayHeader(i, days[i], entries)),
                ],
              ),
              const Divider(color: Colors.white10),
              // Time Slots Row
              ...List.generate((endTime - startTime) * (60 ~/ slotDuration), (index) {
                final totalMinutes = startTime * 60 + index * slotDuration;
                final hour = totalMinutes ~/ 60;
                final minute = totalMinutes % 60;
                final timeStr = '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

                return Row(
                  children: [
                    // Time Label
                    Container(
                      width: 60,
                      height: 50,
                      alignment: Alignment.center,
                      child: Text(timeStr, style: const TextStyle(color: Colors.white54, fontSize: 10)),
                    ),
                    // Day Slots
                    ...List.generate(6, (dayIndex) {
                      final dayEntries = entries.where((e) => e.weekday == dayIndex + 1).toList();
                      final entryInSlot = dayEntries.firstWhere(
                        (e) => _isTimeInSlot(e, timeStr),
                        orElse: () => TimetableEntry(id: '', weekday: 0, startTime: '', institutionId: ''),
                      );

                      return _buildSlotCell(dayIndex + 1, timeStr, entryInSlot);
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
          AiTranslatedText(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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

  Widget _buildSlotCell(int weekday, String time, TimetableEntry entry) {
    final hasEntry = entry.id.isNotEmpty;

    return Container(
      width: 180,
      height: 50,
      margin: const EdgeInsets.all(1),
      child: GestureDetector(
        onTap: () => hasEntry ? _editEntry(entry) : _addEntry(weekday, time),
        child: hasEntry
            ? _buildEntryWidget(entry)
            : Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(Icons.add, color: Colors.white10, size: 16),
              ),
      ),
    );
  }

  Widget _buildEntryWidget(TimetableEntry entry) {
    if (entry.isBreak) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
        ),
        child: Center(
          child: AiTranslatedText(entry.subjectId ?? 'Intervalo', 
            style: const TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.bold)),
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
          Text(entry.subjectId ?? '', 
            style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
            overflow: TextOverflow.ellipsis,
          ),
          Text(entry.teacherId ?? '', 
            style: const TextStyle(color: Colors.white70, fontSize: 8),
            overflow: TextOverflow.ellipsis,
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
      _copiedDayEntries = allEntries.where((e) => e.weekday == weekday).toList();
      _copiedDayIndex = weekday;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: AiTranslatedText('Dia copiado! Selecione outro dia para colar.')),
      );
    }
  }

  Future<void> _pasteDay(int targetWeekday) async {
    final service = context.read<FirebaseService>();
    final newEntries = _copiedDayEntries.map((e) => TimetableEntry(
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
    )).toList();

    await service.bulkSaveTimetableEntries(newEntries);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: AiTranslatedText('Horário colado com sucesso!')),
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
    String? subjectId = initialEntry.subjectId;
    String? teacherId = initialEntry.teacherId;
    String? classroomId = initialEntry.classroomId ?? _selectedClassroomId;
    int durationMinutes = initialEntry.durationMinutes;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: AiTranslatedText(initialEntry.id.isEmpty ? 'Novo Horário' : 'Editar Horário'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SwitchListTile(
                  title: const AiTranslatedText('É Intervalo?'),
                  value: isBreak,
                  onChanged: (val) => setDialogState(() => isBreak = val),
                ),
                if (!isBreak) ...[
                  StreamBuilder<List<Subject>>(
                    stream: service.getSubjectsByInstitution(widget.institution.id),
                    builder: (context, snapshot) {
                      final subjects = snapshot.data ?? [];
                      return DropdownButtonFormField<String>(
                        value: subjectId,
                        decoration: const InputDecoration(labelText: 'Disciplina'),
                        items: subjects.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))).toList(),
                        onChanged: (val) => setDialogState(() => subjectId = val),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  StreamBuilder<List<UserModel>>(
                    stream: service.getTeachersByInstitution(widget.institution.id),
                    builder: (context, snapshot) {
                      final teachers = snapshot.data ?? [];
                      return DropdownButtonFormField<String>(
                        value: teacherId,
                        decoration: const InputDecoration(labelText: 'Professor'),
                        items: teachers.map((t) => DropdownMenuItem(value: t.id, child: Text(t.name))).toList(),
                        onChanged: (val) => setDialogState(() => teacherId = val),
                      );
                    },
                  ),
                ],
                const SizedBox(height: 16),
                StreamBuilder<List<Classroom>>(
                  stream: service.getClassrooms(widget.institution.id),
                  builder: (context, snapshot) {
                    final rooms = snapshot.data ?? [];
                    return DropdownButtonFormField<String>(
                      value: classroomId,
                      decoration: const InputDecoration(labelText: 'Sala'),
                      items: rooms.map((r) => DropdownMenuItem(value: r.id, child: Text(r.name))).toList(),
                      onChanged: (val) => setDialogState(() => classroomId = val),
                    );
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  value: durationMinutes,
                  decoration: const InputDecoration(labelText: 'Duração (Minutos)'),
                  items: [30, 60, 90, 120, 180].map((d) => 
                    DropdownMenuItem(value: d, child: Text('$d min'))
                  ).toList(),
                  onChanged: (val) => setDialogState(() => durationMinutes = val ?? 60),
                ),
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
                child: const AiTranslatedText('Eliminar', style: TextStyle(color: Colors.red)),
              ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const AiTranslatedText('Cancelar'),
            ),
            CustomButton(
              label: 'Guardar',
              onPressed: () async {
                final entry = TimetableEntry(
                  id: initialEntry.id.isEmpty ? const Uuid().v4() : initialEntry.id,
                  subjectId: isBreak ? 'Intervalo' : subjectId,
                  classroomId: classroomId,
                  teacherId: teacherId,
                  startTime: initialEntry.startTime,
                  durationMinutes: durationMinutes,
                  weekday: initialEntry.weekday,
                  institutionId: widget.institution.id,
                  academicYear: _selectedAcademicYear,
                  isBreak: isBreak,
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
}
