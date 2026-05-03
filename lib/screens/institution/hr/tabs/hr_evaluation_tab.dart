import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../../../models/institution_model.dart';
import '../../../../models/user_model.dart';
import '../../../../models/hr/hr_attendance_model.dart';
import '../../../../models/hr/hr_absence_model.dart';
import '../../../../models/hr/hr_evaluation_model.dart';
import '../../../../services/firebase_service.dart';
import '../../../../services/ai_chat_service.dart';
import '../../../../widgets/ai_translated_text.dart';
import '../../../../widgets/glass_card.dart';

class HREvaluationTab extends StatefulWidget {
  final InstitutionModel institution;

  const HREvaluationTab({super.key, required this.institution});

  @override
  State<HREvaluationTab> createState() => _HREvaluationTabState();
}

class _HREvaluationTabState extends State<HREvaluationTab> {
  UserModel? _selectedEmployee;

  @override
  Widget build(BuildContext context) {
    final service = context.read<FirebaseService>();
    final aiService = context.read<AiChatService>();

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AiTranslatedText(
            'Avaliação 360º com IA',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const AiTranslatedText(
            'Gere avaliações de desempenho baseadas em dados reais de assiduidade e comportamento.',
            style: TextStyle(color: Colors.white54),
          ),
          const SizedBox(height: 32),
          FutureBuilder<List<UserModel>>(
            future: service.getAllInstitutionMembers(widget.institution.id),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const CircularProgressIndicator();
              final employees = snapshot.data!;

              return GlassCard(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<UserModel>(
                      value: _selectedEmployee,
                      hint: const AiTranslatedText('Selecionar Colaborador', style: TextStyle(color: Colors.white54)),
                      dropdownColor: const Color(0xFF1E293B),
                      icon: const Icon(Icons.arrow_drop_down, color: Colors.orangeAccent),
                      isExpanded: true,
                      items: employees.map((e) => DropdownMenuItem(
                        value: e,
                        child: Text(e.name, style: const TextStyle(color: Colors.white)),
                      )).toList(),
                      onChanged: (val) => setState(() => _selectedEmployee = val),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          if (_selectedEmployee != null)
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: () async {
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (_) => const Center(child: CircularProgressIndicator()),
                  );

                  try {
                    final attendance = await service.getHRAttendance(widget.institution.id, employeeId: _selectedEmployee!.id).first;
                    final absences = await service.getHRAbsences(widget.institution.id).first;
                    
                    if (mounted) {
                      Navigator.pop(context); // Close loading
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (_) => const Center(child: CircularProgressIndicator()),
                      );
                    }
                    
                    final feedback = await aiService.generateHREvaluationFeedback(
                      employee: _selectedEmployee!,
                      attendance: attendance,
                      absences: absences.where((a) => a.employeeId == _selectedEmployee!.id).toList(),
                    );
                    
                    if (mounted) {
                      Navigator.pop(context); // Close loading
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          backgroundColor: const Color(0xFF1E293B),
                          title: const AiTranslatedText('Avaliação IA Gerada'),
                          content: SingleChildScrollView(child: Text(feedback, style: const TextStyle(color: Colors.white70))),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const AiTranslatedText('Fechar'),
                            ),
                            ElevatedButton(
                              onPressed: () async {
                                await service.saveHRPerformanceEvaluation(HRPerformanceEvaluation(
                                  id: Uuid().v4(),
                                  institutionId: widget.institution.id,
                                  employeeId: _selectedEmployee!.id,
                                  employeeName: _selectedEmployee!.name,
                                  evaluatorId: 'AI_GEMINI',
                                  date: DateTime.now(),
                                  feedback: feedback,
                                ));
                                if (mounted) {
                                  Navigator.pop(context); // Close dialog
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: AiTranslatedText('Avaliação guardada com sucesso!')),
                                  );
                                }
                              },
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent, foregroundColor: Colors.black),
                              child: const AiTranslatedText('Guardar no Perfil'),
                            ),
                          ],
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
                    }
                  }
                },
                icon: const Icon(Icons.auto_awesome),
                label: const AiTranslatedText('Gerar Avaliação 360º'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7B61FF),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
