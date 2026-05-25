import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../../../models/institution_model.dart';
import '../../../../models/user_model.dart';
import '../../../../models/hr/hr_absence_model.dart';
import '../../../../services/firebase_service.dart';
import '../../../../widgets/ai_translated_text.dart';
import '../../../../widgets/glass_card.dart';

class HRAbsencesTab extends StatelessWidget {
  final InstitutionModel institution;

  const HRAbsencesTab({super.key, required this.institution});

  void _showAddAbsenceDialog(BuildContext context) async {
    final service = context.read<FirebaseService>();
    final employees = await service.getAllInstitutionMembers(institution.id);
    final activeEmployees = employees.where((m) =>
        m.role != UserRole.student &&
        m.role != UserRole.parent &&
        !m.isSuspended).toList();

    if (!context.mounted) return;

    UserModel? selectedEmployee;
    AbsenceType selectedType = AbsenceType.vacation;
    DateTime startDate = DateTime.now();
    DateTime endDate = DateTime.now().add(const Duration(days: 1));
    bool isPaid = true;
    final descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E293B),
              title: const AiTranslatedText('Registar Ausência / Férias Manual'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AiTranslatedText('Colaborador', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<UserModel>(
                      value: activeEmployees.contains(selectedEmployee) ? selectedEmployee : null,
                      dropdownColor: const Color(0xFF1E293B),
                      decoration: const InputDecoration(
                        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                        focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF00D1FF))),
                      ),
                      style: const TextStyle(color: Colors.white),
                      items: activeEmployees.map((emp) => DropdownMenuItem(
                        value: emp,
                        child: Text(emp.name),
                      )).toList(),
                      onChanged: (val) => setState(() => selectedEmployee = val),
                    ),
                    const SizedBox(height: 16),
                    const AiTranslatedText('Tipo de Ausência', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<AbsenceType>(
                      value: selectedType,
                      dropdownColor: const Color(0xFF1E293B),
                      decoration: const InputDecoration(
                        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                        focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF00D1FF))),
                      ),
                      style: const TextStyle(color: Colors.white),
                      items: AbsenceType.values.map((type) => DropdownMenuItem(
                        value: type,
                        child: Text(_getTypeName(type)),
                      )).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => selectedType = val);
                      },
                    ),
                    const SizedBox(height: 16),
                    const AiTranslatedText('Período', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton.icon(
                            onPressed: () async {
                              final d = await showDatePicker(
                                context: context,
                                initialDate: startDate,
                                firstDate: DateTime(2025),
                                lastDate: DateTime(2030),
                              );
                              if (d != null) {
                                setState(() {
                                  startDate = d;
                                  if (endDate.isBefore(startDate)) {
                                    endDate = startDate.add(const Duration(days: 1));
                                  }
                                });
                              }
                            },
                            icon: const Icon(Icons.calendar_today, size: 14),
                            label: Text(_formatDate(startDate, 'dd/MM/yyyy')),
                            style: TextButton.styleFrom(foregroundColor: const Color(0xFF00D1FF)),
                          ),
                        ),
                        Expanded(
                          child: TextButton.icon(
                            onPressed: () async {
                              final d = await showDatePicker(
                                context: context,
                                initialDate: endDate,
                                firstDate: startDate,
                                lastDate: DateTime(2030),
                              );
                              if (d != null) setState(() => endDate = d);
                            },
                            icon: const Icon(Icons.calendar_today, size: 14),
                            label: Text(_formatDate(endDate, 'dd/MM/yyyy')),
                            style: TextButton.styleFrom(foregroundColor: const Color(0xFF00D1FF)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const AiTranslatedText('Remunerada?', style: TextStyle(color: Colors.white, fontSize: 14)),
                        const Spacer(),
                        Switch(
                          value: isPaid,
                          activeColor: const Color(0xFF00FF85),
                          onChanged: (val) => setState(() => isPaid = val),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const AiTranslatedText('Descrição / Observações', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: descriptionController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: 'ex: Férias anuais, atestado médico...',
                        hintStyle: TextStyle(color: Colors.white24),
                        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                        focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF00D1FF))),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const AiTranslatedText('Cancelar', style: TextStyle(color: Colors.white54)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (selectedEmployee == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Selecione um colaborador!')),
                      );
                      return;
                    }
                    final absence = HRAbsence(
                      id: const Uuid().v4(),
                      employeeId: selectedEmployee!.id,
                      institutionId: institution.id,
                      startDate: startDate,
                      endDate: endDate,
                      type: selectedType,
                      description: descriptionController.text,
                      isPaid: isPaid,
                      status: 'approved',
                    );
                    await service.saveHRAbsence(absence);
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Ausência registada e aprovada com sucesso!')),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00FF85), foregroundColor: Colors.black),
                  child: const AiTranslatedText('Gravar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _getTypeName(AbsenceType type) {
    switch (type) {
      case AbsenceType.vacation: return 'Férias';
      case AbsenceType.sickLeave: return 'Doença / Baixa';
      case AbsenceType.justified: return 'Falta Justificada';
      case AbsenceType.mourning: return 'Nojo (Falecimento)';
      case AbsenceType.maternity: return 'Parentalidade';
      case AbsenceType.insurance: return 'Acidente de Trabalho';
      case AbsenceType.unjustified: return 'Falta Injustificada';
      case AbsenceType.other: return 'Outro';
    }
  }

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
                onPressed: () => _showAddAbsenceDialog(context),
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

              // Sort pending first, then newest start date
              absences.sort((a, b) {
                if (a.status == 'pending' && b.status != 'pending') return -1;
                if (a.status != 'pending' && b.status == 'pending') return 1;
                return b.startDate.compareTo(a.startDate);
              });

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
    final service = context.read<FirebaseService>();
    Color statusColor;
    switch (absence.status) {
      case 'approved': statusColor = const Color(0xFF00FF85); break;
      case 'rejected': statusColor = const Color(0xFFFF4A4A); break;
      default: statusColor = const Color(0xFFFFB800);
    }

    return GlassCard(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: StreamBuilder<UserModel?>(
          stream: service.getUserStream(absence.employeeId),
          builder: (context, userSnapshot) {
            final user = userSnapshot.data;
            final employeeName = user?.name ?? 'A carregar...';

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
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
                          Text(
                            employeeName,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              AiTranslatedText(
                                _getTypeName(absence.type),
                                style: const TextStyle(color: Colors.white70, fontSize: 13),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: absence.isPaid ? Colors.green.withValues(alpha: 0.2) : Colors.red.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  absence.isPaid ? 'Paga' : 'Não Paga',
                                  style: TextStyle(
                                    color: absence.isPaid ? Colors.greenAccent : Colors.redAccent,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
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
                      child: Text(
                        absence.status.toUpperCase(),
                        style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined, color: Colors.white38, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      '${_formatDate(absence.startDate, 'dd/MM/yyyy')} a ${_formatDate(absence.endDate, 'dd/MM/yyyy')} (${absence.days} dias)',
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
                if (absence.description.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    absence.description,
                    style: const TextStyle(color: Colors.white38, fontSize: 12, fontStyle: FontStyle.italic),
                  ),
                ],
                if (absence.medicalCertificateUrl != null && absence.medicalCertificateUrl!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          backgroundColor: const Color(0xFF1E293B),
                          title: const AiTranslatedText('Documento Comprovativo'),
                          content: SingleChildScrollView(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.insert_drive_file, color: Color(0xFF00D1FF), size: 48),
                                const SizedBox(height: 16),
                                const AiTranslatedText('O documento pode ser acedido através do seguinte link:', style: TextStyle(color: Colors.white70, fontSize: 13)),
                                const SizedBox(height: 8),
                                SelectableText(
                                  absence.medicalCertificateUrl!,
                                  style: const TextStyle(color: Color(0xFF00D1FF), fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const AiTranslatedText('Fechar'),
                            ),
                          ],
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00D1FF).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF00D1FF).withValues(alpha: 0.2)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.attachment, color: Color(0xFF00D1FF), size: 14),
                          SizedBox(width: 6),
                          AiTranslatedText(
                            'Ver Comprovativo Anexo',
                            style: TextStyle(color: Color(0xFF00D1FF), fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                if (absence.status == 'pending') ...[
                  const SizedBox(height: 16),
                  const Divider(color: Colors.white10, height: 1),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: () async {
                          final updated = HRAbsence(
                            id: absence.id,
                            employeeId: absence.employeeId,
                            institutionId: absence.institutionId,
                            startDate: absence.startDate,
                            endDate: absence.endDate,
                            type: absence.type,
                            description: absence.description,
                            isPaid: absence.isPaid,
                            medicalCertificateUrl: absence.medicalCertificateUrl,
                            status: 'rejected',
                          );
                          await service.saveHRAbsence(updated);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Ausência rejeitada.')),
                            );
                          }
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFFF4A4A),
                          side: const BorderSide(color: Color(0xFFFF4A4A)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const AiTranslatedText('Rejeitar'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: () async {
                          final updated = HRAbsence(
                            id: absence.id,
                            employeeId: absence.employeeId,
                            institutionId: absence.institutionId,
                            startDate: absence.startDate,
                            endDate: absence.endDate,
                            type: absence.type,
                            description: absence.description,
                            isPaid: absence.isPaid,
                            medicalCertificateUrl: absence.medicalCertificateUrl,
                            status: 'approved',
                          );
                          await service.saveHRAbsence(updated);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Ausência aprovada com sucesso!')),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00FF85),
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const AiTranslatedText('Aprovar'),
                      ),
                    ],
                  ),
                ],
              ],
            );
          },
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

String _formatDate(DateTime date, String pattern) {
  try {
    return DateFormat(pattern).format(date);
  } catch (_) {
    if (pattern == 'dd/MM/yyyy') {
      final d = date.day.toString().padLeft(2, '0');
      final m = date.month.toString().padLeft(2, '0');
      final y = date.year.toString().padLeft(4, '0');
      return '$d/$m/$y';
    }
    return date.toIso8601String().split('T')[0];
  }
}
