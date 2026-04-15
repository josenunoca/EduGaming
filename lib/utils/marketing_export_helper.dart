import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:http/http.dart' as http;
import 'package:archive/archive.dart';
import '../models/activity_model.dart';
import 'download_helper.dart';

class MarketingExportHelper {
  /// Generates the PDF document as bytes.
  static Future<Uint8List> generateMarketingPdf({
    required InstitutionalActivity activity,
    required String platform,
    required String generatedContent,
  }) async {
    final pdf = pw.Document();

    final titleStyle = pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold);
    final headingStyle = pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold);
    final normalStyle = const pw.TextStyle(fontSize: 12);

    // Filter only selected images
    final selectedImages = activity.media
        .where((m) => m.isSocialMediaSelected && m.type == 'image')
        .toList();

    // Fetch image bytes
    final imageProviders = <pw.MemoryImage>[];
    for (var img in selectedImages) {
      try {
        final response = await http.get(Uri.parse(img.url));
        if (response.statusCode == 200) {
          imageProviders.add(pw.MemoryImage(response.bodyBytes));
        }
      } catch (e) {
        debugPrint('Failed to load image for PDF: ${img.url}');
      }
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return [
            // Header
            pw.Header(
              level: 0,
              child: pw.Text('Relatório de Marketing: ${activity.title}', style: titleStyle),
            ),
            pw.SizedBox(height: 20),

            // Info Block
            pw.Text('Plataformas Escolhidas: $platform', style: headingStyle),
            pw.SizedBox(height: 10),
            
            // Text Block
            pw.Text('Conteúdo Gerado:', style: headingStyle),
            pw.SizedBox(height: 5),
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
              ),
              child: pw.Text(generatedContent, style: normalStyle),
            ),
            pw.SizedBox(height: 20),

            // Contact Info
            pw.Text('Pessoa Responsável', style: headingStyle),
            pw.SizedBox(height: 5),
            pw.Text('Nome: ${activity.responsibleName ?? "Não especificado"}', style: normalStyle),
            pw.Text('Email: ${activity.responsibleEmail ?? "Não especificado"}', style: normalStyle),
            pw.Text('Telefone: ${activity.responsiblePhone ?? "Não especificado"}', style: normalStyle),
            pw.SizedBox(height: 20),

            // Images Grid
            if (imageProviders.isNotEmpty) ...[
              pw.Text('Imagens para Publicação:', style: headingStyle),
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

            // Signature Block
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
                    pw.Text('Data de Publicação', style: headingStyle),
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

  /// Generates a ZIP archive containing the PDF, images, and text.
  static Future<Uint8List> generateMarketingZip({
    required InstitutionalActivity activity,
    required String platform,
    required String generatedContent,
    required Uint8List pdfBytes,
  }) async {
    final archive = Archive();

    // 1. Add PDF
    archive.addFile(ArchiveFile('Plano_Marketing_${activity.id}.pdf', pdfBytes.length, pdfBytes));

    // 2. Add Content Text File
    final textBytes = utf8.encode(generatedContent);
    archive.addFile(ArchiveFile('Texto_Publicacao_${platform}.txt', textBytes.length, textBytes));

    // 3. Add Raw Images
    final selectedImages = activity.media
        .where((m) => m.isSocialMediaSelected && m.type == 'image')
        .toList();

    for (int i = 0; i < selectedImages.length; i++) {
      final img = selectedImages[i];
      try {
        final response = await http.get(Uri.parse(img.url));
        if (response.statusCode == 200) {
          final ext = img.name.contains('.') ? img.name.split('.').last : 'jpg';
          final fileName = 'Imagem_${i + 1}.${ext}';
          archive.addFile(ArchiveFile(fileName, response.bodyBytes.length, response.bodyBytes));
        }
      } catch (e) {
        debugPrint('Failed to download image for ZIP: ${img.url}');
      }
    }

    // Encode ZIP
    final zipEncoder = ZipEncoder();
    final zipData = zipEncoder.encode(archive);
    return Uint8List.fromList(zipData);
  }

  /// Exports the PDF file
  static Future<void> downloadPdf(InstitutionalActivity activity, String platform, String content) async {
    final pdfBytes = await generateMarketingPdf(
      activity: activity,
      platform: platform,
      generatedContent: content,
    );
    await DownloadHelper.downloadFile(pdfBytes, 'Plano_Marketing_${activity.title.replaceAll(' ', '_')}.pdf');
  }

  /// Exports the ZIP archive
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
    await DownloadHelper.downloadFile(zipBytes, 'Marketing_${activity.title.replaceAll(' ', '_')}.zip');
  }
}
