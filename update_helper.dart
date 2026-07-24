import 'dart:io';

void main() {
  final file = File('c:/Users/josen/apptest/lib/utils/infrastructure_export_helper.dart');
  var content = file.readAsStringSync();
  
  // Update generateGlobalReportPdf
  content = content.replaceFirst(
    "static Future<Uint8List> generateGlobalReportPdf(List<Infrastructure> infrastructures) async {",
    "static Future<Uint8List> generateGlobalReportPdf(List<Infrastructure> infrastructures, {DateTime? startDate, DateTime? endDate}) async {"
  );
  
  // Add maintenance calculation inside the loop
  final maintenanceLogic = '''
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
                widgets.add(pw.Text('Intervencoes: \${filteredMaintenances.length}', style: normalStyle));
                widgets.add(pw.Text('Custo Total: EUR\${totalMaintenanceCost.toStringAsFixed(2)}', style: normalStyle));
                
                // Details
                for (var m in filteredMaintenances) {
                  final desc = m.description.replaceAll(RegExp(r'[^\\x00-\\xFF]'), '');
                  widgets.add(pw.Padding(
                    padding: const pw.EdgeInsets.only(left: 10, top: 4),
                    child: pw.Text('- \$desc (EUR\${m.cost.toStringAsFixed(2)})', style: smallStyle),
                  ));
                }
              }
            }

            if (infra.description.isNotEmpty) {
''';

  content = content.replaceFirst("if (infra.description.isNotEmpty) {", maintenanceLogic);
  
  // Update downloadGlobalReport
  content = content.replaceFirst(
    "static Future<void> downloadGlobalReport(List<Infrastructure> infrastructures) async {",
    "static Future<void> downloadGlobalReport(List<Infrastructure> infrastructures, {DateTime? startDate, DateTime? endDate}) async {"
  );
  content = content.replaceFirst(
    "final pdfBytes = await generateGlobalReportPdf(infrastructures);",
    "final pdfBytes = await generateGlobalReportPdf(infrastructures, startDate: startDate, endDate: endDate);"
  );
  
  file.writeAsStringSync(content);
}
