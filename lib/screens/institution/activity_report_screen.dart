import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/activity_model.dart';
import '../../models/annual_report_draft.dart';
import '../../services/ai_chat_service.dart';
import '../../widgets/ai_translated_text.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/custom_button.dart';
import '../../services/pdf_service.dart';
import '../../models/institution_model.dart';

class ActivityReportScreen extends StatefulWidget {
  final List<InstitutionalActivity> activities;
  final InstitutionModel institution;
  const ActivityReportScreen({super.key, required this.activities, required this.institution});

  @override
  State<ActivityReportScreen> createState() => _ActivityReportScreenState();
}

class _ActivityReportScreenState extends State<ActivityReportScreen> {
  late AnnualReportDraft _draft;
  bool _isGenerating = false;
  bool _isExporting = false;
  
  final TextEditingController _introController = TextEditingController();
  final TextEditingController _conclusionController = TextEditingController();
  final Map<String, TextEditingController> _sectionControllers = {};

  @override
  void initState() {
    super.initState();
    _draft = AnnualReportDraft.fromRawData(widget.activities);
    _introController.text = _draft.introduction;
    _conclusionController.text = _draft.conclusion;
    for (var section in _draft.sections) {
      _sectionControllers[section.title] = TextEditingController(text: section.summary);
    }
  }

  @override
  void dispose() {
    _introController.dispose();
    _conclusionController.dispose();
    for (var c in _sectionControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _generateWithAI() async {
    setState(() => _isGenerating = true);
    try {
      final aiService = context.read<AiChatService>();
      final result = await aiService.generateAnnualReportDraft(
        institution: widget.institution,
        activities: widget.activities,
      );

      setState(() {
        _introController.text = result['introduction'] ?? '';
        _conclusionController.text = result['conclusion'] ?? '';
        final rawSections = result['sections'];
        final sectionsMap = rawSections is Map ? Map<String, dynamic>.from(rawSections) : <String, dynamic>{};
        
        for (var section in _draft.sections) {
          if (sectionsMap.containsKey(section.title)) {
            _sectionControllers[section.title]?.text = sectionsMap[section.title] ?? '';
          }
        }
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Esboço gerado com sucesso pela IA!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao gerar com IA: $e')),
      );
    } finally {
      setState(() => _isGenerating = false);
    }
  }

  void _updateDraft() {
    _draft.introduction = _introController.text;
    _draft.conclusion = _conclusionController.text;
    for (var section in _draft.sections) {
      section.summary = _sectionControllers[section.title]?.text ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const AiTranslatedText('Editor de Relatório Anual'),
        actions: [
          if (!_isGenerating)
            IconButton(
              icon: const Icon(Icons.auto_awesome, color: Colors.amber),
              tooltip: 'Gerar com IA',
              onPressed: _generateWithAI,
            ),
        ],
      ),
      body: _isGenerating 
        ? const Center(child: CircularProgressIndicator(color: Colors.amber))
        : SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader('Introdução do Relatório', Icons.subject),
                _buildEditorCard(_introController),
                
                const SizedBox(height: 32),
                _buildSectionHeader('Resumo por Categorias', Icons.category),
                ..._draft.sections.map((section) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 16, bottom: 8),
                      child: Text(section.title.toUpperCase(), 
                        style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                    _buildEditorCard(_sectionControllers[section.title]!),
                  ],
                )),

                const SizedBox(height: 32),
                _buildSectionHeader('Considerações Finais', Icons.flag),
                _buildEditorCard(_conclusionController),

                const SizedBox(height: 48),
                const Text('EXPORTAR DOCUMENTO FINAL', 
                  style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: CustomButton(
                        onPressed: _isExporting ? null : () async {
                          _updateDraft();
                          setState(() => _isExporting = true);
                          try {
                            await PdfService.generateAnnualReportPDF(
                              widget.institution, 
                              widget.activities,
                              draft: _draft,
                            );
                          } finally {
                            if (mounted) setState(() => _isExporting = false);
                          }
                        },
                        icon: Icons.picture_as_pdf,
                        label: 'Relatório PDF',
                        height: 54,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: CustomButton(
                        onPressed: _isExporting ? null : () async {
                          _updateDraft();
                          setState(() => _isExporting = true);
                          try {
                            await PdfService.generatePresentationPDF(
                              widget.institution, 
                              widget.activities,
                              draft: _draft,
                            );
                          } finally {
                            if (mounted) setState(() => _isExporting = false);
                          }
                        },
                        icon: Icons.slideshow,
                        label: 'Apresentação',
                        height: 54,
                        color: Colors.indigo,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: Colors.white70, size: 20),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildEditorCard(TextEditingController controller) {
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: TextFormField(
          controller: controller,
          maxLines: null,
          style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
          decoration: const InputDecoration(
            border: InputBorder.none,
            hintText: 'Escreva aqui...',
            hintStyle: TextStyle(color: Colors.white24),
          ),
        ),
      ),
    );
  }
}

