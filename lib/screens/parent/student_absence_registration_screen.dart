import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';
import '../../models/user_model.dart';
import '../../models/student_absence_model.dart';
import '../../services/firebase_service.dart';
import '../../services/email_invitation_service.dart';
import '../../widgets/ai_translated_text.dart';
import '../../widgets/glass_card.dart';

class StudentAbsenceRegistrationScreen extends StatefulWidget {
  final UserModel child;
  final UserModel parent;

  const StudentAbsenceRegistrationScreen({
    super.key,
    required this.child,
    required this.parent,
  });

  @override
  State<StudentAbsenceRegistrationScreen> createState() =>
      _StudentAbsenceRegistrationScreenState();
}

class _StudentAbsenceRegistrationScreenState
    extends State<StudentAbsenceRegistrationScreen> {
  final _descriptionController = TextEditingController();
  DateTimeRange? _selectedRange;
  PlatformFile? _selectedFile;
  bool _isSubmitting = false;
  StudentAbsenceType _selectedType = StudentAbsenceType.sickLeave;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime date) {
    try {
      return DateFormat('dd/MM/yyyy').format(date);
    } catch (_) {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  Future<void> _pickProofFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'png', 'jpeg', 'doc', 'docx'],
      withData: true,
    );

    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _selectedFile = result.files.first;
      });
    }
  }

  Future<void> _submitAbsence() async {
    if (_selectedRange == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, selecione os dias de ausência do educando.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final service = context.read<FirebaseService>();
      String? documentUrl;

      if (_selectedFile != null) {
        final destination =
            'student_absences/${widget.child.institutionId ?? 'general'}/${widget.child.id}/${const Uuid().v4()}_${_selectedFile!.name}';
        Uint8List? bytes = _selectedFile!.bytes;
        if (bytes == null && _selectedFile!.path != null) {
          try {
            bytes = await File(_selectedFile!.path!).readAsBytes();
          } catch (_) {}
        }
        if (bytes != null) {
          documentUrl = await service.uploadFileBytes(bytes, destination);
        }
      }

      final absence = StudentAbsence(
        id: const Uuid().v4(),
        studentId: widget.child.id,
        studentName: widget.child.name,
        parentId: widget.parent.id,
        parentName: widget.parent.name,
        institutionId: widget.child.institutionId ?? '',
        startDate: _selectedRange!.start,
        endDate: _selectedRange!.end,
        type: _selectedType,
        description: _descriptionController.text.trim(),
        proofUrl: documentUrl,
        status: 'reported',
        createdAt: DateTime.now(),
      );

      await service.saveStudentAbsence(absence);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Ausência de ${widget.child.name} registada! Os professores foram alertados.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao registar ausência: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String _getTypeName(StudentAbsenceType type) {
    switch (type) {
      case StudentAbsenceType.sickLeave:
        return 'Doença / Baixa Médica';
      case StudentAbsenceType.vacation:
        return 'Férias em Família';
      case StudentAbsenceType.medicalAppointment:
        return 'Consulta / Tratamento Médico';
      case StudentAbsenceType.familyReason:
        return 'Assuntos Familiares / Pessoais';
      case StudentAbsenceType.other:
        return 'Outro Motivo';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: AiTranslatedText(
          'Registar Ausência / Férias: ${widget.child.name}',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Educando Header Card
            GlassCard(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: const Color(0xFF00D1FF).withValues(alpha: 0.2),
                    child: const Icon(Icons.child_care, color: Color(0xFF00D1FF), size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.child.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Encarregado(a): ${widget.parent.name}',
                          style: const TextStyle(color: Colors.white60, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Date Range Selection (HR style)
            const Text(
              '1. Selecione o Período de Ausência (Dia ou Intervalo)',
              style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            InkWell(
              onTap: () async {
                final initialRange = _selectedRange ??
                    DateTimeRange(
                      start: DateTime.now(),
                      end: DateTime.now(),
                    );
                final picked = await showDateRangePicker(
                  context: context,
                  initialDateRange: initialRange,
                  firstDate: DateTime.now().subtract(const Duration(days: 30)),
                  lastDate: DateTime.now().add(const Duration(days: 180)),
                  builder: (context, child) {
                    return Theme(
                      data: ThemeData.dark().copyWith(
                        colorScheme: const ColorScheme.dark(
                          primary: Color(0xFF00D1FF),
                          onPrimary: Colors.black,
                          surface: Color(0xFF1E293B),
                          onSurface: Colors.white,
                        ),
                      ),
                      child: child!,
                    );
                  },
                );
                if (picked != null) {
                  setState(() => _selectedRange = picked);
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF00D1FF).withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_month, color: Color(0xFF00D1FF)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _selectedRange == null
                            ? 'Clique para escolher as datas (ex: 15/08 a 20/08)'
                            : '${_formatDate(_selectedRange!.start)} até ${_formatDate(_selectedRange!.end)}',
                        style: TextStyle(
                          color: _selectedRange == null ? Colors.white38 : Colors.white,
                          fontSize: 14,
                          fontWeight: _selectedRange == null ? FontWeight.normal : FontWeight.bold,
                        ),
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios, color: Colors.white38, size: 14),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Absence Type Dropdown
            const Text(
              '2. Motivo da Ausência / Férias',
              style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<StudentAbsenceType>(
              value: _selectedType,
              dropdownColor: const Color(0xFF1E293B),
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              items: StudentAbsenceType.values.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Text(_getTypeName(type)),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedType = val);
              },
            ),
            const SizedBox(height: 24),

            // Justification Text Field
            const Text(
              '3. Observações / Descrição (Opcional)',
              style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _descriptionController,
              maxLines: 3,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Ex: Consulta médica agendada / Férias familiares informadas...',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 24),

            // Proof Upload / Photo
            const Text(
              '4. Anexar Comprovativo / Fotografar Baixa (Opcional)',
              style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _pickProofFile,
              icon: const Icon(Icons.attach_file, color: Color(0xFF00D1FF)),
              label: Text(
                _selectedFile == null
                    ? '📁 Carregar Ficheiro ou Foto do Comprovativo'
                    : '✅ ${_selectedFile!.name}',
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF00D1FF)),
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
            const SizedBox(height: 32),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _isSubmitting ? null : _submitAbsence,
                icon: _isSubmitting
                    ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                    : const Icon(Icons.send_rounded),
                label: const AiTranslatedText(
                  'Confirmar e Alertar Professores',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7B61FF),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
