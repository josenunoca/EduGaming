import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';
import '../../../../models/user_model.dart';
import '../../../../models/hr/hr_absence_model.dart';
import '../../../../services/firebase_service.dart';
import '../../../../widgets/ai_translated_text.dart';
import '../../../../widgets/glass_card.dart';

class HRAbsenceJustificationScreen extends StatefulWidget {
  final UserModel user;

  const HRAbsenceJustificationScreen({super.key, required this.user});

  @override
  State<HRAbsenceJustificationScreen> createState() => _HRAbsenceJustificationScreenState();
}

class _HRAbsenceJustificationScreenState extends State<HRAbsenceJustificationScreen> {
  final _descriptionController = TextEditingController();
  DateTimeRange? _selectedRange;
  PlatformFile? _selectedFile;
  bool _isUploading = false;
  AbsenceType _selectedType = AbsenceType.justified;

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'png', 'doc', 'docx'],
    );

    if (result != null) {
      setState(() {
        _selectedFile = result.files.first;
      });
    }
  }

  Future<void> _submit() async {
    if (_selectedRange == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: AiTranslatedText('Por favor, selecione as datas.')),
      );
      return;
    }

    if (_descriptionController.text.isEmpty && _selectedFile == null) {
       ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: AiTranslatedText('Por favor, adicione uma descrição ou um documento.')),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      final service = context.read<FirebaseService>();
      String? documentUrl;

      if (_selectedFile != null && _selectedFile!.path != null) {
        final destination = 'hr_absences/${widget.user.institutionId}/${widget.user.id}/${const Uuid().v4()}_${_selectedFile!.name}';
        documentUrl = await service.uploadFile(_selectedFile!.path!, destination);
      }

      final absence = HRAbsence(
        id: const Uuid().v4(),
        employeeId: widget.user.id,
        institutionId: widget.user.institutionId ?? '',
        startDate: _selectedRange!.start,
        endDate: _selectedRange!.end,
        type: _selectedType,
        description: _descriptionController.text,
        medicalCertificateUrl: documentUrl,
        status: 'pending',
      );

      await service.saveHRAbsence(absence);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: AiTranslatedText('Justificação enviada com sucesso!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const AiTranslatedText('Justificar Falta'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AiTranslatedText(
              'Detalhes da Ausência',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            
            // Date Selection
            InkWell(
              onTap: () async {
                final range = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime.now().subtract(const Duration(days: 365)),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                  builder: (context, child) {
                    return Theme(
                      data: Theme.of(context).copyWith(
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
                if (range != null) setState(() => _selectedRange = range);
              },
              child: GlassCard(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, color: Color(0xFF00D1FF)),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const AiTranslatedText('Datas da Ausência', style: TextStyle(color: Colors.white70, fontSize: 12)),
                          Text(
                            _selectedRange == null 
                              ? 'Selecionar período' 
                              : '${DateFormat('dd/MM/yyyy').format(_selectedRange!.start)} - ${DateFormat('dd/MM/yyyy').format(_selectedRange!.end)}',
                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Absence Type
            const AiTranslatedText('Tipo de Ausência', style: TextStyle(color: Colors.white70, fontSize: 14)),
            const SizedBox(height: 8),
            DropdownButtonFormField<AbsenceType>(
              value: _selectedType,
              dropdownColor: const Color(0xFF1E293B),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
              items: AbsenceType.values.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: AiTranslatedText(_getTypeName(type)),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedType = val);
              },
            ),

            const SizedBox(height: 24),
            
            // Description
            const AiTranslatedText('Justificação (Texto)', style: TextStyle(color: Colors.white70, fontSize: 14)),
            const SizedBox(height: 8),
            TextField(
              controller: _descriptionController,
              maxLines: 4,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Explique o motivo da ausência...',
                hintStyle: const TextStyle(color: Colors.white24),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Document Upload
            const AiTranslatedText('Documento Comprovativo', style: TextStyle(color: Colors.white70, fontSize: 14)),
            const SizedBox(height: 8),
            InkWell(
              onTap: _pickFile,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white10),
                ),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        _selectedFile == null ? Icons.cloud_upload_outlined : Icons.insert_drive_file,
                        color: const Color(0xFF00D1FF),
                        size: 40,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _selectedFile == null ? 'Clique para fazer upload' : _selectedFile!.name,
                        style: TextStyle(color: _selectedFile == null ? Colors.white38 : Colors.white, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 40),
            
            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isUploading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00D1FF),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _isUploading 
                  ? const CircularProgressIndicator(color: Colors.black)
                  : const AiTranslatedText('Enviar Justificação', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getTypeName(AbsenceType type) {
    switch (type) {
      case AbsenceType.sickLeave: return 'Doença / Baixa';
      case AbsenceType.vacation: return 'Férias';
      case AbsenceType.justified: return 'Falta Justificada';
      case AbsenceType.mourning: return 'Nojo (Falecimento)';
      case AbsenceType.maternity: return 'Parentalidade';
      case AbsenceType.insurance: return 'Acidente de Trabalho';
      case AbsenceType.unjustified: return 'Falta Injustificada';
      case AbsenceType.other: return 'Outro';
    }
  }
}
