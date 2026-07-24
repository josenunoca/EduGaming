import 'package:flutter/material.dart';
import '../../../widgets/ai_translated_text.dart';

// Stub for Web/Windows — face scanner not available
class HRFaceScanner extends StatelessWidget {
  final Function(dynamic photo) onFaceVerified;
  const HRFaceScanner({super.key, required this.onFaceVerified});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const AiTranslatedText('Verificação Facial'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.camera_alt_outlined, size: 80, color: Colors.white24),
            const SizedBox(height: 24),
            const AiTranslatedText(
              'Verificação facial disponível apenas\nna aplicação móvel (Android / iOS).',
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
