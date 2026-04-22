import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/course_model.dart';
import '../models/activity_model.dart';
import '../models/course_report_model.dart';

class ReportPdfGenerator {
  static Future<void> generateAndPrintCourseReport(CourseReport report, String courseName) async {
    final pdf = pw.Document();

    final font = await PdfGoogleFonts.interRegular();
    final fontBold = await PdfGoogleFonts.interBold();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        build: (pw.Context context) {
          return [
            _buildHeader(report, courseName),
            pw.SizedBox(height: 20),
            _buildMetricsGrid(report),
            pw.SizedBox(height: 20),
            _buildSubjectsTable(report),
            pw.SizedBox(height: 20),
            _buildSurveySummary(report),
            pw.SizedBox(height: 20),
            ...report.sections.map((s) => _buildSection(s)),
            pw.SizedBox(height: 20),
            _buildPhotos(report),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Relatorio_Curso_${courseName}_${report.academicYear.replaceAll('/', '_')}.pdf',
    );
  }

  static pw.Widget _buildHeader(CourseReport report, String courseName) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(report.title, style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
        pw.Text('Curso: $courseName', style: const pw.TextStyle(fontSize: 14)),
        pw.Text('Ano Letivo: ${report.academicYear}', style: const pw.TextStyle(fontSize: 12)),
        pw.Text('Gerado em: ${report.updatedAt.toString().split('.')[0]}', style: const pw.TextStyle(fontSize: 10)),
        pw.Divider(),
      ],
    );
  }

  static pw.Widget _buildMetricsGrid(CourseReport report) {
    final m = report.snapshotMetrics;
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        _buildMetricBox('Alunos', m['totalAcceptedStudents']?.toString() ?? '0'),
        _buildMetricBox('Assiduidade', '${((m['attendancePercentage'] ?? 0.0)).toStringAsFixed(1)}%'),
        _buildMetricBox('Programa', '${((m['syllabusCoveragePercentage'] ?? 0.0)).toStringAsFixed(1)}%'),
      ],
    );
  }

  static pw.Widget _buildMetricBox(String label, String value) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
      ),
      child: pw.Column(
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
          pw.Text(value, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }

  static pw.Widget _buildSubjectsTable(CourseReport report) {
    final metrics = report.snapshotMetrics['subjectMetrics'] as List? ?? [];
    
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Desempenho por Disciplina', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 10),
        pw.TableHelper.fromTextArray(
          headers: ['Disciplina', 'Assiduidade', 'Sumários'],
          data: metrics.map((m) => [
            m['subjectName'],
            '${((m['attendanceRatio'] ?? 0.0) * 100).toStringAsFixed(0)}%',
            '${m['sessionsDelivered']}/${m['sessionsPlanned']}'
          ]).toList(),
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
          cellAlignment: pw.Alignment.centerLeft,
        ),
      ],
    );
  }

  static pw.Widget _buildSurveySummary(CourseReport report) {
    final surveys = report.snapshotMetrics['surveys'] as List? ?? [];
    if (surveys.isEmpty) return pw.SizedBox();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Dados de Inquéritos Académicos', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 10),
        ...surveys.map((s) {
          final total = s['summary']?['totalResponses'] ?? 0;
          return pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 8),
            child: pw.Text('- ${s['title']}: $total respostas analisadas.', style: const pw.TextStyle(fontSize: 11)),
          );
        }),
      ],
    );
  }

  static pw.Widget _buildSection(ReportSection section) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(height: 15),
        pw.Text(section.title, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
        pw.SizedBox(height: 5),
        pw.Text(section.content, style: const pw.TextStyle(fontSize: 11)),
      ],
    );
  }

  static pw.Widget _buildPhotos(CourseReport report) {
    if (report.selectedActivityPhotoUrls.isEmpty) return pw.SizedBox();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(height: 20),
        pw.Text('Evidências Fotográficas', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 10),
        pw.Text('Nota: Devido a restrições de processamento remoto, as fotos serão indexadas por URL no PDF final ou podem ser impressas localmente.', style: pw.TextStyle(fontSize: 9, fontStyle: pw.FontStyle.italic)),
        ...report.selectedActivityPhotoUrls.map((url) => pw.Padding(
          padding: const pw.EdgeInsets.only(top: 5),
          child: pw.UrlLink(child: pw.Text(url, style: const pw.TextStyle(fontSize: 8, color: PdfColors.blue)), destination: url),
        )),
      ],
    );
  }
}
