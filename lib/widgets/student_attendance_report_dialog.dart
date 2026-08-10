import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/user_model.dart';
import '../models/institution_model.dart';
import '../models/subject_model.dart';
import '../models/student_absence_model.dart';
import '../models/hr/hr_attendance_model.dart';
import '../models/activity_model.dart';
import '../services/firebase_service.dart';
import '../services/pdf_service.dart';
import 'ai_translated_text.dart';
import 'glass_card.dart';

class StudentAttendanceReportDialog extends StatefulWidget {
  final UserModel student;

  const StudentAttendanceReportDialog({
    super.key,
    required this.student,
  });

  @override
  State<StudentAttendanceReportDialog> createState() =>
      _StudentAttendanceReportDialogState();
}

class _StudentAttendanceReportDialogState
    extends State<StudentAttendanceReportDialog> {
  String _periodOption = 'month'; // 'day', 'week', 'month', 'custom'
  DateTimeRange _customRange = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 30)),
    end: DateTime.now(),
  );
  String? _selectedSubjectId; // null = Global
  bool _isDetailed = true;
  bool _isGenerating = false;

  DateTime get _effectiveStartDate {
    final now = DateTime.now();
    switch (_periodOption) {
      case 'day':
        return DateTime(now.year, now.month, now.day);
      case 'week':
        return now.subtract(Duration(days: now.weekday - 1));
      case 'month':
        return DateTime(now.year, now.month, 1);
      case 'custom':
      default:
        return _customRange.start;
    }
  }

  DateTime get _effectiveEndDate {
    final now = DateTime.now();
    switch (_periodOption) {
      case 'day':
        return DateTime(now.year, now.month, now.day, 23, 59, 59);
      case 'week':
        return now.add(Duration(days: 7 - now.weekday));
      case 'month':
        return DateTime(now.year, now.month + 1, 0, 23, 59, 59);
      case 'custom':
      default:
        return _customRange.end;
    }
  }

  String _formatDate(DateTime d) {
    try {
      return DateFormat('dd/MM/yyyy').format(d);
    } catch (_) {
      return '${d.day}/${d.month}/${d.year}';
    }
  }

  Future<void> _generateReport(BuildContext context) async {
    setState(() => _isGenerating = true);

    try {
      final service = context.read<FirebaseService>();
      final institutionId = widget.student.institutionId ?? '';
      
      // Fetch Institution Details
      final inst = await service.getInstitution(institutionId);
      final institution = inst ??
          InstitutionModel(
            id: institutionId,
            name: 'EduGaming Portugal',
            nif: '500000000',
            address: '',
            phone: '',
            email: '',
            educationLevels: [],
            createdAt: DateTime.now(),
          );

      // Fetch Attendance Records
      final attendanceList = await service
          .getHRAttendance(institutionId, employeeId: widget.student.id)
          .first;

      final filteredAttendance = attendanceList.where((r) {
        return r.timestamp.isAfter(_effectiveStartDate.subtract(const Duration(seconds: 1))) &&
            r.timestamp.isBefore(_effectiveEndDate.add(const Duration(seconds: 1)));
      }).toList();

      // Fetch Student Absences
      final absencesList = await service
          .getStudentAbsences(institutionId, studentId: widget.student.id)
          .first;

      final filteredAbsences = absencesList.where((a) {
        return a.startDate.isAfter(_effectiveStartDate.subtract(const Duration(days: 1))) &&
            a.endDate.isBefore(_effectiveEndDate.add(const Duration(days: 1)));
      }).toList();

      // Fetch Activities
      final activitiesList = await service
          .getActivities(institutionId)
          .first;

      final filteredActivities = activitiesList.where((act) {
        return act.startDate.isAfter(_effectiveStartDate.subtract(const Duration(days: 1))) &&
            act.startDate.isBefore(_effectiveEndDate.add(const Duration(days: 1)));
      }).toList();

      // Subject Filter Name
      String? subjectName;
      if (_selectedSubjectId != null && _selectedSubjectId!.isNotEmpty) {
        final subjectDoc = await service.getSubject(_selectedSubjectId!);
        subjectName = subjectDoc?.name;
      }

      await PdfService.generateStudentAttendanceReportPDF(
        institution: institution,
        student: widget.student,
        startDate: _effectiveStartDate,
        endDate: _effectiveEndDate,
        attendanceRecords: filteredAttendance,
        absences: filteredAbsences,
        activities: filteredActivities,
        subjectName: subjectName,
        isDetailed: _isDetailed,
      );

      if (context.mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao gerar relatório: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<FirebaseService>();
    final institutionId = widget.student.institutionId ?? '';

    return AlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Icon(Icons.print_rounded, color: Color(0xFF00D1FF)),
          SizedBox(width: 10),
          Text(
            'Mapa de Assiduidade e Atividades',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Aluno(a): ${widget.student.name}',
              style: const TextStyle(color: Color(0xFF00D1FF), fontSize: 13, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // 1. Period Option
            const Text(
              '1. Escolha o Período:',
              style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Hoje'),
                  selected: _periodOption == 'day',
                  selectedColor: const Color(0xFF00D1FF),
                  onSelected: (s) => setState(() => _periodOption = 'day'),
                ),
                ChoiceChip(
                  label: const Text('Esta Semana'),
                  selected: _periodOption == 'week',
                  selectedColor: const Color(0xFF00D1FF),
                  onSelected: (s) => setState(() => _periodOption = 'week'),
                ),
                ChoiceChip(
                  label: const Text('Este Mês'),
                  selected: _periodOption == 'month',
                  selectedColor: const Color(0xFF00D1FF),
                  onSelected: (s) => setState(() => _periodOption = 'month'),
                ),
                ChoiceChip(
                  label: const Text('Personalizado'),
                  selected: _periodOption == 'custom',
                  selectedColor: const Color(0xFF00D1FF),
                  onSelected: (s) async {
                    setState(() => _periodOption = 'custom');
                    final picked = await showDateRangePicker(
                      context: context,
                      initialDateRange: _customRange,
                      firstDate: DateTime.now().subtract(const Duration(days: 365)),
                      lastDate: DateTime.now().add(const Duration(days: 180)),
                    );
                    if (picked != null) {
                      setState(() => _customRange = picked);
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Período: ${_formatDate(_effectiveStartDate)} até ${_formatDate(_effectiveEndDate)}',
              style: const TextStyle(color: Colors.white60, fontSize: 12, fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 18),

            // 2. Scope Option (Global vs Subject)
            const Text(
              '2. Âmbito do Mapa:',
              style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            StreamBuilder<List<Subject>>(
              stream: service.getSubjectsByInstitution(institutionId),
              builder: (context, snapshot) {
                final subjects = snapshot.data ?? [];

                return DropdownButtonFormField<String?>(
                  value: _selectedSubjectId,
                  dropdownColor: const Color(0xFF0F172A),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('🌐 Visão Global (Todas as Disciplinas)'),
                    ),
                    ...subjects.map((sub) {
                      return DropdownMenuItem(
                        value: sub.id,
                        child: Text('📚 ${sub.name} (${sub.level})'),
                      );
                    }),
                  ],
                  onChanged: (val) => setState(() => _selectedSubjectId = val),
                );
              },
            ),
            const SizedBox(height: 18),

            // 3. Format Version (Simple vs Detailed)
            const Text(
              '3. Nível de Detalhe:',
              style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: RadioListTile<bool>(
                    title: const Text('Resumo Simples', style: TextStyle(color: Colors.white, fontSize: 12)),
                    value: false,
                    groupValue: _isDetailed,
                    activeColor: const Color(0xFF00D1FF),
                    onChanged: (val) => setState(() => _isDetailed = val!),
                  ),
                ),
                Expanded(
                  child: RadioListTile<bool>(
                    title: const Text('Relatório Detalhado', style: TextStyle(color: Colors.white, fontSize: 12)),
                    value: true,
                    groupValue: _isDetailed,
                    activeColor: const Color(0xFF00D1FF),
                    onChanged: (val) => setState(() => _isDetailed = val!),
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
          child: const Text('Cancelar', style: TextStyle(color: Colors.white54)),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF7B61FF),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          icon: _isGenerating
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
              : const Icon(Icons.picture_as_pdf_rounded, size: 18),
          label: const Text('Gerir & Imprimir PDF'),
          onPressed: _isGenerating ? null : () => _generateReport(context),
        ),
      ],
    );
  }
}
