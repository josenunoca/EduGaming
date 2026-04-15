import 'package:flutter/material.dart';
import '../../models/activity_model.dart';
import '../../services/report_service.dart';
import '../../widgets/ai_translated_text.dart';
import '../../widgets/glass_card.dart';

class ActivityReportScreen extends StatelessWidget {
  final List<InstitutionalActivity> activities;
  const ActivityReportScreen({super.key, required this.activities});

  @override
  Widget build(BuildContext context) {
    final report = ReportService.generateAnnualReport(activities);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const AiTranslatedText('Relatório Anual de Atividades'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              // Share logic placeholder
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            GlassCard(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: SelectableText(
                  report,
                  style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'monospace',
                      fontSize: 13),
                ),
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                // Export PDF logic placeholder
              },
              icon: const Icon(Icons.picture_as_pdf),
              label: const AiTranslatedText('Exportar como PDF Profissional'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7B61FF),
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
