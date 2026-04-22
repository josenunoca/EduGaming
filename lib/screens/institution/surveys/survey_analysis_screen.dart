import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../../services/firebase_service.dart';
import '../../../services/ai_chat_service.dart';
import '../../../models/questionnaire_model.dart';
import '../../../models/survey_response_summary_model.dart';
import '../../../models/institution_model.dart';
import '../../../widgets/glass_card.dart';
import '../../../widgets/ai_translated_text.dart';
import '../../../services/pdf_service.dart';

class SurveyAnalysisScreen extends StatefulWidget {
  final Questionnaire survey;
  final InstitutionModel institution;

  const SurveyAnalysisScreen({
    super.key,
    required this.survey,
    required this.institution,
  });

  @override
  State<SurveyAnalysisScreen> createState() => _SurveyAnalysisScreenState();
}

class _SurveyAnalysisScreenState extends State<SurveyAnalysisScreen> {
  bool _isGenerating = false;
  final _notesCtrl = TextEditingController();
  bool _notesDirty = false;

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final service = context.read<FirebaseService>();

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: const AiTranslatedText('Análise e Relatório',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<List<QuestionnaireResponse>>(
        stream: service.getSurveyResponses(widget.institution.id, widget.survey.id),
        builder: (context, respSnap) {
          final responses = respSnap.data ?? [];

          return StreamBuilder<SurveyResponseSummary?>(
            stream: service.getSurveySummary(widget.institution.id, widget.survey.id),
            builder: (context, summSnap) {
              final summary = summSnap.data;
              if (summary != null && _notesCtrl.text.isEmpty && !_notesDirty) {
                _notesCtrl.text = summary.humanNotes;
              }

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Summary stats row
                  Row(
                    children: [
                      Expanded(child: _statBox('Total Respostas', '${responses.length}', const Color(0xFF00BFA5))),
                      const SizedBox(width: 12),
                      if (summary?.overallSatisfactionScore != null)
                        Expanded(child: _statBox('Score Global',
                            '${summary!.overallSatisfactionScore!.toStringAsFixed(1)}/10',
                            const Color(0xFF7B61FF))),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Buttons: Generate / PDF
                  if (summary != null || !widget.survey.isReportLocked)
                    Row(
                      children: [
                        if (!widget.survey.isReportLocked)
                          Expanded(
                            flex: summary != null ? 1 : 2,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF7B61FF),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: responses.isEmpty || _isGenerating
                                  ? null
                                  : () => _generateAnalysis(context, service, responses),
                              icon: _isGenerating
                                  ? const SizedBox(width: 18, height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : Icon(summary == null ? Icons.auto_awesome : Icons.refresh, color: Colors.white),
                              label: AiTranslatedText(
                                summary == null ? 'Gerar Análise' : 'Regenerar',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        if (summary != null) ...[
                          if (!widget.survey.isReportLocked) const SizedBox(width: 12),
                          Expanded(
                            flex: 1,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF00BFA5),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: () {
                                PdfService.generateSurveyReport(
                                  widget.survey,
                                  summary,
                                  institution: widget.institution,
                                );
                              },
                              icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
                              label: const AiTranslatedText('Exportar PDF',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ],
                    ),

                  const SizedBox(height: 16),

                  // Analysis results
                  if (summary != null) ...[
                    // Key trends
                    if (summary.keyTrends.isNotEmpty) ...[
                      GlassCard(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                const Icon(Icons.trending_up, size: 18, color: Color(0xFF00BFA5)),
                                const SizedBox(width: 8),
                                const AiTranslatedText('Tendências Principais',
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                              ]),
                              const SizedBox(height: 12),
                              ...summary.keyTrends.map((t) => Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(Icons.arrow_right, size: 16, color: Color(0xFF00BFA5)),
                                    Expanded(child: Text(t,
                                        style: const TextStyle(color: Colors.white70, fontSize: 13))),
                                  ],
                                ),
                              )),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Per-question quantitative analysis
                    ...widget.survey.questions.map((q) {
                      final qData = summary.quantitativeData[q.id] ?? {};
                      final qualText = summary.qualitativeInsights[q.id];

                      if (qData.isEmpty && qualText == null) return const SizedBox.shrink();

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: GlassCard(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(q.text, style: const TextStyle(color: Colors.white,
                                    fontWeight: FontWeight.bold, fontSize: 13)),
                                const SizedBox(height: 12),
                                if (qData.isNotEmpty) _buildBarChart(qData),
                                if (qualText != null) ...[
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF7B61FF).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: const Color(0xFF7B61FF).withValues(alpha: 0.3)),
                                    ),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Icon(Icons.auto_awesome, size: 14, color: Color(0xFF7B61FF)),
                                        const SizedBox(width: 8),
                                        Expanded(child: Text(qualText,
                                            style: const TextStyle(color: Colors.white70, fontSize: 12))),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    }),

                    // Human notes
                    const SizedBox(height: 4),
                    GlassCard(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              const Icon(Icons.edit_note, size: 18, color: Colors.amber),
                              const SizedBox(width: 8),
                              const AiTranslatedText('Notas e Interpretações',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                            ]),
                            const SizedBox(height: 10),
                            TextField(
                              controller: _notesCtrl,
                              maxLines: 5,
                              enabled: !summary.isLocked,
                              style: const TextStyle(color: Colors.white),
                              onChanged: (_) => setState(() => _notesDirty = true),
                              decoration: InputDecoration(
                                hintText: summary.isLocked
                                    ? 'Relatório finalizado e bloqueado.'
                                    : 'Adicione as suas interpretações e conclusões aqui...',
                                hintStyle: const TextStyle(color: Colors.white30),
                                filled: true,
                                fillColor: Colors.white.withValues(alpha: 0.05),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: Colors.amber),
                                ),
                              ),
                            ),
                            if (!summary.isLocked && _notesDirty) ...[
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerRight,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.amber,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  onPressed: () async {
                                    await service.updateSurveyHumanNotes(
                                        widget.institution.id, widget.survey.id, _notesCtrl.text);
                                    setState(() => _notesDirty = false);
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                                          content: AiTranslatedText('Notas guardadas!')));
                                    }
                                  },
                                  icon: const Icon(Icons.save, size: 14, color: Colors.black),
                                  label: const AiTranslatedText('Guardar Notas',
                                      style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12)),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Visibility settings + Lock
                    if (!summary.isLocked) ...[
                      _buildVisibilitySection(context, service, summary),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          minimumSize: const Size(double.infinity, 0),
                        ),
                        onPressed: () => _confirmLock(context, service),
                        icon: const Icon(Icons.lock, color: Colors.white),
                        label: const AiTranslatedText('Finalizar e Bloquear Relatório',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ] else ...[
                      GlassCard(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              const Icon(Icons.lock, color: Colors.redAccent, size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const AiTranslatedText('Relatório Finalizado',
                                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                    if (summary.lockedAt != null)
                                      AiTranslatedText(
                                        'Bloqueado em ${DateFormatHelper.format(summary.lockedAt!)}',
                                        style: const TextStyle(color: Colors.white54, fontSize: 11),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 80),
                  ] else if (!_isGenerating && responses.isEmpty) ...[
                    const SizedBox(height: 60),
                    const Center(
                      child: AiTranslatedText(
                        'Ainda não há respostas para analisar.',
                        style: TextStyle(color: Colors.white54, fontSize: 15),
                      ),
                    ),
                  ],
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _statBox(String label, String value, Color color) {
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        child: Column(
          children: [
            Text(value, style: TextStyle(color: color, fontSize: 26, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            AiTranslatedText(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _buildBarChart(Map<String, int> data) {
    final total = data.values.fold(0, (a, b) => a + b);
    if (total == 0) return const SizedBox.shrink();

    final sorted = data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      children: sorted.map((e) {
        final pct = e.value / total;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(e.key, style: const TextStyle(color: Colors.white70, fontSize: 12),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  Text('${e.value} (${(pct * 100).toStringAsFixed(0)}%)',
                      style: const TextStyle(color: Colors.white54, fontSize: 11)),
                ],
              ),
              const SizedBox(height: 4),
              LayoutBuilder(builder: (ctx, constraints) {
                return Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.white12,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: pct,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF00BFA5), Color(0xFF7B61FF)],
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildVisibilitySection(
      BuildContext context, FirebaseService service, SurveyResponseSummary summary) {
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.visibility_outlined, size: 18, color: Color(0xFF00D1FF)),
              const SizedBox(width: 8),
              const AiTranslatedText('Visibilidade das Conclusões',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            ]),
            const SizedBox(height: 12),
            ...SurveyVisibility.values.map((v) {
              final label = _visibilityLabel(v);
              final current = widget.survey.visibility;
              return RadioListTile<SurveyVisibility>(
                dense: true,
                activeColor: const Color(0xFF00BFA5),
                title: AiTranslatedText(label, style: const TextStyle(color: Colors.white, fontSize: 13)),
                value: v,
                groupValue: current,
                onChanged: (val) async {
                  if (val != null) {
                    await service.updateSurveyVisibility(
                        widget.institution.id, widget.survey.id, val);
                  }
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  String _visibilityLabel(SurveyVisibility v) {
    switch (v) {
      case SurveyVisibility.directionOnly: return 'Apenas Direção';
      case SurveyVisibility.departments: return 'Departamentos';
      case SurveyVisibility.publicAccess: return 'Público Geral';
    }
  }

  Future<void> _generateAnalysis(BuildContext context, FirebaseService service,
      List<QuestionnaireResponse> responses) async {
    setState(() => _isGenerating = true);
    try {
      // Build quantitative data locally (fast)
      final Map<String, Map<String, int>> quantData = {};
      final Map<String, List<String>> openTextAnswers = {};

      for (final q in widget.survey.questions) {
        quantData[q.id] = {};
        if (q.type == QuestionType.openText) {
          openTextAnswers[q.id] = [];
        }
      }

      for (final resp in responses) {
        resp.answers.forEach((qId, answer) {
          if (openTextAnswers.containsKey(qId)) {
            if (answer is String && answer.isNotEmpty) {
              openTextAnswers[qId]!.add(answer);
            }
          } else {
            final key = answer.toString();
            quantData[qId] ??= {};
            quantData[qId]![key] = (quantData[qId]![key] ?? 0) + 1;
          }
        });
      }

      // Use AI to analyse qualitative responses
      final aiService = context.read<AiChatService>();

      final aiResult = await aiService.analyzeSurveyResponses(
        survey: widget.survey,
        responses: responses,
        openTextAnswers: openTextAnswers,
      );

      if (!mounted) return;

      final summary = SurveyResponseSummary(
        id: const Uuid().v4(),
        questionnaireId: widget.survey.id,
        generatedAt: DateTime.now(),
        quantitativeData: quantData,
        qualitativeInsights: Map<String, String>.from(aiResult['qualitativeInsights'] ?? {}),
        overallSatisfactionScore: (aiResult['overallScore'] as num?)?.toDouble(),
        keyTrends: List<String>.from(aiResult['keyTrends'] ?? []),
        totalResponses: responses.length,
        humanNotes: _notesCtrl.text,
      );

      await service.saveSurveySummary(widget.institution.id, summary);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: AiTranslatedText('Análise gerada com sucesso!'),
          backgroundColor: Color(0xFF00BFA5),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: AiTranslatedText('Erro ao gerar análise: $e'),
          backgroundColor: Colors.redAccent,
        ));
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Future<void> _confirmLock(BuildContext context, FirebaseService service) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const AiTranslatedText('Finalizar Relatório',
            style: TextStyle(color: Colors.white)),
        content: const AiTranslatedText(
          'Ao finalizar, o relatório ficará bloqueado e não poderá ser editado. Esta ação é irreversível.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const AiTranslatedText('Cancelar', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const AiTranslatedText('Finalizar e Bloquear', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await service.lockSurveyReport(widget.institution.id, widget.survey.id);
      await service.updateSurveyStatus(widget.institution.id, widget.survey.id, SurveyStatus.locked);
    }
  }
}

class DateFormatHelper {
  static String format(DateTime dt) {
    return '${dt.day.toString().padLeft(2,'0')}/${dt.month.toString().padLeft(2,'0')}/${dt.year} ${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
  }
}
