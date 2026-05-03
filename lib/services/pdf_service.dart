import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import '../models/subject_model.dart';
import '../models/institution_model.dart';
import '../models/questionnaire_model.dart';
import '../models/user_model.dart';
import '../models/institution_organ_model.dart';
import '../models/activity_model.dart';
import '../models/annual_report_draft.dart';
import '../models/survey_response_summary_model.dart';
import '../models/hr/hr_attendance_model.dart';
import '../models/finance/finance_models.dart';
import '../models/hr/hr_absence_model.dart';
import '../models/hr/hr_schedule_model.dart';
import '../models/procurement/procurement_models.dart';

class PdfService {
  static Future<pw.ImageProvider?> _fetchLogo(String? url) async {
    if (url == null || url.isEmpty) return null;
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        return pw.MemoryImage(response.bodyBytes);
      }
    } catch (e) {
      // Error loading logo for PDF
    }
    return null;
  }

  static pw.Widget _buildHeader(pw.Context? context, String title,
      InstitutionModel? institution, pw.ImageProvider? logoImage) {
    return pw.Container(
      width: 485,
      padding: const pw.EdgeInsets.only(bottom: 5),
      decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.indigo900, width: 2))),
      child: pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        mainAxisAlignment: pw.MainAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 60,
            height: 60,
            child: logoImage != null
              ? pw.Image(logoImage)
              : pw.Container(
                  decoration: const pw.BoxDecoration(
                    color: PdfColors.grey300,
                    shape: pw.BoxShape.circle,
                  ),
                  child: pw.Center(
                    child: pw.Text('LOGO',
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white))),
                ),
          ),
          pw.SizedBox(width: 15), 
          pw.SizedBox(
            width: 410,
            child: pw.Column(
              mainAxisSize: pw.MainAxisSize.min,
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(institution?.name ?? 'EduGaming', 
                  style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900),
                  textAlign: pw.TextAlign.right),
                pw.Text(title, 
                  style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                  textAlign: pw.TextAlign.right),
                if (context != null)
                  pw.Text('Página ${context.pageNumber}', 
                    style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
                    textAlign: pw.TextAlign.right),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Future<void> generateProgramPDF(Subject subject,
      {InstitutionModel? institution}) async {
    final pdf = pw.Document();
    final logoImage = await _fetchLogo(institution?.logoUrl);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        header: (context) => _buildHeader(
            context, 'Programa da Disciplina', institution, logoImage),
        build: (pw.Context context) {
          return [
            pw.Text('Programa da Disciplina: ${subject.name}',
                style:
                    pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            pw.Text('Área Científica: ${subject.scientificArea ?? "N/A"}'),
            pw.Text('Ano Académico: ${subject.academicYear}'),
            pw.Text('Nível: ${subject.level}'),
            pw.SizedBox(height: 20),
            if (subject.programDescription != null &&
                subject.programDescription!.isNotEmpty) ...[
              pw.Text('DESCRIÇÃO DO PROGRAMA',
                  style: pw.TextStyle(
                      fontSize: 16, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              pw.Text(subject.programDescription!,
                  style: const pw.TextStyle(fontSize: 11)),
              pw.SizedBox(height: 20),
            ],
            pw.Text('PROGRAMA INDICATIVO',
                style:
                    pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            pw.TableHelper.fromTextArray(
              headers: ['Sessão', 'Data', 'Tópico', 'Bibliografia'],
              data: subject.sessions
                  .map((s) => [
                        s.sessionNumber.toString(),
                        DateFormat('dd/MM/yyyy').format(s.date),
                        s.topic,
                        s.bibliography,
                      ])
                  .toList(),
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save());
  }

  static Future<void> generateSummariesPDF(
      Subject subject, List<Attendance> attendances,
      {InstitutionModel? institution, bool includeAttendance = true}) async {
    final pdf = pw.Document();
    final logoImage = await _fetchLogo(institution?.logoUrl);
    final finalized = subject.sessions.where((s) => s.isFinalized).toList();
    finalized.sort((a, b) => a.sessionNumber.compareTo(b.sessionNumber));

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        header: (context) => _buildHeader(
            context,
            includeAttendance
                ? 'Relatório de Sumários e Presenças'
                : 'Relatório de Sumários',
            institution,
            logoImage),
        build: (pw.Context context) {
          return [
            pw.Text(
                includeAttendance
                    ? 'Relatório de Sumários e Presenças: ${subject.name}'
                    : 'Relatório de Sumários: ${subject.name}',
                style:
                    pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 20),
            ...finalized.map((s) {
              final sessionAttendances =
                  attendances.where((a) => a.sessionId == s.id).toList();
              return pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 20),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Sessão ${s.sessionNumber}: ${s.topic}',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.Text(
                        'Data: ${DateFormat('dd/MM/yyyy').format(s.date)} ${s.startTime ?? ""} - ${s.endTime ?? ""}'),
                    pw.SizedBox(height: 5),
                    pw.Text('SUMÁRIO:',
                        style: pw.TextStyle(
                            fontSize: 10, fontWeight: pw.FontWeight.bold)),
                    pw.Text(s.finalSummary ?? '',
                        style: const pw.TextStyle(fontSize: 10)),
                    if (includeAttendance) ...[
                      pw.SizedBox(height: 5),
                      pw.Text('PRESENÇAS (${sessionAttendances.length}):',
                          style: pw.TextStyle(
                              fontSize: 10, fontWeight: pw.FontWeight.bold)),
                      pw.Text(
                          sessionAttendances.map((a) => a.userName).join(', '),
                          style: const pw.TextStyle(fontSize: 9)),
                    ],
                    pw.Divider(),
                  ],
                ),
              );
            }),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save());
  }

  static Future<Uint8List> generateCertificate({
    required InstitutionModel institution,
    required UserModel teacher,
    required Subject subject,
    required String studentName,
    required double finalGrade,
    required String qualitativeGrade,
    required DateTime date,
    dynamic enrollment, // Kept for compatibility if needed
  }) async {
    final pdf = pw.Document();
    final logoImage = await _fetchLogo(institution.logoUrl);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        build: (pw.Context context) {
          return pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.amber, width: 4),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
            ),
            padding: const pw.EdgeInsets.all(40),
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                if (logoImage != null)
                  pw.Image(logoImage, width: 100, height: 100),
                pw.SizedBox(height: 20),
                pw.Text('CERTIFICADO DE APROVEITAMENTO',
                    style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.indigo900)),
                pw.SizedBox(height: 30),
                pw.Text('Certifica-se que',
                    style: const pw.TextStyle(fontSize: 16)),
                pw.SizedBox(height: 10),
                pw.Text(studentName,
                    style: pw.TextStyle(
                        fontSize: 32,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.black)),
                pw.SizedBox(height: 10),
                pw.Text('concluiu com sucesso a disciplina de',
                    style: const pw.TextStyle(fontSize: 16)),
                pw.SizedBox(height: 5),
                pw.Text(subject.name,
                    style: pw.TextStyle(
                        fontSize: 22,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.indigo700)),
                pw.SizedBox(height: 20),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  children: [
                    pw.Text('Classificação Final: ',
                        style: const pw.TextStyle(fontSize: 18)),
                    pw.Text('$finalGrade / 20 ($qualitativeGrade)',
                        style: pw.TextStyle(
                            fontSize: 18, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
                pw.Spacer(),
                pw.Divider(thickness: 1, color: PdfColors.grey300),
                pw.SizedBox(height: 10),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      children: [
                        pw.Text(teacher.name,
                            style:
                                pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        pw.Text('O Docente',
                            style: const pw.TextStyle(fontSize: 10)),
                      ],
                    ),
                    pw.Column(
                      children: [
                        pw.Text(institution.name,
                            style:
                                pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        pw.Text('A Instituição',
                            style: const pw.TextStyle(fontSize: 10)),
                      ],
                    ),
                    pw.Column(
                      children: [
                        pw.Text(DateFormat('dd/MM/yyyy').format(date),
                            style:
                                pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        pw.Text('Data de Emissão',
                            style: const pw.TextStyle(fontSize: 10)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  static Future<Uint8List> generateTranscriptPdf({
    required InstitutionModel institution,
    required Subject subject,
    required List<Enrollment> students,
    required List<EvaluationComponent> components,
    required Map<String, Map<String, String>> grades,
    required bool isFull,
    String? sealedByUserName,
    dynamic student, // Kept for compatibility
  }) async {
    final pdf = pw.Document();
    final logoImage = await _fetchLogo(institution.logoUrl);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        header: (context) =>
            _buildHeader(context, 'Pauta de Avaliação', institution, logoImage),
        build: (pw.Context context) {
          return [
            pw.Header(level: 0, text: 'Pauta de Avaliação: ${subject.name}'),
            pw.SizedBox(height: 10),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Nível: ${subject.level}'),
                pw.Text('Ano: ${subject.academicYear}'),
              ],
            ),
            pw.SizedBox(height: 20),
            pw.TableHelper.fromTextArray(
              headers: [
                'Estudante',
                ...components
                    .map((c) => '${c.name}\n(${(c.weight * 100).toInt()}%)'),
                'Final',
              ],
              data: students.map((s) {
                final studentGrades = grades[s.userId] ?? {};
                return [
                  s.studentName,
                  ...components.map((c) => studentGrades[c.id] ?? '-'),
                  studentGrades['final'] ?? '-',
                ];
              }).toList(),
              headerStyle:
                  pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
              cellStyle: const pw.TextStyle(fontSize: 9),
              cellAlignment: pw.Alignment.center,
              headerDecoration:
                  const pw.BoxDecoration(color: PdfColors.grey200),
            ),
            if (sealedByUserName != null) ...[
              pw.SizedBox(height: 40),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Column(
                  children: [
                    pw.Text('Lacrado eletronicamente por:',
                        style: const pw.TextStyle(fontSize: 10)),
                    pw.Text(sealedByUserName,
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.Text(
                        DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now()),
                        style: const pw.TextStyle(fontSize: 8)),
                  ],
                ),
              ),
            ],
          ];
        },
      ),
    );

    return pdf.save();
  }

  static Future<void> downloadPdf(Uint8List bytes, String fileName) async {
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => bytes,
      name: fileName,
    );
  }

  static Future<Uint8List> generateAssessmentReport({
    String? title,
    String? subtitle,
    required String content,
    bool isSynthetic = true,
    AdvancedScoreStats? stats,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        header: (context) => pw.Column(
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('EduGaming - Relatório de Avaliação',
                    style: pw.TextStyle(fontSize: 10, color: PdfColors.grey)),
                pw.Text(DateFormat('dd/MM/yyyy').format(DateTime.now()),
                    style: pw.TextStyle(fontSize: 10, color: PdfColors.grey)),
              ],
            ),
            pw.Divider(color: PdfColors.grey300),
            pw.SizedBox(height: 10),
          ],
        ),
        build: (pw.Context context) {
          return [
            pw.Header(level: 0, text: title ?? 'Relatório de Avaliação'),
            if (subtitle != null) ...[
              pw.Text(subtitle,
                  style: pw.TextStyle(fontSize: 14, color: PdfColors.grey700)),
              pw.SizedBox(height: 20),
            ],
            if (stats != null) ...[
              pw.Header(level: 1, text: 'Indicadores de Desempenho'),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  _buildStatBox('Média', stats.average.toStringAsFixed(1)),
                  _buildStatBox('Mínima', stats.min.toStringAsFixed(1)),
                  _buildStatBox('Máxima', stats.max.toStringAsFixed(1)),
                ],
              ),
              pw.SizedBox(height: 20),
            ],
            pw.Header(level: 1, text: 'Análise Detalhada'),
            pw.Paragraph(
              text: content,
              style: pw.TextStyle(fontSize: 11, lineSpacing: 2),
            ),
            pw.SizedBox(height: 40),
            pw.Divider(color: PdfColors.grey300),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text('Gerado por EduGaming AI',
                  style: const pw.TextStyle(
                      fontSize: 8, color: PdfColors.grey500)),
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildStatBox(String label, String value) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
      ),
      child: pw.Column(
        children: [
          pw.Text(label,
              style:
                  const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
          pw.SizedBox(height: 5),
          pw.Text(value,
              style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue900)),
        ],
      ),
    );
  }

  static Future<Uint8List> generateStudentExamReport({
    required AiGame game,
    required AiGameResult result,
    required String studentName,
  }) async {
    final pdf = pw.Document();
    final maxScore = game.questions.fold(0.0, (sum, q) => sum + q.points);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        header: (context) => pw.Column(
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('EduGaming - Detalhes da Prova',
                    style: pw.TextStyle(fontSize: 10, color: PdfColors.grey)),
                pw.Text(DateFormat('dd/MM/yyyy HH:mm').format(result.playedAt),
                    style: pw.TextStyle(fontSize: 10, color: PdfColors.grey)),
              ],
            ),
            pw.Divider(color: PdfColors.grey300),
            pw.SizedBox(height: 10),
          ],
        ),
        build: (pw.Context context) {
          return [
            pw.Header(level: 0, text: 'Relatório de Desempenho do Aluno'),
            pw.Text('Aluno: $studentName',
                style:
                    pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.Text('Atividade: ${game.title}',
                style: const pw.TextStyle(fontSize: 14)),
            pw.SizedBox(height: 10),
            pw.Container(
              padding: const pw.EdgeInsets.all(15),
              decoration: pw.BoxDecoration(
                color: PdfColors.blue50,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  pw.Column(children: [
                    pw.Text('Pontuação Final',
                        style: const pw.TextStyle(fontSize: 10)),
                    pw.Text('${result.score.toInt()} / ${maxScore.toInt()}',
                        style: pw.TextStyle(
                            fontSize: 24,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blue900)),
                  ]),
                  pw.Column(children: [
                    pw.Text('Aproveitamento',
                        style: const pw.TextStyle(fontSize: 10)),
                    pw.Text(
                        '${((result.score / maxScore) * 100).toStringAsFixed(1)}%',
                        style: pw.TextStyle(
                            fontSize: 24,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.indigo900)),
                  ]),
                ],
              ),
            ),
            pw.SizedBox(height: 20),
            pw.Header(level: 1, text: 'Respostas Detalhadas'),
            ...List.generate(game.questions.length, (index) {
              final q = game.questions[index];
              final isCorrect = result.correctAnswers.contains(index);
              final teacherAdj = result.teacherAdjustments[index];
              final score = teacherAdj ?? (isCorrect ? q.points : 0.0);
              final response = result.studentResponses[index];

              return pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 15),
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey200),
                  borderRadius:
                      const pw.BorderRadius.all(pw.Radius.circular(5)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Pergunta ${index + 1}',
                            style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold, fontSize: 10)),
                        pw.Text('${score.toDouble()} / ${q.points}',
                            style: pw.TextStyle(
                                color: score > 0
                                    ? PdfColors.green900
                                    : PdfColors.red900,
                                fontSize: 10)),
                      ],
                    ),
                    pw.SizedBox(height: 5),
                    pw.Text(q.question,
                        style: const pw.TextStyle(fontSize: 11)),
                    if (response != null) ...[
                      pw.SizedBox(height: 5),
                      pw.Text(
                          'Resposta do Aluno: ${response['value'] ?? 'N/A'}',
                          style: pw.TextStyle(
                              fontSize: 10,
                              color: PdfColors.grey700,
                              fontStyle: pw.FontStyle.italic)),
                    ],
                  ],
                ),
              );
            }),
          ];
        },
      ),
    );

    return pdf.save();
  }

  static Future<void> generateLifestyleReport(Questionnaire questionnaire,
      List<QuestionnaireResponse> responses, Map<String, dynamic> aiAnalysis,
      {InstitutionModel? institution}) async {
    final pdf = pw.Document();
    final logoImage = await _fetchLogo(institution?.logoUrl);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        header: (context) => _buildHeader(context,
            'Relatório de Estilo de Vida Saudável', institution, logoImage),
        build: (pw.Context context) {
          return [
            pw.Header(
                level: 0,
                child: pw.Text('Inquérito: ${questionnaire.title}',
                    style: pw.TextStyle(
                        fontSize: 22,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.indigo))),
            pw.SizedBox(height: 10),
            pw.Text(questionnaire.description,
                style:
                    const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
            pw.SizedBox(height: 20),
            pw.Header(level: 1, text: 'Resumo Estatístico Descritivo'),
            pw.Paragraph(
                text: aiAnalysis['pdfSummary'] ??
                    'Análise detalhada do bem-estar institucional.'),
            pw.SizedBox(height: 20),
            _buildSectionTitle('Distribuição de Bem-estar (Histograma)'),
            pw.Paragraph(
                text:
                    'Representação gráfica da frequência das respostas dos colaboradores.'),
            _buildHistogramMock(),
            pw.SizedBox(height: 30),
            _buildSectionTitle('Diagrama de Extremos e Quartis (Box Plot)'),
            pw.Paragraph(
                text:
                    'Análise da dispersão e tendência central da qualidade de vida.'),
            _buildBoxPlotMock(),
            pw.SizedBox(height: 30),
            pw.Header(level: 1, text: 'Análise Qualitativa IA'),
            pw.Paragraph(text: aiAnalysis['qualitativeAnalysis'] ?? 'N/A'),
            pw.SizedBox(height: 20),
            pw.Header(level: 1, text: 'Estratégias e Medidas de Melhoria'),
            ...((aiAnalysis['strategies'] as List?) ?? []).map((s) => pw.Bullet(
                text: s.toString(), style: const pw.TextStyle(fontSize: 11))),
            pw.SizedBox(height: 30),
            pw.Header(level: 1, text: 'Histórico de Abrangência e Reaberturas'),
            pw.TableHelper.fromTextArray(
              headers: ['Início', 'Fim', 'Motivo / Contexto'],
              data: [
                [
                  DateFormat('dd/MM/yy').format(questionnaire.startDate),
                  DateFormat('dd/MM/yy').format(questionnaire.endDate),
                  'Lançamento Inicial'
                ],
                ...questionnaire.reopenHistory.map((h) => [
                      DateFormat('dd/MM/yy').format(h.startDate),
                      DateFormat('dd/MM/yy').format(h.endDate),
                      h.reason,
                    ]),
              ],
            ),
            pw.SizedBox(height: 20),
            pw.Footer(
              padding: const pw.EdgeInsets.only(top: 20),
              leading: pw.Text(
                  'Documento gerado e analisado por Inteligência Artificial (Gemini 1.5 Pro)',
                  style: const pw.TextStyle(
                      fontSize: 8, color: PdfColors.grey500)),
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  static pw.Widget _buildSectionTitle(String title) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 10),
      child: pw.Text(title,
          style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.indigo900)),
    );
  }

  static pw.Widget _buildHistogramMock() {
    return pw.Container(
      height: 150,
      child: pw.Chart(
        grid: pw.CartesianGrid(
          xAxis: pw.FixedAxis([0, 1, 2, 3, 4], format: (v) => 'Q${v.toInt()}'),
          yAxis: pw.FixedAxis([0, 5, 10, 15, 20]),
        ),
        datasets: [
          pw.BarDataSet(
            color: PdfColors.blueAccent,
            width: 15,
            data: const [
              pw.PointChartValue(1, 5),
              pw.PointChartValue(2, 12),
              pw.PointChartValue(3, 18),
              pw.PointChartValue(4, 7),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Stack _buildBoxPlotMock() {
    return pw.Stack(
      alignment: pw.Alignment.center,
      children: [
        pw.Container(width: 300, height: 2, color: PdfColors.grey700),
        pw.Positioned(
            left: 50,
            child:
                pw.Container(width: 2, height: 20, color: PdfColors.grey700)),
        pw.Positioned(
            left: 250,
            child:
                pw.Container(width: 2, height: 20, color: PdfColors.grey700)),
        pw.Positioned(
          left: 100,
          child: pw.Container(
            width: 100,
            height: 40,
            decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.indigo900, width: 2),
                color: PdfColors.indigo100),
          ),
        ),
        pw.Positioned(
            left: 150,
            child: pw.Container(width: 2, height: 40, color: PdfColors.red)),
      ],
    );
  }

  static Future<void> generateStatisticsPDF(
      Subject subject, dynamic studentData,
      {InstitutionModel? institution}) async {
    final pdf = pw.Document();
    final logoImage = await _fetchLogo(institution?.logoUrl);

    final data = (studentData as List);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        header: (context) => _buildHeader(context,
            'Relatório Estatístico de Aproveitamento', institution, logoImage),
        build: (pw.Context context) {
          return [
            pw.Text('Relatório Estatístico: ${subject.name}',
                style:
                    pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            pw.Text(
                'Ano Académico: ${subject.academicYear} | Nível: ${subject.level}'),
            pw.SizedBox(height: 20),
            pw.Header(level: 1, text: 'Resumo de Turma'),
            pw.Text('Total de Alunos Analisados: ${data.length}'),
            pw.SizedBox(height: 10),
            pw.TableHelper.fromTextArray(
              headers: [
                'Estudante',
                'Assiduidade (%)',
                'Jogos Treino',
                'Nota Final'
              ],
              data: data
                  .map((s) => [
                        s.studentName,
                        '${s.attendancePercentage.toStringAsFixed(1)}%',
                        s.trainingGamesCount.toString(),
                        s.finalGrade.toStringAsFixed(1),
                      ])
                  .toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              cellAlignment: pw.Alignment.center,
            ),
            pw.SizedBox(height: 30),
            pw.Header(level: 1, text: 'Considerações Finais'),
            pw.Paragraph(
              text:
                  'Este relatório correlaciona a assiduidade e a prática em jogos de treino com o aproveitamento final acadêmico. Alunos com maior frequência de treino tendem a obter melhores classificações.',
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save());
  }

  static Future<void> generateAttendanceMatrixPDF({
    required Subject subject,
    required List<Enrollment> students,
    required List<Attendance> attendances,
    required List<SyllabusSession> finalizedSessions,
    required UserModel teacher,
    InstitutionModel? institution,
  }) async {
    final pdf = pw.Document();
    final logoImage = await _fetchLogo(institution?.logoUrl);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        header: (context) => _buildHeader(
            context, 'Matrix de Presenças', institution, logoImage),
        build: (pw.Context context) {
          return [
            pw.Text('Disciplina: ${subject.name}',
                style:
                    pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.Text('Ano Letivo: ${subject.academicYear}',
                style: const pw.TextStyle(fontSize: 12)),
            pw.Text('Docente: ${teacher.name}',
                style: const pw.TextStyle(fontSize: 12)),
            pw.SizedBox(height: 20),
            pw.TableHelper.fromTextArray(
              headers: [
                'Estudante',
                ...finalizedSessions.map((s) =>
                    'S${s.sessionNumber}\n${DateFormat('dd/MM').format(s.date)}'),
                'Assiduidade (%)',
              ],
              data: students.map((student) {
                int presentCount = 0;
                final sessionData = finalizedSessions.map((s) {
                  final isPresent = attendances.any(
                      (a) => a.userId == student.userId && a.sessionId == s.id);
                  if (isPresent) presentCount++;
                  return isPresent ? 'P' : 'F';
                }).toList();

                final percentage = finalizedSessions.isEmpty
                    ? 100.0
                    : (presentCount / finalizedSessions.length) * 100;

                return [
                  student.studentName,
                  ...sessionData,
                  '${percentage.toStringAsFixed(0)}%',
                ];
              }).toList(),
              headerStyle:
                  pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
              cellStyle: const pw.TextStyle(fontSize: 9),
              cellAlignment: pw.Alignment.center,
              headerDecoration:
                  const pw.BoxDecoration(color: PdfColors.grey200),
            ),
            pw.SizedBox(height: 40),
            pw.Divider(thickness: 1, color: PdfColors.grey300),
            pw.SizedBox(height: 10),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Column(
                  children: [
                    pw.Text('__________________________________________',
                        style: const pw.TextStyle(fontSize: 12)),
                    pw.Text('O Docente: ${teacher.name}',
                        style: pw.TextStyle(
                            fontSize: 10, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Matrix_Presencas_${subject.name}.pdf',
    );
  }

  static Future<void> generateStudentAttendancePDF({
    required Subject subject,
    required List<Attendance> attendances,
    required List<SyllabusSession> finalizedSessions,
    required String studentName,
    required String studentId,
    InstitutionModel? institution,
  }) async {
    final pdf = pw.Document();
    final logoImage = await _fetchLogo(institution?.logoUrl);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        header: (context) => _buildHeader(
            context, 'Folha de Presenças Individual', institution, logoImage),
        build: (pw.Context context) {
          int presentCount = 0;
          final sessionData = finalizedSessions.map((s) {
            final isPresent = attendances
                .any((a) => a.userId == studentId && a.sessionId == s.id);
            if (isPresent) presentCount++;
            return [
              s.sessionNumber.toString(),
              DateFormat('dd/MM/yyyy').format(s.date),
              s.topic,
              isPresent ? 'Presente' : 'Ausente',
            ];
          }).toList();

          final percentage = finalizedSessions.isEmpty
              ? 100.0
              : (presentCount / finalizedSessions.length) * 100;

          return [
            pw.Text('Estudante: $studentName',
                style:
                    pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.Text('Disciplina: ${subject.name}',
                style: const pw.TextStyle(fontSize: 12)),
            pw.Text('Ano Letivo: ${subject.academicYear}',
                style: const pw.TextStyle(fontSize: 12)),
            pw.SizedBox(height: 10),
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: const pw.BoxDecoration(color: PdfColors.grey100),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Total de Sessões: ${finalizedSessions.length}'),
                  pw.Text('Presenças: $presentCount'),
                  pw.Text('Assiduidade: ${percentage.toStringAsFixed(1)}%'),
                ],
              ),
            ),
            pw.SizedBox(height: 20),
            pw.TableHelper.fromTextArray(
              headers: ['Sessão', 'Data', 'Tópico', 'Estado'],
              data: sessionData,
              headerStyle:
                  pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
              cellStyle: const pw.TextStyle(fontSize: 9),
              headerDecoration:
                  const pw.BoxDecoration(color: PdfColors.grey200),
            ),
            if (subject.attendanceControlEnabled) ...[
              pw.SizedBox(height: 20),
              pw.Text(
                'Nota: Esta disciplina requer um mínimo de ${subject.requiredAttendancePercentage}% de presenças.',
                style:
                    pw.TextStyle(fontSize: 9, fontStyle: pw.FontStyle.italic),
              ),
              pw.Text(
                percentage >= subject.requiredAttendancePercentage
                    ? 'O aluno cumpre os critérios de assiduidade.'
                    : 'O aluno NÃO cumpre os critérios de assiduidade.',
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: percentage >= subject.requiredAttendancePercentage
                      ? PdfColors.green900
                      : PdfColors.red900,
                ),
              ),
            ],
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Folha_Presencas_${studentName}_${subject.name}.pdf',
    );
  }

  static Future<void> generateStudentGameReportPDF({
    required Subject subject,
    required AiGame game,
    required AiGameResult result,
    required double averageScore,
    required int ranking,
    InstitutionModel? institution,
  }) async {
    final pdf = pw.Document();
    final logoImage = await _fetchLogo(institution?.logoUrl);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        header: (context) => _buildHeader(context,
            'Relatório de Desempenho - Jogo de Treino', institution, logoImage),
        footer: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 10),
          child: pw.Text(
            'Página ${context.pageNumber} de ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey),
          ),
        ),
        build: (pw.Context context) {
          return [
            pw.Text(game.title,
                style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue900)),
            pw.SizedBox(height: 10),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Estudante: ${result.studentName}',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.Text('Disciplina: ${subject.name}'),
                    pw.Text('Ano Letivo: ${subject.academicYear}'),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                        'Data: ${DateFormat('dd/MM/yyyy').format(result.playedAt)}'),
                    pw.Text(
                        'Hora: ${DateFormat('HH:mm').format(result.playedAt)}'),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 30),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                _buildColoredStatBox('A Tua Pontuação',
                    result.score.toStringAsFixed(1), PdfColors.blue),
                _buildColoredStatBox('Média Global',
                    averageScore.toStringAsFixed(1), PdfColors.grey700),
                _buildColoredStatBox(
                    'Posição Ranking', '#$ranking', PdfColors.amber700),
              ],
            ),
            pw.SizedBox(height: 40),
            pw.Text('RESUMO DE RESPOSTAS',
                style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue900)),
            pw.Divider(thickness: 1, color: PdfColors.blue900),
            pw.SizedBox(height: 10),
            pw.TableHelper.fromTextArray(
              headers: ['#', 'Pergunta', 'Resultado', 'Referência de Estudo'],
              headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration:
                  const pw.BoxDecoration(color: PdfColors.blue900),
              cellAlignment: pw.Alignment.centerLeft,
              columnWidths: {
                0: const pw.FixedColumnWidth(20),
                1: const pw.FlexColumnWidth(3),
                2: const pw.FixedColumnWidth(60),
                3: const pw.FlexColumnWidth(2),
              },
              data: List.generate(game.questions.length, (index) {
                final q = game.questions[index];
                final isCorrect = result.correctAnswers.contains(index);
                return [
                  (index + 1).toString(),
                  q.question,
                  isCorrect ? 'CERTO' : 'ERRADO',
                  !isCorrect
                      ? (q.studyReference != null
                          ? 'Deve ler o ${q.studyReference} que fala do tema no documento: ${subject.contents.where((c) => game.sourceContentIds.contains(c.id)).map((c) => c.name).join(", ")}'
                          : 'Deve consultar os conteúdos: ${subject.contents.where((c) => game.sourceContentIds.contains(c.id)).map((c) => c.name).join(", ")}')
                      : '-',
                ];
              }),
              cellStyle: const pw.TextStyle(fontSize: 10),
              rowDecoration: const pw.BoxDecoration(
                  border: pw.Border(
                      bottom: pw.BorderSide(color: PdfColors.grey300))),
            ),
            pw.SizedBox(height: 40),
            pw.Container(
              padding: const pw.EdgeInsets.all(15),
              decoration: pw.BoxDecoration(
                color: PdfColors.blue50,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
                border: pw.Border.all(color: PdfColors.blue200),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('DICA PARA O TEU SUCESSO',
                      style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue900)),
                  pw.SizedBox(height: 5),
                  pw.Text(
                      'Foca-te nas perguntas assinaladas como "ERRADO" e consulta as referências de estudo indicadas na tabela acima para consolidar o teu conhecimento sobre esses temas específicos.',
                      style: const pw.TextStyle(
                          fontSize: 10, color: PdfColors.blue900)),
                ],
              ),
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Relatorio_Jogo_${game.title}_${result.studentName}.pdf',
    );
  }

  static pw.Widget _buildColoredStatBox(
      String label, String value, PdfColor color) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      width: 120,
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: color, width: 2),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Column(
        children: [
          pw.Text(label,
              style:
                  const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
          pw.SizedBox(height: 5),
          pw.Text(value,
              style: pw.TextStyle(
                  fontSize: 20, fontWeight: pw.FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  static Future<void> generateMeetingMinutesPDF({
    required InstitutionOrgan organ,
    required Meeting meeting,
    InstitutionModel? institution,
  }) async {
    final fontRegular = await PdfGoogleFonts.robotoRegular();
    final fontBold = await PdfGoogleFonts.robotoBold();

    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(
        base: fontRegular,
        bold: fontBold,
      ),
    );
    final logoImage = await _fetchLogo(institution?.logoUrl);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        header: (context) =>
            _buildHeader(context, 'Ata de Reunião', institution, logoImage),
        build: (pw.Context context) {
          return [
            pw.Center(
              child: pw.Text('ATA DE REUNIÃO - ${organ.name.toUpperCase()}',
                  style: pw.TextStyle(
                      fontSize: 16, fontWeight: pw.FontWeight.bold)),
            ),
            pw.SizedBox(height: 20),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                    'Data: ${DateFormat('dd/MM/yyyy').format(meeting.date)}'),
                pw.Text('Início: ${DateFormat('HH:mm').format(meeting.date)}'),
              ],
            ),
            pw.SizedBox(height: 10),
            pw.Text('Assunto: ${meeting.title}',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 20),
            pw.Header(level: 1, text: '1. Ordem de Trabalhos / Conteúdo'),
            pw.Paragraph(
              text: meeting.minutes ?? 'Nenhuma ata gerada ainda.',
              style: const pw.TextStyle(fontSize: 11, lineSpacing: 2),
            ),
            pw.SizedBox(height: 40),
            pw.Header(level: 1, text: '2. Assinaturas'),
            pw.SizedBox(height: 20),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                pw.Column(
                  children: [
                    pw.Text('_____________________________'),
                    pw.Text('Presidente / Secretário',
                        style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
                pw.Column(
                  children: [
                    pw.Text('_____________________________'),
                    pw.Text('Interveniente',
                        style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 50),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text('Gerado eletronicamente por EduGaming AI',
                  style:
                      const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name:
          'Ata_${organ.name}_${DateFormat('yyyyMMdd').format(meeting.date)}.pdf',
    );
  }

  static Future<void> generateAttendanceSheetPDF({
    required InstitutionOrgan organ,
    required Meeting meeting,
    InstitutionModel? institution,
  }) async {
    final fontRegular = await PdfGoogleFonts.robotoRegular();
    final fontBold = await PdfGoogleFonts.robotoBold();

    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(
        base: fontRegular,
        bold: fontBold,
      ),
    );
    final logoImage = await _fetchLogo(institution?.logoUrl);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        header: (context) =>
            _buildHeader(context, 'Folha de Presenças', institution, logoImage),
        build: (pw.Context context) {
          return [
            pw.Center(
              child: pw.Text('FOLHA DE PRESENÇAS: ${organ.name.toUpperCase()}',
                  style: pw.TextStyle(
                      fontSize: 16, fontWeight: pw.FontWeight.bold)),
            ),
            pw.SizedBox(height: 20),
            pw.Text('Reunião: ${meeting.title}',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Text('Data: ${DateFormat('dd/MM/yyyy').format(meeting.date)}'),
            pw.SizedBox(height: 20),
            pw.Header(level: 1, text: 'Ordem de Trabalhos (Agenda)'),
            pw.Text(meeting.agenda ?? 'Nenhuma agenda definida.',
                style: const pw.TextStyle(fontSize: 10)),
            pw.SizedBox(height: 30),
            pw.Header(level: 1, text: 'Quadro de Presenças / Assinaturas'),
            pw.TableHelper.fromTextArray(
              headers: [
                'Nome do Participante',
                'E-mail',
                'Presença',
                'Assinatura'
              ],
              data: meeting.participants
                  .map((p) => [
                        p.name,
                        p.email,
                        p.status.contains('attended') ? 'Presente' : '---',
                        '', // Space for signature
                      ])
                  .toList(),
              headerStyle:
                  pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
              cellStyle: const pw.TextStyle(fontSize: 9),
              headerDecoration:
                  const pw.BoxDecoration(color: PdfColors.grey200),
              cellHeight: 30,
            ),
            pw.SizedBox(height: 30),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text('Gerado por EduGaming AI',
                  style:
                      const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name:
          'Presencas_${organ.name}_${DateFormat('yyyyMMdd').format(meeting.date)}.pdf',
    );
  }

  static Future<void> generateConvocatoriaPDF({
    required InstitutionOrgan organ,
    required Meeting meeting,
    InstitutionModel? institution,
  }) async {
    final pdf = pw.Document();
    final logoImage = await _fetchLogo(institution?.logoUrl);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        header: (context) => _buildHeader(
            context, 'Convocatória de Reunião', institution, logoImage),
        build: (pw.Context context) {
          return [
            pw.Center(
              child: pw.Text('CONVOCATÓRIA',
                  style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.indigo900)),
            ),
            pw.SizedBox(height: 30),
            pw.Text(
                'Nos termos legais, convoca-se o(a) ${organ.name} para uma reunião a realizar-se com os seguintes detalhes:'),
            pw.SizedBox(height: 20),
            pw.Container(
              padding: const pw.EdgeInsets.all(15),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Assunto: ${meeting.title}',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 8),
                  pw.Text(
                      'Data: ${DateFormat('dd/MM/yyyy').format(meeting.date)}'),
                  pw.Text(
                      'Horário: ${meeting.startTime != null ? DateFormat('HH:mm').format(meeting.startTime!) : '--:--'} às ${meeting.endTime != null ? DateFormat('HH:mm').format(meeting.endTime!) : '--:--'}'),
                  pw.Text('Local: ${meeting.location ?? 'Sede da Empresa'}'),
                ],
              ),
            ),
            pw.SizedBox(height: 30),
            pw.Header(level: 1, text: 'Ordem de Trabalhos (Agenda)'),
            pw.Paragraph(
              text: meeting.agenda ?? 'A definir.',
              style: const pw.TextStyle(fontSize: 11, lineSpacing: 1.5),
            ),
            pw.SizedBox(height: 30),
            pw.Header(level: 1, text: 'Convocados'),
            pw.TableHelper.fromTextArray(
              headers: ['Nome', 'Cargo / E-mail'],
              data: meeting.participants
                  .map((p) => [
                        p.name,
                        p.email,
                      ])
                  .toList(),
              headerStyle:
                  pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
              cellStyle: const pw.TextStyle(fontSize: 9),
            ),
            pw.SizedBox(height: 40),
            pw.Text('A Administração / Direção',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 40),
            pw.Divider(thickness: 1, color: PdfColors.grey300),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text('Gerado por EduGaming AI',
                  style:
                      const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name:
          'Convocatoria_${organ.name}_${DateFormat('yyyyMMdd').format(meeting.date)}.pdf',
    );
  }
  static Future<void> generateAnnualReportPDF(
      InstitutionModel institution, List<InstitutionalActivity> activities, {AnnualReportDraft? draft}) async {
    WidgetsFlutterBinding.ensureInitialized();
    
    pw.Font? fontRegular;
    pw.Font? fontBold;
    pw.Font? fontItalic;

    try {
      fontRegular = await PdfGoogleFonts.robotoRegular();
      fontBold = await PdfGoogleFonts.robotoBold();
      fontItalic = await PdfGoogleFonts.robotoItalic();
    } catch (e) {
      debugPrint('Error loading Google Fonts for PDF: $e');
    }

    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(
        base: fontRegular,
        bold: fontBold,
        italic: fontItalic,
      ),
    );
    final logoImage = await _fetchLogo(institution.logoUrl);
    final signatureImage = await _fetchLogo(institution.signatureUrl);

    // Pre-fetch all selected media images
    final Map<String, pw.MemoryImage> preFetchedImages = {};
    for (var a in activities) {
      final selectedMedia = _getSelectedMedia(a.media);
      for (var m in selectedMedia) {
        try {
          final response = await http.get(Uri.parse(m.url)).timeout(const Duration(seconds: 15));
          if (response.statusCode == 200) {
            preFetchedImages[m.id] = pw.MemoryImage(response.bodyBytes);
          }
        } catch (e) {
          debugPrint('Error fetching media image for PDF: ${m.url} - $e');
        }
      }
    }

    // Group activities by type
    final Map<String, List<InstitutionalActivity>> grouped = {};
    for (var a in activities) {
      grouped[a.activityGroup] = (grouped[a.activityGroup] ?? [])..add(a);
    }

    // Statistics
    final totalParticipants = activities.fold(0, (sum, a) => sum + a.participants.length);
    final completed = activities.where((a) => a.status == 'completed').length;
    final financialImpact = activities.where((a) => a.hasFinancialImpact).length;

    // 1. Cover Page
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) {
          return pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Header(level: 0, text: 'RELATÓRIO ANUAL DE ATIVIDADES'),
              pw.SizedBox(height: 10),
              pw.Text('Ano Letivo: ${DateTime.now().year - 1} / ${DateTime.now().year}', style: const pw.TextStyle(fontSize: 14)),
              pw.SizedBox(height: 60),
              if (logoImage != null)
                pw.Center(child: pw.Image(logoImage, width: 200)),
              pw.SizedBox(height: 60),
              pw.Text('Instituição: ${institution.name}',
                  style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 5),
              pw.Text('NIF: ${institution.nif}', style: const pw.TextStyle(fontSize: 12)),
              pw.Text(institution.address, textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
              pw.SizedBox(height: 60),
              pw.Container(
                width: 200,
                height: 2,
                color: PdfColors.amber,
              ),
              pw.SizedBox(height: 20),
              pw.Text('Ano Académico: 2024/2025',
                  style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 100),
              pw.Text('Gerado em ${DateFormat('dd/MM/yyyy').format(DateTime.now())}',
                  style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
            ],
          );
        },
      ),
    );

    // 2. Introduction & Indicators
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        header: (context) => _buildHeader(context, 'Introdução e Indicadores', institution, logoImage),
        footer: (context) => _buildFooter(context, institution),
        build: (context) {
          return [
            pw.SizedBox(
              width: 480,
              child: pw.Column(
                mainAxisSize: pw.MainAxisSize.min,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Header(level: 0, text: 'Resumo Executivo'),
                  pw.Paragraph(
                    text: draft?.introduction ?? 'Durante o ano letivo, a dinâmica institucional foi marcada por um compromisso contínuo com a excelência educativa. Este relatório sintetiza as principais atividades e conquistas do período.',
                    style: const pw.TextStyle(fontSize: 11, lineSpacing: 1.5),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),
            pw.SizedBox(
              width: 480,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                   pw.Header(level: 1, text: 'Indicadores Globais'),
                   pw.Row(
                    mainAxisSize: pw.MainAxisSize.min,
                    mainAxisAlignment: pw.MainAxisAlignment.start,
                    children: [
                      _buildModernStatBox('Atividades', activities.length.toString(), PdfColors.blue900),
                      pw.SizedBox(width: 20),
                      _buildModernStatBox('Participantes', _getParticipantsCount(activities).toString(), PdfColors.indigo900),
                      pw.SizedBox(width: 20),
                      _buildModernStatBox('Concluídas', _getCompletedCount(activities).toString(), PdfColors.green900),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 30),
          ];
        },
      ),
    );

    // 3. Deep Dive for each group and activity
    // 3. Deep Dive for each group and activity
    for (var section in (draft?.sections ?? [])) {
      final items = section.activities;
      final summary = section.summary;
      
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          header: (context) => _buildHeader(context, section.title, institution, logoImage),
          footer: (context) => _buildFooter(context, institution),
          build: (context) {
            return [
              pw.SizedBox(
                width: 480,
                child: pw.Column(
                  mainAxisSize: pw.MainAxisSize.min,
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Header(level: 0, text: section.title.toUpperCase()),
                    pw.Paragraph(text: summary, style: pw.TextStyle(fontStyle: pw.FontStyle.italic, color: PdfColors.grey700)),
                  ],
                ),
              ),
              pw.SizedBox(height: 15),
              ...items.map((a) => pw.SizedBox(
                width: 480,
                child: pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 25),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.start,
                        children: [
                          pw.SizedBox(
                            width: 380, 
                            child: pw.Text(a.title, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
                          ),
                          pw.SizedBox(width: 20),
                          pw.Text(DateFormat('dd/MM/yyyy').format(a.startDate), style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                        ],
                      ),
                      pw.SizedBox(height: 5),
                      pw.Text(a.description, style: const pw.TextStyle(fontSize: 10)),
                      pw.SizedBox(height: 10),
                      pw.Row(
                        mainAxisSize: pw.MainAxisSize.min,
                        children: [
                          pw.Row(
                            mainAxisSize: pw.MainAxisSize.min,
                            children: [
                              pw.Text('• ', style: const pw.TextStyle(fontSize: 12)),
                              pw.Text('Participantes: ${a.participants.length}', style: const pw.TextStyle(fontSize: 9)),
                            ],
                          ),
                          pw.SizedBox(width: 15),
                          if (a.responsibleName != null)
                            pw.Row(
                              mainAxisSize: pw.MainAxisSize.min,
                              children: [
                                pw.Text('• ', style: const pw.TextStyle(fontSize: 12)),
                                pw.Text('Responsável: ${a.responsibleName}', style: const pw.TextStyle(fontSize: 9)),
                              ],
                            ),
                        ],
                      ),
                      
                      // Pictures section
                      _buildActivityMediaSection(
                        _getSelectedMedia(a.media),
                        preFetchedImages,
                      ),
                      
                      pw.Divider(color: PdfColors.grey200),
                    ],
                  ),
                ),
              )),
            ];
          },
        ),
      );
    }

    // 4. Conclusion & Signature
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        header: (context) => _buildHeader(context, 'Considerações Finais', institution, logoImage),
        footer: (context) => _buildFooter(context, institution),
        build: (context) {
          return [
            pw.SizedBox(
              width: 480,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Header(level: 0, text: 'Considerações Finais'),
                  pw.Paragraph(
                    text: draft?.conclusion ?? 'Este relatório demonstra o compromisso da ${institution.name} com a excelência educativa e o bem-estar da sua comunidade.',
                    style: const pw.TextStyle(fontSize: 11, lineSpacing: 1.5),
                  ),
                  pw.SizedBox(height: 40),
                  pw.Center(
                    child: pw.Column(
                      children: [
                        pw.Text('VALIDAÇÃO INSTITUCIONAL', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800)),
                        pw.SizedBox(height: 15),
                        if (signatureImage != null)
                          pw.Container(
                            height: 80,
                            child: pw.Image(signatureImage),
                          )
                        else
                          pw.Container(height: 80, child: pw.Center(child: pw.Text('(Assinatura em falta)', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey400)))),
                        pw.Container(width: 250, height: 1, color: PdfColors.black),
                        pw.SizedBox(height: 5),
                        pw.Text('O Responsável / A Direção', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        pw.Text(institution.name, style: const pw.TextStyle(fontSize: 9)),
                        pw.Text('Data: ${DateFormat('dd/MM/yyyy').format(DateTime.now())}', style: const pw.TextStyle(fontSize: 8)),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 40),
                ],
              ),
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: 'Relatorio_Oficial_${institution.name.replaceAll(' ', '_')}.pdf');
  }

  static Future<void> generatePresentationPDF(
      InstitutionModel institution, List<InstitutionalActivity> activities, {AnnualReportDraft? draft}) async {
    WidgetsFlutterBinding.ensureInitialized();
    
    pw.Font? fontRegular;
    pw.Font? fontBold;

    try {
      fontRegular = await PdfGoogleFonts.robotoRegular();
      fontBold = await PdfGoogleFonts.robotoBold();
    } catch (e) {
      debugPrint('Error loading Google Fonts for Presentation: $e');
    }

    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(
        base: fontRegular,
        bold: fontBold,
      ),
    );
    final logoImage = await _fetchLogo(institution.logoUrl);

    // Pre-fetch images for presentation as well
    final Map<String, pw.MemoryImage> preFetchedImages = {};
    for (var a in activities) {
      final highlights = _getSelectedMedia(a.media);
      for (var m in highlights) {
        try {
          final response = await http.get(Uri.parse(m.url)).timeout(const Duration(seconds: 15));
          if (response.statusCode == 200) {
            preFetchedImages[m.id] = pw.MemoryImage(response.bodyBytes);
          }
        } catch (e) {
          debugPrint('Error fetching presentation image: $e');
        }
      }
    }
    
    // Slide master style
    final slideFormat = PdfPageFormat.a4.landscape;

    // 1. Title Slide
    pdf.addPage(
      pw.Page(
        pageFormat: slideFormat,
        build: (context) => pw.Container(
          color: PdfColors.indigo900,
          padding: const pw.EdgeInsets.all(50),
          child: pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              if (logoImage != null) pw.Image(logoImage, width: 100),
              pw.SizedBox(height: 30),
              pw.Text('RELATÓRIO DE ATIVIDADES', style: pw.TextStyle(fontSize: 32, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
              pw.SizedBox(height: 10),
              pw.Text(institution.name, style: const pw.TextStyle(fontSize: 22, color: PdfColors.indigo100)),
              pw.SizedBox(height: 30),
              pw.Container(height: 2, color: PdfColors.amber, width: 400),
              pw.SizedBox(height: 10),
              pw.Text('Ano Letivo 2023/2024', style: const pw.TextStyle(color: PdfColors.white)),
            ],
          ),
        ),
      ),
    );

    // 2. Intro Slide
    pdf.addPage(
      pw.Page(
        pageFormat: slideFormat,
        build: (context) => pw.Padding(
          padding: const pw.EdgeInsets.all(40),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('VISÃO GERAL DO ANO', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
              pw.Divider(color: PdfColors.amber),
              pw.SizedBox(height: 30),
              pw.Text(draft?.introduction ?? '', style: const pw.TextStyle(fontSize: 16)),
              pw.Spacer(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  _buildModernStatBox('Total Atividades', activities.length.toString(), PdfColors.indigo700),
                  _buildModernStatBox('Alcance (Participantes)', activities.fold(0, (sum, a) => sum + a.participants.length).toString(), PdfColors.blue700),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    // 3. Category Summary & Activity Highlight Slides
    for (var section in (draft?.sections ?? [])) {
       // A. Category Summary Slide (Textual)
       pdf.addPage(
        pw.Page(
          pageFormat: slideFormat,
          build: (context) => pw.Padding(
            padding: const pw.EdgeInsets.all(30),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(section.title.toUpperCase(), style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
                    if (logoImage != null) pw.Image(logoImage, height: 30),
                  ],
                ),
                pw.Divider(color: PdfColors.amber, thickness: 1.5),
                pw.SizedBox(height: 20),
                pw.Text('SUMÁRIO DA CATEGORIA', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.grey700)),
                pw.SizedBox(height: 10),
                pw.Text(section.summary, style: const pw.TextStyle(fontSize: 14, lineSpacing: 1.3)),
                pw.Spacer(),
                pw.Text('ATIVIDADES NESTA CATEGORIA:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.indigo700)),
                ...section.activities.take(8).map((a) => pw.Bullet(text: a.title, style: const pw.TextStyle(fontSize: 11))),
                pw.Spacer(),
              ],
            ),
          ),
        ),
      );

      // B. Individual Activity Slides (Only for those with selected photos)
      for (var a in section.activities) {
        final activityPhotos = _getSelectedMedia(a.media);
        
        if (activityPhotos.isNotEmpty) {
          final List<pw.MemoryImage> highlightImages = [];
          for (var m in activityPhotos) {
            if (preFetchedImages.containsKey(m.id)) {
              highlightImages.add(preFetchedImages[m.id]!);
            }
          }

          if (highlightImages.isNotEmpty) {
            pdf.addPage(
              pw.Page(
                pageFormat: slideFormat,
                build: (context) => pw.Padding(
                  padding: const pw.EdgeInsets.all(30),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(a.title, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
                              pw.Text('${section.title} | ${DateFormat('dd/MM/yyyy').format(a.startDate)}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
                            ],
                          ),
                          if (logoImage != null) pw.Image(logoImage, height: 30),
                        ],
                      ),
                      pw.Divider(color: PdfColors.amber),
                      pw.SizedBox(height: 10),
                      pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Expanded(
                            flex: 1,
                            child: pw.Text(a.description, style: const pw.TextStyle(fontSize: 10, lineSpacing: 1.2)),
                          ),
                          pw.SizedBox(width: 20),
                          pw.Expanded(
                            flex: 2,
                            child: pw.Wrap(
                              spacing: 15,
                              runSpacing: 15,
                              children: highlightImages.take(4).map((img) => pw.Container(
                                width: 140,
                                height: 105,
                                decoration: pw.BoxDecoration(
                                  border: pw.Border.all(color: PdfColors.white, width: 2),
                                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                                  boxShadow: [
                                    const pw.BoxShadow(
                                      color: PdfColors.black,
                                      blurRadius: 5,
                                      offset: PdfPoint(0, 2),
                                    ),
                                  ],
                                ),
                                child: pw.Image(img, fit: pw.BoxFit.cover),
                              )).toList(),
                            ),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 20),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Destaque Individual: ${a.title}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
                          pw.Text('Relatório Local 2024', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          }
        }
      }
    }

    // 4. Closing Slide
    pdf.addPage(
      pw.Page(
        pageFormat: slideFormat,
        build: (context) => pw.Container(
          color: PdfColors.indigo900,
          child: pw.Center(
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Text('OBRIGADO', style: pw.TextStyle(fontSize: 40, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                pw.SizedBox(height: 20),
                pw.Text(institution.name, style: const pw.TextStyle(fontSize: 18, color: PdfColors.indigo100)),
              ],
            ),
          ),
        ),
      ),
    );

    await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: 'Apresentacao_${institution.name.replaceAll(' ', '_')}.pdf');
  }

  static pw.Widget _buildFooter(pw.Context context, InstitutionModel institution) {
    return pw.Container(
      width: 485,
      alignment: pw.Alignment.centerRight,
      margin: const pw.EdgeInsets.only(top: 10),
      padding: const pw.EdgeInsets.only(top: 5),
      decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300, width: 0.5))),
      child: pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        mainAxisAlignment: pw.MainAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 400,
            child: pw.Column(
              mainAxisSize: pw.MainAxisSize.min,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('${institution.name} | NIF: ${institution.nif}', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
                pw.Text('${institution.address} | ${institution.email} | ${institution.phone}', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
              ],
            ),
          ),
          pw.SizedBox(width: 30),
          pw.SizedBox(
            width: 50,
            child: pw.Text('Página ${context.pageNumber}',
                style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
                textAlign: pw.TextAlign.right),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildModernStatBox(String label, String value, PdfColor color) {
    return pw.Container(
      width: 100,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: color.shade(0.05),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
        border: pw.Border.all(color: color.shade(0.1)),
      ),
      child: pw.Column(
        children: [
          pw.Text(label, style: pw.TextStyle(fontSize: 8, color: color)),
          pw.SizedBox(height: 4),
          pw.Text(value, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  static pw.Widget _buildActivityMediaSection(List<ActivityMedia> selectedMedia, Map<String, pw.MemoryImage> images) {
    if (selectedMedia.isEmpty) return pw.SizedBox();
    
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 10),
      child: pw.Wrap(
        spacing: 10,
        runSpacing: 10,
        children: selectedMedia.map((m) {
          final img = images[m.id];
          return pw.Container(
            width: 160,
            height: 120,
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
            ),
            child: pw.Column(
              children: [
                pw.Container(
                  height: 100,
                  width: 160,
                  child: img != null 
                    ? pw.Image(img, fit: pw.BoxFit.cover)
                    : pw.Center(
                        child: pw.Text('[FOTO]', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
                      ),
                ),
                pw.Container(
                  width: 160,
                  padding: const pw.EdgeInsets.all(3),
                  color: PdfColors.grey100,
                  child: pw.Text(m.name, style: const pw.TextStyle(fontSize: 6), textAlign: pw.TextAlign.center),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  static List<ActivityMedia> _getSelectedMedia(List<ActivityMedia> media) {
    final List<ActivityMedia> selected = [];
    for (var m in media) {
      if (m.isAnnualReportSelected) {
        selected.add(m);
      }
    }
    return selected;
  }

  static int _getParticipantsCount(List<InstitutionalActivity> activities) {
    int count = 0;
    for (var a in activities) {
      count += a.participants.length;
    }
    return count;
  }

  static int _getCompletedCount(List<InstitutionalActivity> activities) {
    int count = 0;
    for (var a in activities) {
      if (a.status == 'completed') {
        count++;
      }
    }
    return count;
  }

  static Future<void> generateSurveyReport(
      Questionnaire survey,
      SurveyResponseSummary summary,
      {InstitutionModel? institution}) async {
    final pdf = pw.Document();
    final logoImage = await _fetchLogo(institution?.logoUrl);

    final fmt = DateFormat('dd/MM/yyyy HH:mm');
    final startDateStr = DateFormat('dd/MM/yyyy').format(survey.startDate);
    final endDateStr = DateFormat('dd/MM/yyyy').format(survey.endDate);

    String docTitle = 'Relatório de Avaliação';
    if (survey.linkedToAnnualReport) {
      docTitle = 'Relatório Institucional Anual';
    } else if (survey.audiences.contains(SurveyAudience.students) && survey.subjectId != null) {
      docTitle = 'Relatório Contínuo de Disciplina';
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => _buildHeader(context, docTitle, institution, logoImage),
        footer: (context) {
          if (institution != null) {
            return _buildFooter(context, institution);
          }
          return pw.SizedBox();
        },
        build: (pw.Context context) {
          return [
            // Title
            pw.Text(survey.title,
                style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.indigo900)),
            pw.SizedBox(height: 8),
            if (survey.description.trim().isNotEmpty) ...[
              pw.Text(survey.description,
                  style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
              pw.SizedBox(height: 12),
            ],
            
            // Classification Disclaimer
            if (survey.linkedToAnnualReport || survey.audiences.contains(SurveyAudience.students)) ...[
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: pw.BoxDecoration(
                  color: survey.linkedToAnnualReport ? PdfColors.green100 : PdfColors.amber100,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
                child: pw.Text(
                  survey.linkedToAnnualReport 
                      ? 'Integrado no Relatório Institucional de Atividades'
                      : 'Relatório Contínuo de Avaliação Letiva',
                  style: pw.TextStyle(
                    fontSize: 8, 
                    fontWeight: pw.FontWeight.bold,
                    color: survey.linkedToAnnualReport ? PdfColors.green900 : PdfColors.amber900
                  ),
                )
              ),
              pw.SizedBox(height: 12),
            ],
            
            // Meta info
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.indigo50,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Período', style: const pw.TextStyle(fontSize: 8, color: PdfColors.indigo900)),
                      pw.Text('$startDateStr a $endDateStr', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
                    ]
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Respostas', style: const pw.TextStyle(fontSize: 8, color: PdfColors.indigo900)),
                      pw.Text('${summary.totalResponses}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
                    ]
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Gerado em', style: const pw.TextStyle(fontSize: 8, color: PdfColors.indigo900)),
                      pw.Text(fmt.format(summary.generatedAt), style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
                    ]
                  ),
                ]
              )
            ),
            pw.SizedBox(height: 24),

            // AI Insights
            if (summary.qualitativeInsights.isNotEmpty) ...[
              _sectionTitle('Síntese Qualitativa (IA)'),
              ...summary.qualitativeInsights.entries.map((e) {
                final question = survey.questions.firstWhere((q) => q.id == e.key, orElse: () => Question(id: '', text: 'Pergunta', type: QuestionType.openText));
                return pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 8),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(question.text, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 2),
                      pw.Text(e.value, style: const pw.TextStyle(fontSize: 10, lineSpacing: 1.5)),
                    ]
                  )
                );
              }),
              pw.SizedBox(height: 20),
            ],

            if (summary.keyTrends.isNotEmpty) ...[
              _sectionTitle('Principais Tendências'),
              ...summary.keyTrends.map((trend) => pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 6),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('• ', style: const pw.TextStyle(color: PdfColors.indigo900)),
                    pw.Expanded(child: pw.Text(trend, style: const pw.TextStyle(fontSize: 10))),
                  ]
                )
              )),
              pw.SizedBox(height: 20),
            ],

            // Satisfaction Score if available
            if (summary.overallSatisfactionScore != null) ...[
               _sectionTitle('Índice Global de Satisfação'),
               pw.Row(
                 children: [
                   pw.Text('${summary.overallSatisfactionScore!.toStringAsFixed(1)}', style: pw.TextStyle(fontSize: 32, fontWeight: pw.FontWeight.bold, color: PdfColors.green700)),
                   pw.Text(' / 5.0', style: pw.TextStyle(fontSize: 14, color: PdfColors.grey600)),
                 ]
               ),
               pw.SizedBox(height: 24),
            ],

            // Human Notes
            if (summary.humanNotes != null && summary.humanNotes!.trim().isNotEmpty) ...[
              _sectionTitle('Notas da Direção / Responsável'),
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                width: double.infinity,
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  border: pw.Border(left: pw.BorderSide(color: PdfColors.indigo900, width: 3)),
                ),
                child: pw.Text(summary.humanNotes!, style: pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic, color: PdfColors.grey800)),
              ),
              pw.SizedBox(height: 20),
            ],

            // Quantitative Data
            _sectionTitle('Análise Quantitativa'),
            ...summary.quantitativeData.entries.map((entry) {
              final questionId = entry.key;
              final data = entry.value;
              final question = survey.questions.firstWhere((q) => q.id == questionId, orElse: () => Question(id: '', text: 'Pergunta não encontrada', type: QuestionType.openText));
              
              if (question.type == QuestionType.openText) return pw.SizedBox();

              return pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 16),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(question.text, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 6),
                    ...data.entries.map((choice) {
                       final option = choice.key.toString();
                       final count = (choice.value as num).toInt();
                       final percentage = summary.totalResponses > 0 ? (count / summary.totalResponses) : 0.0;
                       
                       return pw.Padding(
                         padding: const pw.EdgeInsets.only(bottom: 4),
                         child: pw.Row(
                           children: [
                             pw.SizedBox(
                               width: 150,
                               child: pw.Text(option, style: const pw.TextStyle(fontSize: 9)),
                             ),
                             pw.Expanded(
                               child: pw.Stack(
                                 children: [
                                   pw.Container(
                                     height: 12,
                                     decoration: pw.BoxDecoration(
                                       color: PdfColors.grey300,
                                       borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)),
                                     )
                                   ),
                                   pw.Container(
                                     height: 12,
                                     width: 200 * percentage, // Approximated
                                     decoration: pw.BoxDecoration(
                                       color: PdfColors.indigo400,
                                       borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)),
                                     )
                                   ),
                                 ]
                               )
                             ),
                             pw.SizedBox(
                               width: 80,
                               child: pw.Text(' $count (${(percentage * 100).toStringAsFixed(1)}%)', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right),
                             ),
                           ]
                         )
                       );
                    }),
                  ]
                )
              );
            }),
          ];
        },
      ),
    );

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'Relatorio_Inquerito_${survey.title.replaceAll(' ', '_')}.pdf',
    );
  }

  static pw.Widget _sectionTitle(String title) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Text(title, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo700)),
    );
  }

  static Future<void> generateHRAttendanceMapPDF({
    required InstitutionModel institution,
    required DateTime month,
    required List<UserModel> employees,
    required List<HRAttendanceRecord> records,
    required List<HRAbsence> absences,
  }) async {
    final pdf = pw.Document();
    final logoImage = await _fetchLogo(institution.logoUrl);
    final monthName = DateFormat('MMMM yyyy').format(month);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        header: (context) => _buildHeader(context, 'Mapa de Assiduidade Mensal - $monthName', institution, logoImage),
        build: (pw.Context context) {
          return [
            pw.TableHelper.fromTextArray(
              headers: ['Colaborador', 'Previsto (h)', 'Real (h)', 'Férias', 'Baixas', 'Faltas', 'Obs'],
              data: employees.map((emp) {
                final empRecords = records.where((r) => r.employeeId == emp.id).toList();
                final empAbsences = absences.where((a) => a.employeeId == emp.id).toList();
                
                final vacationDays = empAbsences.where((a) => a.type == AbsenceType.vacation).length;
                final sickDays = empAbsences.where((a) => a.type == AbsenceType.sickLeave).length;
                final unjustified = empAbsences.where((a) => a.type == AbsenceType.unjustified).length;

                return [
                  emp.name,
                  '160', // Placeholder
                  '152', // Placeholder
                  vacationDays.toString(),
                  sickDays.toString(),
                  unjustified.toString(),
                  '',
                ];
              }).toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
              cellStyle: const pw.TextStyle(fontSize: 9),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save(), name: 'Mapa_Assiduidade_${monthName.replaceAll(' ', '_')}.pdf');
  }

  Future<void> generateFinancialReportPDF({
    required InstitutionModel institution,
    required List<FinanceTransaction> transactions,
    required double balance,
  }) async {
    final pdf = pw.Document();
    final income = transactions.where((t) => t.type == TransactionType.income).fold(0.0, (sum, t) => sum + t.amount);
    final expense = transactions.where((t) => t.type == TransactionType.expense).fold(0.0, (sum, t) => sum + t.amount);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) => [
          pw.Header(
            level: 0,
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Relatorio Financeiro Institucional', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                    pw.Text(institution.name, style: pw.TextStyle(fontSize: 14)),
                  ],
                ),
                pw.Text('Data: ${DateFormat('dd/MM/yyyy').format(DateTime.now())}'),
              ],
            ),
          ),
          pw.SizedBox(height: 20),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
            children: [
              _buildStatBox('Receita Total', 'EUR ${income.toStringAsFixed(2)}'),
              _buildStatBox('Despesa Total', 'EUR ${expense.toStringAsFixed(2)}'),
              _buildStatBox('Saldo', 'EUR ${balance.toStringAsFixed(2)}'),
            ],
          ),
          pw.SizedBox(height: 30),
          pw.Text('Historico de Transacoes', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 10),
          pw.TableHelper.fromTextArray(
            headers: ['Data', 'Descricao', 'Categoria', 'Tipo', 'Montante'],
            data: transactions.map((tx) => [
              DateFormat('dd/MM/yyyy').format(tx.date),
              tx.description,
              tx.category.name.toUpperCase(),
              tx.type.name.toUpperCase(),
              'EUR ${tx.amount.toStringAsFixed(2)}',
            ]).toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            cellAlignment: pw.Alignment.centerLeft,
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
          ),
          pw.Footer(
            trailing: pw.Text('Gerado automaticamente por EduGaming 360 - Pag. ${context.pageNumber} de ${context.pagesCount}'),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save(), name: 'Relatorio_Financeiro_${institution.name}.pdf');
  }


  static Future<void> printPurchaseOrder(InstitutionModel institution, PurchaseOrder order) async {
    final pdf = pw.Document();
    final logoImage = await _fetchLogo(institution.logoUrl);

    pdf.addPage(
      pw.Page(
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _buildHeader(null, 'Nota de Encomenda #${order.id.substring(0, 8)}', institution, logoImage),
            pw.SizedBox(height: 20),
            pw.Text('Fornecedor: ${order.supplierName}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
            pw.Text('Data: ${DateFormat('dd/MM/yyyy HH:mm').format(order.orderDate)}'),
            pw.SizedBox(height: 20),
            pw.TableHelper.fromTextArray(
              headers: ['Artigo', 'Tamanho', 'Quantidade'],
              data: order.items.map((it) => [it.itemName, it.size, it.quantity.toString()]).toList(),
            ),
            pw.Spacer(),
            pw.Divider(),
            pw.Text('Documento gerado institucionalmente - ERP EduGaming 360', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
          ],
        ),
      ),
    );
    await Printing.layoutPdf(onLayout: (format) async => pdf.save(), name: 'PO_${order.id}.pdf');
  }
}

