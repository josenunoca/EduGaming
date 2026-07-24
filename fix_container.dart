import 'dart:io';

void main() {
  final actPath = 'c:/Users/josen/apptest/lib/utils/activity_export_helper.dart';
  final mktPath = 'c:/Users/josen/apptest/lib/utils/marketing_export_helper.dart';
  
  String replaceContainer(String content) {
    final oldBlock = '''            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
              ),
              child: pw.Text(
                generatedContent.replaceAll(RegExp(r'[^\\x00-\\xFF]'), ''),
                style: normalStyle,
              ),
            ),''';
            
    final newBlock = '''            pw.Divider(color: PdfColors.grey),
            pw.SizedBox(height: 10),
            pw.Text(
              generatedContent.replaceAll(RegExp(r'[^\\x00-\\xFF]'), ''),
              style: normalStyle,
            ),
            pw.SizedBox(height: 10),
            pw.Divider(color: PdfColors.grey),''';
            
    return content.replaceAll(oldBlock, newBlock);
  }

  if (File(actPath).existsSync()) {
    var actContent = File(actPath).readAsStringSync();
    actContent = replaceContainer(actContent);
    File(actPath).writeAsStringSync(actContent);
  }

  if (File(mktPath).existsSync()) {
    var mktContent = File(mktPath).readAsStringSync();
    mktContent = replaceContainer(mktContent);
    File(mktPath).writeAsStringSync(mktContent);
  }
}
