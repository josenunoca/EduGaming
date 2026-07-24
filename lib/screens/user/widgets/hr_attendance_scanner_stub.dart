import 'package:flutter/material.dart';
import '../../../widgets/ai_translated_text.dart';

// Stub for Web/Windows — QR scanner not available
class HRAttendanceScanner extends StatelessWidget {
  final Function(String code) onScan;
  const HRAttendanceScanner({super.key, required this.onScan});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const AiTranslatedText('Scanner QR Code'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.qr_code_scanner, size: 80, color: Colors.white24),
            const SizedBox(height: 24),
            const AiTranslatedText(
              'Leitura de QR Code disponível apenas\nna aplicação móvel (Android / iOS).',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back),
              label: const AiTranslatedText('Voltar'),
            ),
          ],
        ),
      ),
    );
  }
}
