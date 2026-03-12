import 'package:flutter/foundation.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'download_helper_stub.dart'
    if (dart.library.html) 'download_helper_web.dart';

class DownloadHelper {
  static Future<void> downloadFile(Uint8List bytes, String fileName) async {
    if (kIsWeb) {
      // Use direct web download to bypass 'printing' plugin issues
      downloadBytesWeb(bytes, fileName);
    } else {
      // Use Printing for non-web platforms (mobile/desktop)
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => bytes,
        name: fileName,
      );
    }
  }
}
