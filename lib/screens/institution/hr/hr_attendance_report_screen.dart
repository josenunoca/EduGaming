import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../models/institution_model.dart';
import '../../../models/user_model.dart';
import '../../../models/hr/hr_attendance_model.dart';
import '../../../models/hr/hr_absence_model.dart';
import '../../../services/firebase_service.dart';
import '../../../services/pdf_service.dart';
import '../../../widgets/ai_translated_text.dart';
import '../../../widgets/glass_card.dart';

class HRAttendanceReportScreen extends StatefulWidget {
  final InstitutionModel institution;

  const HRAttendanceReportScreen({super.key, required this.institution});

  @override
  State<HRAttendanceReportScreen> createState() => _HRAttendanceReportScreenState();
}

class _HRAttendanceReportScreenState extends State<HRAttendanceReportScreen> {
  DateTime _selectedMonth = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final service = context.read<FirebaseService>();

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: AiTranslatedText('Mapa de Assiduidade Mensal'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: () async {
              final employees = await service.getAllInstitutionMembers(widget.institution.id);
              final records = await service.getHRAttendance(widget.institution.id, month: _selectedMonth).first;
              final absences = await service.getHRAbsences(widget.institution.id).first; // Should ideally filter by month too
              
              await PdfService.generateHRAttendanceMapPDF(
                institution: widget.institution,
                month: _selectedMonth,
                employees: employees,
                records: records,
                absences: absences,
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildMonthPicker(),
          Expanded(
            child: FutureBuilder<List<UserModel>>(
              future: service.getAllInstitutionMembers(widget.institution.id),
              builder: (context, empSnapshot) {
                if (empSnapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                final employees = empSnapshot.data ?? [];
                
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SingleChildScrollView(
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(Colors.white.withValues(alpha: 0.05)),
                      dataRowMaxHeight: 60,
                      columns: [
                        const DataColumn(label: AiTranslatedText('Colaborador', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                        const DataColumn(label: AiTranslatedText('Previsto (h)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                        const DataColumn(label: AiTranslatedText('Real (h)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                        const DataColumn(label: AiTranslatedText('Faltas', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                        const DataColumn(label: AiTranslatedText('Status', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                      ],
                      rows: employees.map((emp) => DataRow(
                        cells: [
                          DataCell(Text(emp.name, style: const TextStyle(color: Colors.white))),
                          const DataCell(Text('160h', style: TextStyle(color: Colors.white70))),
                          const DataCell(Text('152h', style: TextStyle(color: Color(0xFF00FF85)))),
                          const DataCell(Row(
                            children: [
                              _AbsenceBadge(count: 1, type: 'D', color: Colors.orange), // Doença
                              SizedBox(width: 4),
                              _AbsenceBadge(count: 0, type: 'I', color: Colors.red), // Injustificada
                            ],
                          )),
                          const DataCell(Icon(Icons.check_circle, color: Colors.green, size: 20)),
                        ],
                      )).toList(),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthPicker() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, color: Colors.white),
            onPressed: () => setState(() => _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1)),
          ),
          AiTranslatedText(
            DateFormat('MMMM yyyy').format(_selectedMonth),
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, color: Colors.white),
            onPressed: () => setState(() => _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1)),
          ),
        ],
      ),
    );
  }
}

class _AbsenceBadge extends StatelessWidget {
  final int count;
  final String type;
  final Color color;

  const _AbsenceBadge({required this.count, required this.type, required this.color});

  @override
  Widget build(BuildContext context) {
    if (count == 0) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        '$count$type',
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}
