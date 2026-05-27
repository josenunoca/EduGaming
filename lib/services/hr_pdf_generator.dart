import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../models/user_model.dart';
import '../models/hr/hr_schedule_model.dart';
import '../models/institution_model.dart';
import '../models/hr/hr_absence_model.dart';

class HRPdfGenerator {
  static Future<void> generateAndPrintStaffSchedule({
    required List<UserModel> staff,
    required List<HRScheduleEntry> entries,
    required DateTime start,
    required DateTime end,
    required String institutionName,
    String? roleFilter,
  }) async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.interRegular();
    final fontBold = await PdfGoogleFonts.interBold();

    final days = <DateTime>[];
    for (var date = start; date.isBefore(end.add(const Duration(days: 1))); date = date.add(const Duration(days: 1))) {
      days.add(date);
    }

    final filteredStaff = roleFilter == null
        ? staff
        : staff.where((u) => u.role.name.toLowerCase() == roleFilter.toLowerCase()).toList();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        build: (pw.Context context) {
          return [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Escala de Trabalho - Recursos Humanos', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                    pw.Text(institutionName, style: const pw.TextStyle(fontSize: 14, color: PdfColors.grey700)),
                    if (roleFilter != null)
                      pw.Text('Função: ${roleFilter.toUpperCase()}', style: const pw.TextStyle(fontSize: 11, color: PdfColors.blue700)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Período: ${DateFormat('dd/MM/yyyy').format(start)} - ${DateFormat('dd/MM/yyyy').format(end)}', style: const pw.TextStyle(fontSize: 10)),
                    pw.Text('Gerado em: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey500)),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 15),
            pw.Divider(color: PdfColors.grey300),
            pw.SizedBox(height: 10),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(2.5),
                for (int i = 0; i < days.length; i++) i + 1: const pw.FlexColumnWidth(1),
              },
              children: [
                // Header row
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.blue800),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(5),
                      child: pw.Text('Colaborador', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 8)),
                    ),
                    for (var day in days)
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Center(
                          child: pw.Column(
                            children: [
                              pw.Text(DateFormat('E', 'pt_PT').format(day).toUpperCase(), style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 6)),
                              pw.Text(DateFormat('dd/MM').format(day), style: pw.TextStyle(color: PdfColors.white, fontSize: 6)),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                // Rows for each staff member
                for (var employee in filteredStaff) ...[
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(employee.name, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
                            pw.Text(employee.role.name.toUpperCase(), style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey600)),
                            pw.Text('Horas: ${employee.contractedHours}h/sem', style: const pw.TextStyle(fontSize: 6, color: PdfColors.blue600)),
                          ],
                        ),
                      ),
                      for (var day in days) ...[
                        _buildScheduleCell(employee, day, entries),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: 'Escala_${institutionName.replaceAll(' ', '_')}_${DateFormat('yyyyMMdd').format(start)}.pdf',
    );
  }

