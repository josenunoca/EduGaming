import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/subject_model.dart';
import '../models/institution_model.dart';
import '../models/user_model.dart';
import 'package:flutter/foundation.dart';

class PdfService {
  static Future<Uint8List> generateAssessmentReport({
    required String title,
    required String subtitle,
    required String content,
    AdvancedScoreStats? stats,
    bool isSynthetic = true,
  }) async {
    final pdf = pw.Document();
    
    // Define theme colors
    final primaryColor = PdfColor.fromHex('#00D1FF');
    final secondaryColor = PdfColor.fromHex('#7B61FF');
    const textColor = PdfColors.grey900;
    const mutedTextColor = PdfColors.grey600;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (pw.Context context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(bottom: 20),
          child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('EduGAming Platform Learning', style: pw.TextStyle(color: primaryColor, fontWeight: pw.FontWeight.bold, fontSize: 10)),
                pw.Text('Relatório Técnico de Desempenho', style: const pw.TextStyle(color: mutedTextColor, fontSize: 10)),
              ]
          ),
        ),
        footer: (pw.Context context) => pw.Column(
          children: [
            pw.Divider(color: PdfColors.grey300),
            pw.SizedBox(height: 10),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Página ${context.pageNumber} de ${context.pagesCount}',
                    style: const pw.TextStyle(fontSize: 8, color: mutedTextColor)),
                pw.Text('Documento gerado automaticamente pela EduGAming Platform',
                    style: const pw.TextStyle(fontSize: 8, color: mutedTextColor)),
              ],
            ),
          ],
        ),
        build: (pw.Context context) => [
          // Header Section
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 20, horizontal: 15),
            decoration: pw.BoxDecoration(
              color: primaryColor,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(title, style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                pw.SizedBox(height: 5),
                pw.Text(subtitle, style: const pw.TextStyle(fontSize: 12, color: PdfColors.white)),
              ],
            ),
          ),
          
          pw.SizedBox(height: 30),

          // Statistics Section (If available)
          if (stats != null) ...[
            pw.Text('Estatísticas Descritivas Quantitativas', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: secondaryColor)),
            pw.SizedBox(height: 15),
            
            // Summary Cards
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                _buildStatCard('Média', stats.average.toStringAsFixed(1), primaryColor),
                _buildStatCard('Mediana', stats.median.toStringAsFixed(1), primaryColor),
                _buildStatCard('Moda', stats.modes.join(', '), primaryColor),
                _buildStatCard('Participantes', stats.totalParticipants.toString(), primaryColor),
              ],
            ),
            
            pw.SizedBox(height: 30),
            
            // Charts Row
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  flex: 3,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Histograma de Distribuição', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 10),
                      _buildHistogram(stats.histogramBins, primaryColor),
                    ],
                  ),
                ),
                pw.SizedBox(width: 30),
                pw.Expanded(
                  flex: 2,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Box Plot (Quartis)', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 10),
                      _buildBoxPlot(stats, secondaryColor),
                    ],
                  ),
                ),
              ],
            ),
            
            pw.SizedBox(height: 40),

            // Performance Highlights (Top/Bottom Questions)
            pw.Text('Destaques de Desempenho por Questão', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: secondaryColor)),
            pw.SizedBox(height: 15),
            _buildHighlightSection(stats, primaryColor),
            
            pw.SizedBox(height: 40),

            // Detailed Per-Question Analysis (Only if not synthetic or explicitly requested)
            if (!isSynthetic) ...[
              pw.Text('Análise Individualizada por Questão', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: secondaryColor)),
              pw.SizedBox(height: 15),
              ...stats.questionStats.map((q) => _buildQuestionAnalysis(q, primaryColor)),
              pw.SizedBox(height: 40),
            ],
          ],

          ..._buildFormattedContent(content, primaryColor, secondaryColor, textColor),
          
          pw.SizedBox(height: 30),

          // Conclusion Placeholder (If is synthetic, it's already in 'content' from IA)
          // But the user wants a clear point for it.
          if (isSynthetic) ...[
             pw.Container(
               padding: const pw.EdgeInsets.all(15),
               decoration: pw.BoxDecoration(
                 color: PdfColor.fromHex('#F0FDFF'),
                 border: pw.Border.all(color: primaryColor, width: 0.5),
                 borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
               ),
               child: pw.Column(
                 crossAxisAlignment: pw.CrossAxisAlignment.start,
                 children: [
                   pw.Text('Conclusão e Próximos Passos', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                   pw.SizedBox(height: 10),
                   pw.Text('Consulte as recomendações acima para implementar estratégias de reforço focadas nos conteúdos com menor taxa de acerto.', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                 ],
               ),
             ),
          ],

          pw.SizedBox(height: 60),
          
          pw.Container(
            padding: const pw.EdgeInsets.all(20),
            decoration: const pw.BoxDecoration(
              color: PdfColors.grey50,
              borderRadius: pw.BorderRadius.all(pw.Radius.circular(8)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Data de Emissão:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: mutedTextColor)),
                    pw.Text('${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}', style: const pw.TextStyle(fontSize: 10, color: textColor)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Container(width: 180, child: pw.Divider(color: PdfColors.grey400, thickness: 0.5)),
                    pw.SizedBox(height: 4),
                    pw.Text('Assinatura do Professor', style: pw.TextStyle(fontSize: 9, color: mutedTextColor, fontStyle: pw.FontStyle.italic)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildPdfResponseValue(Map<String, dynamic> response) {
    final type = response['type'];
    final value = response['value'];

    if (type == 'text') return pw.Text(value, style: const pw.TextStyle(fontSize: 9));
    if (type == 'audio') return pw.Row(children: [pw.Text('[Respostas em Áudio - Ver na Plataforma]', style: const pw.TextStyle(fontSize: 9, color: PdfColors.blue700))]);
    if (type == 'image') return pw.Row(children: [pw.Text('[Imagem Anexada - Ver na Plataforma]', style: const pw.TextStyle(fontSize: 9, color: PdfColors.green700))]);
    return pw.Text('Tipo desconhecido', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey500));
  }

  static pw.Widget _buildStatCard(String label, String value, PdfColor color) {
    return pw.Container(
      width: 100,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: color),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
      ),
      child: pw.Column(
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
          pw.SizedBox(height: 5),
          pw.Text(value, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  static pw.Widget _buildHistogram(List<int> bins, PdfColor color) {
    // bins: [0-20, 20-40, 40-60, 60-80, 80-100]
    final maxVal = bins.isEmpty ? 1 : bins.reduce((a, b) => a > b ? a : b);
    const chartHeight = 100.0;
    
    return pw.Container(
      height: chartHeight + 20,
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
        children: List.generate(bins.length, (i) {
          final barHeight = (bins[i] / maxVal) * chartHeight;
          final labels = ['0-20', '20-40', '40-60', '60-80', '80-100'];
          return pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              pw.Text(bins[i].toString(), style: const pw.TextStyle(fontSize: 8)),
              pw.SizedBox(height: 2),
              pw.Container(
                width: 30,
                height: barHeight > 0 ? barHeight : 2,
                color: color,
              ),
              pw.SizedBox(height: 5),
              pw.Text(labels[i], style: const pw.TextStyle(fontSize: 6)),
            ],
          );
        }),
      ),
    );
  }

  static pw.Widget _buildBoxPlot(AdvancedScoreStats stats, PdfColor color) {
    const chartHeight = 100.0;
    const chartWidth = 60.0;
    
    // Normalize values to chart height (assuming 0-100 scale for scores)
    double norm(double val) => (val / 100.0) * chartHeight;
    
    final bottom = norm(stats.min);
    final top = norm(stats.max);
    final q1 = norm(stats.q1);
    final q3 = norm(stats.q3);
    final median = norm(stats.median);

    return pw.Container(
      height: chartHeight + 20,
      width: chartWidth,
      child: pw.Stack(
        alignment: pw.Alignment.bottomCenter,
        children: [
          // The vertical line (whiskers)
          pw.Positioned(
            bottom: bottom + 10,
            child: pw.Container(
              height: top - bottom,
              width: 1,
              color: PdfColors.black,
            ),
          ),
          // Top whisker cap
          pw.Positioned(bottom: top + 10, child: pw.Container(width: 20, height: 1, color: PdfColors.black)),
          // Bottom whisker cap
          pw.Positioned(bottom: bottom + 10, child: pw.Container(width: 20, height: 1, color: PdfColors.black)),
          
          // The Box (Q1 to Q3)
          pw.Positioned(
            bottom: q1 + 10,
            child: pw.Container(
              width: 40,
              height: q3 - q1,
              decoration: pw.BoxDecoration(
                color: color,
                border: pw.Border.all(color: color, width: 1),
              ),
            ),
          ),
          // Median line
          pw.Positioned(
            bottom: median + 10,
            child: pw.Container(width: 40, height: 2, color: color),
          ),
        ],
      ),
    );
  }

  static Future<void> downloadPdf(Uint8List bytes, String fileName) async {
    // Printing.layoutPdf is more reliable on Web as it triggers the browser's PDF viewer/print dialog
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => bytes,
      name: fileName,
    );
  }

  static pw.Widget _buildHighlightSection(AdvancedScoreStats stats, PdfColor primaryColor) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Top 3 - Maior Taxa de Acerto', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.green700)),
              pw.SizedBox(height: 8),
              ...stats.topQuestions.map((q) => pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 4),
                child: pw.Row(
                  children: [
                    pw.Container(width: 4, height: 4, decoration: const pw.BoxDecoration(color: PdfColors.green700, shape: pw.BoxShape.circle)),
                    pw.SizedBox(width: 8),
                    pw.Expanded(child: pw.Text('${q.questionText} (${q.percentage.toStringAsFixed(0)}%)', style: const pw.TextStyle(fontSize: 9))),
                  ],
                ),
              )),
            ],
          ),
        ),
        pw.SizedBox(width: 20),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Críticos - Menor Taxa de Acerto', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.red700)),
              pw.SizedBox(height: 8),
              ...stats.bottomQuestions.map((q) => pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 4),
                child: pw.Row(
                  children: [
                    pw.Container(width: 4, height: 4, decoration: const pw.BoxDecoration(color: PdfColors.red700, shape: pw.BoxShape.circle)),
                    pw.SizedBox(width: 8),
                    pw.Expanded(child: pw.Text('${q.questionText} (${q.percentage.toStringAsFixed(0)}%)', style: const pw.TextStyle(fontSize: 9))),
                  ],
                ),
              )),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildQuestionAnalysis(QuestionStat q, PdfColor color) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 15),
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(q.questionText, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 10),
          pw.Row(
            children: [
              pw.Expanded(
                flex: (q.percentage).toInt().clamp(1, 100),
                child: pw.Container(
                  height: 12,
                  color: PdfColors.green400,
                  alignment: pw.Alignment.centerLeft,
                  padding: const pw.EdgeInsets.only(left: 4),
                  child: pw.Text('${q.correctCount} Certas', style: const pw.TextStyle(fontSize: 7, color: PdfColors.white)),
                ),
              ),
              pw.Expanded(
                flex: (100 - q.percentage).toInt().clamp(1, 100),
                child: pw.Container(
                  height: 12,
                  color: PdfColors.red400,
                  alignment: pw.Alignment.centerRight,
                  padding: const pw.EdgeInsets.only(right: 4),
                  child: pw.Text('${q.incorrectCount} Erradas', style: const pw.TextStyle(fontSize: 7, color: PdfColors.white)),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 5),
          pw.Text('Percentagem de Sucesso: ${q.percentage.toStringAsFixed(1)}%', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
        ],
      ),
    );
  }

  static List<pw.Widget> _buildFormattedContent(String content, PdfColor primaryColor, PdfColor secondaryColor, PdfColor textColor) {
    final List<pw.Widget> widgets = [];
    final lines = content.split('\n');

    for (var line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        widgets.add(pw.SizedBox(height: 10));
        continue;
      }

      // Detect Headers (#### or ## or 1. Title)
      if (trimmed.startsWith('####') || trimmed.startsWith('###') || trimmed.startsWith('##') || 
          RegExp(r'^\d+\.').hasMatch(trimmed)) {
        
        final title = trimmed.replaceFirst(RegExp(r'^#+\s*'), '').replaceFirst(RegExp(r'^\d+\.\s*'), '');
        final prefix = RegExp(r'^\d+\.').firstMatch(trimmed)?.group(0) ?? '';
        
        widgets.add(pw.SizedBox(height: 15));
        widgets.add(_buildHeaderBox(prefix.isNotEmpty ? '$prefix $title' : title, primaryColor));
        widgets.add(pw.SizedBox(height: 10));
      } 
      // Detect Bullet Points
      else if (trimmed.startsWith('-') || trimmed.startsWith('*')) {
        final itemText = trimmed.replaceFirst(RegExp(r'^[-\*]\s*'), '').trim();
        widgets.add(
          pw.Padding(
            padding: const pw.EdgeInsets.only(left: 15, bottom: 5),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Container(
                  margin: const pw.EdgeInsets.only(top: 4, right: 8),
                  width: 3,
                  height: 3,
                  decoration: const pw.BoxDecoration(color: PdfColors.grey700, shape: pw.BoxShape.circle),
                ),
                pw.Expanded(child: pw.Text(itemText, style: pw.TextStyle(fontSize: 10, color: textColor, lineSpacing: 1.2))),
              ],
            ),
          ),
        );
      } 
      // Regular Paragraph
      else {
        widgets.add(
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 8),
            child: pw.Text(trimmed, style: pw.TextStyle(fontSize: 10, color: textColor, lineSpacing: 1.4)),
          ),
        );
      }
    }

    return widgets;
  }

  static pw.Widget _buildHeaderBox(String title, PdfColor color) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#F0FDFF'),
        border: pw.Border(left: pw.BorderSide(color: color, width: 4)),
      ),
      child: pw.Text(
        title,
        style: pw.TextStyle(
          fontSize: 13,
          fontWeight: pw.FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  static Future<Uint8List> generateTranscriptPdf({
    required InstitutionModel institution,
    required Subject subject,
    required List<Enrollment> students,
    required List<EvaluationComponent> components,
    required Map<String, Map<String, String>> grades, // studentId -> {componentId: gradeStr, 'final': finalStr}
    required bool isFull,
    String? sealedByUserName,
  }) async {
    final pdf = pw.Document();
    final primaryColor = PdfColor.fromHex('#00D1FF');
    const mutedTextColor = PdfColors.grey600;
    final isSealed = subject.pautaStatus == PautaStatus.sealed;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(40),
        header: (pw.Context context) => pw.Column(
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(institution.name, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                    pw.Text('Pauta de Avaliação Académica', style: const pw.TextStyle(fontSize: 10, color: mutedTextColor)),
                    if (isSealed)
                      pw.Container(
                        margin: const pw.EdgeInsets.only(top: 5),
                        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.red50,
                          border: pw.Border.all(color: PdfColors.red700, width: 1),
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                        ),
                        child: pw.Text('PAUTA LACRADA', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.red700)),
                      ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Ano Letivo: ${subject.academicYear}', style: const pw.TextStyle(fontSize: 10, color: mutedTextColor)),
                    pw.Text('Data: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}', style: const pw.TextStyle(fontSize: 10, color: mutedTextColor)),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 10),
            pw.Divider(color: PdfColors.grey300, thickness: 0.5),
            pw.SizedBox(height: 10),
          ],
        ),
        footer: (pw.Context context) => pw.Column(
          children: [
            if (isSealed && subject.sealedAt != null)
              pw.Container(
                alignment: pw.Alignment.centerLeft,
                margin: const pw.EdgeInsets.only(bottom: 10),
                child: pw.Text(
                  'Pauta lacrada digitalmente por ${sealedByUserName ?? subject.sealedBy ?? "Professor"} em ${subject.sealedAt!.day}/${subject.sealedAt!.month}/${subject.sealedAt!.year} às ${subject.sealedAt!.hour}:${subject.sealedAt!.minute.toString().padLeft(2, '0')}',
                  style: pw.TextStyle(fontSize: 7, color: PdfColors.red700, fontStyle: pw.FontStyle.italic),
                ),
              ),
            pw.SizedBox(height: 10),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Página ${context.pageNumber} de ${context.pagesCount}', style: const pw.TextStyle(fontSize: 8, color: mutedTextColor)),
                pw.Column(
                  children: [
                    pw.Container(width: 200, child: pw.Divider(color: PdfColors.grey400, thickness: 0.5)),
                    pw.Text('Assinatura do Responsável / Professor', style: pw.TextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic, color: mutedTextColor)),
                  ],
                ),
              ],
            ),
          ],
        ),
        build: (pw.Context context) => [
          pw.Center(child: pw.Text(subject.name.toUpperCase(), style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold))),
          if (isSealed)
            pw.Center(child: pw.Padding(
              padding: const pw.EdgeInsets.only(top: 5),
              child: pw.Text('(Classificações Finais Arredondadas)', style: pw.TextStyle(fontSize: 9, color: mutedTextColor, fontStyle: pw.FontStyle.italic)),
            )),
          pw.SizedBox(height: 20),
          
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
            children: [
              // Header Row
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                children: [
                  _cell('NOME DO ALUNO', isHeader: true),
                  _cell('EMAIL', isHeader: true),
                  if (isFull) ...components.map((c) => _cell('${c.name}\n(${(c.weight * 100).toStringAsFixed(0)}%)', isHeader: true, center: true)),
                  _cell('CLASSIFICAÇÃO FINAL', isHeader: true, center: true),
                ],
              ),
              // Data Rows
              ...students.map((student) {
                final studentGrades = grades[student.userId] ?? {};
                String finalGrade = studentGrades['final'] ?? '-';
                
                // Round if sealed and it's a number
                if (isSealed && finalGrade != '-' && finalGrade != 'F') {
                  final double? val = double.tryParse(finalGrade);
                  if (val != null) {
                    finalGrade = val.round().toString();
                  }
                }

                return pw.TableRow(
                  children: [
                    _cell(student.studentName.toUpperCase()),
                    _cell(student.studentEmail.toLowerCase()),
                    if (isFull) ...components.map((c) => _cell(studentGrades[c.id] ?? '-', center: true)),
                    _cell(finalGrade, isBold: true, center: true),
                  ],
                );
              }),
            ],
          ),
        ],
      ),
    );

    return pdf.save();
  }

  static Future<Uint8List> generateStudentExamReport({
    required AiGame game,
    required AiGameResult result,
    required String studentName,
  }) async {
    final pdf = pw.Document();
    final primaryColor = PdfColor.fromHex('#00D1FF');
    final secondaryColor = PdfColor.fromHex('#7B61FF');
    const textColor = PdfColors.grey900;
    const mutedTextColor = PdfColors.grey600;

    final double maxScore = game.questions.fold(0.0, (sum, q) => sum + q.points);
    final String formattedDate = '${result.playedAt.day}/${result.playedAt.month}/${result.playedAt.year}';
    final String formattedTime = '${result.playedAt.hour}:${result.playedAt.minute.toString().padLeft(2, '0')}';

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        header: (pw.Context context) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Relatório de Avaliação Individual', style: pw.TextStyle(color: primaryColor, fontSize: 10, fontWeight: pw.FontWeight.bold)),
            pw.Text('EduGAming Platform', style: const pw.TextStyle(color: mutedTextColor, fontSize: 10)),
          ]
        ),
        footer: (pw.Context context) => pw.Column(
          children: [
            pw.Divider(color: PdfColors.grey300),
            pw.SizedBox(height: 10),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Página ${context.pageNumber} de ${context.pagesCount}', style: const pw.TextStyle(fontSize: 8, color: mutedTextColor)),
                pw.Text('Documento gerado em ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}', style: const pw.TextStyle(fontSize: 8, color: mutedTextColor)),
              ],
            ),
          ],
        ),
        build: (pw.Context context) => [
          // Title & Score Section
          pw.Container(
            padding: const pw.EdgeInsets.all(20),
            decoration: pw.BoxDecoration(
              color: primaryColor,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(studentName.toUpperCase(), style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                    pw.SizedBox(height: 5),
                    pw.Text(game.title, style: const pw.TextStyle(fontSize: 12, color: PdfColors.white)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('CLASSIFICAÇÃO', style: pw.TextStyle(fontSize: 10, color: PdfColors.white, fontWeight: pw.FontWeight.bold)),
                    pw.Text('${result.score.toInt()} / ${maxScore.toInt()}', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                  ],
                ),
              ],
            ),
          ),
          
          pw.SizedBox(height: 30),

          // Exam Info
          pw.Row(
            children: [
              pw.Expanded(child: _buildInfoBox('Data da Prova', formattedDate, mutedTextColor, textColor)),
              pw.SizedBox(width: 20),
              pw.Expanded(child: _buildInfoBox('Hora de Realização', formattedTime, mutedTextColor, textColor)),
            ],
          ),

          pw.SizedBox(height: 30),
          pw.Text('Respostas Submetidas:', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: secondaryColor)),
          pw.SizedBox(height: 15),

          // Questions List
          ...List.generate(game.questions.length, (index) {
            final q = game.questions[index];
            final int? selectedOption = result.selectedOptions[index];
            final bool isCorrect = result.correctAnswers.contains(index);

            return pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 10),
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Pergunta ${index + 1}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: mutedTextColor)),
                      pw.Text(isCorrect ? 'Certa (+${q.points.toInt()} pts)' : 'Errada (0 pts)', 
                        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: isCorrect ? PdfColors.green700 : PdfColors.red700)),
                    ],
                  ),
                  pw.SizedBox(height: 5),
                  pw.Text(q.question, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 8),
                  ...List.generate(q.options.length, (optIdx) {
                    final isUserSelection = selectedOption == optIdx;
                    final isCorrectOption = optIdx == q.correctOptionIndex;
                    
                    PdfColor optColor = textColor;
                    if (isCorrectOption) optColor = PdfColors.green700;
                    if (isUserSelection && !isCorrectOption) optColor = PdfColors.red700;

                    return pw.Padding(
                      padding: const pw.EdgeInsets.only(bottom: 3),
                      child: pw.Row(
                        children: [
                          pw.Container(
                            width: 8, height: 8,
                            decoration: pw.BoxDecoration(
                              shape: pw.BoxShape.circle,
                              border: pw.Border.all(color: mutedTextColor, width: 0.5),
                              color: isUserSelection ? secondaryColor : null,
                            ),
                          ),
                          pw.SizedBox(width: 8),
                          pw.Expanded(
                            child: pw.Text(
                              q.options[optIdx],
                              style: pw.TextStyle(
                                fontSize: 9, 
                                color: optColor,
                                fontWeight: (isUserSelection || isCorrectOption) ? pw.FontWeight.bold : pw.FontWeight.normal,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),

                  if (result.studentResponses.containsKey(index)) ...[
                    pw.SizedBox(height: 10),
                    pw.Text('Resposta do Aluno:', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: mutedTextColor)),
                    pw.SizedBox(height: 4),
                    _buildPdfResponseValue(result.studentResponses[index]!),
                  ],
                ],
              ),
            );
          }),

          pw.SizedBox(height: 50),

          // Signature Section
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                children: [
                  pw.Container(width: 150, decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 0.5)))),
                  pw.SizedBox(height: 5),
                  pw.Text('Assinatura do Aluno', style: const pw.TextStyle(fontSize: 9)),
                ],
              ),
              pw.Column(
                children: [
                  pw.Container(width: 150, decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 0.5)))),
                  pw.SizedBox(height: 5),
                  pw.Text('Assinatura do Professor', style: const pw.TextStyle(fontSize: 9)),
                ],
              ),
            ],
          ),
        ],
      ),
    );

    return pdf.save();
  }

  static Future<Uint8List> generateCertificate({
    required InstitutionModel? institution,
    required UserModel teacher,
    required Subject subject,
    required String studentName,
    required double finalGrade,
    required String qualitativeGrade,
    required DateTime date,
  }) async {
    final pdf = pw.Document();
    
    // In pdf package, we often need to fetch images from network manually if they are URLs
    pw.MemoryImage? signatureImage;
    if (institution?.signatureUrl != null || teacher.signatureUrl != null) {
      try {
        final url = institution?.signatureUrl ?? teacher.signatureUrl!;
        final response = await NetworkAssetBundle(Uri.parse(url)).load(url);
        signatureImage = pw.MemoryImage(response.buffer.asUint8List());
      } catch (e) {
        debugPrint('Erro ao carregar imagem da assinatura para o PDF: $e');
      }
    }

    final primaryColor = PdfColor.fromHex('#0F172A');
    final goldColor = PdfColor.fromHex('#D4AF37');

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        build: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.all(30),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: goldColor, width: 5),
            ),
            child: pw.Container(
              padding: const pw.EdgeInsets.all(20),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: goldColor, width: 1),
              ),
              child: pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  pw.Text(institution?.name.toUpperCase() ?? 'EDUGAMING PLATFORM',
                      style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                  pw.SizedBox(height: 10),
                  pw.Divider(color: goldColor, thickness: 2, indent: 100, endIndent: 100),
                  pw.SizedBox(height: 30),
                  pw.Text('CERTIFICADO DE APROVEITAMENTO',
                      style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                  pw.SizedBox(height: 20),
                  pw.Text('Certifica-se que', style: const pw.TextStyle(fontSize: 16)),
                  pw.SizedBox(height: 10),
                  pw.Text(studentName.toUpperCase(),
                      style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                  pw.SizedBox(height: 10),
                  pw.Text('concluiu com sucesso a unidade curricular de', style: const pw.TextStyle(fontSize: 16)),
                  pw.SizedBox(height: 10),
                  pw.Text(subject.name.toUpperCase(),
                      style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                  pw.SizedBox(height: 20),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.center,
                    children: [
                      pw.Column(
                        children: [
                          pw.Text('Nota Quantitativa', style: const pw.TextStyle(fontSize: 12)),
                          pw.Text('${finalGrade.toInt()} Valores',
                              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                        ],
                      ),
                      pw.SizedBox(width: 50),
                      pw.Column(
                        children: [
                          pw.Text('Mencão Qualitativa', style: const pw.TextStyle(fontSize: 12)),
                          pw.Text(qualitativeGrade,
                              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 30),
                  pw.Text(
                      'Carga Horária: ${subject.teachingHours.toInt()}h (Lectivas) + ${subject.nonTeachingHours.toInt()}h (Não Lectivas)',
                      style: const pw.TextStyle(fontSize: 14)),
                  pw.SizedBox(height: 40),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                    children: [
                      pw.Column(
                        children: [
                          pw.Text('${date.day}/${date.month}/${date.year}',
                              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                          pw.SizedBox(height: 5),
                          pw.Text('Data da Emissão', style: const pw.TextStyle(fontSize: 10)),
                        ],
                      ),
                      pw.Column(
                        children: [
                          if (signatureImage != null)
                            pw.Image(signatureImage, height: 60, width: 120, fit: pw.BoxFit.contain)
                          else
                            pw.Container(height: 60, width: 120, decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black)))),
                          pw.SizedBox(height: 5),
                          pw.Text(institution?.name ?? teacher.name, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                          pw.Text('Assinatura Responsável', style: const pw.TextStyle(fontSize: 10)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _cell(String text, {bool isHeader = false, bool isBold = false, bool center = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        textAlign: center ? pw.TextAlign.center : pw.TextAlign.left,
        style: pw.TextStyle(
          fontSize: isHeader ? 8 : 9,
          fontWeight: (isHeader || isBold) ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  static pw.Widget _buildInfoBox(String label, String value, PdfColor labelColor, PdfColor valColor) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: const pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label, style: pw.TextStyle(fontSize: 8, color: labelColor)),
          pw.SizedBox(height: 3),
          pw.Text(value, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: valColor)),
        ],
      ),
    );
  }
}
