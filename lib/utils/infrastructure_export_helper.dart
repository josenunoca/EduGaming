import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:http/http.dart' as http;
import 'package:archive/archive.dart';

import '../models/infrastructure_model.dart';
import 'download_helper.dart';

class InfrastructureExportHelper {
  static Future<Uint8List> generateGlobalReportPdf(List<Infrastructure> infrastructures, {DateTime? startDate, DateTime? endDate}) async {
    final pdf = pw.Document();

    final titleStyle = pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold);
    final headingStyle = pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold);
    final normalStyle = const pw.TextStyle(fontSize: 12);
    final smallStyle = const pw.TextStyle(fontSize: 10, color: PdfColors.grey);

    final filteredInfras = infrastructures.where((i) => i.includeInReport).toList();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          final widgets = <pw.Widget>[
            pw.Header(
              level: 0,
              child: pw.Text('Relatorio Global de Infraestruturas', style: titleStyle),
            ),
            pw.SizedBox(height: 10),
            pw.Text('Total incluídas no relatorio: ${filteredInfras.length}', style: normalStyle),
            pw.SizedBox(height: 20),
          ];

          for (var infra in filteredInfras) {
            widgets.add(pw.Divider());
            widgets.add(pw.SizedBox(height: 10));
            widgets.add(
              pw.Text(
                infra.name.replaceAll(RegExp(r'[^\x00-\xFF]'), ''),
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)
              )
            );
            widgets.add(pw.SizedBox(height: 8));

            if (infra.address.isNotEmpty) {
              widgets.add(pw.Text('Morada: ${infra.address.replaceAll(RegExp(r'[^\x00-\xFF]'), '')}', style: normalStyle));
            }
            if (infra.contact.isNotEmpty) {
              widgets.add(pw.Text('Contacto: ${infra.contact.replaceAll(RegExp(r'[^\x00-\xFF]'), '')}', style: normalStyle));
            }
            if (!infra.isMarketValueNotApplicable && infra.marketValue != null) {
              widgets.add(pw.Text('Valor de Mercado: EUR${infra.marketValue!.toStringAsFixed(2)}', style: normalStyle));
            } else {
              widgets.add(pw.Text('Valor de Mercado: N/A', style: normalStyle));
            }
            
            widgets.add(pw.SizedBox(height: 10));
                        widgets.add(pw.SizedBox(height: 10));
            
            // Maintenance logic
            if (infra.maintenances.isNotEmpty) {
              final filteredMaintenances = infra.maintenances.where((m) {
                if (startDate != null && m.startDate.isBefore(startDate)) return false;
                if (endDate != null && m.endDate.isAfter(endDate)) return false;
                return true;
              }).toList();
              
              if (filteredMaintenances.isNotEmpty) {
                final totalMaintenanceCost = filteredMaintenances.fold<double>(0, (sum, m) => sum + m.cost);
                widgets.add(pw.Text('Manutencao no periodo:', style: headingStyle));
                widgets.add(pw.SizedBox(height: 4));
                widgets.add(pw.Text('Intervencoes: ${filteredMaintenances.length}', style: normalStyle));
                widgets.add(pw.Text('Custo Total: EUR${totalMaintenanceCost.toStringAsFixed(2)}', style: normalStyle));
                
                // Details
                for (var m in filteredMaintenances) {
                  final desc = m.description.replaceAll(RegExp(r'[^\x00-\xFF]'), '');
                  widgets.add(pw.Padding(
                    padding: const pw.EdgeInsets.only(left: 10, top: 4),
                    child: pw.Text('- $desc (EUR${m.cost.toStringAsFixed(2)})', style: smallStyle),
                  ));
                }
              }
            }

            if (infra.description.isNotEmpty) {

              widgets.add(pw.Text('Resenha Historica:', style: headingStyle));
              widgets.add(pw.SizedBox(height: 4));
              widgets.add(
                pw.Text(
                  infra.description.replaceAll(RegExp(r'[^\x00-\xFF]'), ''),
                  style: normalStyle,
                )
              );
            }

            widgets.add(pw.SizedBox(height: 20));
          }

          return widgets;
        },
      ),
    );

    return await pdf.save();
  }

  static Future<void> downloadGlobalReport(List<Infrastructure> infrastructures, {DateTime? startDate, DateTime? endDate}) async {
    final pdfBytes = await generateGlobalReportPdf(infrastructures, startDate: startDate, endDate: endDate);
    await DownloadHelper.downloadFile(pdfBytes, 'Relatorio_Global_Infraestruturas.pdf');
  }
}