  static pw.Widget _buildScheduleCell(UserModel employee, DateTime day, List<HRScheduleEntry> entries) {
    final entry = entries.firstWhere(
      (e) => e.employeeId == employee.id &&
             e.date.year == day.year &&
             e.date.month == day.month &&
             e.date.day == day.day,
      orElse: () => HRScheduleEntry(
        id: '',
        employeeId: employee.id,
        institutionId: employee.institutionId ?? '',
        date: day,
        shiftId: '',
      ),
    );

    final String text;
    final PdfColor bgColor;
    final PdfColor textColor;

    if (entry.isOffDay) {
      text = 'FOLGA';
      bgColor = PdfColors.grey100;
      textColor = PdfColors.grey600;
    } else if (entry.shiftId != null && entry.shiftId!.isNotEmpty) {
      final start = entry.customStartTime;
      final end = entry.customEndTime;
      text = '$start\n$end';
      bgColor = PdfColors.blue50;
      textColor = PdfColors.blue800;
    } else {
      text = '-';
      bgColor = PdfColors.white;
      textColor = PdfColors.grey400;
    }

    return pw.Container(
      alignment: pw.Alignment.center,
      height: 30,
      color: bgColor,
      child: pw.Text(
        text,
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: textColor),
      ),
    );
  }

  static String _getAbsenceTypeLabel(AbsenceType type) {
    switch (type) {
      case AbsenceType.sickLeave: return 'Baixa Médica';
      case AbsenceType.unjustified: return 'Falta Não Justificada';
      case AbsenceType.vacation: return 'Férias';
      case AbsenceType.insurance: return 'Acidente de Trabalho';
      case AbsenceType.maternity: return 'Licença Parental';
      case AbsenceType.mourning: return 'Nojo (Luto)';
      case AbsenceType.justified: return 'Falta Justificada';
      case AbsenceType.other: return 'Outra Ausência';
    }
  }

  static pw.Widget _buildScheduleCellWithAbsences(
    UserModel employee,
    DateTime day,
    List<HRScheduleEntry> entries,
    List<HRAbsence> absences,
  ) {
    final checkDay = DateTime(day.year, day.month, day.day);
    HRAbsence? absence;
    for (var a in absences) {
      if (a.employeeId == employee.id && a.status == 'approved') {
        final start = DateTime(a.startDate.year, a.startDate.month, a.startDate.day);
        final end = DateTime(a.endDate.year, a.endDate.month, a.endDate.day);
        if ((checkDay.isAtSameMomentAs(start) || checkDay.isAfter(start)) &&
            (checkDay.isAtSameMomentAs(end) || checkDay.isBefore(end))) {
          absence = a;
          break;
        }
      }
    }

    if (absence != null) {
      final isVacation = absence.type == AbsenceType.vacation;
      return pw.Container(
        alignment: pw.Alignment.center,
        height: 30,
        color: isVacation ? PdfColors.orange50 : PdfColors.red50,
        child: pw.Text(
          isVacation ? 'FÉRIAS' : 'AUSENTE',
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(fontSize: 6, fontWeight: pw.FontWeight.bold, color: isVacation ? PdfColors.orange800 : PdfColors.red800),
        ),
      );
    }

    final entry = entries.firstWhere(
      (e) => e.employeeId == employee.id &&
             e.date.year == day.year &&
             e.date.month == day.month &&
             e.date.day == day.day,
      orElse: () => HRScheduleEntry(
        id: '',
        employeeId: employee.id,
        institutionId: employee.institutionId ?? '',
        date: day,
        shiftId: '',
      ),
    );

    final String text;
    final PdfColor bgColor;
    final PdfColor textColor;

    if (entry.isOffDay) {
      text = 'FOLGA';
      bgColor = PdfColors.grey100;
      textColor = PdfColors.grey600;
    } else if (entry.shiftId != null && entry.shiftId!.isNotEmpty) {
      final start = entry.customStartTime;
      final end = entry.customEndTime;
      text = '$start\n$end';
      bgColor = PdfColors.green50;
      textColor = PdfColors.green800;
    } else {
      text = '-';
      bgColor = PdfColors.white;
      textColor = PdfColors.grey400;
    }

    return pw.Container(
      alignment: pw.Alignment.center,
      height: 30,
      color: bgColor,
      child: pw.Text(
        text,
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: textColor),
      ),
    );
  }

  static Future<void> generateAndPrintDetailedReport({
    required List<UserModel> staff,
    required List<HRScheduleEntry> entries,
    required List<HRAbsence> absences,
    required DateTime start,
    required DateTime end,
    required String institutionName,
    bool isSingleEmployee = false,
  }) async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.interRegular();
    final fontBold = await PdfGoogleFonts.interBold();

    final days = <DateTime>[];
    for (var date = start; date.isBefore(end.add(const Duration(days: 1))); date = date.add(const Duration(days: 1))) {
      days.add(date);
    }

    final relevantAbsences = absences.where((a) {
      final isEmployeeMatch = staff.any((e) => e.id == a.employeeId);
      if (!isEmployeeMatch) return false;
      
      final checkStart = DateTime(a.startDate.year, a.startDate.month, a.startDate.day);
      final checkEnd = DateTime(a.endDate.year, a.endDate.month, a.endDate.day);
      
      final reportStart = DateTime(start.year, start.month, start.day);
      final reportEnd = DateTime(end.year, end.month, end.day);
      
      return (checkStart.isBefore(reportEnd) || checkStart.isAtSameMomentAs(reportEnd)) &&
             (checkEnd.isAfter(reportStart) || checkEnd.isAtSameMomentAs(reportStart));
    }).toList();

    relevantAbsences.sort((a, b) => a.startDate.compareTo(b.startDate));

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        header: (pw.Context context) {
          return pw.Column(
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        isSingleEmployee
                            ? 'Relatório Individual de Escala e Assiduidade'
                            : 'Escala e Ausências para Contabilidade',
                        style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900),
                      ),
                      pw.Text(institutionName, style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Período: ${DateFormat('dd/MM/yyyy').format(start)} - ${DateFormat('dd/MM/yyyy').format(end)}', style: const pw.TextStyle(fontSize: 9)),
                      pw.Text('Gerado em: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 10),
              pw.Divider(color: PdfColors.grey300),
              pw.SizedBox(height: 8),
            ],
          );
        },
        build: (pw.Context context) {
          return [
            pw.Text('Mapa de Escala de Trabalho', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800)),
            pw.SizedBox(height: 8),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(2.5),
                for (int i = 0; i < days.length; i++) i + 1: const pw.FlexColumnWidth(1),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.blue800),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Text('Colaborador', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 8)),
                    ),
                    for (var day in days)
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(3),
                        child: pw.Center(
                          child: pw.Column(
                            children: [
                              pw.Text(DateFormat('E', 'pt_PT').format(day).toUpperCase(), style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 5)),
                              pw.Text(DateFormat('dd/MM').format(day), style: pw.TextStyle(color: PdfColors.white, fontSize: 5)),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                for (var employee in staff) ...[
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(employee.name, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7)),
                            pw.Text(employee.role.name.toUpperCase(), style: const pw.TextStyle(fontSize: 5, color: PdfColors.grey600)),
                          ],
                        ),
                      ),
                      for (var day in days) ...[
                        _buildScheduleCellWithAbsences(employee, day, entries, absences),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ];
        },
      ),
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        header: (pw.Context context) {
          return pw.Column(
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        isSingleEmployee
                            ? 'Resumo de Faltas e Férias - Colaborador'
                            : 'Resumo de Ausências para Contabilidade',
                        style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900),
                      ),
                      pw.Text(institutionName, style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
                    ],
                  ),
                  pw.Text('Pág. ${context.pageNumber}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey500)),
                ],
              ),
              pw.SizedBox(height: 8),
              pw.Divider(color: PdfColors.grey300),
              pw.SizedBox(height: 10),
            ],
          );
        },
        build: (pw.Context context) {
          return [
            pw.Text(
              'Detalhamento de Períodos de Ausência',
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800),
            ),
            pw.SizedBox(height: 5),
            pw.Text(
              'Este relatório resume as faltas, licenças e períodos de férias registados e aprovados para efeitos de contabilidade e processamento salarial.',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
            ),
            pw.SizedBox(height: 15),

            if (relevantAbsences.isEmpty)
              pw.Container(
                padding: const pw.EdgeInsets.all(15),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Center(
                  child: pw.Text(
                    'Não foram registadas ausências no período selecionado.',
                    style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
                  ),
                ),
              )
            else
              pw.TableHelper.fromTextArray(
                headers: [
                  if (!isSingleEmployee) 'Colaborador',
                  'Período de Ausência',
                  'Dias',
                  'Tipo de Ausência',
                  'Motivo / Descrição',
                  'Remunerado',
                  'Estado'
                ],
                data: relevantAbsences.map((a) {
                  final employee = staff.firstWhere((e) => e.id == a.employeeId, orElse: () => UserModel(id: '', email: '', name: 'N/A', role: UserRole.teacher, adConsent: false, dataConsent: false));
                  final typeLabel = _getAbsenceTypeLabel(a.type);
                  final periodStr = '${DateFormat('dd/MM/yyyy').format(a.startDate)} a ${DateFormat('dd/MM/yyyy').format(a.endDate)}';
                  
                  final isPaidStr = a.isPaid ? 'Sim (Remunerado)' : 'Não (Não Remunerado)';
                  
                  String statusStr = 'Pendente';
                  if (a.status == 'approved') statusStr = 'Aprovada';
                  if (a.status == 'rejected') statusStr = 'Rejeitada';

                  return [
                    if (!isSingleEmployee) employee.name,
                    periodStr,
                    '${a.days} d',
                    typeLabel,
                    a.description.isNotEmpty ? a.description : '-',
                    isPaidStr,
                    statusStr,
                  ];
                }).toList(),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 8),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.blue800),
                cellAlignment: pw.Alignment.centerLeft,
                cellStyle: const pw.TextStyle(fontSize: 8),
                columnWidths: {
                  if (!isSingleEmployee) 0: const pw.FlexColumnWidth(2),
                  if (!isSingleEmployee) 1: const pw.FlexColumnWidth(2.2) else 0: const pw.FlexColumnWidth(2.2),
                  if (!isSingleEmployee) 2: const pw.FlexColumnWidth(0.8) else 1: const pw.FlexColumnWidth(0.8),
                  if (!isSingleEmployee) 3: const pw.FlexColumnWidth(2) else 2: const pw.FlexColumnWidth(2),
                  if (!isSingleEmployee) 4: const pw.FlexColumnWidth(3) else 3: const pw.FlexColumnWidth(3),
                  if (!isSingleEmployee) 5: const pw.FlexColumnWidth(1.8) else 4: const pw.FlexColumnWidth(1.8),
                  if (!isSingleEmployee) 6: const pw.FlexColumnWidth(1.2) else 5: const pw.FlexColumnWidth(1.2),
                },
              ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: 'Escalas_e_Ausencias_${institutionName.replaceAll(' ', '_')}_${DateFormat('yyyyMMdd').format(start)}.pdf',
    );
  }

  static Future<void> generateAndPrintInstitutionClosedMap({

    required InstitutionModel institution,
    required List<Map<String, dynamic>> closedDays,
  }) async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.interRegular();
    final fontBold = await PdfGoogleFonts.interBold();

    // Map day integers to Portuguese weekday names
    final ptWeekdays = {
      1: 'Segunda-feira',
      2: 'Terça-feira',
      3: 'Quarta-feira',
      4: 'Quinta-feira',
      5: 'Sexta-feira',
      6: 'Sábado',
      7: 'Domingo',
    };

    final closedWeekdays = [1, 2, 3, 4, 5, 6, 7]
        .where((d) => !institution.workingDays.contains(d))
        .map((d) => ptWeekdays[d] ?? '')
        .toList();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        build: (pw.Context context) {
          return [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Mapa de Fecho e Períodos de Encerramento', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.red900)),
                    pw.Text(institution.name, style: const pw.TextStyle(fontSize: 14, color: PdfColors.grey700)),
                  ],
                ),
                pw.Text('Gerado em: ${DateFormat('dd/MM/yyyy').format(DateTime.now())}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey500)),
              ],
            ),
            pw.SizedBox(height: 15),
            pw.Divider(color: PdfColors.grey300),
            pw.SizedBox(height: 15),
            
            pw.Text('Encerramento Semanal Regular', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800)),
            pw.SizedBox(height: 8),
            if (closedWeekdays.isEmpty)
              pw.Text('A instituição funciona todos os dias da semana.', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700))
            else
              pw.Text(
                'Dias de encerramento semanal: ${closedWeekdays.join(', ')}.',
                style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700, fontStyle: pw.FontStyle.italic),
              ),

            pw.SizedBox(height: 25),
            pw.Text('Períodos de Fecho Anual, Férias Coletivas e Formação', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800)),
            pw.SizedBox(height: 10),

            if (closedDays.isEmpty)
              pw.Container(
                padding: const pw.EdgeInsets.all(15),
                decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                child: pw.Center(child: pw.Text('Não existem períodos de fecho registados para o ano letivo.', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey500))),
              )
            else
              pw.TableHelper.fromTextArray(
                headers: ['Designação / Motivo', 'Data de Início', 'Data de Fim', 'Tipo de Fecho'],
                data: closedDays.map((c) {
                  final start = (c['startDate'] as DateTime?) ?? DateTime.now();
                  final end = (c['endDate'] as DateTime?) ?? DateTime.now();
                  final typeStr = c['type'] == 'holiday'
                      ? 'Feriado'
                      : c['type'] == 'training'
                          ? 'Formação Geral'
                          : 'Encerramento Geral';
                  return [
                    c['name'] ?? 'N/A',
                    DateFormat('dd/MM/yyyy').format(start),
                    DateFormat('dd/MM/yyyy').format(end),
                    typeStr,
                  ];
                }).toList(),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.red800),
                cellAlignment: pw.Alignment.centerLeft,
                cellStyle: const pw.TextStyle(fontSize: 9),
              ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: 'Mapa_Fecho_${institution.name.replaceAll(' ', '_')}.pdf',
    );
  }
}
