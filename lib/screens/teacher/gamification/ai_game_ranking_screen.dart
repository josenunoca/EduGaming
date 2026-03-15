import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/subject_model.dart';
import '../../../services/firebase_service.dart';
import '../../../services/ai_chat_service.dart';
import '../../../widgets/ai_translated_text.dart';
import '../../../widgets/glass_card.dart';
import 'report_edit_screen.dart';
import 'package:intl/intl.dart';

class AiGameRankingScreen extends StatefulWidget {
  final AiGame game;
  const AiGameRankingScreen({super.key, required this.game});

  @override
  State<AiGameRankingScreen> createState() => _AiGameRankingScreenState();
}

class _AiGameRankingScreenState extends State<AiGameRankingScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<AiGameResult> _results = [];
  bool _isLoading = true;
  String? _aiAnalysis;
  bool _isGeneratingAnalysis = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadResults();
  }

  Future<void> _loadResults() async {
    final service = context.read<FirebaseService>();
    final results = await service.getGameResults(widget.game.id);
    if (mounted) {
      setState(() {
        _results = results;
        _isLoading = false;
      });
    }
  }

  Future<void> _generateAnalysis() async {
    setState(() => _isGeneratingAnalysis = true);
    try {
      final chatService = context.read<AiChatService>();

      final stats = _calculateAdvancedStats();

      String statsText = 'Jogo: ${widget.game.title}\n';
      statsText += 'Total de jogadas: ${stats.totalParticipants}\n';
      statsText += 'Média de pontuação: ${stats.average.toStringAsFixed(1)}\n';
      statsText += 'Mediana: ${stats.median.toStringAsFixed(1)}\n';
      statsText += 'Moda: ${stats.modes.join(', ')}\n';
      statsText +=
          'Quartis: Q1=${stats.q1.toStringAsFixed(1)}, Q3=${stats.q3.toStringAsFixed(1)}\n';
      statsText +=
          'Distribuição (Histograma): ${stats.histogramBins.join(' | ')}\n';

      statsText += '\nTaxas de Acerto por Pergunta:\n';
      for (int i = 0; i < widget.game.questions.length; i++) {
        int correct = 0;
        for (var r in _results) {
          if (r.correctAnswers.contains(i)) correct++;
        }
        double r = (correct / _results.length) * 100;
        statsText +=
            '- P${i + 1} (${widget.game.questions[i].question}): ${r.toStringAsFixed(0)}% de acerto\n';
      }

      final prompt = '''
Analisa estas estatísticas descriptivas e quantitativas avançadas de uma avaliação da EduGAming Platform.
Gera uma Análise Qualitativa "Poderosa" e Profissional que inclua:
1. Visão Geral do Desempenho (interpretando média vs mediana vs moda).
2. Análise da Dispersão e Distribuição (com base nos quartis e histograma).
3. DESTAQUES DE ACERTOS: Analisa as perguntas com maior percentagem de acerto.
4. PONTOS CRÍTICOS: Analisa as perguntas com menor percentagem de acerto, identificando potenciais lacunas de conhecimento.
5. Sugestões Pedagógicas de Intervenção Imediata.
6. CONCLUSÃO E PRÓXIMOS PASSOS: Um resumo final estratégico com sugestões concretas de melhoria.

Estatísticas Detalhadas:
$statsText
''';

      List<SubjectContent> contextContent = [];
      await chatService.initializeSession(contextContent);

      String response = '';
      await for (final chunk in chatService.sendMessage(prompt)) {
        response += chunk;
        if (mounted) setState(() => _aiAnalysis = response);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro: $e')));
      }
    } finally {
      if (mounted) setState(() => _isGeneratingAnalysis = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: AiTranslatedText('Estatísticas e Ranking: ${widget.game.title}',
            style: const TextStyle(fontSize: 16)),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(
                icon: Icon(Icons.dashboard),
                child: AiTranslatedText('Dashboard')),
            Tab(
                icon: Icon(Icons.leaderboard),
                child: AiTranslatedText('Ranking')),
            Tab(
                icon: Icon(Icons.analytics),
                child: AiTranslatedText('Estatísticas e IA')),
          ],
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          ),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                controller: _tabController,
                children: [
                  _buildDashboardTab(),
                  _buildRankingTab(),
                  _buildStatisticsTab(),
                ],
              ),
      ),
    );
  }

  Widget _buildRankingTab() {
    if (_results.isEmpty) {
      return const Center(
          child: AiTranslatedText('Nenhum aluno jogou este jogo ainda.',
              style: TextStyle(color: Colors.white38)));
    }

    // Group by best score per student
    Map<String, AiGameResult> bestResults = {};
    Map<String, int> playCounts = {};
    for (var r in _results) {
      playCounts[r.studentId] = (playCounts[r.studentId] ?? 0) + 1;
      if (!bestResults.containsKey(r.studentId) ||
          bestResults[r.studentId]!.score < r.score) {
        bestResults[r.studentId] = r;
      }
    }

    final rankedList = bestResults.values.toList()
      ..sort((a, b) => b.score.compareTo(a.score));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: rankedList.length,
      itemBuilder: (context, index) {
        final r = rankedList[index];
        final isTop3 = index < 3;
        Color medalColor = Colors.transparent;
        if (index == 0) {
          medalColor = Colors.amber;
        } else if (index == 1)
          medalColor = Colors.blueGrey[300]!;
        else if (index == 2) medalColor = Colors.brown[400]!;

        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: GlassCard(
            child: ListTile(
              leading: isTop3
                  ? CircleAvatar(
                      backgroundColor: medalColor.withValues(alpha: 0.2),
                      child: Icon(Icons.emoji_events, color: medalColor))
                  : CircleAvatar(
                      backgroundColor: Colors.white10,
                      child: Text('${index + 1}',
                          style: const TextStyle(color: Colors.white54))),
              title: Text(r.studentName,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
              subtitle: Text(
                  'Jogado ${playCounts[r.studentId]} vezes • Última vez: ${DateFormat('dd/MM HH:mm').format(r.playedAt)}',
                  style: const TextStyle(color: Colors.white38, fontSize: 11)),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const AiTranslatedText('Classificação Máx',
                      style: TextStyle(color: Colors.white54, fontSize: 9)),
                  Text('${r.score.toStringAsFixed(0)} pts',
                      style: const TextStyle(
                          color: Color(0xFF00D1FF),
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatisticsTab() {
    if (_results.isEmpty) {
      return const Center(
          child: AiTranslatedText('Estatísticas indisponíveis (sem dados).',
              style: TextStyle(color: Colors.white38)));
    }

    // Question difficulty analysis
    Map<int, int> correctCounts = {};
    Map<int, int> incorrectCounts = {};
    for (int i = 0; i < widget.game.questions.length; i++) {
      correctCounts[i] = 0;
      incorrectCounts[i] = 0;
    }
    for (var r in _results) {
      for (var c in r.correctAnswers) {
        correctCounts[c] = (correctCounts[c] ?? 0) + 1;
      }
      for (var i in r.incorrectAnswers) {
        incorrectCounts[i] = (incorrectCounts[i] ?? 0) + 1;
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: GlassCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const AiTranslatedText('Total de Jogadas',
                          style:
                              TextStyle(color: Colors.white54, fontSize: 12)),
                      const SizedBox(height: 8),
                      Text('${_results.length}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: GlassCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const AiTranslatedText('Média Global',
                          style:
                              TextStyle(color: Colors.white54, fontSize: 12)),
                      const SizedBox(height: 8),
                      Text(
                          '${(_results.map((r) => r.score).reduce((a, b) => a + b) / _results.length).toStringAsFixed(0)} pts',
                          style: const TextStyle(
                              color: Color(0xFF00D1FF),
                              fontSize: 24,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const AiTranslatedText('Análise por Questões',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white)),
          const SizedBox(height: 12),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: widget.game.questions.length,
            itemBuilder: (context, index) {
              final q = widget.game.questions[index];
              final corrects = correctCounts[index] ?? 0;
              final incorrects = incorrectCounts[index] ?? 0;
              final total = corrects + incorrects;
              final correctRatio = total > 0 ? corrects / total : 0.0;

              Color barColor = Colors.greenAccent;
              if (correctRatio < 0.5) {
                barColor = Colors.redAccent;
              } else if (correctRatio < 0.8) barColor = Colors.orangeAccent;

              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: GlassCard(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('P${index + 1}: ${q.question}',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 13),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: LinearProgressIndicator(
                              value: correctRatio,
                              backgroundColor: Colors.white10,
                              color: barColor,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                              '${(correctRatio * 100).toStringAsFixed(0)}% Acerto',
                              style: TextStyle(
                                  color: barColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isGeneratingAnalysis ? null : _generateAnalysis,
              icon: _isGeneratingAnalysis
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.auto_awesome),
              label: const AiTranslatedText(
                  'Gerar Análise Qualitativa com Inteligência Artificial'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7B61FF),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16)),
            ),
          ),
          const SizedBox(height: 24),
          if (_aiAnalysis != null) ...[
            const AiTranslatedText('Análise do AI Assistant:',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF00D1FF))),
            const SizedBox(height: 12),
            GlassCard(
              padding: const EdgeInsets.all(16),
              child: Text(_aiAnalysis!,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 13, height: 1.5)),
            ),
            const SizedBox(height: 24),
          ],
          if (_results.isNotEmpty) ...[
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showPdfOptionsDialog(),
                    icon: const Icon(Icons.picture_as_pdf),
                    label: const AiTranslatedText('Exportar Relatório'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00D1FF),
                      foregroundColor: const Color(0xFF0F172A),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                if (_aiAnalysis != null) ...[
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 60,
                    height: 56,
                    child: OutlinedButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ReportEditScreen(
                            initialContent: _aiAnalysis!,
                            title: 'Relatório: ${widget.game.title}',
                            subtitle: 'Análise de Desempenho e Sugestões IA',
                            stats: _calculateAdvancedStats(),
                          ),
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF00D1FF),
                        side: const BorderSide(color: Color(0xFF00D1FF)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Icon(Icons.edit_note),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  AdvancedScoreStats _calculateAdvancedStats() {
    if (_results.isEmpty) {
      return AdvancedScoreStats(
          average: 0,
          median: 0,
          modes: [],
          min: 0,
          max: 0,
          q1: 0,
          q3: 0,
          histogramBins: [0, 0, 0, 0, 0],
          totalParticipants: 0);
    }

    final scores = _results.map((r) => r.score).toList()..sort();
    final total = scores.length;

    double avg = scores.reduce((a, b) => a + b) / total;

    // Median
    double median;
    if (total % 2 == 0) {
      median = (scores[total ~/ 2 - 1] + scores[total ~/ 2]) / 2;
    } else {
      median = scores[total ~/ 2];
    }

    // Mode
    Map<double, int> counts = {};
    for (var s in scores) {
      counts[s] = (counts[s] ?? 0) + 1;
    }
    int maxCount = counts.values.reduce((a, b) => a > b ? a : b);
    List<double> modes = counts.entries
        .where((e) => e.value == maxCount)
        .map((e) => e.key)
        .toList();

    // Quartiles
    double getPercentile(double p) {
      int index = (p * (total - 1)).floor();
      return scores[index];
    }

    double q1 = getPercentile(0.25);
    double q3 = getPercentile(0.75);

    // Question-specific stats
    List<QuestionStat> qStats = [];
    for (int i = 0; i < widget.game.questions.length; i++) {
      int correct = 0;
      for (var r in _results) {
        if (r.correctAnswers.contains(i)) correct++;
      }
      int incorrect = _results.length - correct;
      double percentage = (correct / _results.length) * 100;

      qStats.add(QuestionStat(
        questionText: widget.game.questions[i].question,
        correctCount: correct,
        incorrectCount: incorrect,
        percentage: percentage,
      ));
    }

    // Histogram (assuming scores are usually 0-100 base or similar)
    List<int> bins = [0, 0, 0, 0, 0];
    for (var s in scores) {
      if (s < 20) {
        bins[0]++;
      } else if (s < 40)
        bins[1]++;
      else if (s < 60)
        bins[2]++;
      else if (s < 80)
        bins[3]++;
      else
        bins[4]++;
    }

    // Sort to find top and bottom questions
    final sortedQStats = List<QuestionStat>.from(qStats)
      ..sort((a, b) => b.percentage.compareTo(a.percentage));

    final topQ = sortedQStats.take(3).toList();
    final bottomQ = sortedQStats.reversed.take(3).toList().reversed.toList();

    // Student ranking for dash
    Map<String, AiGameResult> bestResults = {};
    for (var r in _results) {
      if (!bestResults.containsKey(r.studentId) ||
          bestResults[r.studentId]!.score < r.score) {
        bestResults[r.studentId] = r;
      }
    }
    final rankedStudents = bestResults.values.toList()
      ..sort((a, b) => b.score.compareTo(a.score));

    final topStudents = rankedStudents.take(3).toList();
    final bottomStudents = rankedStudents.length > 3
        ? rankedStudents.reversed.take(3).toList().reversed.toList()
        : <AiGameResult>[];

    return AdvancedScoreStats(
      average: avg,
      median: median,
      modes: modes,
      min: scores.first,
      max: scores.last,
      q1: q1,
      q3: q3,
      histogramBins: bins,
      totalParticipants: total,
      questionStats: qStats,
      topQuestions: topQ,
      bottomQuestions: bottomQ,
      topStudents: topStudents,
      bottomStudents: bottomStudents,
    );
  }

  Widget _buildDashboardTab() {
    if (_results.isEmpty) {
      return const Center(
          child: AiTranslatedText(
              'Sem dados suficientes para gerar o Dashboard.',
              style: TextStyle(color: Colors.white38)));
    }

    final stats = _calculateAdvancedStats();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Key Indicators
          Row(
            children: [
              Expanded(
                  child: _buildDashboardIndicator(
                      'Média Pontuação',
                      '${stats.average.toStringAsFixed(0)} pts',
                      Icons.analytics_outlined,
                      const Color(0xFF00D1FF))),
              const SizedBox(width: 12),
              Expanded(
                  child: _buildDashboardIndicator(
                      'Total Jogadas',
                      '${stats.totalParticipants}',
                      Icons.people_outline,
                      const Color(0xFF7B61FF))),
              const SizedBox(width: 12),
              Expanded(
                  child: _buildDashboardIndicator(
                      'Taxa Sucesso',
                      '${((stats.average / 100) * 100).toStringAsFixed(0)}%',
                      Icons.check_circle_outline,
                      Colors.greenAccent)),
            ],
          ),
          const SizedBox(height: 24),

          // Row 2: Student Ranking Highlights
          const AiTranslatedText('Desempenho de Alunos',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white)),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildDashboardSection(
                  title: '🏆 TOP 3 ALUNOS',
                  color: Colors.amber,
                  items: stats.topStudents
                          ?.map((s) => _buildMiniRankItem(s.studentName,
                              '${s.score.toStringAsFixed(0)} pts', true))
                          .toList() ??
                      [],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildDashboardSection(
                  title: '⚠️ NECESSITA APOIO',
                  color: Colors.redAccent,
                  items: stats.bottomStudents
                          ?.map((s) => _buildMiniRankItem(s.studentName,
                              '${s.score.toStringAsFixed(0)} pts', false))
                          .toList() ??
                      [],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Row 3: Questions Highlights
          const AiTranslatedText('Análise de Conteúdo',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white)),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildDashboardSection(
                  title: '✅ SUCESSO TOTAL',
                  color: Colors.greenAccent,
                  items: stats.topQuestions
                      .map((q) => _buildMiniRankItem(q.questionText,
                          '${q.percentage.toStringAsFixed(0)}%', true))
                      .toList(),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildDashboardSection(
                  title: '❌ LACUNAS (GAPS)',
                  color: Colors.orangeAccent,
                  items: stats.bottomQuestions
                      .map((q) => _buildMiniRankItem(q.questionText,
                          '${q.percentage.toStringAsFixed(0)}%', false))
                      .toList(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Simplified Distribution
          const AiTranslatedText('Distribuição de Performance (Geral)',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white)),
          const SizedBox(height: 12),
          GlassCard(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(stats.histogramBins.length, (i) {
                final maxVal = stats.histogramBins.isNotEmpty
                    ? stats.histogramBins.reduce((a, b) => a > b ? a : b)
                    : 1;
                final h =
                    maxVal > 0 ? (stats.histogramBins[i] / maxVal) * 100 : 5.0;
                final labels = ['0-20', '21-40', '41-60', '61-80', '81-100'];
                return Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      width: 36,
                      height: h.toDouble() + 5,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xFF00D1FF), Color(0xFF7B61FF)],
                        ),
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: [
                          BoxShadow(
                              color: const Color(0xFF00D1FF)
                                  .withValues(alpha: 0.3),
                              blurRadius: 8,
                              spreadRadius: 0),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(labels[i],
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 9)),
                  ],
                );
              }),
            ),
          ),
          const SizedBox(height: 32),

          // Shortcut to full statistics
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _tabController.animateTo(2),
              icon: const Icon(Icons.auto_awesome),
              label: const AiTranslatedText(
                  'Ver Análise Qualitativa IA e Exportar PDF'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7B61FF).withValues(alpha: 0.2),
                foregroundColor: Colors.white,
                side: const BorderSide(color: Color(0xFF7B61FF)),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildDashboardIndicator(
      String label, String value, IconData icon, Color color) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 12),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          AiTranslatedText(label,
              style: const TextStyle(color: Colors.white38, fontSize: 8),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildDashboardSection(
      {required String title,
      required Color color,
      required List<Widget> items}) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AiTranslatedText(title,
              style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5)),
          const SizedBox(height: 12),
          ...items.isEmpty
              ? [
                  const AiTranslatedText('Sem dados ainda',
                      style: TextStyle(color: Colors.white24, fontSize: 10))
                ]
              : items,
        ],
      ),
    );
  }

  Widget _buildMiniRankItem(String label, String value, bool isPositive) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 10),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 4),
          Text(value,
              style: TextStyle(
                  color: isPositive
                      ? const Color(0xFF00D1FF)
                      : Colors.orangeAccent,
                  fontSize: 10,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  void _showPdfOptionsDialog() {
    final stats = _calculateAdvancedStats();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AiTranslatedText('Exportar Relatório',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const AiTranslatedText(
                'Escolha o formato do relatório para download.',
                style: TextStyle(color: Colors.white54)),
            const SizedBox(height: 24),
            _buildPdfOption(
              icon: Icons.auto_awesome,
              title: 'Relatório Sintético (IA)',
              description:
                  'Análise qualitativa, pontos fortes/fracos e sugestões de melhoria.',
              onTap: () {
                Navigator.pop(context);
                if (_aiAnalysis == null) {
                  _generateAnalysis();
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ReportEditScreen(
                        initialContent: _aiAnalysis!,
                        title: 'Relatório Sintético: ${widget.game.title}',
                        subtitle: 'Análise Qualitativa IA',
                        stats: stats,
                      ),
                    ),
                  );
                }
              },
            ),
            const SizedBox(height: 12),
            _buildPdfOption(
              icon: Icons.table_chart,
              title: 'Relatório Detalhado',
              description:
                  'Lista completa de resultados individuais e desempenho por questão.',
              onTap: () async {
                Navigator.pop(context);
                final detailedContent = _generateDetailedText();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ReportEditScreen(
                      initialContent: detailedContent,
                      title: 'Relatório Detalhado: ${widget.game.title}',
                      subtitle: 'Resultados Quantitativos por Aluno',
                      isSynthetic: false,
                      stats: stats,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  String _generateDetailedText() {
    String text = 'Total de Jogadas: ${_results.length}\n';
    double avg =
        _results.map((r) => r.score).reduce((a, b) => a + b) / _results.length;
    text += 'Média Global: ${avg.toStringAsFixed(1)} pts\n\n';
    text += '--- RESULTADOS POR ALUNO ---\n';

    final sorted = List<AiGameResult>.from(_results)
      ..sort((a, b) => b.score.compareTo(a.score));
    for (var r in sorted) {
      text +=
          '- ${r.studentName}: ${r.score.toStringAsFixed(0)} pts (${DateFormat('dd/MM HH:mm').format(r.playedAt)})\n';
    }

    text += '\n--- DESEMPENHO POR QUESTÃO ---\n';
    for (int i = 0; i < widget.game.questions.length; i++) {
      int correct = 0;
      for (var r in _results) {
        if (r.correctAnswers.contains(i)) correct++;
      }
      double ratio = (correct / _results.length) * 100;
      text +=
          'P${i + 1} (${widget.game.questions[i].question}): ${ratio.toStringAsFixed(0)}% de Acerto\n';
    }

    return text;
  }

  Widget _buildPdfOption(
      {required IconData icon,
      required String title,
      required String description,
      required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF00D1FF), size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AiTranslatedText(title,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  AiTranslatedText(description,
                      style:
                          const TextStyle(color: Colors.white54, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white24),
          ],
        ),
      ),
    );
  }
}
