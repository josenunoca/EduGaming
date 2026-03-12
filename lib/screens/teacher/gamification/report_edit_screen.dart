import 'package:flutter/material.dart';
import '../../../widgets/ai_translated_text.dart';
import '../../../widgets/glass_card.dart';
import '../../../services/pdf_service.dart';
import '../../../models/subject_model.dart';

class ReportEditScreen extends StatefulWidget {
  final String initialContent;
  final String title;
  final String subtitle;
  final bool isSynthetic;
  final AdvancedScoreStats? stats;

  const ReportEditScreen({
    super.key,
    required this.initialContent,
    required this.title,
    required this.subtitle,
    this.isSynthetic = true,
    this.stats,
  });

  @override
  State<ReportEditScreen> createState() => _ReportEditScreenState();
}

class _ReportEditScreenState extends State<ReportEditScreen> {
  bool _isGenerating = false;
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialContent);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _generateAndDownload() async {
    if (_isGenerating) return;
    setState(() => _isGenerating = true);
    try {
      final bytes = await PdfService.generateAssessmentReport(
        title: widget.title,
        subtitle: widget.subtitle,
        content: _controller.text,
        isSynthetic: widget.isSynthetic,
        stats: widget.stats,
      );
      
      await PdfService.downloadPdf(
        bytes, 
        'Relatorio_${widget.title.replaceAll(' ', '_').replaceAll(':', '')}.pdf'
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao gerar PDF: $e'))
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const AiTranslatedText('Editar Relatório'),
        actions: [
          IconButton(
            icon: _isGenerating ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.download),
            onPressed: _isGenerating ? null : _generateAndDownload,
            tooltip: 'Download PDF',
          ),
        ],
      ),
      body: Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          ),
        ),
        child: Column(
          children: [
            const AiTranslatedText(
              'Reveja e edite a análise gerada pela IA antes de exportar para PDF.',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: GlassCard(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _controller,
                  maxLines: null,
                  expands: true,
                  style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.5),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Conteúdo do relatório...',
                    hintStyle: TextStyle(color: Colors.white24),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _isGenerating ? null : _generateAndDownload,
                icon: _isGenerating 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                  : const Icon(Icons.picture_as_pdf),
                label: AiTranslatedText(_isGenerating ? 'A GERAR PDF...' : 'DESCARREGAR RELATÓRIO PDF'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00D1FF),
                  foregroundColor: const Color(0xFF0F172A),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
