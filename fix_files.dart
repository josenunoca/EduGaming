import 'dart:io';

void main() {
  final actCode = """import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:http/http.dart' as http;
import 'package:archive/archive.dart';

import '../models/activity_model.dart';
import 'download_helper.dart';

class ActivityExportHelper {
  static Future<Uint8List> generateMarketingPdf({
    required InstitutionalActivity activity,
    required String platform,
    required String generatedContent,
  }) async {
    final pdf = pw.Document();

    final titleStyle = pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold);
    final headingStyle = pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold);
    final normalStyle = const pw.TextStyle(fontSize: 12);

    final selectedImages = activity.media
        .where((m) => m.isSocialMediaSelected && m.type == 'image')
        .toList();

    final imageProviders = <pw.MemoryImage>[];
    for (var img in selectedImages) {
      try {
        final response = await http.get(Uri.parse(img.url));
        if (response.statusCode == 200) {
          imageProviders.add(pw.MemoryImage(response.bodyBytes));
        }
      } catch (e) {
        debugPrint('Failed to load image for PDF: \${img.url}');
      }
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Text('Relatorio de Marketing: ' + (activity.title.replaceAll(RegExp(r'[^\\x00-\\xFF]'), '')), style: titleStyle),
            ),
            pw.SizedBox(height: 20),
            pw.Text('Plataformas Escolhidas: \$platform', style: headingStyle),
            pw.SizedBox(height: 10),
            pw.Text('Conteudo Gerado:', style: headingStyle),
            pw.SizedBox(height: 5),
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
              ),
              child: pw.Text(
                generatedContent.replaceAll(RegExp(r'[^\\x00-\\xFF]'), ''),
                style: normalStyle,
              ),
            ),
            pw.SizedBox(height: 20),
            pw.Text('Pessoa Responsavel', style: headingStyle),
            pw.SizedBox(height: 5),
            pw.Text('Nome: \${activity.responsibleName ?? "Nao especificado"}', style: normalStyle),
            pw.Text('Email: \${activity.responsibleEmail ?? "Nao especificado"}', style: normalStyle),
            pw.Text('Telefone: \${activity.responsiblePhone ?? "Nao especificado"}', style: normalStyle),
            pw.SizedBox(height: 20),
            if (imageProviders.isNotEmpty) ...[
              pw.Text('Imagens para Publicacao:', style: headingStyle),
              pw.SizedBox(height: 10),
              pw.Wrap(
                spacing: 10,
                runSpacing: 10,
                children: imageProviders.map((img) {
                  return pw.Container(
                    width: 150,
                    height: 150,
                    child: pw.Image(img, fit: pw.BoxFit.cover),
                  );
                }).toList(),
              ),
              pw.SizedBox(height: 30),
            ],
            pw.Spacer(),
            pw.Divider(),
            pw.SizedBox(height: 10),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Assinatura do Marketing', style: headingStyle),
                    pw.SizedBox(height: 20),
                    pw.Container(width: 200, height: 1, color: PdfColors.black),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Data de Publicacao', style: headingStyle),
                    pw.SizedBox(height: 20),
                    pw.Container(width: 150, height: 1, color: PdfColors.black),
                  ],
                ),
              ],
            ),
          ];
        },
      ),
    );

    return await pdf.save();
  }

  static Future<Uint8List> generateMarketingZip({
    required InstitutionalActivity activity,
    required String platform,
    required String generatedContent,
    required Uint8List pdfBytes,
  }) async {
    final archive = Archive();
    archive.addFile(ArchiveFile('Plano_Marketing_\${activity.id}.pdf', pdfBytes.length, pdfBytes));
    final textBytes = utf8.encode(generatedContent);
    archive.addFile(ArchiveFile('Texto_Publicacao_\${platform}.txt', textBytes.length, textBytes));

    final selectedImages = activity.media
        .where((m) => m.isSocialMediaSelected && m.type == 'image')
        .toList();

    for (int i = 0; i < selectedImages.length; i++) {
      final img = selectedImages[i];
      try {
        final response = await http.get(Uri.parse(img.url));
        if (response.statusCode == 200) {
          final ext = img.name.contains('.') ? img.name.split('.').last : 'jpg';
          final fileName = 'Imagem_\${i + 1}.\${ext}';
          archive.addFile(ArchiveFile(fileName, response.bodyBytes.length, response.bodyBytes));
        }
      } catch (e) {
        debugPrint('Failed to download image for ZIP: \${img.url}');
      }
    }
    final zipEncoder = ZipEncoder();
    final zipData = zipEncoder.encode(archive);
    return Uint8List.fromList(zipData);
  }

  static Future<void> downloadPdf(InstitutionalActivity activity, String platform, String content) async {
    final pdfBytes = await generateMarketingPdf(
      activity: activity,
      platform: platform,
      generatedContent: content,
    );
    await DownloadHelper.downloadFile(pdfBytes, 'Plano_Marketing_\${activity.title.replaceAll(RegExp(r'[^\\x00-\\xFF]'), '').replaceAll(' ', '_')}.pdf');
  }

  static Future<void> downloadZip(InstitutionalActivity activity, String platform, String content) async {
    final pdfBytes = await generateMarketingPdf(
      activity: activity,
      platform: platform,
      generatedContent: content,
    );
    final zipBytes = await generateMarketingZip(
      activity: activity,
      platform: platform,
      generatedContent: content,
      pdfBytes: pdfBytes,
    );
    await DownloadHelper.downloadFile(zipBytes, 'Marketing_\${activity.title.replaceAll(RegExp(r'[^\\x00-\\xFF]'), '').replaceAll(' ', '_')}.zip');
  }
}
""";

  final mktCode = actCode.replaceAll('InstitutionalActivity', 'MarketingEvent')
                         .replaceAll('ActivityExportHelper', 'MarketingExportHelper')
                         .replaceAll('activity_model.dart', 'marketing_event_model.dart');

  File('c:/Users/josen/apptest/lib/utils/activity_export_helper.dart').writeAsStringSync(actCode);
  File('c:/Users/josen/apptest/lib/utils/marketing_export_helper.dart').writeAsStringSync(mktCode);
}
